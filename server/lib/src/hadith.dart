import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// One hadith as its publisher records it, in one language.
class HadithRecord {
  const HadithRecord({
    required this.id,
    required this.lang,
    required this.title,
    required this.text,
    required this.attribution,
    required this.grade,
    required this.explanation,
    required this.url,
  });

  /// Basirah's id, e.g. «he:5361» (HadeethEnc 5361).
  final String id;
  final String lang;

  /// The publisher's short title (a key phrase of the narration).
  final String title;

  /// The narration, verbatim.
  final String text;

  /// «رواه الترمذي» / «Narrated by At-Termedhy».
  final String attribution;

  /// The grade as the publisher recorded it, e.g. «حسن لغيره».
  final String grade;

  /// The publisher's own explanation.
  final String explanation;
  final String url;

  Map<String, dynamic> toJson() => {
    'id': id,
    'lang': lang,
    'title': title,
    'text': text,
    'attribution': attribution,
    'grade': grade,
    'explanation': explanation,
    'url': url,
  };

  factory HadithRecord.fromJson(Map<String, dynamic> j) => HadithRecord(
    id: j['id'] as String,
    lang: j['lang'] as String,
    title: j['title'] as String,
    text: j['text'] as String,
    attribution: j['attribution'] as String,
    grade: j['grade'] as String,
    explanation: j['explanation'] as String,
    url: j['url'] as String,
  );
}

/// A hadith found for the model, in Arabic (the grade is checked on the
/// Arabic record) and, for another answer language, in that language too.
class HadithFound {
  const HadithFound(this.arabic, this.local);
  final HadithRecord arabic;
  final HadithRecord? local;
  String get id => arabic.id;
}

/// The reference pack (p.3): «الأحاديث الصحيحة من الصحيحين، وما يضاف من
/// كتب السنة بعد التأكد من صحته»; «لا ينسب حديث دون مصدر وحكم معتمد».
/// Basirah keeps a hadith only when its recorded grade is an accepted one
/// (صحيح or حسن, including «لغيره»), never ضعيف or موضوع.
bool acceptedGrade(String arabicGrade) {
  final g = arabicGrade.replaceAll(RegExp('[ً-ْ]'), '');
  if (RegExp('ضعيف|موضوع|منكر|باطل|لا أصل|لا يصح').hasMatch(g)) return false;
  return g.contains('صحيح') || g.contains('حسن') || g.contains('متفق عليه');
}

/// Hadith from موسوعة الأحاديث النبوية (HadeethEnc, جمعية خدمة المحتوى
/// الإسلامي باللغات — reference pack p.9): searched through the
/// association's MCP server (mcp.islamiccontent.org) and read from the
/// HadeethEnc API (hadeethenc.com/api-docs). Records are cached on disk.
class HadeethEnc {
  HadeethEnc({http.Client? client, this.cacheDir = 'cache/hadeethenc'}) : _http = client ?? http.Client();

  static const mcpUrl = 'https://mcp.islamiccontent.org/mcp';
  static const apiUrl = 'https://hadeethenc.com/api/v1/hadeeths/one/';
  final http.Client _http;
  final String cacheDir;
  final _memory = <String, HadithRecord?>{};

  /// HadeethEnc ids matching [query] (Arabic or English words), best first.
  Future<List<String>> search(String query, {int limit = 6}) async {
    try {
      final res = await _http
          .post(
            Uri.parse(mcpUrl),
            headers: {
              'content-type': 'application/json',
              'accept': 'application/json, text/event-stream',
              'mcp-protocol-version': '2025-06-18',
            },
            body: utf8.encode(jsonEncode({
              'jsonrpc': '2.0',
              'id': 1,
              'method': 'tools/call',
              'params': {
                'name': 'search',
                'arguments': {'query': query, 'sources': ['hadith'], 'language': 'ar', 'limit': limit},
              },
            })),
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return const [];
      final body = utf8.decode(res.bodyBytes);
      final data = body.trimLeft().startsWith('{')
          ? body
          : body.split('\n').where((l) => l.startsWith('data: ')).map((l) => l.substring(6)).join();
      final result = (jsonDecode(data) as Map)['result'] as Map?;
      final items = ((result?['structuredContent'] as Map?)?['results'] as List?) ?? const [];
      return [
        for (final r in items.cast<Map>())
          if (RegExp(r'^hadith:(\d+):').firstMatch(r['id'] as String? ?? '') case final m?) m[1]!,
      ];
    } on Exception {
      return const [];
    }
  }

  /// The hadith [number] in [lang], or null.
  Future<HadithRecord?> get(String number, String lang) async {
    final key = '${number}_$lang';
    if (_memory.containsKey(key)) return _memory[key];
    final file = File('$cacheDir/$key.json');
    if (file.existsSync()) {
      return _memory[key] = HadithRecord.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
    }
    try {
      final res = await _http
          .get(Uri.parse('$apiUrl?language=$lang&id=$number'), headers: {'user-agent': 'basirah/1.0'})
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (j is! Map || j['hadeeth'] == null) return _memory[key] = null;
      final record = HadithRecord(
        id: 'he:$number',
        lang: lang,
        title: (j['title'] as String? ?? '').trim(),
        text: (j['hadeeth'] as String).trim(),
        attribution: (j['attribution'] as String? ?? '').trim(),
        grade: (j['grade'] as String? ?? '').trim(),
        explanation: (j['explanation'] as String? ?? '').trim(),
        url: 'https://hadeethenc.com/$lang/browse/hadith/$number',
      );
      try {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(jsonEncode(record.toJson()));
      } on FileSystemException {
        // Read-only filesystem: memory only.
      }
      return _memory[key] = record;
    } on Exception {
      return null;
    }
  }

  /// Search, then read each result in Arabic (and in [lang] when it is not
  /// Arabic); only accepted grades are kept.
  Future<List<HadithFound>> find(String query, {String lang = 'ar', int limit = 4}) async {
    final ids = await search(query, limit: limit + 2);
    final found = <HadithFound>[];
    for (final n in ids) {
      if (found.length >= limit) break;
      final ar = await get(n, 'ar');
      if (ar == null || !acceptedGrade(ar.grade)) continue;
      final local = lang == 'ar' ? null : await get(n, lang);
      found.add(HadithFound(ar, local));
    }
    return found;
  }

  /// A hadith by Basirah id («he:5361»), Arabic and [lang].
  Future<HadithFound?> byId(String id, {String lang = 'ar'}) async {
    final m = RegExp(r'^he:(\d+)$').firstMatch(id);
    if (m == null) return null;
    final ar = await get(m[1]!, 'ar');
    if (ar == null || !acceptedGrade(ar.grade)) return null;
    return HadithFound(ar, lang == 'ar' ? null : await get(m[1]!, lang));
  }
}
