import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:basirah_core/basirah_core.dart';
import 'package:basirah_server/basirah_server.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// The live research loop end-to-end against a scripted Messages API: the
/// request shape, tool execution, the "read before citing" rule and the
/// fallbacks — without network or cost.
void main() {
  final kb = loadKnowledgeBase('../assets/kb');
  final quran = loadFixtureQuran();

  AskPipeline pipeline(ScriptedClaude s, [FakeTafsir? t]) =>
      AskPipeline(kb, llm: s.client(), quran: quran, tafsir: t ?? FakeTafsir());

  test('a question in another language is answered in it, with the approved translation of the verse', () async {
    final s = ScriptedClaude([
      toolTurn([('read_tafsir', {'refs': ['60:8']})]),
      toolTurn([
        (
          'submit_answer',
          submission(principle: 'Oui : l’islam ordonne la bonté envers les parents, même s’ils ne sont pas musulmans.', hadithIds: const []),
        ),
      ]),
    ]);
    final tmp = Directory.systemTemp.createTempSync('basirah_meaning');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final meaning = MeaningSource(
      cacheDir: tmp.path,
      client: MockClient((req) async {
        if (req.url.path.contains('/translations/list/')) {
          return http.Response.bytes(utf8.encode(jsonEncode({'translations': [{'key': 'french_rashid', 'title': 'French Translation - Rashid Maash'}]})), 200);
        }
        expect(req.url.toString(), 'https://quranenc.com/api/v1/translation/aya/french_rashid/60/8');
        return http.Response.bytes(utf8.encode(jsonEncode({'result': {'translation': '8. Allah ne vous défend pas'}})), 200);
      }),
    );
    final r = await AskPipeline(kb, llm: s.client(), quran: quran, tafsir: FakeTafsir(), meaning: meaning)
        .ask('Est-ce que je peux rendre visite à ma famille non musulmane ?');
    // Not declined as off-topic for lack of Arabic or English words.
    expect(r.via, Via.ai);
    expect(r.answer.kind, AnswerKind.answer);
    expect(jsonEncode(s.requests.first['messages']), contains('<answer_language>French</answer_language>'));
    final verse = r.answer.evidence.firstWhere((e) => e.isQuran);
    expect(verse.text, quran.verse('60:8')!.uthmani);
    expect(verse.translation, 'Allah ne vous défend pas');
    expect(verse.translationSource, 'French Translation - Rashid Maash');
  });

  test('live answer: search → read tafsir → submit, with verified verse text', () async {
    final tafsir = FakeTafsir();
    final s = ScriptedClaude([
      toolTurn([('search_quran', {'query': 'بر الأقارب غير المسلمين'})]),
      toolTurn([('read_tafsir', {'refs': ['60:8']})]),
      toolTurn([('submit_answer', submission())]),
    ]);
    final r = await pipeline(s, tafsir).ask('هل يمكنني زيارة عائلتي غير المسلمة؟');

    expect(r.via, Via.ai);
    expect(r.answer.origin, AnswerOrigin.ai);
    expect(r.answer.kind, AnswerKind.answer);
    final verse = r.answer.evidence.first;
    expect(verse.text, quran.verse('60:8')!.uthmani);
    expect(verse.tafsirUrl, 'https://example.test/tafsir/60:8');
    // Shown under the verse: the tafsir source's own words, with its label.
    expect(verse.tafsir, 'شرح الآية 60:8');
    expect(verse.tafsirSource, fakeLabel('60:8'));
    // The closest reference answer's verses were pre-read; reading one of
    // them again neither refetches nor repeats it in the trail.
    expect(tafsir.requested, ['60:8', '31:15']);
    expect(r.answer.research, [
      'قراءة موسوعة التفسير — الدرر السنية: الممتحنة 8',
      'قراءة موسوعة التفسير — الدرر السنية: لقمان 15',
      'بحث في القرآن الكريم: «بر الأقارب غير المسلمين»',
    ]);
    expect(r.usage['cache_read_input_tokens'], 27000);

    // Request shape (first call)
    expect(s.requests, hasLength(3));
    final first = s.requests.first;
    expect(first['model'], 'claude-opus-5-5');
    expect([for (final t in first['tools'] as List) t['name']], ['search_quran', 'read_tafsir', 'submit_answer']);
    expect(first['tool_choice'], {'type': 'auto'});
    expect(first['fallbacks'], 'default');
    expect(first['output_config'], {'effort': 'high'});
    expect(first.containsKey('thinking'), isFalse);
    expect(((first['system'] as List).single as Map)['cache_control'], {'type': 'ephemeral'});
    expect(s.headers.first['anthropic-beta'], 'server-side-fallback-2026-07-01');

    // Second call: assistant turn echoed unchanged (thinking kept) + tool_result
    final msgs = s.requests[1]['messages'] as List;
    expect(msgs, hasLength(3));
    final echoed = msgs[1] as Map;
    expect(echoed['role'], 'assistant');
    expect((echoed['content'] as List).first['type'], 'thinking');
    final toolResult = ((msgs[2] as Map)['content'] as List).single as Map;
    expect(toolResult['type'], 'tool_result');
    expect(toolResult['tool_use_id'], (echoed['content'] as List)[1]['id']);
    expect(toolResult['content'], contains('"results"'));
    // al-Muyassar only ranks search results; the model never reads it.
    expect(toolResult['content'], isNot(contains('muyassar')));

    // Third call carries the tafsir the model read (موسوعة التفسير) only
    final read = (((s.requests[2]['messages'] as List).last as Map)['content'] as List).single as Map;
    expect(read['content'], contains('شرح الآية 60:8'));
    expect(read['content'], isNot(contains('muyassar')));
    expect(read['content'], isNot(contains(quran.verse('60:8')!.muyassar.substring(0, 20))));
  });

  test('a verse whose tafsir cannot be read cannot be cited', () async {
    final s = ScriptedClaude([
      toolTurn([('read_tafsir', {'refs': ['60:8', '31:15']})]),
      toolTurn([
        ('submit_answer', submission(english: true, quran: const [
          {'ref': '60:8', 'why': 'x'},
          {'ref': '31:15', 'why': 'y'},
        ])),
      ]),
    ]);
    final r = await pipeline(s, FakeTafsir(unavailable: {'31:15'})).ask('Can I visit my non-Muslim parents?');
    expect([for (final e in r.answer.evidence) if (e.isQuran) e.surah], [60]);
    expect(r.guardActions.single, contains('31:15'));
    final result = (((s.requests[1]['messages'] as List).last as Map)['content'] as List).single as Map;
    expect(result['content'], contains('do not cite this verse'));
  });

  test('a verse cited without reading its tafsir is dropped', () async {
    final s = ScriptedClaude([
      toolTurn([('read_tafsir', {'refs': ['60:8']})]),
      toolTurn([
        ('submit_answer', submission(english: true, quran: const [
          {'ref': '60:8', 'why': 'x'},
          {'ref': '2:256', 'why': 'y'},
        ])),
      ]),
    ]);
    final r = await pipeline(s).ask('Can I visit my non-Muslim parents?');
    expect([for (final e in r.answer.evidence) if (e.isQuran) e.surah], [60]);
    expect(r.guardActions.single, contains('2:256'));
    // «إيصال بصيرة»: the drop travels with the answer, in its JSON too.
    expect(r.answer.guard, r.guardActions);
    expect(BasirahAnswer.fromJson(r.answer.toJson()).guard, r.guardActions);
  });

  test('pre-read tafsir: the closest reference answer\'s verses let the model answer in one request', () async {
    final tafsir = FakeTafsir();
    final s = ScriptedClaude([
      toolTurn([('submit_answer', submission())]),
    ]);
    final r = await pipeline(s, tafsir).ask('هل يمكنني زيارة عائلتي غير المسلمة؟');
    expect(s.requests, hasLength(1));
    final user = (s.requests.single['messages'] as List).first['content'] as String;
    expect(user, contains('<tafsir_already_read>'));
    expect(user, contains('[60:8]'));
    expect(user, contains('شرح الآية 60:8'));
    final verse = r.answer.evidence.first;
    expect(verse.surah, 60); // cited directly: it counts as read
    expect(verse.tafsir, 'شرح الآية 60:8');
    expect(r.answer.research, ['قراءة موسوعة التفسير — الدرر السنية: الممتحنة 8', 'قراءة موسوعة التفسير — الدرر السنية: لقمان 15']);
  });

  test('no pre-read when no reference answer is close', () async {
    final tafsir = FakeTafsir();
    final s = ScriptedClaude([
      toolTurn([('submit_answer', submission(english: true, kind: 'abstain', quran: const [], hadithIds: const [], entries: const []))]),
    ]);
    await pipeline(s, tafsir).ask('How many angels carry the Throne on the Day of Judgement?');
    expect(tafsir.requested, isEmpty);
    final user = (s.requests.single['messages'] as List).first['content'] as String;
    expect(user, isNot(contains('<tafsir_already_read>')));
  });

  test('refusal becomes an abstention, never a guess', () async {
    final s = ScriptedClaude([textTurn('', stop: 'refusal')]);
    final r = await pipeline(s).ask('What is the ruling on music in Islam?');
    expect(r.answer.kind, AnswerKind.abstain);
    expect(r.guardActions, contains('model declined (refusal)'));
  });

  test('a plain-text ending is nudged once to submit', () async {
    final s = ScriptedClaude([
      textTurn('Here is my answer…'),
      toolTurn([('submit_answer', submission(quran: const []))]),
    ]);
    final r = await pipeline(s).ask('ما معنى التوحيد؟');
    expect(r.answer.kind, AnswerKind.answer);
    final nudge = ((s.requests[1]['messages'] as List).last as Map)['content'];
    expect(nudge, contains('submit_answer'));
  });

  test('model answering a level-D case is forced to refer', () async {
    final s = ScriptedClaude([
      toolTurn([('submit_answer', submission(english: true, level: 'D', entries: const []))]),
    ]);
    final r = await pipeline(s).ask('My husband is not Muslim, is my marriage still valid?');
    expect(r.answer.kind, AnswerKind.refer);
  });

  test('follow-up questions carry earlier turns', () async {
    final s = ScriptedClaude([
      toolTurn([('submit_answer', submission(quran: const []))]),
    ]);
    await pipeline(s).ask(
      'وماذا عن أمي تحديداً؟',
      history: const [Turn('هل يمكنني زيارة عائلتي غير المسلمة؟', '[answer/A] نعم…')],
    );
    final user = (s.requests.single['messages'] as List).first['content'] as String;
    expect(user, contains('<previous_turns>'));
    expect(user.indexOf('<previous_turns>'), lessThan(user.indexOf('<question>')));
  });

  test('kb mode answers from the curated base without calling Claude', () async {
    final s = ScriptedClaude([]);
    final r = await pipeline(s).ask('هل يمكنني زيارة عائلتي غير المسلمة؟', mode: AskMode.kb);
    expect(r.via, Via.kb);
    expect(s.requests, isEmpty);
  });

  test('without a key, live mode says so and serves the stored answer', () async {
    final r = await AskPipeline(kb).ask('هل يمكنني زيارة عائلتي غير المسلمة؟');
    expect(r.notice, 'no_ai');
    expect(r.answer.origin, AnswerOrigin.kb);
  });

  test('API errors fall back to the offline router', () async {
    final failing = ClaudeClient(
      apiKey: 'k',
      client: MockClient((_) async => http.Response('{"error":{"message":"overloaded"}}', 529)),
    );
    final r = await AskPipeline(kb, llm: failing, quran: quran, tafsir: FakeTafsir())
        .ask('How many angels carry the Throne on the Day of Judgement?');
    expect(r.via, Via.offline);
    expect(r.notice, 'ai_busy');
    expect(r.answer.kind, AnswerKind.abstain);
  });

  test('past the time budget: the stored answer with a notice, not a longer wait', () async {
    final slow = ClaudeClient(
      apiKey: 'k',
      client: MockClient((_) => Completer<http.Response>().future), // never answers
    );
    final r = await AskPipeline(kb, llm: slow, quran: quran, tafsir: FakeTafsir(), answerBudget: const Duration(milliseconds: 200))
        .ask('How many angels carry the Throne on the Day of Judgement?');
    expect(r.via, Via.offline);
    expect(r.notice, 'ai_busy');
    expect(r.guardActions.last, startsWith('time budget reached'));
  });

  test('the tools of one turn run together; the research trail keeps their order', () async {
    final s = ScriptedClaude([
      toolTurn([
        ('search_quran', {'query': 'بر الأقارب'}),
        ('read_tafsir', {'refs': ['60:8']}),
        ('search_quran', {'query': 'صلة الرحم'}),
      ]),
      toolTurn([('submit_answer', submission())]),
    ]);
    final r = await pipeline(s).ask('هل يمكنني زيارة عائلتي غير المسلمة؟');
    expect(r.via, Via.ai);
    final searches = [for (final step in r.answer.research) if (step.startsWith('بحث في القرآن')) step];
    expect(searches, ['بحث في القرآن الكريم: «بر الأقارب»', 'بحث في القرآن الكريم: «صلة الرحم»']);
  });

  test('clearly off-topic questions are declined without calling Claude', () async {
    final s = ScriptedClaude([]);
    final r = await pipeline(s).ask('Recommend the best sushi restaurant in Riyadh');
    expect(r.via, Via.scope);
    expect(r.answer.kind, AnswerKind.offTopic);
    expect(r.answer.evidence, isEmpty);
    expect(s.requests, isEmpty);
  });

  test('the model can also decline as off-topic; nothing is cited', () async {
    final s = ScriptedClaude([
      toolTurn([
        ('submit_answer', {
          ...submission(english: true),
          'kind': 'offTopic',
          'abstainReason': 'Basirah only answers questions about Islam.',
        }),
      ]),
    ]);
    final r = await pipeline(s).ask('Can I get a pizza recommendation?');
    expect(r.answer.kind, AnswerKind.offTopic);
    expect(r.answer.evidence, isEmpty);
    expect(r.answer.principle, isEmpty);
  });

  test('an answer in the wrong language is sent back once to be rewritten', () async {
    final s = ScriptedClaude([
      toolTurn([('submit_answer', submission())]), // Arabic, for an English question
      toolTurn([('submit_answer', submission(english: true))]),
    ]);
    final r = await pipeline(s).ask('Can I visit my non-Muslim parents?');
    expect(s.requests, hasLength(2));
    final user = (s.requests.first['messages'] as List).first['content'] as String;
    expect(user, contains('<answer_language>English</answer_language>'));
    final rejection = ((s.requests[1]['messages'] as List).last as Map)['content'] as List;
    expect((rejection.single as Map)['is_error'], isTrue);
    expect((rejection.single as Map)['content'], contains('must be written in English'));
    expect(r.answer.principle, startsWith('Yes. Islam commands'));
  });

  test('English questions get English fixed texts and English verse details', () async {
    final s = ScriptedClaude([
      toolTurn([('read_tafsir', {'refs': ['60:8']})]),
      toolTurn([('submit_answer', submission(english: true))]),
    ]);
    final r = await pipeline(s).ask('Can I visit my non-Muslim parents?');
    final verse = r.answer.evidence.first;
    expect(verse.translation, isNotNull);
    expect(verse.tafsir, isNull); // the Arabic tafsir is linked, not shown, in English
    expect(r.answer.research, everyElement(startsWith('Read Dorar Tafsir Encyclopedia on')));
    final hadith = r.answer.evidence.firstWhere((e) => e.id == 'h_asma');
    expect(hadith.translation, contains('keep ties with your mother'));
  });
}
