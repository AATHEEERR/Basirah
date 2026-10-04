import 'package:basirah_server/basirah_server.dart';

Future<void> main(List<String> args) async {
  final t = QuranComTabari(cacheDir: 'cache/tabari');
  for (final k in args) {
    final text = await t.forVerse(k);
    final ex = text == null ? 'unavailable' : excerpt(text, max: 900);
    print('== $k  (${text?.length ?? 0} chars total)\n$ex\n');
  }
}
