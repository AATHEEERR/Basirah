import 'package:basirah_server/src/quran.dart';

void main(List<String> args) {
  final sw = Stopwatch()..start();
  final q = QuranLibrary.tryLoad('data/quran.json')!;
  print('loaded ${q.length} verses + index in ${sw.elapsedMilliseconds} ms');
  for (final query in args) {
    sw.reset();
    final hits = q.search(query, limit: 5);
    print('\n«$query»  (${sw.elapsedMilliseconds} ms)');
    for (final h in hits) {
      print('  ${h.verse.key.padRight(7)} ${q.surahName(h.verse.surah).padRight(10)} ${h.score.toStringAsFixed(1)}  ${h.verse.simple.substring(0, h.verse.simple.length.clamp(0, 70))}');
    }
  }
}
