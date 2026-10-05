import 'dart:io';

import 'package:basirah_server/basirah_server.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late Metrics metrics;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('basirah_metrics');
    metrics = Metrics(file: '${tmp.path}/m.jsonl', clock: () => DateTime.utc(2026, 10, 5, 9, 41, 27));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  void ask(String kind, {int ms = 1000, bool cached = false, int verses = 1, int hadith = 0, int guard = 0}) => metrics.recordAsk(
    kind: kind,
    via: 'ai',
    cached: cached,
    ms: ms,
    verses: verses,
    hadith: hadith,
    guardCatches: guard,
    lang: 'ar',
    category: 'family',
  );

  test('events hold no question text, no IP, and the time only to the hour', () {
    ask('answer');
    metrics.recordFeedback(helpful: true, reasons: ['clear'], kind: 'answer', lang: 'ar');
    final text = File(metrics.file).readAsStringSync();
    expect(text, contains('"t":"2026-10-05T09:00Z"'));
    expect(text, isNot(contains('09:41')));
    for (final key in ['question', 'ip', 'user', 'id', 'role', 'context']) {
      expect(text, isNot(contains('"$key"')), reason: key);
    }
  });

  test('feedback accepts only the fixed choices', () {
    expect(metrics.recordFeedback(helpful: false, reasons: ['unclear', 'evidence'], kind: 'answer', lang: 'en'), isTrue);
    // A reason from the other side, a typed reason, an unknown kind or language.
    expect(metrics.recordFeedback(helpful: true, reasons: ['unclear'], kind: 'answer', lang: 'ar'), isFalse);
    expect(metrics.recordFeedback(helpful: false, reasons: ['my husband says…'], kind: 'answer', lang: 'ar'), isFalse);
    expect(metrics.recordFeedback(helpful: true, reasons: [], kind: 'fatwa', lang: 'ar'), isFalse);
    expect(metrics.recordFeedback(helpful: true, reasons: [], kind: 'answer', lang: 'fr'), isFalse);
    expect(metrics.recordFeedback(helpful: true, reasons: [], kind: 'answer', lang: 'ar', category: 'Name: Sara'), isFalse);
    expect(File(metrics.file).readAsLinesSync(), hasLength(1));
  });

  test('summary: counts and shares, cached answers left out of the times', () {
    ask('answer', ms: 4000, verses: 2);
    ask('answer', ms: 8000, hadith: 1, guard: 1);
    ask('refer', ms: 2000, verses: 0);
    ask('answer', ms: 5, cached: true);
    metrics.recordFeedback(helpful: true, reasons: ['clear', 'sources'], kind: 'answer', lang: 'ar');
    metrics.recordFeedback(helpful: false, reasons: ['incomplete'], kind: 'refer', lang: 'ar');
    final s = metrics.summary();
    expect(s['questions'], 4);
    expect(s['kinds'], {'answer': 3, 'refer': 1});
    expect(s['cached'], 1);
    expect(s['withVerses'], 3);
    expect(s['withHadith'], 1);
    expect(s['guardCatches'], 1);
    expect(s['medianMs'], 4000);
    expect(s['feedback'], {
      'total': 2,
      'helpful': 1,
      'reasons': {'clear': 1, 'sources': 1, 'incomplete': 1},
    });
  });

  test('the median of an even count is the mean of the two middle times', () {
    ask('answer', ms: 37532);
    ask('answer', ms: 75742);
    expect(metrics.summary()['medianMs'], 56637);
  });

  test('only the guard changing an answer counts as an intervention', () {
    expect(isGuardIntervention('replaced Quran quotation with its reference'), isTrue);
    expect(isGuardIntervention('dropped 60:8: cited without reading its tafsir'), isTrue);
    expect(isGuardIntervention(AskPipeline.cachedAction), isFalse);
    expect(isGuardIntervention('gemini:gemini-3.8-flash daily quota exhausted'), isFalse);
    expect(isGuardIntervention('claude:claude-sonnet-5-5 unavailable (529)'), isFalse);
    expect(isGuardIntervention('no model available'), isFalse);
    expect(isGuardIntervention('time budget reached (75 s)'), isFalse);
  });

  test('a new server starts from the seed once, never over existing counts', () {
    final seed = File('${tmp.path}/seed.jsonl')..writeAsStringSync('{"e":"ask","t":"2026-10-04T18:00Z","kind":"answer","via":"ai","cached":false,"ms":1000,"verses":1,"hadith":0,"guard":0,"lang":"ar"}\n');
    final m = Metrics(file: '${tmp.path}/disk/metrics.jsonl');
    expect(m.seedFrom(seed.path), isTrue);
    expect(m.summary()['questions'], 1);
    seed.writeAsStringSync('');
    expect(m.seedFrom(seed.path), isFalse); // the disk file now exists
    expect(m.summary()['questions'], 1);
    expect(Metrics(file: '${tmp.path}/x.jsonl').seedFrom('${tmp.path}/missing'), isFalse);
  });

  test('no file yet: an empty summary', () {
    final s = metrics.summary();
    expect(s['questions'], 0);
    expect(s['medianMs'], isNull);
  });
}
