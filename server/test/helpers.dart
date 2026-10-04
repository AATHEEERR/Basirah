import 'dart:convert';
import 'dart:io';

import 'package:basirah_server/basirah_server.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

QuranLibrary loadFixtureQuran() => QuranLibrary.fromJson(
  jsonDecode(File('test/fixtures/quran_sample.json').readAsStringSync()) as Map<String, dynamic>,
);

class FakeTabari implements TafsirSource {
  FakeTabari({this.unavailable = const {}});

  /// Verse keys for which the tafsir cannot be fetched.
  final Set<String> unavailable;
  final requested = <String>[];

  @override
  String get name => 'تفسير الطبري';

  @override
  Future<String?> forVerse(String key) async {
    requested.add(key);
    if (unavailable.contains(key)) return null;
    return 'القول في تأويل قوله تعالى: …\nيقول تعالى ذكره: شرح الآية $key\n1234 - حدثنا فلان…';
  }

  @override
  String urlFor(String key) => 'https://example.test/tabari/$key';
}

/// A Messages API double that replays scripted assistant turns and records
/// every request body.
class ScriptedClaude {
  ScriptedClaude(this.turns);

  final List<Map<String, dynamic>> turns;
  final requests = <Map<String, dynamic>>[];
  final headers = <Map<String, String>>[];

  ClaudeClient client() => ClaudeClient(
    apiKey: 'test-key',
    client: MockClient((req) async {
      requests.add(jsonDecode(req.body) as Map<String, dynamic>);
      headers.add(req.headers);
      if (turns.isEmpty) return http.Response('{"error":{"message":"no more turns"}}', 500);
      return http.Response.bytes(
        utf8.encode(jsonEncode(turns.removeAt(0))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
}

var _n = 0;

Map<String, dynamic> toolTurn(List<(String, Map<String, dynamic>)> calls) => {
  'id': 'msg_${_n++}',
  'type': 'message',
  'role': 'assistant',
  'model': 'claude-opus-5',
  'stop_reason': 'tool_use',
  'content': [
    {'type': 'thinking', 'thinking': '', 'signature': 'sig_$_n'},
    for (final (name, input) in calls)
      {'type': 'tool_use', 'id': 'toolu_${_n++}', 'name': name, 'input': input},
  ],
  'usage': {'input_tokens': 100, 'output_tokens': 20, 'cache_read_input_tokens': 9000},
};

Map<String, dynamic> textTurn(String text, {String stop = 'end_turn'}) => {
  'id': 'msg_${_n++}',
  'type': 'message',
  'role': 'assistant',
  'model': 'claude-opus-5',
  'stop_reason': stop,
  'content': stop == 'refusal' ? [] : [{'type': 'text', 'text': text}],
  'usage': {'input_tokens': 10, 'output_tokens': 5},
};

Map<String, dynamic> submission({
  String kind = 'answer',
  String level = 'A',
  String confidence = 'high',
  String principle = 'نعم؛ يأمر الإسلام ببر الوالدين والإحسان إليهما ولو كانا غير مسلمين.',
  List<Map<String, String>> quran = const [
    {'ref': '60:8', 'why': 'تبيح الآية البر والإحسان لغير المحاربين كما في التفسير.'},
  ],
  List<String> hadithIds = const ['h_asma'],
  List<String> entries = const ['fam-visit'],
  bool english = false,
}) => {
  'kind': kind,
  'level': level,
  'confidence': confidence,
  'principle': english
      ? 'Yes. Islam commands honouring parents and being kind to them, even if they are not Muslim.'
      : principle,
  'culture': '',
  'guidance': [english ? 'Visit your family and be kind to them.' : 'زر أهلك وأحسن إليهم.'],
  'khilafAgreed': '',
  'khilafNote': '',
  'referReason': '',
  'referTo': '',
  'abstainReason': '',
  'quran': quran,
  'hadith': [
    for (final id in hadithIds)
      {'id': id, 'why': english ? 'It shows that keeping ties with a non-Muslim mother is allowed.' : 'يدل الحديث على جواز صلة الأم غير المسلمة.'},
  ],
  'basedOnEntries': entries,
};
