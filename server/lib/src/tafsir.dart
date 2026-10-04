import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Supplies long-form tafsir for a verse at answer time.
abstract class TafsirSource {
  /// Display name, e.g. «تفسير الطبري».
  String get name;

  /// Plain-text tafsir for [key] («60:8»), or null when unavailable.
  Future<String?> forVerse(String key);

  /// Public page where a reader can check the tafsir.
  String urlFor(String key);
}

/// Tafsir al-Tabari (Jāmiʿ al-Bayān, d. 310 AH) via the Quran.com API —
/// an early-centuries source as the reference pack requires for tafsir.
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
  String urlFor(String key) => 'https://quran.com/$key/tafsirs/ar-tafsir-al-tabari';

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

/// Tabari often runs to many pages with long chains of narration; the model
/// gets the opening (where he states the meaning) up to [max] characters.
String excerpt(String text, {int max = 3500}) {
  if (text.length <= max) return text;
  final cut = text.lastIndexOf('\n', max);
  return '${text.substring(0, cut > max * .6 ? cut : max)}\n[…اقتُطع باقي كلام الطبري]';
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
