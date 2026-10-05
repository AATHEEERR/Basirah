import 'dart:io';

import 'package:basirah_core/basirah_core.dart';
import 'package:basirah_server/basirah_server.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final kb = loadKnowledgeBase('../assets/kb');
  final quran = loadFixtureQuran();
  late Directory dir;
  var now = DateTime.utc(2026, 10, 4, 12);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('basirah_cache_test');
    now = DateTime.utc(2026, 10, 4, 12);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  (AskPipeline, ScriptedClaude) setup() {
    final s = ScriptedClaude([
      toolTurn([('read_tafsir', {'refs': ['60:8']})]),
      toolTurn([('submit_answer', submission())]),
    ]);
    final cache = AnswerCache(dir: dir.path, clock: () => now);
    return (AskPipeline(kb, llm: s.client(), quran: quran, tafsir: FakeTafsir(), cache: cache), s);
  }

  test('a question asked again is answered from the cache, without a model call', () async {
    final (pipeline, s) = setup();
    final first = await pipeline.ask('هل يمكنني زيارة عائلتي غير المسلمة؟');
    expect(s.requests, hasLength(2));

    // Same words, different diacritics and punctuation.
    final again = await pipeline.ask('هَلْ يمكنني زيارة عائلتي غير المسلمة');
    expect(s.requests, hasLength(2));
    expect(again.guardActions, [AskPipeline.cachedAction]);
    expect(again.via, Via.ai);
    expect(again.answer.principle, first.answer.principle);
    expect(again.answer.question, 'هَلْ يمكنني زيارة عائلتي غير المسلمة');
  });

  test('the question text is never written to disk', () async {
    final (pipeline, _) = setup();
    await pipeline.ask('هل يمكنني زيارة عائلتي غير المسلمة؟');
    final files = dir.listSync(recursive: true).whereType<File>().toList();
    expect(files, hasLength(1));
    expect(files.single.path, isNot(contains('عائلتي')));
    expect(files.single.readAsStringSync(), isNot(contains('عائلتي')));
  });

  test('follow-ups are not cached, and entries expire', () async {
    final (pipeline, s) = setup();
    await pipeline.ask(
      'هل يمكنني زيارة عائلتي غير المسلمة؟',
      history: const [Turn('سؤال سابق', 'جواب سابق')],
    );
    expect(dir.listSync(recursive: true).whereType<File>(), isEmpty);

    final cache = AnswerCache(dir: dir.path, clock: () => now);
    final key = cache.keyFor(question: 'سؤال', kbVersion: kb.version);
    cache.put(key, BasirahAnswer.fromJson({...submissionAnswerJson, 'question': 'سؤال'}));
    expect(cache.get(key, 'سؤال'), isNotNull);
    now = now.add(const Duration(days: 15));
    expect(cache.get(key, 'سؤال'), isNull);
    expect(s.requests, hasLength(2));
  });

  test('a different category or asker context is a different entry', () {
    final cache = AnswerCache(dir: dir.path, clock: () => now);
    final a = cache.keyFor(question: 'سؤال', kbVersion: '1');
    expect(cache.keyFor(question: 'سؤال', kbVersion: '1', categoryId: 'family'), isNot(a));
    expect(cache.keyFor(question: 'سؤال', kbVersion: '1', context: 'new-muslim'), isNot(a));
    expect(cache.keyFor(question: 'سؤال', kbVersion: '2'), isNot(a));
    expect(cache.keyFor(question: 'سُؤالٌ!', kbVersion: '1'), a);
  });

  test('questions in scripts the normaliser drops never share an entry', () {
    final cache = AnswerCache(dir: dir.path, clock: () => now);
    String key(String q) => cache.keyFor(question: q, kbVersion: '1');
    final keys = {
      key('为什么穆斯林崇拜克尔白？'),
      key('なぜイスラム教徒はカアバを崇拝するのですか？'),
      key('मुसलमान काबा की पूजा क्यों करते हैं?'),
      key('முஸ்லிம்கள் ஏன் கஅபாவை வணங்குகிறார்கள்?'),
      key('مسلمان کعبہ کی عبادت کیوں کرتے ہیں؟'),
      key('کیا اسلام تلوار سے پھیلا؟'),
      key("Müslümanlar neden Kâbe'ye tapıyor?"),
    };
    expect(keys, hasLength(7));
    // The same question still finds its entry.
    expect(key('为什么穆斯林崇拜克尔白？'), key('为什么穆斯林崇拜克尔白?'));
  });
}

const submissionAnswerJson = <String, dynamic>{
  'kind': 'answer',
  'level': 'A',
  'origin': 'ai',
  'principle': 'مبدأ',
};
