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
///   ANTHROPIC_API_KEY, CLAUDE_MODEL (one model id or several separated by
///                    commas, tried in order; default claude-opus-5-5),
///   CLAUDE_EFFORT (default high), CLAUDE_FALLBACKS (`default` | `off`),
///   ANTHROPIC_BASE_URL
///
/// With both keys set, the chosen provider's models come first and the
/// other provider's follow as the last resort (e.g. Claude Sonnet → Claude
/// Haiku → the Gemini chain).
///
/// Returns an empty list when no usable key is configured — or when
/// AI_PROVIDER names a provider without its key: the API then serves curated
/// and offline answers only.
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
  List<String> models(String key, String fallback) => [
    for (final m in (value(key) ?? fallback).split(','))
      if (m.trim().isNotEmpty) m.trim(),
  ];
  final gemini = <LlmClient>[
    if (geminiKey != null)
      for (final model in models('GEMINI_MODEL', GeminiClient.defaultModel))
        GeminiClient(apiKey: geminiKey, model: model, thinkingLevel: value('GEMINI_THINKING')),
  ];
  final claude = <LlmClient>[
    if (claudeKey != null)
      for (final model in models('CLAUDE_MODEL', ClaudeClient.defaultModel))
        ClaudeClient(
          apiKey: claudeKey,
          model: model,
          effort: value('CLAUDE_EFFORT') ?? 'high',
          useFallbacks: (value('CLAUDE_FALLBACKS') ?? 'default') != 'off',
          baseUrl: value('ANTHROPIC_BASE_URL') ?? 'https://api.anthropic.com',
        ),
  ];
  return switch (provider) {
    'gemini' when geminiKey != null => [...gemini, ...claude],
    'claude' when claudeKey != null => [...claude, ...gemini],
    _ => const [],
  };
}

/// The preferred model only (see [llmsFromEnv]).
LlmClient? llmFromEnv(Map<String, String> env) => llmsFromEnv(env).firstOrNull;
