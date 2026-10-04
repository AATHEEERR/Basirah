import 'dart:convert';
import 'dart:io';

import 'package:basirah_server/basirah_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

/// Environment (process env, or a local `server/.env` — see `.env.example`):
///   GEMINI_API_KEY or ANTHROPIC_API_KEY enable the AI layer (otherwise
///   curated + offline answers only); AI_PROVIDER, GEMINI_MODEL,
///   GEMINI_THINKING, CLAUDE_MODEL, CLAUDE_EFFORT, CLAUDE_FALLBACKS and
///   ANTHROPIC_BASE_URL are described in lib/src/providers.dart
///   KB_DIR             default ../assets/kb
///   QURAN_FILE         default data/quran.json (built on first start if missing)
///   ALLOWED_ORIGIN     CORS origin, default *
///   PORT               default 8080
Future<void> main() async {
  final env = loadEnv();
  final kbDir = env['KB_DIR'] ?? '../assets/kb';
  final kb = loadKnowledgeBase(kbDir);

  final quranFile = env['QURAN_FILE'] ?? 'data/quran.json';
  if (!File(quranFile).existsSync()) {
    stdout.writeln('Quran dataset missing — downloading it once from api.quran.com …');
    try {
      stdout.writeln(await fetchQuranDataset(quranFile));
    } on Exception catch (e) {
      stdout.writeln('Could not build the Quran dataset ($e). Live answers will not cite verses.');
    }
  }
  final quran = QuranLibrary.tryLoad(quranFile);

  final llms = llmsFromEnv(env);
  final llm = llms.firstOrNull;
  final pipeline = AskPipeline(kb, llm: llm, fallbacks: llms.skip(1).toList(), quran: quran);
  final limiter = RateLimiter();
  final origin = env['ALLOWED_ORIGIN'] ?? '*';

  final app = Router()
    ..get('/health', (Request _) => _json({
          'ok': true,
          'kbVersion': kb.version,
          'entries': kb.entries.length,
          'evidence': kb.evidence.length,
          'ai': pipeline.aiEnabled,
          'provider': llm?.provider,
          'model': llm?.model,
          'models': [for (final m in llms) m.model],
          'quranVerses': quran?.length ?? 0,
          'tafsir': quran == null ? null : ['تفسير الطبري'],
        }))
    ..post('/api/ask', (Request req) async {
      final ip = req.headers['x-forwarded-for']?.split(',').first.trim() ??
          (req.context['shelf.io.connection_info'] as HttpConnectionInfo?)
              ?.remoteAddress
              .address ??
          'unknown';
      if (!limiter.allow(ip)) {
        return _json({'error': 'rate_limited'}, status: 429);
      }

      final Map<String, dynamic> body;
      try {
        body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      } on FormatException {
        return _json({'error': 'invalid_json'}, status: 400);
      }
      final question = (body['question'] as String?)?.trim() ?? '';
      if (question.isEmpty || question.length > 600) {
        return _json({'error': 'question must be 1–600 characters'}, status: 400);
      }
      final categoryId = body['categoryId'] as String?;
      final mode = body['mode'] == 'kb' ? AskMode.kb : AskMode.live;
      final history = [
        for (final t in (body['history'] as List? ?? const []).take(4))
          if (t is Map<String, dynamic>) Turn.fromJson(t),
      ];

      final started = DateTime.now();
      final result = await pipeline.ask(
        question,
        categoryId: kb.category(categoryId ?? '') == null ? null : categoryId,
        mode: mode,
        history: history,
      );

      // Privacy: log metadata only — never the question text.
      stdout.writeln(jsonEncode({
        't': started.toUtc().toIso8601String(),
        'via': result.via.name,
        'kind': result.answer.kind.name,
        'level': result.answer.level.code,
        'entry': result.answer.entryId,
        'verses': [for (final e in result.answer.evidence) if (e.isQuran) e.reference],
        'research': result.answer.research.length,
        'turns': history.length,
        'ms': DateTime.now().difference(started).inMilliseconds,
        'guard': result.guardActions,
        'cacheRead': result.usage['cache_read_input_tokens'],
      }));
      return _json(result.toJson());
    });

  final handler = const Pipeline()
      .addMiddleware(_cors(origin))
      .addHandler(app.call);

  final port = int.tryParse(env['PORT'] ?? '') ?? 8080;
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln(
    'Basirah API on :${server.port} — kb ${kb.version} '
    '(${kb.entries.length} entries), quran=${quran?.length ?? 0} verses, ai=${pipeline.aiEnabled}'
    '${llm != null ? ' (${llm.provider}: ${llms.map((m) => m.model).join(' → ')})' : ' — no GEMINI_API_KEY / ANTHROPIC_API_KEY: curated + offline answers only'}',
  );
}

Response _json(Object body, {int status = 200}) => Response(
  status,
  body: jsonEncode(body),
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Middleware _cors(String origin) {
  final headers = {
    'access-control-allow-origin': origin,
    'access-control-allow-methods': 'GET, POST, OPTIONS',
    'access-control-allow-headers': 'content-type',
    'access-control-max-age': '86400',
  };
  return (inner) => (req) async {
    if (req.method == 'OPTIONS') return Response.ok('', headers: headers);
    final res = await inner(req);
    return res.change(headers: headers);
  };
}
