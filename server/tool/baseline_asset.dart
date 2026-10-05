import 'dart:convert';
import 'dart:io';

/// Writes the app's copy of the baseline comparison
/// (`assets/kb/baseline.json`) from `eval/baseline_report.json`: the totals,
/// and per question what each side did, with the general chatbot's answer
/// shortened. Run from `server/`: `dart run tool/baseline_asset.dart`.
void main() {
  final report = jsonDecode(File('../eval/baseline_report.json').readAsStringSync()) as Map<String, dynamic>;
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
  final out = {
    'date': (report['date'] as String).substring(0, 10),
    'model': report['model'],
    'cases': report['cases'],
    'general': report['general'],
    'basirah': report['basirah'],
    'basirahExpectedBehaviour': report['basirahExpectedBehaviour'],
    'rows': rows,
  };
  File('../assets/kb/baseline.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
  stdout.writeln('assets/kb/baseline.json: ${rows.length} questions');
}
