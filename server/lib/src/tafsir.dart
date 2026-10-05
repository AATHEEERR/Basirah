import 'dart:convert';
import 'dart:io';

import 'package:basirah_core/basirah_core.dart';
import 'package:http/http.dart' as http;

/// Supplies long-form tafsir for a verse at answer time.
abstract class TafsirSource {
  /// Display name, e.g. «موسوعة التفسير — الدرر السنية».
  String get name;

  /// The name in English, for the English research trail.
  String get nameEn;

  /// Plain-text tafsir for [key] («60:8»), or null when unavailable.
  Future<String?> forVerse(String key);

  /// Public page where a reader can check the tafsir.
  String urlFor(String key);

  /// What the app shows under the verse [key]: the source's own words
  /// (verbatim; only editorial marks removed) and their label, from the
  /// [text] read for it. [verseSimple] is the verse in simple script.
  ({String label, String text})? shownUnder(String key, String? text, String verseSimple);
}

/// موسوعة التفسير في الدرر السنية (dorar.net/tafseer) — the tafsir platform
/// the approved reference names («أي مصادر إسلامية في القرون الثلاثة
/// الأولى أو منصة dorar.net/tafseer»). Each surah is divided into passages
/// («الآيات (4-6)»); a verse is read from its passage page: the overall
/// meaning (المعنى الإجمالي) and the verse-by-verse tafsir (تفسير الآيات),
/// without footnotes. Pages are cached in memory and on disk.
class DorarTafsir implements TafsirSource {
  DorarTafsir({http.Client? client, this.cacheDir = 'cache/dorar_tafseer'})
    : _http = client ?? http.Client();

  static const site = 'https://dorar.net/tafseer';
  final http.Client _http;
  final String cacheDir;
  final _passages = <int, List<DorarPassage>>{};
  final _memory = <String, String>{};

  @override
  String get name => 'موسوعة التفسير — الدرر السنية';

  @override
  String get nameEn => 'Dorar Tafsir Encyclopedia';

  DorarPassage? _passageOf(String key) {
    final parts = key.split(':');
    final ayah = int.parse(parts[1]);
    for (final p in _passages[int.parse(parts[0])] ?? const <DorarPassage>[]) {
      if (ayah >= p.from && ayah <= p.to) return p;
    }
    return null;
  }

  @override
  String urlFor(String key) {
    final surah = key.split(':').first;
    final p = _passageOf(key);
    return p == null ? '$site/$surah' : '$site/$surah/${p.n}';
  }

  /// Dorar explains each verse as «…الآية (رقم). أي: …»: that explanation is
  /// shown when found; otherwise the passage's overall meaning.
  @override
  ({String label, String text})? shownUnder(String key, String? text, String verseSimple) {
    if (text == null) return null;
    final own = dorarVerseExplanation(text, verseSimple);
    if (own != null) return (label: 'موسوعة التفسير، الدرر السنية — تفسير الآية ${key.split(':').last}', text: own);
    final summary = dorarSummary(text);
    if (summary == null) return null;
    final p = _passageOf(key);
    final range = p == null ? '' : (p.from == p.to ? ' للآية ${p.from}' : ' للآيات ${p.from}–${p.to}');
    return (label: 'موسوعة التفسير، الدرر السنية — المعنى الإجمالي$range', text: summary);
  }

  @override
  Future<String?> forVerse(String key) async {
    final surah = int.parse(key.split(':').first);
    if (!_passages.containsKey(surah)) {
      final index = await _index(surah);
      if (index.isEmpty) return null;
      _passages[surah] = index;
    }
    final p = _passageOf(key);
    if (p == null) return null;
    final id = '${surah}_${p.n}';
    final hit = _memory[id];
    if (hit != null) return hit;
    final file = File('$cacheDir/$id.txt');
    if (file.existsSync()) return _memory[id] = file.readAsStringSync();
    final html = await _get('$site/$surah/${p.n}');
    final text = html == null ? null : dorarPassageText(html);
    if (text == null) return null;
    _save(file, text);
    return _memory[id] = text;
  }

  Future<List<DorarPassage>> _index(int surah) async {
    final file = File('$cacheDir/index_$surah.txt');
    if (file.existsSync()) return parseDorarIndexCache(file.readAsStringSync());
    final html = await _get('$site/$surah');
    final index = html == null ? const <DorarPassage>[] : parseDorarIndex(html);
    if (index.isNotEmpty) _save(file, index.map((p) => '${p.n} ${p.from} ${p.to}').join('\n'));
    return index;
  }

  Future<String?> _get(String url) async {
    try {
      final res = await _http
          .get(Uri.parse(url), headers: {'user-agent': 'Mozilla/5.0 (compatible; Basirah/1.0)'})
          .timeout(const Duration(seconds: 25));
      return res.statusCode == 200 ? utf8.decode(res.bodyBytes, allowMalformed: true) : null;
    } on Exception {
      return null;
    }
  }

  void _save(File file, String text) {
    try {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(text);
    } on FileSystemException {
      // Read-only filesystem: memory cache only.
    }
  }
}

/// One passage of a surah in Dorar's tafsir: its number in the URL and the
/// verses it covers.
typedef DorarPassage = ({int n, int from, int to});

final _passageOption = RegExp(r'<option value="(\d+)">\s*(?:الآيات|الآيتان|الآية)\s*\((\d+)(?:\s*-\s*(\d+))?\)');

/// The passages listed on a surah page (its «الآيات (7-9)» selector).
List<DorarPassage> parseDorarIndex(String html) {
  final seen = <int>{};
  return [
    for (final m in _passageOption.allMatches(html))
      if (seen.add(int.parse(m[1]!))) (n: int.parse(m[1]!), from: int.parse(m[2]!), to: int.parse(m[3] ?? m[2]!)),
  ];
}

List<DorarPassage> parseDorarIndexCache(String text) => [
  for (final line in text.split('\n'))
    if (line.trim().split(' ') case [final n, final from, final to])
      (n: int.parse(n), from: int.parse(from), to: int.parse(to)),
];

final _scriptOrStyle = RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false);
final _footnote = RegExp(r'^\[\d+\]');
final _spaceBeforePunct = RegExp(r'\s+([.،؛:])');

/// The top-level section of a Dorar passage page a line opens, if any. The
/// headers' order varies by page, some carry diacritics («المعنى
/// الإجماليُّ:») and their wording follows the number of verses («تفسير
/// الآية / الآيتين / الآيات»), so they are compared without diacritics.
String? _dorarHeader(String line) {
  if (!line.endsWith(':') || line.length > 40) return null;
  final n = normalizeArabic(line.substring(0, line.length - 1));
  if (n == _meaningHeader) return 'meaning';
  if (n.startsWith(_tafsirHeader)) return 'tafsir';
  return _otherHeaders.any(n.startsWith) ? 'other' : null;
}

final _meaningHeader = normalizeArabic('المعنى الإجمالي');
final _tafsirHeader = normalizeArabic('تفسير الآي');
final _otherHeaders = [
  for (final h in ['غريب الكلمات', 'مشكل الإعراب', 'الفوائد التربوية', 'الفوائد العلمية', 'بلاغة الآي']) normalizeArabic(h),
];

/// The overall meaning and the verse-by-verse tafsir of a passage page, as
/// plain text under «[المعنى الإجمالي]» and «[تفسير الآيات]»; footnotes (the
/// «[97] يُنظر: …» references) are left out. Null when neither is found.
String? dorarPassageText(String html) {
  final lines = html
      .replaceAll(_scriptOrStyle, ' ')
      .replaceAll(_tags, '\n')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((l) => l.isNotEmpty)
      .toList();
  String? section(String kind) {
    final start = lines.indexWhere((l) => _dorarHeader(l) == kind);
    if (start < 0) return null;
    final out = <String>[];
    for (var i = start + 1; i < lines.length; i++) {
      final l = lines[i];
      if (_dorarHeader(l) != null) break;
      if (_footnote.hasMatch(l)) continue;
      out.add(l);
    }
    final s = out
        .join(' ')
        .replaceAll(_inlineReference, ' ')
        .replaceAllMapped(_spaceBeforePunct, (m) => m[1]!)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s.isEmpty ? null : s;
  }

  final meaning = section('meaning');
  final tafsir = section('tafsir');
  if (meaning == null && tafsir == null) return null;
  return [
    if (meaning != null) '[المعنى الإجمالي]\n$meaning',
    if (tafsir != null) '[تفسير الآيات]\n$tafsir',
  ].join('\n');
}

/// Dorar's overall meaning of the passage, for display under a verse: its
/// own words, cut at the end of a sentence near [max] characters.
String? dorarSummary(String? text, {int max = 450}) {
  if (text == null) return null;
  final start = text.indexOf('[المعنى الإجمالي]\n');
  if (start < 0) return null;
  var s = text.substring(start + '[المعنى الإجمالي]\n'.length);
  final end = s.indexOf('\n[تفسير الآيات]');
  if (end >= 0) s = s.substring(0, end);
  s = s.trim();
  if (s.isEmpty) return null;
  if (s.length > max) {
    final cut = [s.lastIndexOf('.', max), s.lastIndexOf('،', max), s.lastIndexOf('؛', max)]
        .reduce((a, b) => a > b ? a : b);
    s = '${s.substring(0, cut > max * .5 ? cut : max).trim()} …';
  }
  return s;
}

/// Tafsir al-Tabari (Jāmiʿ al-Bayān, d. 310 AH) via the Quran.com API.
/// Kept but not used: the reference pack names early-centuries sources or
/// dorar.net/tafseer for tafsir, and Basirah reads [DorarTafsir].
/// Responses are cached in memory and on disk.
class QuranComTabari implements TafsirSource {
  QuranComTabari({http.Client? client, this.cacheDir = 'cache/tabari'})
    : _http = client ?? http.Client();

  static const _id = 15;
  final http.Client _http;
  final String cacheDir;
  final _memory = <String, String>{};

  @override
  String get name => 'تفسير الطبري';

  @override
  String get nameEn => 'Tafsir al-Tabari';

  @override
  String urlFor(String key) => 'https://quran.com/$key/tafsirs/ar-tafsir-al-tabari';

  @override
  ({String label, String text})? shownUnder(String key, String? text, String verseSimple) {
    final summary = tabariSummary(text);
    return summary == null ? null : (label: tabariLabel, text: summary);
  }

  @override
  Future<String?> forVerse(String key) async {
    final hit = _memory[key];
    if (hit != null) return hit;
    final file = File('$cacheDir/${key.replaceAll(':', '_')}.txt');
    if (file.existsSync()) {
      return _memory[key] = file.readAsStringSync();
    }
    try {
      final res = await _http
          .get(
            Uri.parse('https://api.quran.com/api/v4/tafsirs/$_id/by_ayah/$key'),
            headers: {'user-agent': 'basirah/1.0'},
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final text = cleanTafsirHtml(((j['tafsir'] as Map?)?['text'] as String?) ?? '');
      if (text.isEmpty) return null;
      try {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(text);
      } on FileSystemException {
        // Read-only filesystem: memory cache only.
      }
      return _memory[key] = text;
    } on Exception {
      return null;
    }
  }
}

final _tags = RegExp(r'<[^>]+>');

/// Print-edition page markers such as «&amp;; 5-408 &amp;;».
final _pageMarkers = RegExp(r'(&amp;|&);?\s*\d+\s*-\s*\d+\s*(&amp;|&);?');

String cleanTafsirHtml(String html) => html
    .replaceAll(RegExp(r'</p>\s*'), '\n')
    .replaceAll(_tags, '')
    .replaceAll(_pageMarkers, '')
    .replaceAll('&amp;', '&')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&quot;', '"')
    .replaceAll(RegExp(r'[ \t]+'), ' ')
    .replaceAll(RegExp(r'\n\s*\n+'), '\n')
    .trim();

/// What the model reads for one verse of a Dorar passage: the passage's
/// overall meaning, then the verse-by-verse tafsir from where it quotes this
/// verse ([verseSimple], matched on its opening words without diacritics),
/// up to [max] characters. Other sources' text is passed through [excerpt].
String tafsirForVerse(String text, String verseSimple, {int max = 3500}) {
  final parts = _dorarParts(text);
  if (parts == null) return excerpt(text, max: max);
  final at = _verseStart(parts.words, verseSimple);
  final body = (at < 0 ? parts.words : parts.words.sublist(at)).join(' ');
  return excerpt('${parts.meaning}\n[تفسير الآية]\n$body', max: max);
}

const _tafsirMarker = '\n[تفسير الآيات]\n';

({String meaning, List<String> words})? _dorarParts(String text) {
  final split = text.indexOf(_tafsirMarker);
  if (split < 0) return null;
  return (meaning: text.substring(0, split), words: text.substring(split + _tafsirMarker.length).split(' '));
}

/// Index of the word where the verse-by-verse tafsir quotes [verseSimple]
/// (its opening words, compared without diacritics), or -1.
int _verseStart(List<String> words, String verseSimple) {
  final norm = [for (final w in words) normalizeArabic(w).replaceAll(' ', '')];
  final opening = normalizeArabic(verseSimple).split(' ').where((w) => w.isNotEmpty).take(4).toList();
  if (opening.isEmpty) return -1;
  for (var i = 0; i + opening.length <= norm.length; i++) {
    var j = 0;
    while (j < opening.length && norm[i + j] == opening[j]) {
      j++;
    }
    if (j == opening.length) return i;
  }
  return -1;
}

final _verseNumber = RegExp(r'\(\d+\)\.');

/// A footnote's list of references that ended up inline: «يُنظر: ((تفسير
/// ابن جرير)) (7/174)، ((تفسير السعدي)) (ص: 183)..».
final _inlineReference = RegExp(r'و?يُ?نظر:?\s*\(\([\s\S]*?\.+(?=\s|$)');

/// Dorar's own explanation of one verse. The verse is quoted with its
/// number «(8).», sometimes followed by «مناسبة الآية لما قبلها» or «سبب
/// النزول», then explained phrase by phrase («… أي: …»). Returns the text
/// from the first «أي:» before the next quoted verse, about [max]
/// characters (cut at the end of a sentence), or null.
String? dorarVerseExplanation(String text, String verseSimple, {int max = 450}) {
  final parts = _dorarParts(text);
  if (parts == null) return null;
  final at = _verseStart(parts.words, verseSimple);
  if (at < 0) return null;
  var rest = parts.words.sublist(at).join(' ');
  final number = _verseNumber.firstMatch(rest);
  if (number == null || number.start > 1500) return null;
  rest = rest.substring(number.end);
  final next = _verseNumber.firstMatch(rest);
  if (next != null) {
    // Drop the next verse's quotation that precedes its number.
    rest = rest.substring(0, next.start);
    final sentenceEnd = rest.lastIndexOf('.');
    if (sentenceEnd > 0) rest = rest.substring(0, sentenceEnd + 1);
  }
  final ai = rest.indexOf('أي:');
  if (ai < 0) return null;
  var s = rest.substring(ai + 'أي:'.length).replaceAll(_inlineReference, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.isEmpty) return null;
  if (s.length > max) {
    final end = [s.lastIndexOf('.', max), s.lastIndexOf('،', max), s.lastIndexOf('؛', max)]
        .reduce((a, b) => a > b ? a : b);
    s = '${s.substring(0, end > max * .5 ? end : max).trim()} …';
  }
  return 'أي: $s';
}

/// Tafsir can run to many pages; the model gets the opening (the overall
/// meaning, then the verse-by-verse tafsir) up to [max] characters.
String excerpt(String text, {int max = 3500}) {
  if (text.length <= max) return text;
  final cut = text.lastIndexOf(RegExp(r'[.\n]'), max);
  return '${text.substring(0, cut > max * .6 ? cut + 1 : max)}\n[…بقية التفسير في المصدر]';
}

/// Label shown above the excerpt in the app.
const tabariLabel = 'تفسير الطبري (ت 310هـ) — مقتطف';

/// Where al-Tabari moves from his own statement of the meaning to the
/// narrations that support it (at a line start or inside a line).
final _narrations = RegExp(r'^\s*(\*\s*)?(ذكر من قال|\d+\s*-\s*حد)');
final _narrationsInline = RegExp(r'(\*\s*)?ذكر من قال|\d+\s*-\s*حد|\bحدثن[اي]\b');

/// The heading «القول في تأويل قوله تعالى: {…}» and the start of what follows it.
final _heading = RegExp('القول في تأويل قوله');
final _statement = RegExp('قال أبو جعفر|يقول تعالى ذكره|يعني');

/// Print-edition marks that are not al-Tabari's words: footnote numbers
/// «(1)» and the «=» that joins a sentence across a footnote.
final _editorial = RegExp(r'\s*\(\d+\)|=');

/// Al-Tabari's own statement of a verse's meaning, for display under the
/// verse: the paragraph(s) after the heading «القول في تأويل قوله…», up to the
/// first chain of narration, at most about [max] characters (cut at the end
/// of a sentence). The words are his, verbatim; only print-edition marks are
/// removed. Null when nothing usable is found.
String? tabariSummary(String? text, {int max = 450}) {
  if (text == null) return null;
  final kept = <String>[];
  for (final line in text.split('\n')) {
    final l = line.trim();
    if (l.isEmpty || (kept.isEmpty && l.startsWith('القول في تأويل'))) continue;
    if (_narrations.hasMatch(l)) break;
    kept.add(l);
    if (kept.join(' ').length >= max) break;
  }
  var s = kept.join(' ').replaceAll(_editorial, '').replaceAll(RegExp(r'\s+'), ' ').trim();
  // A heading inside the first line: start at the statement that follows it.
  final h = _heading.firstMatch(s);
  if (h != null && h.start < 200) {
    final after = _statement.firstMatch(s.substring(h.end));
    if (after != null) s = s.substring(h.end + after.start);
  }
  final n = _narrationsInline.firstMatch(s);
  if (n != null && n.start > 40) s = s.substring(0, n.start).trim();
  if (s.isEmpty) return null;
  if (s.length > max) {
    final end = [s.lastIndexOf('.', max), s.lastIndexOf('،', max), s.lastIndexOf('؛', max)]
        .reduce((a, b) => a > b ? a : b);
    s = '${s.substring(0, end > max * .5 ? end : max).trim()} …';
  }
  return s;
}
