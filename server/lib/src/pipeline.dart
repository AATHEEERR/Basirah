import 'dart:async';

import 'package:basirah_core/basirah_core.dart';

import 'agent.dart';
import 'answer_cache.dart';
import 'guard.dart';
import 'hadith.dart';
import 'llm.dart';
import 'meaning.dart';
import 'prompt.dart';
import 'quran.dart';
import 'tafsir.dart';

/// How the answer was produced — returned to the client and logged.
enum Via { kb, ai, offline, scope }

/// `live`: always research and answer with the model (the Ask tab).
/// `kb`: curated answer when one matches, otherwise the offline router.
enum AskMode { live, kb }

class PipelineResult {
  PipelineResult({
    required this.answer,
    required this.via,
    this.notice,
    this.guardActions = const [],
    this.usage = const {},
  });

  final BasirahAnswer answer;
  final Via via;
  final String? notice;
  final List<String> guardActions;
  final Map<String, int> usage;

  Map<String, dynamic> toJson() => {
    'answer': answer.toJson(),
    'via': via.name,
    if (notice != null) 'notice': notice,
  };
}

/// Question → answer.
///
/// 1. The answer language is the question's language ([detectLanguage]).
///    Arabic and English use the matching knowledge base (Arabic master or
///    English overlay); any other language is answered live in that
///    language, from the English overlay, with each verse's approved
///    translation in that language (QuranEnc) and each hadith's (HadeethEnc)
///    when they exist.
/// 2. Clearly non-Islamic questions are declined deterministically, before
///    any model call.
/// 3. Live mode: the research agent (search the Quran, read the tafsir in
///    موسوعة التفسير — الدرر السنية, cite only what it read, submit cards) → the guard. The model is
///    Claude or Gemini ([LlmClient]); everything around it is the same.
/// 4. When a model's daily quota is exhausted (the Gemini free tier allows a
///    few requests per model per day), the question is asked again, from the
///    start, on the next model in [fallbacks]; that model is skipped until
///    its quota resets.
///    A model that times out or is overloaded is likewise skipped for a few
///    minutes when another model can answer.
/// 5. Any other failure falls back to the offline router (curated answer,
///    referral or abstention), never to an unguarded answer.
class AskPipeline {
  AskPipeline(
    this.kb, {
    this.llm,
    this.fallbacks = const [],
    this.quran,
    TafsirSource? tafsir,
    this.hadith,
    this.cache,
    this.meaning,
    this.answerBudget = const Duration(seconds: 75),
    DateTime Function()? clock,
  }) : tafsir = tafsir ?? (quran == null ? null : DorarTafsir()),
       _clock = clock ?? DateTime.now,
       _routers = {
         'ar': OfflineRouter(kb),
         'en': OfflineRouter(kb.localized('en')),
       } {
    _agents = [
      for (final c in [?llm, ...fallbacks])
        (c, ResearchAgent(llm: c, kb: kb, quran: quran, tafsir: this.tafsir, hadith: hadith)),
    ];
  }

  final KnowledgeBase kb;

  /// The preferred model; [fallbacks] are tried in order when it is out of
  /// daily quota.
  final LlmClient? llm;
  final List<LlmClient> fallbacks;
  final QuranLibrary? quran;
  final TafsirSource? tafsir;

  /// Live hadith search (HadeethEnc); null = the registry only.
  final HadeethEnc? hadith;

  /// Saved live answers ([AnswerCache]); null = always research afresh
  /// (as the evaluation does).
  final AnswerCache? cache;

  /// Approved translations of the meanings, for answers in other languages.
  final MeaningSource? meaning;

  /// The longest a live answer may take, all models included. Past it the
  /// stored answer is shown, with a notice, instead of a longer wait.
  final Duration answerBudget;
  final DateTime Function() _clock;
  final Map<String, OfflineRouter> _routers;
  late final List<(LlmClient, ResearchAgent)> _agents;

  /// Models out of daily quota (or resting after a failure), and when they
  /// can be tried again.
  final _exhaustedUntil = <LlmClient, DateTime>{};

  /// How long a model that timed out or was overloaded is skipped when
  /// other models are configured.
  static const unavailableCooldown = Duration(minutes: 5);

  /// How long a model that rejected the request (e.g. HTTP 404 "no longer
  /// available to new users") is skipped when other models are configured.
  static const rejectedCooldown = Duration(hours: 6);

  bool get aiEnabled => _agents.isNotEmpty;

  /// The guard-actions entry of an answer served from the cache.
  static const cachedAction = 'answered from cache';

  /// The first agent's model, for logs and `/health`.
  ResearchAgent? get agent => _agents.isEmpty ? null : _agents.first.$2;

  OfflineRouter routerFor(String lang) => _routers[lang] ?? _routers['ar']!;

  Future<PipelineResult> ask(
    String question, {
    String? categoryId,
    AskMode mode = AskMode.live,
    List<Turn> history = const [],
    AskerContext asker = AskerContext.none,
  }) async {
    // Arabic and English answers use their own knowledge base; any other
    // language is answered in that language from the English one.
    final answerLang = detectLanguage(question);
    final other = answerLang != 'ar' && answerLang != 'en';
    final lang = other ? 'en' : questionLang(question);
    final router = routerFor(lang);
    final previous = history.isEmpty ? null : history.last.question;
    final routed = router.route(question, categoryId: categoryId, previousQuestion: previous);

    // Clearly not about Islam: declined without calling the model. (The
    // word lists are Arabic and English: in another language the model
    // judges the scope, under the same rules.)
    if (routed.offTopic && !other) {
      return PipelineResult(answer: routed.answer, via: Via.scope);
    }

    if (mode == AskMode.kb || _agents.isEmpty) {
      return PipelineResult(
        answer: routed.answer,
        via: routed.strong ? Via.kb : Via.offline,
        notice: mode == AskMode.live ? 'no_ai' : null,
      );
    }

    // A first question asked before (same words, category and asker
    // context) is answered from the cache, without a model call.
    final cache = this.cache;
    final cacheKey = cache == null || history.isNotEmpty
        ? null
        : cache.keyFor(question: question, kbVersion: kb.version, categoryId: categoryId, context: asker.key);
    if (cacheKey != null) {
      final saved = cache!.get(cacheKey, question);
      if (saved != null) return PipelineResult(answer: saved, via: Via.ai, guardActions: const [cachedAction]);
    }

    // For follow-ups, retrieve with the previous question as context and
    // stay conservative: a personal case earlier in the chat still counts.
    final hits = previous == null
        ? routed.hits
        : router.retriever.search('$previous $question', categoryId: categoryId, limit: 6);
    final signals = previous == null ? routed.signals : _merge(routed.signals, SafetySignals.detect(previous));
    final preread = await _preread(routed.hits);
    final userTurn = buildUserTurn(
      question: question,
      signals: signals,
      hits: hits.take(4).toList(),
      categoryTitle: categoryId == null ? null : kb.category(categoryId)?.title,
      history: history,
      lang: lang,
      answerLanguage: other ? languageName(answerLang) : null,
      asker: asker,
    ) + (preread.isEmpty ? '' : buildPrereadBlock(quran!, preread, lang: lang));

    final skipped = <String>[];
    final watch = Stopwatch()..start();
    for (final (client, agent) in _agents) {
      final until = _exhaustedUntil[client];
      if (until != null && _clock().isBefore(until)) continue;
      final left = answerBudget - watch.elapsed;
      if (left <= Duration.zero) break;
      try {
        final AgentOutcome outcome;
        try {
          outcome = await agent.run(userTurn, lang: lang, answerLang: other ? answerLang : null, preread: preread).timeout(left);
        } on TimeoutException {
          return PipelineResult(
            answer: routed.answer,
            via: Via.offline,
            notice: 'ai_busy',
            guardActions: [...skipped, 'time budget reached (${answerBudget.inSeconds} s)'],
          );
        }
        var finished = _finish(outcome, question, router, signals, hits);
        if (other) {
          finished = PipelineResult(
            answer: await _localize(finished.answer, answerLang),
            via: finished.via,
            notice: finished.notice,
            guardActions: finished.guardActions,
            usage: finished.usage,
          );
        }
        // What the guard did travels with the answer («إيصال بصيرة»).
        final result = finished.guardActions.isEmpty
            ? finished
            : PipelineResult(
                answer: finished.answer.copyWith(guard: finished.guardActions),
                via: finished.via,
                notice: finished.notice,
                guardActions: finished.guardActions,
                usage: finished.usage,
              );
        // A personal case is never cached: its referral may restate the
        // asker's situation, and the server does not keep that.
        if (cacheKey != null &&
            outcome.submitted != null &&
            !signals.personalCase &&
            result.answer.kind != AnswerKind.refer) {
          cache!.put(cacheKey, result.answer);
        }
        return skipped.isEmpty
            ? result
            : PipelineResult(
                answer: result.answer,
                via: result.via,
                notice: result.notice,
                guardActions: [...skipped, ...result.guardActions],
                usage: result.usage,
              );
      } on ModelException catch (e) {
        if (e.quotaExhausted) {
          _exhaustedUntil[client] = nextQuotaReset(_clock());
          skipped.add('${client.provider}:${client.model} daily quota exhausted');
          continue;
        }
        // Any other failure while another model can take over: rest this one
        // (briefly if overloaded or timed out, longer if the model refused
        // the request, e.g. retired for new users) and ask the next.
        if (_agents.length > 1) {
          _exhaustedUntil[client] = _clock().add(e.retryable ? unavailableCooldown : rejectedCooldown);
          skipped.add(
            '${client.provider}:${client.model} ${e.retryable ? 'unavailable' : 'rejected'} '
            '(${e.statusCode ?? e.message.split(':').first})',
          );
          continue;
        }
        return PipelineResult(
          answer: routed.answer,
          via: Via.offline,
          notice: e.retryable ? 'ai_busy' : 'ai_error',
          guardActions: [...skipped, '${client.provider}:${client.model} error ${e.statusCode ?? ''}: ${e.message}'.trim()],
        );
      }
    }
    // No model could answer (all out of quota or resting): stored answer,
    // labelled as such.
    return PipelineResult(
      answer: routed.answer,
      via: Via.offline,
      notice: 'ai_busy',
      guardActions: [...skipped, 'no model available'],
    );
  }

  /// The tafsir of the Quran verses (at most three) of the reference answer
  /// the question clearly matches — the same bar as answering from the
  /// curated base ([Retriever.isStrong]) — read before the model is called.
  /// Such answers then need one model request instead of three (the free
  /// tier's daily quota counts requests). A loose match pre-reads nothing,
  /// so unrelated verses are never put in front of the model.
  Future<Map<String, String>> _preread(List<RetrievalHit> hits) async {
    final q = quran;
    final t = tafsir;
    if (q == null || t == null || !Retriever.isStrong(hits)) return const {};
    final keys = <String>[
      for (final id in hits.first.entry.evidenceIds)
        if (kb.evidence[id] case final e? when e.isQuran)
          for (final k in e.verseKeys)
            if (q.verse(k) != null) k,
    ].take(3);
    final out = <String, String>{};
    for (final k in keys) {
      final text = await t.forVerse(k);
      if (text != null) out[k] = text;
    }
    return out;
  }

  /// An answer in [iso] (neither Arabic nor English): each verse gets its
  /// approved translation of the meaning in that language (QuranEnc) and
  /// each HadeethEnc hadith its approved translation, when they exist;
  /// otherwise the English ones stay.
  Future<BasirahAnswer> _localize(BasirahAnswer a, String iso) async {
    if (iso == 'und') return a;
    final language = meaningLanguages.where((l) => l.iso == iso).firstOrNull;
    final title = language == null ? null : await meaning?.title(language);
    final evidence = <Evidence>[];
    for (final e in a.evidence) {
      if (e.isQuran && language != null && meaning != null && e.surah != null) {
        final texts = <String>[];
        for (final k in e.verseKeys) {
          final v = await meaning!.verse(e.surah!, int.parse(k.split(':')[1]), language);
          if (v == null) break;
          texts.add(v.text);
        }
        evidence.add(
          texts.length == e.verseKeys.length && texts.isNotEmpty
              ? e.copyWith(translation: texts.join(' '), translationSource: title ?? 'QuranEnc · ${language.native}')
              : e,
        );
      } else if (!e.isQuran && hadith != null && RegExp(r'^he:(\d+)$').hasMatch(e.id)) {
        final local = await hadith!.get(e.id.substring(3), iso);
        evidence.add(
          local == null || local.text.trim().isEmpty
              ? e
              : e.copyWith(translation: local.text, translationSource: 'Approved translation — HadeethEnc (${languageName(iso)})'),
        );
      } else {
        evidence.add(e);
      }
    }
    return a.copyWith(evidence: evidence);
  }

  /// A research outcome → the guarded answer.
  PipelineResult _finish(
    AgentOutcome outcome,
    String question,
    OfflineRouter router,
    SafetySignals signals,
    List<RetrievalHit> hits,
  ) {
    final raw = outcome.submitted;
    if (raw == null) {
      // Declined by a safety classifier even after fallback: do not guess.
      final t = RouterTexts.of(router.kb.lang);
      return PipelineResult(
        answer: BasirahAnswer(
          question: question,
          kind: AnswerKind.abstain,
          level: ContentLevel.b,
          origin: AnswerOrigin.ai,
          abstainReason: t.abstainReason,
          guidance: t.abstainGuidance,
          review: 'generated',
          model: outcome.model,
          research: outcome.research,
        ),
        via: Via.ai,
        guardActions: const ['model declined (refusal)'],
        usage: outcome.usage,
      );
    }
    final report = GuardReport();
    var answer = guardAnswer(
      raw: raw,
      question: question,
      kb: router.kb,
      model: outcome.model,
      signals: signals,
      report: report,
      quran: quran,
      readRefs: outcome.readRefs,
      tafsirText: (key) => outcome.tafsirRead[key],
      tafsirSource: tafsir,
      hadithRead: outcome.hadithRead,
      research: outcome.research,
    );
    if (answer.related.isEmpty && answer.kind != AnswerKind.offTopic) {
      answer = answer.copyWith(
        related: [
          for (final h in hits)
            if (h.entry.id != answer.entryId && h.score >= Retriever.relatedThreshold) h.entry.id,
        ].take(3).toList(),
      );
    }
    return PipelineResult(answer: answer, via: Via.ai, guardActions: report.actions, usage: outcome.usage);
  }

  /// Google's free-tier daily quotas reset at midnight Pacific time. Using
  /// UTC−8 (standard time) all year means that in summer a model is retried
  /// an hour late at most — never early.
  static DateTime nextQuotaReset(DateTime now) {
    final pacific = now.toUtc().subtract(const Duration(hours: 8));
    final nextMidnight = DateTime.utc(pacific.year, pacific.month, pacific.day + 1);
    return nextMidnight.add(const Duration(hours: 8));
  }

  static SafetySignals _merge(SafetySignals now, SafetySignals before) => SafetySignals(
    personalCase: now.personalCase || before.personalCase,
    hadithRequest: now.hadithRequest,
    hostileTone: now.hostileTone,
    translationRequest: now.translationRequest,
    matched: [...now.matched, ...before.matched],
  );
}
