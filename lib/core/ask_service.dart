import 'dart:async';
import 'dart:convert';

import 'package:basirah_core/basirah_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'kb_provider.dart';

/// Why a stored answer is shown instead of a live one.
enum AskNotice { noServer, noAi, busy, rateLimited, network }

/// What the UI shows for one asked question.
class AskOutcome {
  const AskOutcome({required this.answer, this.notice});

  final BasirahAnswer answer;

  /// Set when a live answer was not possible (the UI explains it).
  final AskNotice? notice;

  /// True when this is a stored answer shown because a live one was not
  /// possible (off-topic refusals are final, not "stored").
  bool get isStored => answer.origin != AnswerOrigin.ai && answer.kind != AnswerKind.offTopic;
}

/// Question flow on the client. Every typed question gets a **live** answer:
/// the Basirah API researches it (searches the Quran, reads the tafsir in Dorar,
/// cites only what it read) and the guard checks it. Answers come
/// in the language of the question. Only when a live answer is impossible
/// (no server, server without a key, network error) does the app fall back to
/// the on-device router: the stored answer if one matches, otherwise
/// referral, abstention or an off-topic refusal — never a guess.
class AskService {
  AskService(this.routers, {http.Client? client}) : _http = client ?? http.Client();

  final Map<String, OfflineRouter> routers;
  final http.Client _http;

  /// [history]: earlier turns as `{q, a}` (question + short answer summary)
  /// so the API can resolve follow-ups such as «وماذا عن أمي؟».
  Future<AskOutcome> ask(
    String question, {
    String? categoryId,
    List<Map<String, String>> history = const [],
    AskerContext context = AskerContext.none,
  }) async {
    final router = routers[questionLang(question)] ?? routers['ar']!;
    final previous = history.isEmpty ? null : history.last['q'];
    final local = router.route(question, categoryId: categoryId, previousQuestion: previous);
    AskOutcome stored(AskNotice notice) => AskOutcome(answer: local.answer, notice: notice);

    // Clearly not about Islam: declined right away, same rule as the server
    // (whose word lists are Arabic and English: a question in another
    // language goes to the server, where the model judges the scope).
    final otherLanguage = !const {'ar', 'en'}.contains(detectLanguage(question));
    if (local.offTopic && !otherLanguage) return AskOutcome(answer: local.answer);
    if (!AppConfig.hasApi) return stored(AskNotice.noServer);

    try {
      final res = await _http
          .post(
            Uri.parse('${AppConfig.apiBase}/api/ask'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'question': question,
              'categoryId': ?categoryId,
              'mode': 'live',
              if (history.isNotEmpty) 'history': history,
              if (!context.isEmpty) 'context': context.toJson(),
            }),
          )
          .timeout(const Duration(seconds: 180));
      if (res.statusCode == 429) return stored(AskNotice.rateLimited);
      if (res.statusCode != 200) throw http.ClientException('HTTP ${res.statusCode}');
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final answer = BasirahAnswer.fromJson(body['answer'] as Map<String, dynamic>);
      final notice = switch (body['notice']) {
        'no_ai' => AskNotice.noAi,
        'ai_busy' || 'ai_error' => AskNotice.busy,
        _ => null,
      };
      return AskOutcome(answer: answer, notice: notice);
    } on Exception {
      return stored(AskNotice.network);
    }
  }
}

/// Server capabilities from `/health`.
class ServerStatus {
  const ServerStatus({
    required this.reachable,
    required this.ai,
    this.model,
    this.models = const [],
    this.quranVerses = 0,
  });

  final bool reachable;
  final bool ai;
  final String? model;

  /// The models in the order they are tried (the first, then fallbacks).
  final List<String> models;
  final int quranVerses;
}

final serverStatusProvider = FutureProvider<ServerStatus>((ref) async {
  if (!AppConfig.hasApi) return const ServerStatus(reachable: false, ai: false);
  try {
    final res = await http.get(Uri.parse('${AppConfig.apiBase}/health')).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) return const ServerStatus(reachable: false, ai: false);
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return ServerStatus(
      reachable: true,
      ai: j['ai'] == true,
      model: j['model'] as String?,
      models: [for (final m in (j['models'] as List? ?? const [])) '$m'],
      quranVerses: (j['quranVerses'] as int?) ?? 0,
    );
  } on Exception {
    return const ServerStatus(reachable: false, ai: false);
  }
});

final askServiceProvider = Provider<AskService?>((ref) {
  final routers = ref.watch(routersProvider);
  return routers == null ? null : AskService(routers);
});
