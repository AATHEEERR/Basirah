import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm.dart';

/// Minimal Claude Messages API client over raw HTTP (Dart has no official
/// Anthropic SDK).
class ClaudeClient implements LlmClient {
  ClaudeClient({
    required this.apiKey,
    this.model = 'claude-sonnet-5',
    this.effort = 'high',
    this.useFallbacks = true,
    this.timeout = const Duration(seconds: 120),
    String baseUrl = 'https://api.anthropic.com',
    http.Client? client,
  }) : _endpoint = Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}/v1/messages'),
       _http = client ?? http.Client();

  final String apiKey;
  @override
  final String model;

  @override
  String get provider => 'claude';

  final String effort;

  /// Server-side refusal fallbacks (`fallbacks: "default"`): if a safety
  /// classifier declines, the API retries on Anthropic's recommended model.
  final bool useFallbacks;
  final Duration timeout;
  final http.Client _http;
  final Uri _endpoint;

  /// Sends one request. [system] is sent as a single cached block (tools
  /// render before it, so both are covered by the cache breakpoint).
  @override
  Future<ModelTurn> send({
    required String system,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools = const [],
    int maxTokens = 16000,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'max_tokens': maxTokens,
      'system': [
        {
          'type': 'text',
          'text': system,
          'cache_control': {'type': 'ephemeral'},
        },
      ],
      'messages': messages,
      if (tools.isNotEmpty) 'tools': tools,
      if (tools.isNotEmpty) 'tool_choice': {'type': 'auto'},
      'output_config': {'effort': effort},
      if (useFallbacks) 'fallbacks': 'default',
    };

    final http.Response res;
    try {
      res = await _http
          .post(
            _endpoint,
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              if (useFallbacks) 'anthropic-beta': 'server-side-fallback-2026-07-01',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on Exception catch (e) {
      throw ModelException('network error: $e', retryable: true);
    }

    if (res.statusCode != 200) {
      final retryable = res.statusCode == 429 || res.statusCode >= 500;
      String message;
      try {
        final err = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        message = ((err['error'] as Map?)?['message'] as String?) ?? res.body;
      } on FormatException {
        message = res.body;
      }
      throw ModelException(message, statusCode: res.statusCode, retryable: retryable);
    }
    try {
      return ModelTurn(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
    } on FormatException {
      throw ModelException('response was not valid JSON');
    }
  }

  @override
  void close() => _http.close();
}
