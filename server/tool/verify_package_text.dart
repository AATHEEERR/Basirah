import 'dart:convert';
import 'dart:io';

/// Checks, character by character, that every text Basirah quotes from the
/// approved reference document (its updated
/// edition) appears in it verbatim: assets/kb/reference.json
/// (levels, sources, standards, glossary, platforms) and the official test
/// situations in eval/test_cases.json.
///
/// The pack's text is extracted with PDF.js (logical order); the PDF stores
/// no spaces between words, mirrors brackets and maps the lam-alef ligature
/// as «ال». So both sides are compared without spaces, brackets or tatweel,
/// and Basirah's side gets the same lam-alef mapping. Every letter, mark and
/// punctuation sign is still compared.
///
///   dart run tool/verify_package_text.dart <extracted-pack.txt>
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/verify_package_text.dart <extracted-pack.txt>');
    exit(2);
  }
  final pack = _pack(File(args.first).readAsStringSync());
  final ref = jsonDecode(File('../assets/kb/reference.json').readAsStringSync()) as Map<String, dynamic>;
  final checks = <(String, String)>[];
  for (final l in ref['levels'] as List) {
    checks
      ..add(('level ${l['level']} title', l['title'] as String))
      ..add(('level ${l['level']} scope', l['scope'] as String))
      ..add(('level ${l['level']} handling', l['handling'] as String));
  }
  for (final s in ref['sources'] as List) {
    checks
      ..add(('source «${s['field']}» field', s['field'] as String))
      ..add(('source «${s['field']}» content', s['content'] as String))
      ..add(('source «${s['field']}» rule', s['rule'] as String));
  }
  for (final s in ref['standards'] as List) {
    checks
      ..add(('standard «${s['title']}» title', s['title'] as String))
      ..add(('standard «${s['title']}» text', s['text'] as String));
  }
  for (final g in ref['glossary'] as List) {
    checks
      ..add(('glossary «${g['term']}» rule', g['rule'] as String))
      ..add(('glossary «${g['term']}» english', g['english'] as String));
  }
  for (final p in (ref['platforms'] as List? ?? const [])) {
    checks
      ..add(('platform «${p['name']}» section', p['section'] as String))
      ..add(('platform «${p['name']}» name', p['name'] as String));
    for (final c in p['content'] as List) {
      checks.add(('platform «${p['name']}» content', c as String));
    }
  }
  final a = ref['association'] as Map?;
  if (a != null) {
    checks
      ..add(('association about', a['about'] as String))
      ..add(('association MCP', a['mcp'] as String));
    for (final f in a['facts'] as List) {
      checks
        ..add(('association ${f['item']}', f['item'] as String))
        ..add(('association ${f['item']} text', f['text'] as String));
    }
  }
  for (final k in ['standardsIntro', 'externalIntro', 'externalNote']) {
    if (ref[k] is String) checks.add((k, ref[k] as String));
  }
  for (final s in (ref['scopeText'] as List? ?? const [])) {
    checks.add(('scope text', s as String));
  }
  final cases = (jsonDecode(File('../eval/test_cases.json').readAsStringSync()) as Map)['cases'] as List;
  for (final c in cases.where((c) => c['source'] == 'official')) {
    checks.add(('test ${c['id']} expected behaviour', c['expectedBehavior'] as String));
  }

  var bad = 0;
  for (final (label, text) in checks) {
    if (pack.contains(_ours(text))) continue;
    bad++;
    stdout.writeln('✗ $label\n    $text');
  }
  stdout.writeln('\n${checks.length - bad} of ${checks.length} texts match the reference pack exactly');
  exit(bad == 0 ? 0 : 1);
}

/// Spaces, brackets, tatweel and fathatan (whose position the PDF stores
/// inconsistently: «ًحكما» / «مستقالً»).
final _ignore = RegExp(r'[\s()ـً]');

/// «م» next to a year: the PDF reorders «(2008م)،» as «2008،م».
final _yearMark = RegExp(r'(?<=\d[،.]?)م|م(?=\d)');

/// The extracted pack, as one comparable string; the ﷺ glyph is extracted
/// as reversed words.
String _pack(String text) =>
    text.replaceAll(_ignore, '').replaceAll('ملسوهيلعهللاىلص', 'ﷺ').replaceAll(_yearMark, '');

/// Basirah's text in the extraction's form: no spaces, brackets or tatweel;
/// lam + alef (any hamza form) as the PDF maps the ligature.
String _ours(String text) => text
    .replaceAllMapped(RegExp('ل([اأإآ])'), (m) => '${m[1]}ل') // within a word only
    .replaceAll(_ignore, '')
    .replaceAll(_yearMark, '');
