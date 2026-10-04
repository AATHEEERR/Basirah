import 'dart:convert';
import 'dart:io';

import 'package:basirah_core/basirah_core.dart';
import 'package:basirah_server/src/quran.dart';

/// Fills the "quran" section of assets/kb/en.json for every Quran item in
/// assets/kb/evidence.json, from data/quran.json (no network):
///   surahName    — English transliterated surah name
///   translation  — The Noble Quran, al-Hilali & Khan (King Fahd Complex),
///                  as published on QuranEnc, footnote markers removed
///   partial      — true when the curated Arabic text is an excerpt of the
///                  verse (the English then renders the full verse)
///   arabic       — for an excerpt: the whole verse(s), Mushaf text
///
///   dart run tool/build_en_quran.dart     (from server/, needs data/quran.json)
void main() {
  final quran = QuranLibrary.tryLoad('data/quran.json');
  if (quran == null) {
    stderr.writeln('data/quran.json missing — run: dart run tool/fetch_quran.dart');
    exit(2);
  }
  final evidence = (jsonDecode(File('../assets/kb/evidence.json').readAsStringSync())
      as Map<String, dynamic>)['evidence'] as List;
  final enFile = File('../assets/kb/en.json');
  final en = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;

  String compact(String s) => normalizeArabic(s).replaceAll(' ', '');
  final out = <String, dynamic>{};
  for (final raw in evidence.cast<Map<String, dynamic>>()) {
    final e = Evidence.fromJson(raw);
    if (!e.isQuran) continue;
    final verses = [for (final key in e.verseKeys) quran.verse(key)!];
    if (verses.any((v) => v.english.isEmpty)) throw StateError('no English meaning for ${e.reference}');
    final full = compact(verses.map((v) => v.uthmani).join(' '));
    final shown = compact(e.text.replaceAll('۝', ' '));
    final partial = shown.length < full.length * 0.9;
    out[e.id] = {
      'surahName': quran.surahName(e.surah!, lang: 'en'),
      'translation': verses.map((v) => v.english).join(' '),
      'partial': partial,
      // The translation renders whole verses, so English mode shows the whole
      // Arabic verse too (Mushaf text from the dataset), never an excerpt.
      if (partial) 'arabic': verses.map((v) => v.uthmani).join(' ۝ '),
    };
    stdout.writeln('${e.id.padRight(8)} ${e.verseKeys.join(",").padRight(12)} ${partial ? '(excerpt)' : ''}');
  }
  en['quran'] = out;
  enFile.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(en)}\n');
  stdout.writeln('\nWrote ${out.length} verse translations into assets/kb/en.json');
}
