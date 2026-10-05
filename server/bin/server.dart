import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:basirah_core/basirah_core.dart';
import 'package:basirah_server/basirah_server.dart';
import 'package:http/http.dart' as http;
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
///   WEB_DIR            optional: the web app's build, served on the same link
///   METRICS_FILE       anonymous usage + ratings (default cache/metrics.jsonl)
///   REFERRALS_FILE     requests to a specialist (default cache/referrals.json)
///   SPECIALIST_KEY     opens the specialists' panel (16+ characters; closed without it)
///   NOTIFY_WEBHOOK     optional Slack/Discord webhook told of each new request (code only)
///   PORT               default 8080
Future<void> main() async {
  final env = loadEnv();
  final kbDir = env['KB_DIR'] ?? '../assets/kb';
  final kb = loadKnowledgeBase(kbDir);

  final quranFile = env['QURAN_FILE'] ?? 'data/quran.json';
  if (!File(quranFile).existsSync()) {
    stdout.writeln('Quran dataset missing — downloading it once from QuranEnc and Quranpedia …');
    try {
      stdout.writeln(await fetchQuranDataset(quranFile));
    } on Exception catch (e) {
      stdout.writeln('Could not build the Quran dataset ($e). Live answers will not cite verses.');
    }
  }
  final quran = QuranLibrary.tryLoad(quranFile);

  final llms = llmsFromEnv(env);
  final llm = llms.firstOrNull;
  final meaning = MeaningSource();
  final pipeline = AskPipeline(
    kb,
    llm: llm,
    fallbacks: llms.skip(1).toList(),
    quran: quran,
    hadith: HadeethEnc(),
    cache: AnswerCache(),
    meaning: meaning,
  );
  final limiter = RateLimiter();
  final verseAudio = VerseAudioSource();
  final library = IslamHouseLibrary();
  final origin = env['ALLOWED_ORIGIN'] ?? '*';
  final metrics = Metrics(file: env['METRICS_FILE'] ?? 'cache/metrics.jsonl');
  final referrals = Referrals(file: env['REFERRALS_FILE'] ?? 'cache/referrals.json');
  // Without a key of at least 16 characters the specialists' panel is closed.
  final specialistKey = (env['SPECIALIST_KEY'] ?? '').length >= 16 ? env['SPECIALIST_KEY'] : null;
  // Optional: a Slack or Discord webhook told of every new request.
  final notifyWebhook = (env['NOTIFY_WEBHOOK'] ?? '').startsWith('https://') ? env['NOTIFY_WEBHOOK'] : null;
  // A new server (e.g. the first start on Render) continues the counts
  // gathered so far (METRICS_SEED: anonymous counts only, kept in git).
  if (env['METRICS_SEED'] case final seed? when metrics.seedFrom(seed)) {
    stdout.writeln('«لوحة الأثر»: continued from $seed');
  }

  final app = Router()
    ..get(
      '/health',
      (Request _) => _json({
        'ok': true,
        'kbVersion': kb.version,
        'entries': kb.entries.length,
        'evidence': kb.evidence.length,
        'ai': pipeline.aiEnabled,
        'provider': llm?.provider,
        'model': llm?.model,
        'models': [for (final m in llms) m.model],
        'quranVerses': quran?.length ?? 0,
        'tafsir': quran == null ? null : ['موسوعة التفسير — الدرر السنية'],
      }),
    )
    // «اسمعها بلغتك»: a verse's approved translation, text and recorded voice,
    // from موسوعة القرآن الكريم: GET /api/meaning?key=60:8&to=9&lang=tagalog_rwwad
    // (without `lang`: the list of languages).
    ..get('/api/meaning', (Request req) async {
      final q = req.url.queryParameters;
      final languages = [for (final l in meaningLanguages) l.toJson()];
      final lang = meaningLanguages.where((l) => l.key == q['lang']).firstOrNull;
      if (lang == null) return _json({'languages': languages});
      final key = quran?.parseRef(q['key'] ?? '');
      if (key == null) return _json({'error': 'unknown verse'}, status: 400);
      final surah = int.parse(key.split(':')[0]);
      final first = int.parse(key.split(':')[1]);
      final lastKey = q['to'] == null ? key : quran?.parseRef('$surah:${q['to']}');
      final last = lastKey == null ? first : int.parse(lastKey.split(':')[1]);
      if (last < first || last - first >= 20) return _json({'error': 'range'}, status: 400);
      final verses = await Future.wait([for (var a = first; a <= last; a++) meaning.verse(surah, a, lang)]);
      if (verses.any((v) => v == null)) return _json({'error': 'unavailable'}, status: 503);
      return _json({
        'language': lang.toJson(),
        'title': await meaning.title(lang),
        'verses': [for (final v in verses) v!.toJson()],
        'languages': languages,
      });
    })
    // «تعلّم أكثر بلغتك»: the association's own introductions to Islam on
    // IslamHouse in a language, via its MCP server: GET /api/islamhouse?lang=fr
    ..get('/api/islamhouse', (Request req) async {
      final iso = req.url.queryParameters['lang'] ?? '';
      final items = await library.forLanguage(iso);
      return _json({
        'items': [for (final i in items) i.toJson()],
        'library': 'https://islamhouse.com/$iso/main/',
      });
    })
    // Verse recitation, one MP3 per verse from the association's MCP server:
    // GET /api/recitation?key=2:186&to=187&reciter=husary
    ..get('/api/recitation', (Request req) async {
      final q = req.url.queryParameters;
      final key = quran?.parseRef(q['key'] ?? '');
      if (key == null) return _json({'error': 'unknown verse'}, status: 400);
      final parts = key.split(':');
      final surah = int.parse(parts[0]);
      final first = int.parse(parts[1]);
      final lastKey = q['to'] == null ? key : quran?.parseRef('$surah:${q['to']}');
      final last = lastKey == null ? first : int.parse(lastKey.split(':')[1]);
      if (last < first || last - first >= 20) return _json({'error': 'range'}, status: 400);
      final reciter = verseReciters.where((r) => r.id == q['reciter']).firstOrNull ?? verseReciters.first;
      final urls = await Future.wait([for (var a = first; a <= last; a++) verseAudio.url(surah, a, reciter: reciter.id)]);
      if (urls.any((u) => u == null)) return _json({'error': 'unavailable'}, status: 503);
      return _json({
        'verses': [for (var i = 0; i < urls.length; i++) {'ayah': first + i, 'url': urls[i]}],
        'reciter': reciter.toJson(),
        'reciters': [for (final r in verseReciters) r.toJson()],
        'teacherUrl': teacherUrl(surah),
      });
    })
    ..post('/api/ask', (Request req) async {
      final ip =
          req.headers['x-forwarded-for']?.split(',').first.trim() ??
          (req.context['shelf.io.connection_info'] as HttpConnectionInfo?)?.remoteAddress.address ??
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

      // «سياقي»: fixed choices only; unknown values are dropped. Not logged.
      final asker = AskerContext.fromJson(body['context']);

      final started = DateTime.now();
      final result = await pipeline.ask(
        question,
        categoryId: kb.category(categoryId ?? '') == null ? null : categoryId,
        mode: mode,
        history: history,
        asker: asker,
      );

      // Privacy: log metadata only — never the question text.
      stdout.writeln(
        jsonEncode({
          't': started.toUtc().toIso8601String(),
          'via': result.via.name,
          'kind': result.answer.kind.name,
          'level': result.answer.level.code,
          'entry': result.answer.entryId,
          'verses': [
            for (final e in result.answer.evidence)
              if (e.isQuran) e.reference,
          ],
          'research': result.answer.research.length,
          'turns': history.length,
          'cached': result.guardActions.contains(AskPipeline.cachedAction),
          'ms': DateTime.now().difference(started).inMilliseconds,
          'guard': result.guardActions,
          'cacheRead': result.usage['cache_read_input_tokens'],
        }),
      );
      // «لوحة الأثر»: the same metadata, anonymous (see Metrics). The team's
      // own test runs (bin/languages_eval.dart) say so and are not counted.
      final a = result.answer;
      if (req.headers['x-basirah-test'] != '1') metrics.recordAsk(
        kind: a.kind.name,
        via: result.via.name,
        cached: result.guardActions.contains(AskPipeline.cachedAction),
        ms: DateTime.now().difference(started).inMilliseconds,
        verses: a.evidence.where((e) => e.isQuran).length,
        hadith: a.evidence.where((e) => !e.isQuran).length,
        guardCatches: result.guardActions.where(isGuardIntervention).length,
        lang: RegExp('[؀-ۿ]').hasMatch(question) ? 'ar' : 'en',
        category: a.entryId == null ? null : kb.entry(a.entryId!)?.categoryId,
      );
      return _json(result.toJson());
    })
    // A rating from the button under an answer: fixed choices only.
    ..post('/api/feedback', (Request req) async {
      final ip =
          req.headers['x-forwarded-for']?.split(',').first.trim() ??
          (req.context['shelf.io.connection_info'] as HttpConnectionInfo?)?.remoteAddress.address ??
          'unknown';
      if (!limiter.allow(ip)) return _json({'error': 'rate_limited'}, status: 429);
      try {
        final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
        final ok = metrics.recordFeedback(
          helpful: body['helpful'] as bool,
          reasons: [for (final r in body['reasons'] as List? ?? const []) r as String],
          kind: body['kind'] as String,
          lang: body['lang'] as String,
          category: body['category'] as String?,
        );
        return ok ? _json({'ok': true}) : _json({'error': 'invalid'}, status: 400);
      } on Object {
        return _json({'error': 'invalid'}, status: 400);
      }
    })
    // «لوحة الأثر»: totals only.
    ..get('/api/stats', (Request _) => _json(metrics.summary()))
    // «تحدّث مع مختص شرعي»: the asker sends what they approved; they read
    // the reply back with the token kept on their device.
    ..post('/api/referral', (Request req) async {
      if (!limiter.allow('referral:${_ip(req)}')) return _json({'error': 'rate_limited'}, status: 429);
      try {
        final b = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
        if (b['consent'] != true) return _json({'error': 'consent'}, status: 400);
        final r = referrals.create(
          question: b['question'] as String? ?? '',
          conversation: b['conversation'] as String? ?? '',
          context: b['context'] as String? ?? '',
          lang: b['lang'] as String? ?? 'ar',
          mode: b['mode'] as String? ?? 'message',
          slot: b['slot'] == null ? null : DateTime.tryParse(b['slot'] as String),
        );
        if (r == null) return _json({'error': 'invalid'}, status: 400);
        stdout.writeln(jsonEncode({'t': DateTime.now().toUtc().toIso8601String(), 'referral': r['mode']}));
        // Tell the team (NOTIFY_WEBHOOK: a Slack or Discord incoming webhook):
        // the code and the kind only — the question stays on the server and
        // is read in the panel.
        if (notifyWebhook != null) {
          final text =
              'بصيرة: طلب جديد إلى مختص شرعي · ${r['id']} · ${r['mode']}${r['slot'] == null ? '' : ' · ${r['slot']}'}\n'
              'افتح لوحة المختصين: ${req.requestedUri.origin}/#/specialist';
          unawaited(
            http
                .post(Uri.parse(notifyWebhook), headers: {'content-type': 'application/json'}, body: jsonEncode({'text': text, 'content': text}))
                .timeout(const Duration(seconds: 10))
                .then((_) {}, onError: (Object e) => stderr.writeln('notify: $e')),
          );
        }
        return _json({'id': r['id'], 'token': r['token'], 'meetUrl': r['meetUrl'], 'slot': r['slot']});
      } on Object {
        return _json({'error': 'invalid'}, status: 400);
      }
    })
    ..get('/api/referral/<id>', (Request req, String id) {
      final r = referrals.forAsker(id, req.url.queryParameters['token'] ?? '');
      return r == null ? _json({'error': 'not_found'}, status: 404) : _json(r);
    })
    ..post('/api/referral/<id>/message', (Request req, String id) async {
      if (!limiter.allow('referral:${_ip(req)}')) return _json({'error': 'rate_limited'}, status: 429);
      try {
        final b = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
        final ok = referrals.askerMessage(id, b['token'] as String? ?? '', b['text'] as String? ?? '');
        return ok ? _json({'ok': true}) : _json({'error': 'invalid'}, status: 400);
      } on Object {
        return _json({'error': 'invalid'}, status: 400);
      }
    })
    // The specialists' panel: only with the SPECIALIST_KEY header.
    ..get('/api/specialist/referrals', (Request req) {
      if (!_specialist(req, specialistKey)) return _json({'error': 'forbidden'}, status: 403);
      return _json({'referrals': referrals.all()});
    })
    ..post('/api/specialist/referrals/<id>', (Request req, String id) async {
      if (!_specialist(req, specialistKey)) return _json({'error': 'forbidden'}, status: 403);
      try {
        final b = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
        final ok = referrals.reply(id, text: b['text'] as String? ?? '', status: b['status'] as String?);
        return ok ? _json({'ok': true}) : _json({'error': 'invalid'}, status: 400);
      } on Object {
        return _json({'error': 'invalid'}, status: 400);
      }
    });

  // One deployment can serve the web app too (WEB_DIR = the Flutter web
  // build): every path the API does not answer is a file of the app.
  final webDir = env['WEB_DIR'];
  final routes = webDir != null && Directory(webDir).existsSync() ? Cascade().add(app.call).add(webAppHandler(webDir)).handler : app.call;
  final handler = const Pipeline().addMiddleware(_cors(origin)).addHandler(routes);

  final port = int.tryParse(env['PORT'] ?? '') ?? 8080;
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln(
    'Basirah API on :${server.port} — kb ${kb.version} '
    '(${kb.entries.length} entries), quran=${quran?.length ?? 0} verses, ai=${pipeline.aiEnabled}'
    '${llm != null ? ' (${llm.provider}: ${llms.map((m) => m.model).join(' → ')})' : ' — no GEMINI_API_KEY / ANTHROPIC_API_KEY: curated + offline answers only'}',
  );
}

String _ip(Request req) =>
    req.headers['x-forwarded-for']?.split(',').first.trim() ??
    (req.context['shelf.io.connection_info'] as HttpConnectionInfo?)?.remoteAddress.address ??
    'unknown';

/// The specialists' panel sends the key in `x-specialist-key`.
bool _specialist(Request req, String? key) {
  final given = req.headers['x-specialist-key'] ?? '';
  if (key == null || given.length != key.length) return false;
  var diff = 0;
  for (var i = 0; i < key.length; i++) {
    diff |= key.codeUnitAt(i) ^ given.codeUnitAt(i);
  }
  return diff == 0;
}

Response _json(Object body, {int status = 200}) =>
    Response(status, body: jsonEncode(body), headers: {'content-type': 'application/json; charset=utf-8'});

Middleware _cors(String origin) {
  final headers = {
    'access-control-allow-origin': origin,
    'access-control-allow-methods': 'GET, POST, OPTIONS',
    'access-control-allow-headers': 'content-type, x-specialist-key',
    'access-control-max-age': '86400',
    // Not for search engines: the link is shared by hand only.
    'x-robots-tag': 'noindex, nofollow',
  };
  return (inner) => (req) async {
    if (req.method == 'OPTIONS') return Response.ok('', headers: headers);
    final res = await inner(req);
    return res.change(headers: headers);
  };
}
