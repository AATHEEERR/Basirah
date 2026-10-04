import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm.dart';

/// Google Gemini (`models.generateContent`, REST) behind [LlmClient].
///
/// The agent keeps the conversation in the Claude Messages format; this
/// client translates it on every call:
///
/// * `tools[].input_schema` → `functionDeclarations[].parametersJsonSchema`;
/// * a Gemini reply comes back with its raw parts in a `gemini_parts` block,
///   and that block is sent back verbatim as the `model` turn — Gemini
///   attaches thought signatures to parts and needs them back while calling
///   functions;
/// * `tool_result` blocks → `functionResponse` parts (matched by name and,
///   when Gemini gave one, by call id).
///
/// Rate limits (HTTP 429, frequent on the free tier) and server errors are
/// retried after the delay the API asks for, within [maxWait] (short: with a
/// chain of models, moving on is faster than waiting); an exhausted daily
/// quota is reported at once.
class GeminiClient implements LlmClient {
  GeminiClient({
    required this.apiKey,
    this.model = defaultModel,
    this.thinkingLevel,
    this.maxWait = const Duration(seconds: 10),
    this.timeout = const Duration(seconds: 75),
    String baseUrl = 'https://generativelanguage.googleapis.com',
    http.Client? client,
    Future<void> Function(Duration)? sleep,
  }) : _base = baseUrl.replaceAll(RegExp(r'/+$'), ''),
       _http = client ?? http.Client(),
       _sleep = sleep ?? Future<void>.delayed;

  static const defaultModel = 'gemini-2.5-flash';

  final String apiKey;

  @override
  final String model;

  @override
  String get provider => 'gemini';

  /// `thinkingConfig.thinkingLevel` (`minimal` | `low` | `medium` | `high`)
  /// for models that take it; null leaves the model's default.
  final String? thinkingLevel;

  /// Longest total time spent waiting on rate-limit retries per request.
  final Duration maxWait;
  final Duration timeout;
  final String _base;
  final http.Client _http;
  final Future<void> Function(Duration) _sleep;
  var _calls = 0;

  static const _refusals = {
    'SAFETY', 'RECITATION', 'BLOCKLIST', 'PROHIBITED_CONTENT', 'SPII', 'BLOCKED', 'LANGUAGE',
  };

  @override
  Future<ModelTurn> send({
    required String system,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools = const [],
    int maxTokens = 16000,
  }) async {
    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': system},
        ],
      },
      'contents': toContents(messages),
      if (tools.isNotEmpty)
        'tools': [
          {
            'functionDeclarations': [
              for (final t in tools)
                {
                  'name': t['name'],
                  'description': t['description'],
                  'parametersJsonSchema': t['input_schema'],
                },
            ],
          },
        ],
      if (tools.isNotEmpty)
        'toolConfig': {
          'functionCallingConfig': {'mode': 'AUTO'},
        },
      'generationConfig': {
        'maxOutputTokens': maxTokens,
        if (thinkingLevel != null) 'thinkingConfig': {'thinkingLevel': thinkingLevel},
      },
    };
    final uri = Uri.parse('$_base/v1beta/models/$model:generateContent');
    var waited = Duration.zero;
    for (var attempt = 0; ; attempt++) {
      final http.Response res;
      try {
        res = await _http
            .post(
              uri,
              headers: {'content-type': 'application/json', 'x-goog-api-key': apiKey},
              body: jsonEncode(body),
            )
            .timeout(timeout);
      } on Exception catch (e) {
        throw ModelException('network error: $e', retryable: true);
      }
      if (res.statusCode == 200) {
        try {
          return _toTurn(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
        } on FormatException {
          throw ModelException('response was not valid JSON');
        }
      }

      final (message, delay, daily) = _error(res);
      final retryable = res.statusCode == 429 || res.statusCode >= 500;
      final wait = delay ?? Duration(seconds: 2 << attempt.clamp(0, 4));
      if (retryable && !daily && waited + wait <= maxWait) {
        waited += wait;
        await _sleep(wait);
        continue;
      }
      throw ModelException(
        daily ? 'daily quota exhausted: $message' : message,
        statusCode: res.statusCode,
        retryable: retryable,
        quotaExhausted: daily,
      );
    }
  }

  /// Claude-format messages → Gemini `contents`.
  static List<Map<String, dynamic>> toContents(List<Map<String, dynamic>> messages) {
    final names = <String, String>{}; // tool_use id → function name
    final callIds = <String, String>{}; // tool_use id → Gemini's own call id
    final out = <Map<String, dynamic>>[];

    // Gemini wants user/model turns; merge consecutive turns of one role.
    void add(String role, List<Map<String, dynamic>> parts) {
      if (parts.isEmpty) return;
      if (out.isNotEmpty && out.last['role'] == role) {
        (out.last['parts'] as List).addAll(parts);
      } else {
        out.add({'role': role, 'parts': parts});
      }
    }

    for (final m in messages) {
      final role = m['role'] == 'assistant' ? 'model' : 'user';
      final content = m['content'];
      if (content is String) {
        add(role, [
          {'text': content},
        ]);
        continue;
      }
      final blocks = [
        for (final b in content as List)
          if (b is Map) b.cast<String, dynamic>(),
      ];
      for (final b in blocks.where((b) => b['type'] == 'tool_use')) {
        names[b['id'] as String] = b['name'] as String;
        if (b['gemini_id'] case final String gid) callIds[b['id'] as String] = gid;
      }
      final raw = blocks.where((b) => b['type'] == 'gemini_parts').firstOrNull;
      if (raw != null) {
        add(role, [
          for (final p in raw['parts'] as List) (p as Map).cast<String, dynamic>(),
        ]);
        continue;
      }
      final parts = <Map<String, dynamic>>[];
      for (final b in blocks) {
        switch (b['type']) {
          case 'text':
            final t = (b['text'] as String?) ?? '';
            if (t.isNotEmpty) parts.add({'text': t});
          case 'tool_use':
            parts.add({
              'functionCall': {'name': b['name'], 'args': b['input'] ?? const <String, dynamic>{}},
            });
          case 'tool_result':
            final id = b['tool_use_id'] as String;
            parts.add({
              'functionResponse': {
                if (callIds[id] case final String gid) 'id': gid,
                'name': names[id] ?? 'unknown',
                'response': _responseObject(b['content'], isError: b['is_error'] == true),
              },
            });
        }
      }
      add(role, parts);
    }
    return out;
  }

  /// A tool result as the JSON object `functionResponse.response` requires.
  static Map<String, dynamic> _responseObject(Object? content, {required bool isError}) {
    final text = content is String ? content : jsonEncode(content);
    if (isError) return {'error': text};
    try {
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : {'result': decoded};
    } on FormatException {
      return {'result': text};
    }
  }

  ModelTurn _toTurn(Map<String, dynamic> j) {
    final blocked = (j['promptFeedback'] as Map?)?['blockReason'];
    final candidates = (j['candidates'] as List?) ?? const [];
    final candidate = candidates.isEmpty ? null : (candidates.first as Map).cast<String, dynamic>();
    final parts = [
      for (final p in ((candidate?['content'] as Map?)?['parts'] as List?) ?? const [])
        (p as Map).cast<String, dynamic>(),
    ];
    final finish = (candidate?['finishReason'] as String?) ?? '';

    final content = <Map<String, dynamic>>[
      if (parts.isNotEmpty) {'type': 'gemini_parts', 'parts': parts},
    ];
    for (final p in parts) {
      if (p['thought'] == true) continue;
      if (p['functionCall'] case final Map call) {
        final gid = call['id'] as String?;
        content.add({
          'type': 'tool_use',
          'id': gid ?? 'gemini_call_${_calls++}',
          'gemini_id': ?gid,
          'name': call['name'],
          'input': (call['args'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
        });
      } else if (p['text'] case final String text) {
        content.add({'type': 'text', 'text': text});
      }
    }

    final hasCalls = content.any((b) => b['type'] == 'tool_use');
    final stop = blocked != null || _refusals.contains(finish)
        ? 'refusal'
        : finish == 'MAX_TOKENS'
        ? 'max_tokens'
        : hasCalls
        ? 'tool_use'
        : 'end_turn';

    final usage = (j['usageMetadata'] as Map?)?.cast<String, dynamic>() ?? const {};
    int n(String k) => (usage[k] as num?)?.toInt() ?? 0;
    return ModelTurn({
      'model': j['modelVersion'] ?? model,
      'stop_reason': stop,
      'content': content,
      'usage': {
        'input_tokens': n('promptTokenCount') - n('cachedContentTokenCount'),
        'output_tokens': n('candidatesTokenCount') + n('thoughtsTokenCount'),
        'cache_read_input_tokens': n('cachedContentTokenCount'),
      },
    });
  }

  /// Error message, the retry delay the API asked for (if any), and whether
  /// a per-day quota is exhausted (retrying today is pointless).
  static (String, Duration?, bool) _error(http.Response res) {
    try {
      final err = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['error'] as Map?;
      final message = (err?['message'] as String?) ?? res.body;
      Duration? delay;
      var daily = false;
      for (final d in (err?['details'] as List?) ?? const []) {
        if (d is! Map) continue;
        if (d['retryDelay'] case final String s) {
          final secs = double.tryParse(s.replaceAll('s', ''));
          if (secs != null) delay = Duration(milliseconds: (secs * 1000).ceil() + 500);
        }
        for (final v in (d['violations'] as List?) ?? const []) {
          if (v is Map && '${v['quotaId']}'.contains('PerDay')) daily = true;
        }
      }
      return (message, delay, daily);
    } on Object {
      return (res.body, null, false);
    }
  }

  @override
  void close() => _http.close();
}
