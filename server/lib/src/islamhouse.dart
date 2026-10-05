import 'dart:convert';

import 'package:http/http.dart' as http;

/// One IslamHouse library item.
class LibraryItem {
  const LibraryItem({required this.id, required this.title, required this.type, required this.url});

  final String id;
  final String title;

  /// «books», «audios», «videos», «articles»…
  final String type;
  final String url;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'type': type, 'url': url};
}

/// «تعلّم أكثر بلغتك»: what the association's scientific team published on
/// IslamHouse (دار الإسلام) in a language, through the association's MCP
/// server (`browse_library`, filtered by the team's author id). These are
/// the association's own introductions to Islam, reviewed by it, in each
/// language it serves — not a keyword search, so nothing unrelated appears.
class IslamHouseLibrary {
  IslamHouseLibrary({http.Client? client, DateTime Function()? clock})
    : _http = client ?? http.Client(),
      _clock = clock ?? DateTime.now;

  static const mcpUrl = 'https://mcp.islamiccontent.org/mcp';

  /// «الفريق العلمي بجمعية خدمة المحتوى الإسلامي باللغات» on IslamHouse.
  static const associationTeam = 61062;

  final http.Client _http;
  final DateTime Function() _clock;
  final _cache = <String, (DateTime, List<LibraryItem>)>{};

  /// The team's items in [iso] (at most [limit]), books first; empty when
  /// there are none or the server cannot be reached.
  Future<List<LibraryItem>> forLanguage(String iso, {int limit = 4}) async {
    if (!RegExp(r'^[a-z]{2,3}$').hasMatch(iso)) return const [];
    final cached = _cache[iso];
    if (cached != null && _clock().difference(cached.$1) < const Duration(hours: 12)) return cached.$2.take(limit).toList();
    // One retry: the MCP server sometimes drops a first request.
    for (var attempt = 0; attempt < 2; attempt++) {
      final items = await _browse(iso);
      if (items.isNotEmpty) {
        // Only a real result is kept: a failed call is tried again next time.
        _cache[iso] = (_clock(), items);
        return items.take(limit).toList();
      }
    }
    return const [];
  }

  Future<List<LibraryItem>> _browse(String iso) async {
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
                'name': 'browse_library',
                'arguments': {'language': iso, 'author': associationTeam},
              },
            })),
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return const [];
      final body = utf8.decode(res.bodyBytes);
      final data = body.trimLeft().startsWith('{')
          ? body
          : body.split('\n').where((l) => l.startsWith('data: ')).map((l) => l.substring(6)).join();
      final content = ((jsonDecode(data) as Map)['result'] as Map?)?['content'] as List? ?? const [];
      final text = [for (final c in content.cast<Map>()) if (c['type'] == 'text') c['text'] as String].join('\n');
      return parseLibrary(text);
    } on Exception {
      return const [];
    }
  }
}

/// `browse_library`'s text: «[15054] Title\n    books · … \n    …\n
/// https://islamcontent.com/fr/content/15054». Books first, then the rest,
/// one item per title.
List<LibraryItem> parseLibrary(String text) {
  final out = <LibraryItem>[];
  final blocks = text.split(RegExp(r'\n(?=\[\d+\] )'));
  for (final b in blocks) {
    final head = RegExp(r'^\[(\d+)\] (.+)$', multiLine: true).firstMatch(b);
    final type = RegExp(r'^\s+(\w+) ·', multiLine: true).firstMatch(b);
    final url = RegExp(r'https://\S+').firstMatch(b);
    if (head == null || url == null) continue;
    out.add(LibraryItem(id: head[1]!, title: head[2]!.trim(), type: type?[1] ?? '', url: url[0]!));
  }
  final seen = <String>{};
  final unique = [for (final i in out) if (seen.add(i.title.toLowerCase())) i];
  unique.sort((a, b) => (a.type == 'books' ? 0 : 1).compareTo(b.type == 'books' ? 0 : 1));
  return unique;
}
