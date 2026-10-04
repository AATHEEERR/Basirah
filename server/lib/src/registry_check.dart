import 'package:basirah_core/basirah_core.dart';

import 'quran.dart';

/// Checks a Quran item of the evidence registry against the full KFGQPC
/// Uthmani text in data/quran.json, exactly: same letters, same marks, same
/// order of marks. Each ۝-separated segment must be a run of whole words of
/// one cited verse (the ۞ section sign before a verse and a pause mark after
/// the last quoted word are not wording and may be left out).
///
/// Returns null when the text matches, otherwise what is wrong.
String? checkRegistryVerse(Evidence e, QuranLibrary quran) {
  final keys = e.verseKeys;
  final verses = [for (final k in keys) quran.verse(k)];
  if (keys.isEmpty || verses.any((v) => v == null)) return 'reference ${e.reference} not found';
  final segments = e.text.split('۝').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return 'empty text';
  for (final s in segments) {
    if (!verses.any((v) => ' ${v!.uthmani} '.contains(' $s '))) {
      return 'not the exact Mushaf wording: «$s»';
    }
  }
  return null;
}

/// Checks the Arabic shown beside a full English translation (en.json
/// `arabic`): it must be the cited verses, whole, exactly as in the dataset.
String? checkFullVerses(Evidence e, String arabic, QuranLibrary quran) {
  final expected = e.verseKeys.map((k) => quran.verse(k)?.uthmani ?? '').join(' ۝ ');
  return arabic == expected ? null : 'Arabic beside the translation is not the full Mushaf text of ${e.reference}';
}
