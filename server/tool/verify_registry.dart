import 'dart:convert';
import 'dart:io';

import 'package:basirah_core/basirah_core.dart';
import 'package:basirah_server/basirah_server.dart';

/// Checks every Quran item in assets/kb/evidence.json against the full
/// KFGQPC Uthmani text in data/quran.json, exactly — letters, marks and
/// their order — and the full-verse Arabic kept beside each English
/// translation in assets/kb/en.json.
///
///   dart run tool/verify_registry.dart          report only
///   dart run tool/verify_registry.dart --fix    replace single-verse
///                                               mismatches with the whole
///                                               verse in Uthmani wording
void main(List<String> args) {
  final fix = args.contains('--fix');
  final quran = QuranLibrary.tryLoad('data/quran.json');
  if (quran == null) {
    stderr.writeln('data/quran.json missing — run: dart run tool/fetch_quran.dart');
    exit(2);
  }
  final file = File('../assets/kb/evidence.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final items = (json['evidence'] as List).cast<Map<String, dynamic>>();
  final en = (jsonDecode(File('../assets/kb/en.json').readAsStringSync()) as Map<String, dynamic>)['quran']
      as Map<String, dynamic>? ?? const {};

  var ok = 0, bad = 0;
  for (final item in items) {
    final e = Evidence.fromJson(item);
    if (!e.isQuran) continue;
    final problem = checkRegistryVerse(e, quran);
    final arabic = (en[e.id] as Map<String, dynamic>?)?['arabic'] as String?;
    final enProblem = arabic == null ? null : checkFullVerses(e, arabic, quran);
    if (problem == null && enProblem == null) {
      ok++;
      continue;
    }
    bad++;
    for (final p in [problem, enProblem]) {
      if (p != null) stdout.writeln('✗ ${e.id} [${e.reference}]: $p');
    }
    if (problem != null) {
      stdout.writeln('    dataset: ${e.verseKeys.map((k) => quran.verse(k)?.uthmani ?? '?').join(' ۝ ')}');
      if (fix && e.verseKeys.length == 1) item['text'] = quran.verse(e.verseKeys.single)!.uthmani;
    }
  }
  stdout.writeln('\n$ok verified exactly, $bad mismatched');
  if (fix) {
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
    stdout.writeln('evidence.json updated (single-verse mismatches replaced).');
  }
  exit(bad == 0 ? 0 : 1);
}
