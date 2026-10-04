import 'dart:convert';
import 'dart:io';

import 'package:basirah_server/basirah_server.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// HadeethEnc double: the MCP search returns [ids]; the API returns
/// [records] by "id_lang".
HadeethEnc fakeHadeethEnc(Directory cache, List<String> ids, Map<String, Map<String, String>> records) => HadeethEnc(
  cacheDir: cache.path,
  client: MockClient((req) async {
    if (req.method == 'POST') {
      final body = {
        'jsonrpc': '2.0',
        'id': 1,
        'result': {
          'structuredContent': {
            'results': [for (final id in ids) {'id': 'hadith:$id:ar', 'title': 't', 'url': 'u'}],
          },
          'content': [],
        },
      };
      return http.Response.bytes(utf8.encode('event: message\ndata: ${jsonEncode(body)}\n\n'), 200);
    }
    final r = records['${req.url.queryParameters['id']}_${req.url.queryParameters['language']}'];
    return r == null ? http.Response('[]', 200) : http.Response.bytes(utf8.encode(jsonEncode(r)), 200);
  }),
);

Map<String, String> rec(String id, String text, String grade, {String attribution = 'رواه الترمذي'}) => {
  'id': id,
  'title': 'عنوان $id',
  'hadeeth': text,
  'attribution': attribution,
  'grade': grade,
  'explanation': 'شرح الحديث $id.',
};

void main() {
  final kb = loadKnowledgeBase('../assets/kb');
  final quran = loadFixtureQuran();
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('basirah_hadith_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('accepted grades (reference pack: a hadith only with a source and an approved grade)', () {
    test('صحيح and حسن, including «لغيره» and «متفق عليه», are accepted', () {
      for (final g in ['صحيح', 'حسن', 'حسن لغيره', 'صحيح لغيره', 'حَسَن', 'متفق عليه']) {
        expect(acceptedGrade(g), isTrue, reason: g);
      }
    });
    test('weak and fabricated grades, and unknown ones, are not', () {
      for (final g in ['ضعيف', 'ضعيف جداً', 'موضوع', 'منكر', 'لا أصل له', '']) {
        expect(acceptedGrade(g), isFalse, reason: g);
      }
    });
  });

  test('search_hadith → cite: text, source and grade come from HadeethEnc, a weak result is never offered', () async {
    final hadith = fakeHadeethEnc(dir, ['5361', '9000'], {
      '5361_ar': rec('5361', 'عن عبد الله بن عمرو قال: «رضا الله في رضا الوالدين».', 'حسن لغيره'),
      '9000_ar': rec('9000', 'نص ضعيف.', 'ضعيف'),
    });
    final s = ScriptedClaude([
      toolTurn([('search_hadith', {'query': 'بر الوالدين'})]),
      toolTurn([
        ('submit_answer', {
          ...submission(quran: const []),
          'hadith': [
            {'id': 'he:5361', 'why': 'يبين الحديث أن رضا الله في رضا الوالدين.'},
            {'id': 'he:9000', 'why': 'حديث ضعيف لا يُعرض.'},
          ],
        }),
      ]),
    ]);
    final pipeline = AskPipeline(kb, llm: s.client(), quran: quran, tafsir: FakeTafsir(), hadith: hadith);
    final r = await pipeline.ask('كيف أتعامل مع والديّ؟');

    final toolResult = (((s.requests[1]['messages'] as List).last as Map)['content'] as List).single as Map;
    expect(toolResult['content'], contains('he:5361'));
    expect(toolResult['content'], isNot(contains('he:9000')));

    final cited = [for (final e in r.answer.evidence) if (!e.isQuran) e];
    expect(cited.map((e) => e.id), ['he:5361']);
    final e = cited.single;
    expect(e.text, 'عن عبد الله بن عمرو قال: «رضا الله في رضا الوالدين».');
    expect(e.source, 'رواه الترمذي');
    expect(e.grade, 'حسن لغيره');
    expect(e.tafsir, 'شرح الحديث 5361.');
    expect(e.tafsirUrl, 'https://hadeethenc.com/ar/browse/hadith/5361');
    expect(e.note, 'يبين الحديث أن رضا الله في رضا الوالدين.');
    expect(r.answer.research, contains('بحث في موسوعة الأحاديث النبوية: «بر الوالدين»'));
    expect(r.guardActions, contains('dropped unknown hadith id he:9000'));
  });

  test('an English answer shows the approved English translation and grade', () async {
    final hadith = fakeHadeethEnc(dir, ['5361'], {
      '5361_ar': rec('5361', 'نص عربي.', 'حسن لغيره'),
      '5361_en': rec('5361', 'The pleasure of Allah is in the pleasure of the parents.', 'Hasan', attribution: 'Narrated by At-Termedhy'),
    });
    final s = ScriptedClaude([
      toolTurn([('search_hadith', {'query': 'بر الوالدين'})]),
      toolTurn([
        ('submit_answer', {
          ...submission(english: true, quran: const []),
          'hadith': [
            {'id': 'he:5361', 'why': 'It ties the pleasure of Allah to the pleasure of parents.'},
          ],
        }),
      ]),
    ]);
    final r = await AskPipeline(kb, llm: s.client(), quran: quran, tafsir: FakeTafsir(), hadith: hadith)
        .ask('How should I treat my parents?');
    final e = r.answer.evidence.singleWhere((e) => !e.isQuran);
    expect(e.text, 'نص عربي.');
    expect(e.translation, 'The pleasure of Allah is in the pleasure of the parents.');
    expect(e.source, 'Narrated by At-Termedhy');
    expect(e.grade, 'Hasan');
  });
}
