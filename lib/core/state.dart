import 'dart:convert';

import 'package:basirah_core/basirah_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ask_service.dart';

// ─── Bookmarks (stored on this device only) ────────────────────────────────

class SavedNotifier extends Notifier<List<BasirahAnswer>> {
  static const _key = 'basirah.saved.v1';

  @override
  List<BasirahAnswer> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const [];
      state = [
        for (final s in raw) BasirahAnswer.fromJson(jsonDecode(s) as Map<String, dynamic>),
      ];
    } on Exception {
      // Storage unavailable (private window…): bookmarks stay in memory.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, [for (final a in state) jsonEncode(a.toJson())]);
    } on Exception {
      // Ignore; in-memory state is still correct for this session.
    }
  }

  bool isSaved(BasirahAnswer a) => state.any((s) => s.key == a.key);

  void toggle(BasirahAnswer a) {
    state = isSaved(a) ? state.where((s) => s.key != a.key).toList() : [a, ...state];
    _persist();
  }
}

final savedProvider = NotifierProvider<SavedNotifier, List<BasirahAnswer>>(SavedNotifier.new);

// ─── «سياقي»: the asker's context (stored on this device only) ─────────────

class AskerContextNotifier extends Notifier<AskerContext> {
  static const _key = 'basirah.context.v1';

  @override
  AskerContext build() {
    _load();
    return AskerContext.none;
  }

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw != null) state = AskerContext.fromJson(jsonDecode(raw));
    } on Exception {
      // Storage unavailable: no context.
    }
  }

  Future<void> set(AskerContext value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value.isEmpty) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, jsonEncode(value.toJson()));
      }
    } on Exception {
      // In-memory state is still correct for this session.
    }
  }
}

final askerContextProvider = NotifierProvider<AskerContextNotifier, AskerContext>(AskerContextNotifier.new);

// ─── Onboarding flag ───────────────────────────────────────────────────────

abstract final class Onboarding {
  static const _key = 'basirah.welcomed.v1';

  static Future<bool> seen() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    } on Exception {
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, true);
    } on Exception {
      // Non-critical.
    }
  }
}

// ─── Ask screen: conversation + hand-off from other screens ────────────────

class ChatMessage {
  const ChatMessage.user(this.text)
    : fromUser = true,
      outcome = null,
      pending = false,
      categoryId = null;

  const ChatMessage.assistant({
    required this.text,
    this.outcome,
    this.pending = false,
    this.categoryId,
  }) : fromUser = false;

  final bool fromUser;
  final String text;
  final AskOutcome? outcome;
  final bool pending;
  final String? categoryId;
}

class ChatNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => const [];

  bool get busy => state.any((m) => m.pending);

  /// Last few completed exchanges, summarised for the API's follow-up context.
  List<Map<String, String>> _history() {
    final turns = <Map<String, String>>[];
    for (final m in state) {
      final a = m.outcome?.answer;
      if (m.fromUser || m.pending || a == null) continue;
      final gist = switch (a.kind) {
        AnswerKind.answer => a.principle,
        AnswerKind.khilaf => '${a.khilafAgreed} ${a.khilafNote}',
        AnswerKind.refer => a.referReason,
        AnswerKind.abstain || AnswerKind.offTopic => a.abstainReason,
        // The question asked back, so the reply that follows makes sense.
        AnswerKind.clarify => '${a.clarifyQuestion} (${a.clarifyOptions.join(' / ')})',
      };
      turns.add({'q': m.text, 'a': '[${a.kind.name}/${a.level.code}] ${gist.trim()}'});
    }
    return turns.length <= 4 ? turns : turns.sublist(turns.length - 4);
  }

  /// Asks [question] live. With [retry], re-asks the last question in place
  /// (after a stored fallback) instead of adding a new bubble. [display] is
  /// what the asker's bubble shows when it differs from what is sent (a
  /// tapped option of a clarifying question).
  Future<void> send(String question, {String? categoryId, bool retry = false, String? display}) async {
    final q = question.trim();
    final service = ref.read(askServiceProvider);
    if (q.isEmpty || busy || service == null) return;
    final history = _history().where((t) => !(retry && t['q'] == q)).toList();
    state = [
      if (retry) ...state.take(state.length - 1) else ...state,
      if (!retry) ChatMessage.user(display ?? q),
      ChatMessage.assistant(text: q, pending: true, categoryId: categoryId),
    ];
    final outcome = await service.ask(
      q,
      categoryId: categoryId,
      history: history,
      context: ref.read(askerContextProvider),
    );
    state = [
      for (final m in state)
        if (m.pending) ChatMessage.assistant(text: q, outcome: outcome, categoryId: categoryId) else m,
    ];
  }

  void clear() => state = const [];
}

final chatProvider = NotifierProvider<ChatNotifier, List<ChatMessage>>(ChatNotifier.new);

/// Pre-filled question / category passed to the Ask tab from other screens.
class AskDraft {
  const AskDraft({this.question, this.categoryId});
  final String? question;
  final String? categoryId;
}

final askDraftProvider = StateProvider<AskDraft?>((ref) => null);
