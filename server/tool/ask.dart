import 'dart:convert';
import 'dart:io';

import 'package:basirah_server/basirah_server.dart';

/// Asks one question through the full live pipeline and prints the result.
///
///   dart run tool/ask.dart "هل يجوز أكل الجمبري؟"
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/ask.dart "<question>"');
    exit(2);
  }
  final env = loadEnv();
  final llms = llmsFromEnv(env);
  if (llms.isEmpty) {
    stderr.writeln('No GEMINI_API_KEY / ANTHROPIC_API_KEY in server/.env');
    exit(2);
  }
  final pipeline = AskPipeline(
    loadKnowledgeBase(env['KB_DIR'] ?? '../assets/kb'),
    llm: llms.first,
    fallbacks: llms.skip(1).toList(),
    quran: QuranLibrary.tryLoad(env['QURAN_FILE'] ?? 'data/quran.json'),
  );
  final sw = Stopwatch()..start();
  final r = await pipeline.ask(args.join(' '));
  final a = r.answer;
  stdout.writeln(const JsonEncoder.withIndent('  ').convert({
    'model': a.model,
    'seconds': sw.elapsedMilliseconds / 1000,
    'via': r.via.name,
    'notice': r.notice,
    'kind': a.kind.name,
    'level': a.level.code,
    'principle': a.principle,
    'culture': a.culture,
    'khilaf': [a.khilafAgreed, a.khilafNote].where((s) => s.isNotEmpty).toList(),
    'refer': [a.referReason, a.referTo].where((s) => s.isNotEmpty).toList(),
    'abstain': a.abstainReason,
    'guidance': a.guidance,
    'evidence': [
      for (final e in a.evidence)
        e.isQuran ? {'verse': e.reference, 'why': e.note, 'tafsir': e.tafsir} : {'hadith': e.id, 'source': e.source},
    ],
    'research': a.research,
    'guard': r.guardActions,
    'usage': r.usage,
  }));
  for (final m in llms) {
    m.close();
  }
}
