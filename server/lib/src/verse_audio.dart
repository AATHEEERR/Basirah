import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A reciter offered by the association's MCP server (`get_quran_audio`).
class VerseReciter {
  const VerseReciter(this.id, this.ar, this.en);

  /// The MCP server's reciter name.
  final String id;
  final String ar;
  final String en;

  Map<String, dynamic> toJson() => {'id': id, 'ar': ar, 'en': en};
}

/// The reciters, in the order the app lists them.
const verseReciters = [
  VerseReciter('husary', 'محمود خليل الحصري', 'Mahmoud Khalil Al-Husary'),
  VerseReciter('minshawy', 'محمد صديق المنشاوي', 'Muhammad Siddiq Al-Minshawi'),
  VerseReciter('alafasy', 'مشاري العفاسي', 'Mishary Alafasy'),
  VerseReciter('hudhaify', 'علي بن عبدالرحمن الحذيفي', 'Ali Al-Hudhaifi'),
  VerseReciter('sudais', 'عبدالرحمن السديس', 'Abdulrahman Al-Sudais'),
  VerseReciter('abdulbasit', 'عبدالباسط عبدالصمد', 'Abdul Basit Abdul Samad'),
  VerseReciter('shuraym', 'سعود الشريم', 'Saud Al-Shuraim'),
  VerseReciter('tablaway', 'محمد محمود الطبلاوي', 'Mohammad Al-Tablawi'),
];

/// «المصحف المعلّم» (Al-Minshawi, with children repeating each verse after
/// him): whole surahs from المكتبة الصوتية للقرآن الكريم (mp3quran.net).
String teacherUrl(int surah) => 'https://cdn.mp3quran.net/audio/muhammad-minshawi/r3/${surah.toString().padLeft(3, '0')}.mp3';

/// One MP3 per verse, from the association's MCP server
/// (mcp.islamiccontent.org, `get_quran_audio`): small files that start at
/// the verse, instead of seeking inside a whole-surah recording. The links
/// are cached on disk per reciter.
class VerseAudioSource {
  VerseAudioSource({http.Client? client, this.cacheDir = 'cache/verse_audio'}) : _http = client ?? http.Client();

  static const mcpUrl = 'https://mcp.islamiccontent.org/mcp';
  final http.Client _http;
  final String cacheDir;
  final _memory = <String, String>{};

  /// The MP3 link for [surah]:[ayah] by [reciter], or null.
  Future<String?> url(int surah, int ayah, {String reciter = 'husary'}) async {
    final r = verseReciters.where((v) => v.id == reciter).firstOrNull ?? verseReciters.first;
    final key = '${r.id}/${surah}_$ayah';
    final hit = _memory[key];
    if (hit != null) return hit;
    final file = File('$cacheDir/$key.txt');
    if (file.existsSync()) return _memory[key] = file.readAsStringSync().trim();
    try {
      final res = await _http
          .post(
            Uri.parse(mcpUrl),
            headers: {
              'content-type': 'application/json',
              'accept': 'application/json, text/event-stream',
              'mcp-protocol-version': '2025-06-18',
            },
            body: utf8.encode(
              jsonEncode({
                'jsonrpc': '2.0',
                'id': 1,
                'method': 'tools/call',
                'params': {
                  'name': 'get_quran_audio',
                  'arguments': {'surah': surah, 'ayah': ayah, 'reciter': r.id, 'language': 'ar'},
                },
              }),
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final link = audioLinkFrom(utf8.decode(res.bodyBytes));
      if (link == null) return null;
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(link);
      return _memory[key] = link;
    } on Exception {
      return null;
    }
  }
}

/// The first MP3 link in an MCP reply (JSON or an event stream).
String? audioLinkFrom(String body) {
  final data = body.trimLeft().startsWith('{')
      ? body
      : body.split('\n').where((l) => l.startsWith('data: ')).map((l) => l.substring(6)).join();
  try {
    final content = ((jsonDecode(data) as Map)['result'] as Map?)?['content'] as List?;
    final text = [for (final c in content ?? const []) if (c is Map && c['type'] == 'text') c['text'] as String].join('\n');
    return RegExp(r'https://\S+?\.mp3').firstMatch(text)?.group(0);
  } on FormatException {
    return null;
  }
}
