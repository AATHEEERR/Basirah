import 'dart:convert';

import 'package:basirah_core/basirah_core.dart';
import 'package:basirah_server/basirah_server.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// A generateContent double that replays scripted responses (status, body)
/// and records every request.
class ScriptedGemini {
  ScriptedGemini(this.responses);

  final List<(int, Map<String, dynamic>)> responses;
  final requests = <Map<String, dynamic>>[];
  final urls = <Uri>[];
  final headers = <Map<String, String>>[];
  final slept = <Duration>[];

  GeminiClient client({String model = 'gemini-test'}) => GeminiClient(
    apiKey: 'g-key',
    model: model,
    sleep: (d) async => slept.add(d),
    client: MockClient((req) async {
      requests.add(jsonDecode(req.body) as Map<String, dynamic>);
      urls.add(req.url);
      headers.add(req.headers);
      if (responses.isEmpty) return http.Response('{"error":{"message":"no more turns"}}', 500);
      final (status, body) = responses.removeAt(0);
      return http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});
    }),
  );
}

(int, Map<String, dynamic>) call(String name, Map<String, dynamic> args, {String? id, String? signature}) => (
  200,
  {
    'candidates': [
      {
        'content': {
          'role': 'model',
          'parts': [
            {
              'functionCall': {'name': name, 'args': args, 'id': ?id},
              'thoughtSignature': ?signature,
            },
          ],
        },
        'finishReason': 'STOP',
      },
    ],
    'usageMetadata': {'promptTokenCount': 1200, 'candidatesTokenCount': 40, 'thoughtsTokenCount': 60},
    'modelVersion': 'gemini-test-001',
  },
);

(int, Map<String, dynamic>) finish(String reason) => (
  200,
  {
    'candidates': [
      {'finishReason': reason},
    ],
  },
);

(int, Map<String, dynamic>) rateLimited({String delay = '7s', bool daily = false}) => (
  429,
  {
    'error': {
      'code': 429,
      'message': 'Resource has been exhausted',
      'status': 'RESOURCE_EXHAUSTED',
      'details': [
        {
          '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
          'violations': [
            {'quotaId': daily ? 'GenerateRequestsPerDayPerProjectPerModel-FreeTier' : 'GenerateRequestsPerMinutePerProjectPerModel-FreeTier'},
          ],
        },
        {'@type': 'type.googleapis.com/google.rpc.RetryInfo', 'retryDelay': delay},
      ],
    },
  },
);

void main() {
  final kb = loadKnowledgeBase('../assets/kb');
  final quran = loadFixtureQuran();

  AskPipeline pipeline(ScriptedGemini g) => AskPipeline(kb, llm: g.client(), quran: quran, tabari: FakeTabari());

  test('full research loop on Gemini: search → read → submit, guarded', () async {
    final g = ScriptedGemini([
      call('search_quran', {'query': 'بر الأقارب غير المسلمين'}, id: 'c1', signature: 'sig-1'),
      call('read_tafsir', {'refs': ['60:8']}, signature: 'sig-2'),
      call('submit_answer', submission()),
    ]);
    final r = await pipeline(g).ask('هل يمكنني زيارة عائلتي غير المسلمة؟');

    expect(r.via, Via.ai);
    expect(r.answer.kind, AnswerKind.answer);
    expect(r.answer.model, 'gemini-test-001');
    final verse = r.answer.evidence.first;
    expect(verse.text, quran.verse('60:8')!.uthmani); // text from the Mushaf dataset, not the model
    expect(verse.tafsir, 'يقول تعالى ذكره: شرح الآية 60:8');
    expect(r.usage['output_tokens'], 300);

    // Request shape
    expect(g.urls.first.path, '/v1beta/models/gemini-test:generateContent');
    expect(g.headers.first['x-goog-api-key'], 'g-key');
    final first = g.requests.first;
    expect((first['systemInstruction']['parts'] as List).single['text'], contains('You are Basirah'));
    final decls = (first['tools'] as List).single['functionDeclarations'] as List;
    expect([for (final d in decls) d['name']], ['search_quran', 'read_tafsir', 'submit_answer']);
    expect(decls.last['parametersJsonSchema']['required'], contains('kind'));
    expect(decls.last.containsKey('strict'), isFalse);
    expect(first['toolConfig'], {
      'functionCallingConfig': {'mode': 'AUTO'},
    });

    // Second request: the model turn is echoed verbatim (thought signature
    // kept) and the tool result goes back as a functionResponse with the id.
    final second = g.requests[1]['contents'] as List;
    expect(second, hasLength(3));
    expect(second[1]['role'], 'model');
    expect((second[1]['parts'] as List).single['thoughtSignature'], 'sig-1');
    final response = (second[2]['parts'] as List).single['functionResponse'] as Map;
    expect(response['name'], 'search_quran');
    expect(response['id'], 'c1');
    expect(response['response'], contains('results'));

    // Third request: a call without an id is answered by name only.
    final third = g.requests[2]['contents'] as List;
    expect((third[3]['parts'] as List).single['thoughtSignature'], 'sig-2');
    final read = (third[4]['parts'] as List).single['functionResponse'] as Map;
    expect(read['name'], 'read_tafsir');
    expect(read.containsKey('id'), isFalse);
    expect(jsonEncode(read['response']), contains('شرح الآية 60:8'));
  });

  test('the guard applies to Gemini exactly as to Claude', () async {
    final g = ScriptedGemini([
      call('submit_answer', submission(quran: const [
        {'ref': '2:256', 'why': 'cited without reading it'},
      ])),
    ]);
    final r = await pipeline(g).ask('هل يمكنني زيارة عائلتي غير المسلمة؟');
    expect(r.answer.evidence.where((e) => e.isQuran), isEmpty);
    expect(r.guardActions.single, contains('without reading its tafsir'));
  });

  test('per-minute rate limits are retried after the delay Google asks for', () async {
    final g = ScriptedGemini([
      rateLimited(delay: '7s'),
      call('submit_answer', submission(quran: const [])),
    ]);
    final r = await pipeline(g).ask('ما معنى التوحيد؟');
    expect(r.via, Via.ai);
    expect(g.slept.single, const Duration(milliseconds: 7500));
    expect(g.requests, hasLength(2));
  });

  test('an exhausted daily quota (and no other model) falls back at once, labelled busy', () async {
    final g = ScriptedGemini([rateLimited(daily: true)]);
    final r = await pipeline(g).ask('How many angels carry the Throne on the Day of Judgement?');
    expect(r.via, Via.offline);
    expect(r.notice, 'ai_busy');
    expect(g.slept, isEmpty);
    expect(r.guardActions, ['gemini:gemini-test daily quota exhausted', 'no model available']);
  });

  group('model fallback chain (free-tier daily quotas)', () {
    test('the next model answers when the first is out of quota, and the first is skipped until reset', () async {
      var now = DateTime.utc(2026, 9, 27, 10);
      final first = ScriptedGemini([rateLimited(daily: true), call('submit_answer', submission(quran: const []))]);
      final second = ScriptedGemini([
        call('submit_answer', submission(quran: const [])),
        call('submit_answer', submission(quran: const [])),
      ]);
      final p = AskPipeline(
        kb,
        llm: first.client(model: 'model-a'),
        fallbacks: [second.client(model: 'model-b')],
        quran: quran,
        tabari: FakeTabari(),
        clock: () => now,
      );

      final r1 = await p.ask('ما معنى التوحيد؟');
      expect(r1.via, Via.ai);
      expect(r1.guardActions.first, 'gemini:model-a daily quota exhausted');
      expect(first.requests, hasLength(1));
      expect(second.requests, hasLength(1));
      // The question restarts on the new model: a single fresh user turn.
      expect(second.requests.single['contents'], hasLength(1));

      final r2 = await p.ask('ما معنى الشريعة؟');
      expect(r2.via, Via.ai);
      expect(first.requests, hasLength(1)); // skipped: still out of quota
      expect(second.requests, hasLength(2));

      now = AskPipeline.nextQuotaReset(now).add(const Duration(minutes: 1));
      final r3 = await p.ask('ما معنى الإسلام؟');
      expect(r3.via, Via.ai);
      expect(first.requests, hasLength(2)); // quota reset: preferred model again
    });

    test('an overloaded model hands the question to the next and rests briefly', () async {
      var now = DateTime.utc(2026, 9, 27, 10);
      final overloaded = (503, <String, dynamic>{
        'error': {'code': 503, 'message': 'The model is overloaded.', 'status': 'UNAVAILABLE'},
      });
      final first = ScriptedGemini([for (var i = 0; i < 10; i++) overloaded]);
      final second = ScriptedGemini([
        call('submit_answer', submission(quran: const [])),
        call('submit_answer', submission(quran: const [])),
      ]);
      final p = AskPipeline(
        kb,
        llm: first.client(model: 'model-a'),
        fallbacks: [second.client(model: 'model-b')],
        quran: quran,
        tabari: FakeTabari(),
        clock: () => now,
      );
      final r1 = await p.ask('ما معنى التوحيد؟');
      expect(r1.via, Via.ai);
      expect(r1.guardActions.first, 'gemini:model-a unavailable (503)');
      final tried = first.requests.length;

      now = now.add(const Duration(minutes: 1));
      await p.ask('ما معنى الشريعة؟');
      expect(first.requests.length, tried); // still resting
      expect(second.requests, hasLength(2));
    });

    test('a model that rejects the request (e.g. retired) hands over instead of stopping', () async {
      final retired = (404, <String, dynamic>{
        'error': {'code': 404, 'message': 'This model is no longer available to new users.', 'status': 'NOT_FOUND'},
      });
      final first = ScriptedGemini([rateLimited(daily: true)]);
      final second = ScriptedGemini([retired]);
      final third = ScriptedGemini([call('submit_answer', submission(quran: const []))]);
      final p = AskPipeline(
        kb,
        llm: first.client(model: 'model-a'),
        fallbacks: [second.client(model: 'model-b'), third.client(model: 'model-c')],
        quran: quran,
        tabari: FakeTabari(),
      );
      final r = await p.ask('ما معنى التوحيد؟');
      expect(r.via, Via.ai);
      expect(r.guardActions.take(2), [
        'gemini:model-a daily quota exhausted',
        'gemini:model-b rejected (404)',
      ]);
    });

    test('daily quotas reset at midnight Pacific (UTC−8, never early)', () {
      expect(AskPipeline.nextQuotaReset(DateTime.utc(2026, 9, 27, 10)), DateTime.utc(2026, 9, 28, 8));
      expect(AskPipeline.nextQuotaReset(DateTime.utc(2026, 9, 27, 7, 59)), DateTime.utc(2026, 9, 27, 8));
    });

    test('several models from GEMINI_MODEL, in order', () {
      final llms = llmsFromEnv({'GEMINI_API_KEY': 'g', 'GEMINI_MODEL': 'model-a, model-b ,model-c'});
      expect([for (final m in llms) m.model], ['model-a', 'model-b', 'model-c']);
    });
  });

  test('a safety or recitation stop becomes an abstention', () async {
    for (final reason in ['SAFETY', 'RECITATION']) {
      final g = ScriptedGemini([finish(reason)]);
      final r = await pipeline(g).ask('What is the ruling on music in Islam?');
      expect(r.answer.kind, AnswerKind.abstain, reason: reason);
      expect(r.guardActions, contains('model declined (refusal)'));
    }
  });

  test('MAX_TOKENS falls back to the offline router', () async {
    final g = ScriptedGemini([finish('MAX_TOKENS')]);
    final r = await pipeline(g).ask('What is the ruling on music in Islam?');
    expect(r.via, Via.offline);
  });

  test('a text-only reply is nudged, and consecutive user turns are merged', () async {
    final g = ScriptedGemini([
      (
        200,
        {
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': 'thinking out loud', 'thought': true},
                  {'text': 'Here is my answer'},
                ],
              },
              'finishReason': 'STOP',
            },
          ],
        },
      ),
      call('submit_answer', submission(quran: const [])),
    ]);
    final r = await pipeline(g).ask('ما معنى التوحيد؟');
    expect(r.answer.kind, AnswerKind.answer);
    final contents = g.requests[1]['contents'] as List;
    expect([for (final c in contents) c['role']], ['user', 'model', 'user']);
    expect((contents[1]['parts'] as List).first['thought'], isTrue); // echoed verbatim
    expect(jsonEncode(contents[2]), contains('submit_answer'));
  });

  group('provider selection', () {
    test('Gemini when its key is set', () {
      final llm = llmFromEnv({'GEMINI_API_KEY': 'g', 'GEMINI_MODEL': 'gemini-x'});
      expect(llm?.provider, 'gemini');
      expect(llm?.model, 'gemini-x');
    });
    test('Claude when only its key is set', () {
      final llm = llmFromEnv({'ANTHROPIC_API_KEY': 'a'});
      expect(llm?.provider, 'claude');
      expect(llm?.model, 'claude-sonnet-5');
    });
    test('AI_PROVIDER chooses when both keys are set', () {
      expect(llmFromEnv({'GEMINI_API_KEY': 'g', 'ANTHROPIC_API_KEY': 'a'})?.provider, 'gemini');
      expect(llmFromEnv({'GEMINI_API_KEY': 'g', 'ANTHROPIC_API_KEY': 'a', 'AI_PROVIDER': 'claude'})?.provider, 'claude');
    });
    test('no key, or a provider without its key → no AI', () {
      expect(llmFromEnv({}), isNull);
      expect(llmFromEnv({'GEMINI_API_KEY': ' '}), isNull);
      expect(llmFromEnv({'AI_PROVIDER': 'claude', 'GEMINI_API_KEY': 'g'}), isNull);
    });
  });
}
