// Fetches the meaning of Yusuf 12:108 («على بصيرة», the verse Basirah is
// named after) in each approved translation on QuranEnc (موسوعة القرآن
// الكريم), verbatim, for the opening of the home page:
//   dart run tool/hero_verse.dart        (from server/)
// Writes ../assets/kb/hero_verse.json: {ISO code: {key, text}}, cleaned as the
// app cleans every meaning (cleanMeaning).
import 'dart:convert';
import 'dart:io';

import 'package:basirah_server/basirah_server.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final out = <String, Map<String, String>>{};
  for (final l in meaningLanguages) {
    final res = await http.get(Uri.parse('https://quranenc.com/api/v1/translation/aya/${l.key}/12/108'));
    if (res.statusCode != 200) {
      stderr.writeln('${l.key}: HTTP ${res.statusCode}');
      exitCode = 1;
      continue;
    }
    final r = (jsonDecode(utf8.decode(res.bodyBytes)) as Map)['result'] as Map;
    // As everywhere else: no leading verse number or footnote markers.
    final text = cleanMeaning(r['translation'] as String, 108);
    if (text.isEmpty) {
      stderr.writeln('${l.key}: empty');
      exitCode = 1;
      continue;
    }
    out[l.iso] = {'key': l.key, 'text': text};
    stdout.writeln('${l.iso.padRight(3)} ${l.key}: ${text.length} chars');
  }
  final file = File('../assets/kb/hero_verse.json');
  file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({'surah': 12, 'ayah': 108, 'source': 'quranenc.com', 'meanings': out})}\n');
  stdout.writeln('${out.length} meanings → ${file.path}');
}
