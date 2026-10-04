import 'dart:convert';
import 'dart:io';

import 'package:basirah_core/basirah_core.dart';
import 'package:basirah_server/basirah_server.dart';

/// Asks one question through the full live pipeline and prints the result.
///
///   dart run tool/ask.dart "هل يجوز أكل الجمبري؟"
///   dart run tool/ask.dart --context role=exploring,style=simple "ما معنى التوحيد؟"
///
/// --context takes «سياقي» choices (role, since, setting, style), e.g. for
/// the demo that compares one question asked from two contexts.
Future<void> main(List<String> args) async {
  var asker = AskerContext.none;
  final rest = [...args];
  final i = rest.indexOf('--context');
  if (i >= 0 && i + 1 < rest.length) {
    asker = AskerContext.fromJson({
      for (final kv in rest[i + 1].split(','))
        if (kv.split('=') case [final k, final v]) k.trim(): v.trim(),
    });
    rest.removeRange(i, i + 2);
  }
  if (rest.isEmpty) {
    stderr.writeln('usage: dart run tool/ask.dart [--context role=…,setting=…,style=…] "<question>"');
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
    hadith: HadeethEnc(),
  );
  final sw = Stopwatch()..start();
  final r = await pipeline.ask(rest.join(' '), asker: asker);
  final a = r.answer;
  stdout.writeln(const JsonEncoder.withIndent('  ').convert({
    'model': a.model,
    'seconds': sw.elapsedMilliseconds / 1000,
    'context': asker.describe(),
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
        e.isQuran
            ? {'verse': e.reference, 'why': e.note, 'tafsir': e.tafsir}
            : {'hadith': e.id, 'source': e.source, 'grade': e.grade, 'why': e.note},
    ],
    'research': a.research,
    'guard': r.guardActions,
    'usage': r.usage,
  }));
  for (final m in llms) {
    m.close();
  }
}
