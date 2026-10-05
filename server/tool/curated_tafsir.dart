import 'dart:convert';
import 'dart:io';

import 'package:basirah_core/basirah_core.dart';
import 'package:basirah_server/basirah_server.dart';

/// Gives every verse of the stored answers (`assets/kb/evidence.json`) what a
/// live answer shows under it: the passage of موسوعة التفسير in الدرر السنية
/// for that verse, verbatim, chosen by the same [DorarTafsir.shownUnder] the
/// guard uses, with its label and its link. Run from `server/`:
/// `dart run tool/curated_tafsir.dart` (`--check` only reports).
Future<void> main(List<String> args) async {
  final check = args.contains('--check');
  final quran = QuranLibrary.tryLoad('data/quran.json');
  if (quran == null) {
    stderr.writeln('data/quran.json is missing');
    exit(1);
  }
  final kb = loadKnowledgeBase('../assets/kb');
  final tafsir = DorarTafsir();
  final file = File('../assets/kb/evidence.json');
  var s = file.readAsStringSync();
  var added = 0, already = 0, missing = 0;
  for (final e in kb.evidence.values.where((e) => e.isQuran)) {
    final start = s.indexOf('"id": "${e.id}"');
    final end = s.indexOf(' }', start);
    if (start < 0 || end < 0) {
      stderr.writeln('${e.id}: not found');
      exitCode = 1;
      continue;
    }
    if (s.substring(start, end).contains('"tafsir":')) {
      already++;
      continue;
    }
    final key = e.verseKeys.first;
    final verse = quran.verse(key);
    final text = await tafsir.forVerse(key);
    final shown = verse == null ? null : tafsir.shownUnder(key, text, verse.simple);
    if (shown == null) {
      stderr.writeln('${e.id}: no tafsir passage for $key');
      missing++;
      continue;
    }
    stdout.writeln('${e.id} ($key): ${shown.text.length} chars');
    if (check) continue;
    final fields = ',\n      "tafsir": ${jsonEncode(shown.text)},\n      "tafsirSource": ${jsonEncode(shown.label)},\n      "tafsirUrl": ${jsonEncode(tafsir.urlFor(key))}';
    s = s.replaceRange(end, end, fields);
    added++;
  }
  if (!check) file.writeAsStringSync(s);
  stdout.writeln('tafsir added: $added, already there: $already, not found: $missing');
}
