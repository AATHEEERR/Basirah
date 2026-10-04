import 'claude.dart';
import 'gemini.dart';
import 'llm.dart';

/// Picks the answering model from the environment (`server/.env`):
///
///   AI_PROVIDER      `gemini` | `claude` — default: Gemini when
///                    GEMINI_API_KEY is set, otherwise Claude when
///                    ANTHROPIC_API_KEY is set, otherwise none
///   GEMINI_API_KEY   Google AI Studio key
///   GEMINI_MODEL     one model id, or several separated by commas: the
///                    first is preferred, the others take over when it is
///                    out of daily quota (default [GeminiClient.defaultModel])
///   GEMINI_THINKING  optional thinking level: minimal | low | medium | high
///   ANTHROPIC_API_KEY, CLAUDE_MODEL (default claude-sonnet-5),
///   CLAUDE_EFFORT (default high), CLAUDE_FALLBACKS (`default` | `off`),
///   ANTHROPIC_BASE_URL
///
/// Returns an empty list when no usable key is configured: the API then
/// serves curated and offline answers only.
List<LlmClient> llmsFromEnv(Map<String, String> env) {
  String? value(String k) => (env[k]?.trim().isEmpty ?? true) ? null : env[k]!.trim();
  final geminiKey = value('GEMINI_API_KEY');
  final claudeKey = value('ANTHROPIC_API_KEY');
  final provider =
      value('AI_PROVIDER')?.toLowerCase() ??
      (geminiKey != null
          ? 'gemini'
          : claudeKey != null
          ? 'claude'
          : null);
  return switch (provider) {
    'gemini' when geminiKey != null => [
      for (final model in (value('GEMINI_MODEL') ?? GeminiClient.defaultModel).split(','))
        if (model.trim().isNotEmpty)
          GeminiClient(apiKey: geminiKey, model: model.trim(), thinkingLevel: value('GEMINI_THINKING')),
    ],
    'claude' when claudeKey != null => [
      ClaudeClient(
        apiKey: claudeKey,
        model: value('CLAUDE_MODEL') ?? 'claude-sonnet-5',
        effort: value('CLAUDE_EFFORT') ?? 'high',
        useFallbacks: (value('CLAUDE_FALLBACKS') ?? 'default') != 'off',
        baseUrl: value('ANTHROPIC_BASE_URL') ?? 'https://api.anthropic.com',
      ),
    ],
    _ => const [],
  };
}

/// The preferred model only (see [llmsFromEnv]).
LlmClient? llmFromEnv(Map<String, String> env) => llmsFromEnv(env).firstOrNull;
