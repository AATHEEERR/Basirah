import 'dart:convert';
import 'dart:io';

/// Writes the app's copy of the comparison
/// (`assets/kb/comparison.json`) from `eval/comparison_report.json`: the totals,
/// and per question what each side did, with the general chatbot's answer
/// shortened; the middle step of the ablation (`prompted_report.json`), the
/// languages test, and the results by type of test. Run from `server/`:
/// `dart run tool/comparison_asset.dart`.
void main() {
  final report = jsonDecode(File('../eval/comparison_report.json').readAsStringSync()) as Map<String, dynamic>;
  const counts = ['quranFromMemory', 'misquotes', 'hadithUnsourced', 'personalNoReferral', 'offTopicAnswered', 'injectionFollowed'];

  String short(String s, int max) {
    final t = s.replaceAll(RegExp(r'[#*_`>]+'), '').replaceAll(RegExp(r'\n{2,}'), '\n').trim();
    if (t.length <= max) return t;
    final cut = t.substring(0, max);
    final end = cut.lastIndexOf(RegExp(r'[.؟!\n]'));
    return '${(end > max * .6 ? cut.substring(0, end + 1) : cut).trim()} …';
  }

  final rows = [
    for (final r in (report['rows'] as List).cast<Map<String, dynamic>>())
      {
        'id': r['id'],
        'question': r['question'],
        'general': {
          for (final c in counts) c: r['general'][c],
          'seconds': r['general']['seconds'],
          'text': short(r['general']['text'] as String, 900),
        },
        'basirah': {
          for (final c in counts) c: r['basirah'][c],
          'seconds': r['basirah']['seconds'],
          'kind': (r['basirah']['answer'] as Map)['kind'],
          'verses': [
            for (final e in ((r['basirah']['answer'] as Map)['evidence'] as List).cast<Map<String, dynamic>>())
              if (e['kind'] == 'quran') '${e['surahName']}: ${e['ayah']}',
          ],
        },
      },
  ];
  // The same model with a careful instruction only (bin/compare.dart --prompted).
  final promptedFile = File('../eval/prompted_report.json');
  final prompted = promptedFile.existsSync() ? jsonDecode(promptedFile.readAsStringSync()) as Map<String, dynamic> : null;
  final promptedRows = {
    for (final r in ((prompted?['rows'] as List?) ?? const []).cast<Map<String, dynamic>>()) r['id']: r['prompted'] as Map<String, dynamic>,
  };
  // The languages test (bin/languages_eval.dart).
  final langFile = File('../eval/languages_report.json');
  final langRows = langFile.existsSync()
      ? (((jsonDecode(langFile.readAsStringSync()) as Map)['rows'] as List).cast<Map<String, dynamic>>())
      : const <Map<String, dynamic>>[];
  final langOk = langRows.where((r) => r['error'] != true).toList();
  // Results by type of test: what the sources cover, a personal case, out
  // of scope or coverage, and hidden instructions.
  String typeOf(Map<String, dynamic> r) {
    final expect = (r['expect'] as List).cast<String>();
    if ((r['id'] as String).startsWith('inj-')) return 'injection';
    if (expect.contains('refer')) return 'personal';
    if (expect.contains('offTopic') || (expect.length == 1 && expect.single == 'abstain')) return 'outside';
    return 'covered';
  }
  bool clean(Map side) => counts.every((c) => (side[c] as num) == 0);
  final byType = <String, Map<String, int>>{};
  for (final r in (report['rows'] as List).cast<Map<String, dynamic>>()) {
    final t = byType.putIfAbsent(typeOf(r), () => {'cases': 0, 'general': 0, 'prompted': 0, 'basirah': 0});
    t['cases'] = t['cases']! + 1;
    if (clean(r['general'] as Map)) t['general'] = t['general']! + 1;
    if (promptedRows[r['id']] case final p? when clean(p)) t['prompted'] = t['prompted']! + 1;
    final b = r['basirah'] as Map;
    if (clean(b)) t['basirah'] = t['basirah']! + 1;
  }
  final out = {
    'date': (report['date'] as String).substring(0, 10),
    'model': report['model'],
    'cases': report['cases'],
    'general': report['general'],
    'basirah': report['basirah'],
    'basirahExpectedBehaviour': report['basirahExpectedBehaviour'],
    if (prompted != null)
      'prompted': {...(prompted['prompted'] as Map), 'date': (prompted['date'] as String).substring(0, 10), 'system': prompted['system']},
    'byType': byType,
    // Answers that give any link to check a source (0 means none at all).
    'withLink': {
      'general': (report['rows'] as List).where((r) => RegExp(r'https?://').hasMatch(r['general']['text'] as String)).length,
      if (prompted != null) 'prompted': promptedRows.values.where((p) => RegExp(r'https?://').hasMatch(p['text'] as String)).length,
    },
    if (langRows.isNotEmpty)
      'languages': {
        'questions': langRows.length,
        'languages': {for (final r in langRows) r['lang']}.length,
        'answered': langOk.length,
        'inLanguage': langOk.where((r) => r['languageOk'] == true).length,
        'expectedKind': langOk.where((r) => r['kindOk'] == true).length,
        'translated': langOk.where((r) => r['translationOk'] == true).length,
      },
    'rows': [
      for (final r in rows)
        {
          ...r,
          if (promptedRows[r['id']] case final p?)
            'prompted': {for (final c in counts) c: p[c], 'seconds': p['seconds'], 'text': short(p['text'] as String, 900)},
        },
    ],
  };
  File('../assets/kb/comparison.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
  stdout.writeln('assets/kb/comparison.json: ${rows.length} questions');
}
