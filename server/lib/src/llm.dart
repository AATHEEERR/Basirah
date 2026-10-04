/// Thrown when a model call fails or returns something unusable.
class ModelException implements Exception {
  ModelException(this.message, {this.statusCode, this.retryable = false, this.quotaExhausted = false});

  final String message;
  final int? statusCode;
  final bool retryable;

  /// The model's daily quota is used up: another model may still answer.
  final bool quotaExhausted;

  @override
  String toString() => 'ModelException($statusCode): $message';
}

/// One model response, in the Claude Messages shape every provider maps to:
/// `stop_reason` (`end_turn` | `tool_use` | `max_tokens` | `refusal`),
/// `model`, `usage`, and `content` blocks (`text`, `tool_use`, plus any
/// provider-specific blocks that must be echoed back unchanged).
class ModelTurn {
  ModelTurn(this.raw);

  final Map<String, dynamic> raw;

  String get stopReason => (raw['stop_reason'] as String?) ?? '';
  String get model => (raw['model'] as String?) ?? '';
  Map<String, dynamic> get usage => (raw['usage'] as Map<String, dynamic>?) ?? const {};

  /// Full content array — echoed back unchanged as the assistant turn
  /// (it carries thinking blocks / thought signatures the next request needs).
  List<dynamic> get content => (raw['content'] as List?) ?? const [];

  List<Map<String, dynamic>> get toolUses => [
    for (final b in content)
      if (b is Map<String, dynamic> && b['type'] == 'tool_use') b,
  ];

  String get text => [
    for (final b in content)
      if (b is Map && b['type'] == 'text') b['text'] as String,
  ].join();
}

/// A chat model the research agent can drive. The conversation is kept in
/// the Claude Messages format (`text`, `tool_use`, `tool_result` blocks);
/// other providers translate to and from it, so the agent, tools and guard
/// are identical whichever model answers.
abstract class LlmClient {
  /// Provider name for logs and `/health`, e.g. `claude` or `gemini`.
  String get provider;

  /// Requested model id.
  String get model;

  Future<ModelTurn> send({
    required String system,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools = const [],
    int maxTokens = 16000,
  });

  void close();
}
