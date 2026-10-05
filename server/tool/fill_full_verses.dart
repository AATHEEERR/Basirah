import 'dart:io';

import 'package:basirah_core/basirah_core.dart';
import 'package:basirah_server/basirah_server.dart';

/// Adds `"full"` to every Quran entry of `assets/kb/evidence.json` whose
/// `text` is only part of its verse: the whole verse, from data/quran.json,
/// so the app shows the verse complete with the cited words highlighted.
/// Ranges join their verses with « ۝ », as the registry does.
/// Run from `server/`: `dart run tool/fill_full_verses.dart` (`--check` only
/// reports).
void main(List<String> args) {
  final check = args.contains('--check');
  final quran = QuranLibrary.tryLoad('data/quran.json');
  if (quran == null) {
    stderr.writeln('data/quran.json is missing');
    exit(1);
  }
  final file = File('../assets/kb/evidence.json');
  var s = file.readAsStringSync();
  final kb = loadKnowledgeBase('../assets/kb');
  var added = 0, already = 0, partial = 0;
  for (final e in kb.evidence.values.where((e) => e.isQuran)) {
    final keys = e.verseKeys;
    final verses = [for (final k in keys) quran.verse(k)];
    if (verses.any((v) => v == null)) {
      stderr.writeln('${e.id}: unknown verse ${e.ayah}');
      exitCode = 1;
      continue;
    }
    final full = verses.length == 1
        ? verses.single!.uthmani
        : [for (final v in verses) v!.uthmani].join(' ۝ ');
    if (e.text == full) continue;
    partial++;
    if (!full.contains(e.text)) {
      stderr.writeln('${e.id}: the cited text is not a part of ${keys.join(', ')}');
      exitCode = 1;
      continue;
    }
    if (s.contains('"id": "${e.id}"') && RegExp('"id": "${RegExp.escape(e.id)}"[^}]*"full":').hasMatch(s)) {
      already++;
      continue;
    }
    final textJson = '"text": "${e.text}"';
    final at = s.indexOf(textJson, s.indexOf('"id": "${e.id}"'));
    if (at < 0) {
      stderr.writeln('${e.id}: text not found as written');
      exitCode = 1;
      continue;
    }
    if (!check) {
      s = s.replaceRange(at, at + textJson.length, '$textJson,\n      "full": "$full"');
      added++;
    }
  }
  if (!check) file.writeAsStringSync(s);
  stdout.writeln('partial verses: $partial, full text added: $added, already there: $already');
}

