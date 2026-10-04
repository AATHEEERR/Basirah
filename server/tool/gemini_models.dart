import 'dart:convert';
import 'dart:io';

import 'package:basirah_server/basirah_server.dart';
import 'package:http/http.dart' as http;

/// Lists the Gemini models this key can call with generateContent, so
/// GEMINI_MODEL can be set to one that exists for the account.
///
///   dart run tool/gemini_models.dart
Future<void> main() async {
  final key = loadEnv()['GEMINI_API_KEY']?.trim() ?? '';
  if (key.isEmpty) {
    stderr.writeln('Set GEMINI_API_KEY in server/.env first.');
    exit(2);
  }
  String? page;
  do {
    final res = await http.get(
      Uri.https('generativelanguage.googleapis.com', '/v1beta/models', {'pageSize': '100', 'pageToken': ?page}),
      headers: {'x-goog-api-key': key},
    );
    if (res.statusCode != 200) {
      stderr.writeln('HTTP ${res.statusCode}: ${res.body}');
      exit(1);
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    for (final m in (j['models'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final methods = (m['supportedGenerationMethods'] as List? ?? const []).cast<String>();
      if (!methods.contains('generateContent')) continue;
      final id = (m['name'] as String).replaceFirst('models/', '');
      stdout.writeln('${id.padRight(40)} ${m['displayName'] ?? ''}${m['thinking'] == true ? '  (thinking)' : ''}');
    }
    page = j['nextPageToken'] as String?;
  } while (page != null && page.isNotEmpty);
}
