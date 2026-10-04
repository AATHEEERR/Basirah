import 'dart:convert';
import 'dart:io';

import 'package:basirah_server/basirah_server.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// The reply of the association's MCP server, as an event stream (the shape
/// it answered with on 4 Oct 2026).
String mcpReply(String link) => 'event: message\ndata: ${jsonEncode({
  'result': {
    'content': [
      {'type': 'text', 'text': 'Audio for Qur’an 2:186 — husary:\n$link\n\nVerse page: https://islamenc.com/ar/quran/2/186'},
    ],
  },
  'jsonrpc': '2.0',
  'id': 1,
})}\n';

void main() {
  test('the MP3 link is read from an event-stream or a JSON reply', () {
    const link = 'https://everyayah.com/data/Husary_64kbps/002186.mp3';
    expect(audioLinkFrom(mcpReply(link)), link);
    expect(audioLinkFrom(mcpReply(link).split('data: ').last), link);
    expect(audioLinkFrom('not json'), isNull);
  });

  test('asks for the verse and reciter, then serves the link from the cache', () async {
    final tmp = Directory.systemTemp.createTempSync('basirah_audio');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final calls = <Map<String, dynamic>>[];
    final source = VerseAudioSource(
      cacheDir: tmp.path,
      client: MockClient((req) async {
        calls.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response.bytes(utf8.encode(mcpReply('https://everyayah.com/data/Minshawy_Murattal_128kbps/002186.mp3')), 200);
      }),
    );
    expect(await source.url(2, 186, reciter: 'minshawy'), 'https://everyayah.com/data/Minshawy_Murattal_128kbps/002186.mp3');
    expect(await source.url(2, 186, reciter: 'minshawy'), isNotNull);
    expect(calls, hasLength(1));
    expect(calls.single['params'], {
      'name': 'get_quran_audio',
      'arguments': {'surah': 2, 'ayah': 186, 'reciter': 'minshawy', 'language': 'ar'},
    });
    // An unknown reciter falls back to the first one.
    await source.url(1, 1, reciter: 'nobody');
    expect((calls.last['params'] as Map)['arguments']['reciter'], 'husary');
  });
}
