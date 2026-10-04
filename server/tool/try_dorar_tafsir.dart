import 'package:basirah_server/basirah_server.dart';

/// Reads verses from Dorar's tafsir encyclopedia and prints what the app
/// shows and what the model reads.  dart run tool/try_dorar_tafsir.dart 60:8 112:1
Future<void> main(List<String> args) async {
  final t = DorarTafsir();
  final quran = QuranLibrary.tryLoad('data/quran.json')!;
  for (final key in args.isEmpty ? ['60:8', '112:1', '2:256', '31:15'] : args) {
    final verse = quran.verse(key)!;
    final text = await t.forVerse(key);
    final shown = t.shownUnder(key, text, verse.simple);
    print('=== $key  ${t.urlFor(key)}');
    print('label: ${shown?.label}');
    print('shown: ${shown?.text}');
    if (text != null) print('model reads ${tafsirForVerse(text, verse.simple).length} chars');
  }
}
