import 'dart:io';

import 'package:basirah_server/src/quran_fetch.dart';

/// Downloads the Quran text + al-Muyassar dataset.
///
///   dart run tool/fetch_quran.dart [out]      (from server/, default data/quran.json)
///
/// The output is gitignored; the Dockerfile runs this at build time and the
/// server runs it on first start if the file is missing.
Future<void> main(List<String> args) async {
  stdout.writeln('Downloading the Quran text + al-Muyassar from QuranEnc and Quranpedia …');
  final summary = await fetchQuranDataset(
    args.isNotEmpty ? args.first : 'data/quran.json',
    progress: (p) => stdout.write('\r  $p '),
  );
  stdout.writeln('\n$summary');
  exit(0);
}
