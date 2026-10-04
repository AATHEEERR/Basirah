import 'dart:convert';
import 'dart:io';

import 'package:basirah_core/basirah_core.dart';
import 'package:basirah_server/src/quran.dart';
import 'package:http/http.dart' as http;

/// Fills the "quran" section of assets/kb/en.json for every Quran item in
/// assets/kb/evidence.json:
///   surahName    — English transliterated surah name (Quran.com chapters)
///   translation  — The Noble Quran, al-Hilali & Khan (King Fahd Complex),
///                  Quran.com translation id 203, footnote markers removed
///   partial      — true when the curated Arabic text is an excerpt of the
///                  verse (the English then renders the full verse)
///
///   dart run tool/build_en_quran.dart     (from server/, needs data/quran.json)
const _hilaliKhan = 203;
final _client = http.Client();

Future<Map<String, dynamic>> _get(String path) async {
  final res = await _client
      .get(Uri.parse('https://api.quran.com/api/v4$path'), headers: {'user-agent': 'basirah/1.0'})
      .timeout(const Duration(seconds: 60));
  if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode} for $path');
  return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
}

String cleanTranslation(String s) => s
    .replaceAll(RegExp(r'<sup[^>]*>.*?</sup>'), '')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .trim();

Future<void> main() async {
  final quran = QuranLibrary.tryLoad('data/quran.json');
  if (quran == null) {
    stderr.writeln('data/quran.json missing — run: dart run tool/fetch_quran.dart');
    exit(2);
  }
  final evidence = (jsonDecode(File('../assets/kb/evidence.json').readAsStringSync())
      as Map<String, dynamic>)['evidence'] as List;
  final enFile = File('../assets/kb/en.json');
  final en = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;

  final chapters = (await _get('/chapters?language=en'))['chapters'] as List;
  final names = {
    for (final c in chapters.cast<Map<String, dynamic>>()) c['id'] as int: c['name_simple'] as String,
  };

  String compact(String s) => normalizeArabic(s).replaceAll(' ', '');
  final out = <String, dynamic>{};
  for (final raw in evidence.cast<Map<String, dynamic>>()) {
    final e = Evidence.fromJson(raw);
    if (!e.isQuran) continue;
    final parts = <String>[];
    for (final key in e.verseKeys) {
      final t = await _get('/quran/translations/$_hilaliKhan?verse_key=$key');
      final list = (t['translations'] as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) throw StateError('no translation for $key');
      parts.add(cleanTranslation(list.first['text'] as String));
    }
    final full = compact(e.verseKeys.map((k) => quran.verse(k)!.simple).join(' '));
    final shown = compact(e.text.replaceAll('۝', ' '));
    final partial = shown.length < full.length * 0.9;
    out[e.id] = {
      'surahName': names[e.surah]!,
      'translation': parts.join(' '),
      'partial': partial,
      // The translation renders whole verses, so English mode shows the whole
      // Arabic verse too (KFGQPC text from the dataset), never an excerpt.
      if (partial) 'arabic': e.verseKeys.map((k) => quran.verse(k)!.uthmani).join(' ۝ '),
    };
    stdout.writeln('${e.id.padRight(8)} ${e.verseKeys.join(",").padRight(12)} ${out[e.id]['partial'] == true ? '(excerpt)' : ''}');
  }
  en['quran'] = out;
  enFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(en)}\n');
  stdout.writeln('\nWrote ${out.length} verse translations into assets/kb/en.json');
  _client.close();
}
