import 'dart:convert';
import 'dart:io';

import 'package:basirah_core/basirah_core.dart';
import 'package:basirah_server/basirah_server.dart';

/// Runs eval/test_cases.json through the full pipeline and prints a report.
///
///   dart run bin/eval.dart            # curated + offline router only (free)
///   dart run bin/eval.dart --ai       # every case researched live by the
///                                     # configured model (Gemini or Claude,
///                                     # see lib/src/providers.dart)
///   dart run bin/eval.dart --ai --out ../eval/report.json
///                                     # also saves every answer for review
///   dart run bin/eval.dart --ai --only inj-
///                                     # only the cases whose id starts so
///
/// A case passes when the answer's kind is one of `expectKind` and none of
/// its `forbid` phrases (compared without diacritics or spaces) appears in
/// the answer's content: principle, culture, guidance and the khilaf texts.
Future<void> main(List<String> args) async {
  final useAi = args.contains('--ai');
  final outIndex = args.indexOf('--out');
  final outPath = outIndex >= 0 && outIndex + 1 < args.length ? args[outIndex + 1] : null;
  final onlyIndex = args.indexOf('--only');
  final only = onlyIndex >= 0 && onlyIndex + 1 < args.length ? args[onlyIndex + 1] : null;
  final env = loadEnv();
  final kb = loadKnowledgeBase(env['KB_DIR'] ?? '../assets/kb');
  final llms = useAi ? llmsFromEnv(env) : const <LlmClient>[];
  final llm = llms.firstOrNull;
  if (useAi && llm == null) {
    stderr.writeln('--ai needs GEMINI_API_KEY or ANTHROPIC_API_KEY (in server/.env or the environment)');
    exit(2);
  }
  final quran = useAi ? QuranLibrary.tryLoad(env['QURAN_FILE'] ?? 'data/quran.json') : null;
  if (useAi && quran == null) {
    stderr.writeln('data/quran.json missing — run: dart run tool/fetch_quran.dart');
    exit(2);
  }
  final pipeline = AskPipeline(kb, llm: llm, fallbacks: llms.skip(1).toList(), quran: quran, hadith: useAi ? HadeethEnc() : null);
  final report = <Map<String, dynamic>>[];

  final cases = [
    for (final c in ((jsonDecode(File('../eval/test_cases.json').readAsStringSync())
            as Map<String, dynamic>)['cases'] as List).cast<Map<String, dynamic>>())
      if (only == null || (c['id'] as String).startsWith(only)) c,
  ];
  String compact(String s) => normalizeArabic(s).replaceAll(' ', '');
  var passed = 0;
  final rows = <String>[];
  for (final c in cases) {
    final q = c['question'] as String;
    final expect = (c['expectKind'] as List).cast<String>();
    final sw = Stopwatch()..start();
    final r = await pipeline.ask(q, mode: useAi ? AskMode.live : AskMode.kb);
    final a = r.answer;
    final content = compact([a.principle, a.culture, ...a.guidance, a.khilafAgreed, a.khilafNote].join(' '));
    final found = [
      for (final f in ((c['forbid'] as List?) ?? const []).cast<String>())
        if (content.contains(compact(f))) f,
    ];
    final ok = expect.contains(a.kind.name) && found.isEmpty;
    if (ok) passed++;
    final row =
        '${ok ? 'PASS' : 'FAIL'}  ${c['id']}  via=${r.via.name}  '
        'kind=${r.answer.kind.name}/${r.answer.level.code}  expect=${expect.join('|')}  '
        '${found.isEmpty ? '' : 'forbidden=${found.join(' | ')}  '}'
        'evidence=${r.answer.evidence.map((e) => e.isQuran ? e.reference : e.id).join(', ')}'
        '${useAi ? '  ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s' : ''}'
        '${r.guardActions.isEmpty ? '' : '  guard=${r.guardActions.join('; ')}'}';
    rows.add(row);
    if (useAi) stdout.writeln(row);
    report.add({
      'id': c['id'],
      'question': q,
      'expect': expect,
      if (found.isNotEmpty) 'forbiddenFound': found,
      'pass': ok,
      'via': r.via.name,
      'model': r.answer.model,
      'seconds': sw.elapsedMilliseconds / 1000,
      'guard': r.guardActions,
      'usage': r.usage,
      'answer': r.answer.toJson(),
    });
  }
  if (!useAi) rows.forEach(stdout.writeln);
  final mode = useAi ? 'live ${llm!.provider}: ${llms.map((m) => m.model).join(' → ')}' : 'offline';
  final live = report.where((c) => c['via'] == 'ai').length;
  if (useAi) stdout.writeln('\nAnswered by the model: $live of ${cases.length} (the rest: offline fallback or scope check)');
  stdout.writeln('\n$passed/${cases.length} passed ($mode mode)');
  if (outPath != null) {
    File(outPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'mode': mode,
        'date': DateTime.now().toIso8601String(),
        'passed': passed,
        'total': cases.length,
        'cases': report,
      }),
    );
    stdout.writeln('Saved $outPath');
  }
  for (final m in llms) {
    m.close();
  }
  exit(passed == cases.length ? 0 : 1);
}
