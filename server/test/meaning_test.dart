import 'dart:convert';
import 'dart:io';

import 'package:basirah_server/basirah_server.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('the verse number and footnote markers are removed, nothing else', () {
    expect(cleanMeaning('186. Markay addoomahaygu i kaa weydiiyaan', 186), 'Markay addoomahaygu i kaa weydiiyaan');
    expect(cleanMeaning('When My slaves ask you[1] concerning Me', 186), 'When My slaves ask you concerning Me');
    expect(cleanMeaning('186 people', 8), '186 people');
  });

  test('every language has its audio file name and IslamHouse page', () {
    expect(MeaningSource.audioUrl('tagalog_rwwad', 2, 186), 'https://d.quranenc.com/data/audio/tagalog_rwwad/002186.mp3');
    expect(meaningLanguages.map((l) => l.key).toSet(), hasLength(25));
    expect(meaningLanguages.map((l) => l.iso).toSet(), hasLength(25));
    // 13 with a recorded voice, 12 text only.
    expect(meaningLanguages.where((l) => l.audio), hasLength(13));
    for (final l in meaningLanguages) {
      expect(l.toJson()['islamhouse'], 'https://islamhouse.com/${l.iso}/main/');
    }
  });

  test('a text-only language plays no voice', () async {
    final tmp = Directory.systemTemp.createTempSync('basirah_meaning');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final source = MeaningSource(
      cacheDir: tmp.path,
      client: MockClient((req) async => http.Response.bytes(utf8.encode(jsonEncode({'result': {'translation': 'Aur jab'}})), 200)),
    );
    final ur = meaningLanguages.firstWhere((l) => l.iso == 'ur');
    final v = await source.verse(2, 186, ur);
    expect(v!.audio, isNull);
    expect(v.toJson().containsKey('audio'), isFalse);
  });

  test('reads the approved translation once, then from the cache', () async {
    final tmp = Directory.systemTemp.createTempSync('basirah_meaning');
    addTearDown(() => tmp.deleteSync(recursive: true));
    var calls = 0;
    final source = MeaningSource(
      cacheDir: tmp.path,
      client: MockClient((req) async {
        calls++;
        expect(req.url.toString(), 'https://quranenc.com/api/v1/translation/aya/tagalog_rwwad/60/8');
        return http.Response.bytes(utf8.encode(jsonEncode({'result': {'translation': 'Hindi sumasaway sa inyo si Allāh'}})), 200);
      }),
    );
    final tl = meaningLanguages.firstWhere((l) => l.iso == 'tl');
    final v = await source.verse(60, 8, tl);
    expect(v!.text, 'Hindi sumasaway sa inyo si Allāh');
    expect(v.audio, 'https://d.quranenc.com/data/audio/tagalog_rwwad/060008.mp3');
    await source.verse(60, 8, tl);
    expect(calls, 1);
  });
}
