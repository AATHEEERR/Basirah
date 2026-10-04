import 'dart:async';

import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../core/ask_service.dart';
import '../../core/config.dart';
import '../../core/kb_provider.dart';
import '../../core/state.dart';
import '../../shared/brand.dart';
import '../../shared/web_frame.dart';
import '../../shared/widgets.dart';
import '../answer/answer_cards.dart';
import '../answer/feedback_bar.dart';
import '../welcome/context_screen.dart';

class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key, this.initialQuestion});

  final String? initialQuestion;

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _lastQuestion = GlobalKey();
  final _focus = FocusNode();
  String? _categoryId;

  static const _suggestionsAr = [
    'هل يجب أن أغيّر اسمي بعد الإسلام؟',
    'هل يمكنني زيارة أهلي غير المسلمين؟',
    'لماذا يعبد المسلمون الكعبة؟',
    'أسلمت وزوجي غير مسلم، ما حكم زواجنا؟',
    'هل تغطية الوجه واجبة؟',
    'أعطني حديثاً يثبت أن من أسلم يوم الجمعة يدخل الجنة',
    'What does Sharia mean?',
  ];

  static const _suggestionsEn = [
    'Do I have to change my name after becoming Muslim?',
    'Can I visit my non-Muslim family?',
    'Why do Muslims worship the Kaaba?',
    'I became Muslim and my husband is not Muslim. What about our marriage?',
    'Is covering the face obligatory?',
    'Give me a hadith proving that whoever becomes Muslim on a Friday enters Paradise',
    'ما معنى الشريعة؟',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _consumeDraft(ref.read(askDraftProvider));
      final q = widget.initialQuestion?.trim();
      if (q != null && q.isNotEmpty) {
        await ref.read(kbProvider.future);
        if (mounted) await _send(q);
      }
    });
  }

  void _consumeDraft(AskDraft? draft) {
    if (draft == null) return;
    setState(() {
      _categoryId = draft.categoryId ?? _categoryId;
      if (draft.question != null) _input.text = draft.question!;
    });
    ref.read(askDraftProvider.notifier).state = null;
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send([String? text, bool retry = false]) async {
    final q = (text ?? _input.text).trim();
    if (q.isEmpty) return;
    if (!retry) _input.clear();
    FocusScope.of(context).unfocus();
    final future = ref.read(chatProvider.notifier).send(q, categoryId: _categoryId, retry: retry);
    _scrollToEnd();
    await future;
    _scrollToQuestion();
  }

  /// Once the answer arrives, its question goes to the top of the view so
  /// the answer is read from its first card, not from its end.
  void _scrollToQuestion() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _lastQuestion.currentContext;
      if (target == null) {
        _scrollToEnd();
        return;
      }
      Scrollable.ensureVisible(
        target,
        alignment: 0,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(askDraftProvider, (_, next) => _consumeDraft(next));
    final messages = ref.watch(chatProvider);
    final busy = messages.any((m) => m.pending);
    final lastQuestion = messages.lastIndexWhere((m) => m.fromUser);

    return Scaffold(
      body: KbBuilder(
        builder: (context, kb) => Column(
          children: [
            _Header(
              hasMessages: messages.isNotEmpty,
              onClear: () => ref.read(chatProvider.notifier).clear(),
            ),
            Expanded(
              child: messages.isEmpty
                  ? _EmptyState(suggestions: context.isEn ? _suggestionsEn : _suggestionsAr, onPick: _send)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final m = messages[i];
                        if (m.fromUser) return _UserBubble(m.text, key: i == lastQuestion ? _lastQuestion : null);
                        if (m.pending) return const _Thinking();
                        return _AssistantMessage(
                          message: m,
                          kb: kb,
                          onRetryLive: i == messages.length - 1 ? () => _send(m.text, true) : null,
                        );
                      },
                    ),
            ),
            _Composer(
              controller: _input,
              focusNode: _focus,
              busy: busy,
              category: _categoryId == null ? null : kb.category(_categoryId!),
              onClearCategory: () => setState(() => _categoryId = null),
              onSend: () => _send(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.hasMessages, required this.onClear});

  final bool hasMessages;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(serverStatusProvider).valueOrNull;
    final ai = server?.ai ?? false;
    final status = ai
        ? (server!.quranVerses > 0
              ? context.tr('إجابات حية · تقرأ التفسير', 'Live answers · reads the tafsir')
              : context.tr('إجابات حية · مراجع معتمدة', 'Live answers · approved references'))
        : server?.reachable ?? false
        ? context.tr('دون مفتاح AI · إجابات محفوظة', 'No AI key · stored answers')
        : AppConfig.hasApi
        ? context.tr('يتصل بالخادم…', 'Connecting to the server…')
        : context.tr('دون خادم · إجابات محفوظة', 'No server · stored answers');
    final web = isWebsite(context);
    return Container(
      // The website keeps a plain ground under its header.
      decoration: web
          ? null
          : const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(1, -1),
                radius: 2.4,
                colors: [BColors.sand, BColors.bg],
              ),
            ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: web ? const EdgeInsets.fromLTRB(20, 30, 12, 18) : const EdgeInsets.fromLTRB(20, 14, 12, 14),
          child: Row(
            children: [
              const BrandLogo(size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('بصيرة AI', 'Basirah AI'), style: web ? pageTitleStyle(context) : BText.display(22)),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ai ? const Color(0xFF2FA464) : BColors.gold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(child: Text(status, style: BText.label(12, weight: FontWeight.w400))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _ContextChip(asker: ref.watch(askerContextProvider)),
                  ],
                ),
              ),
              _HeaderButton(
                icon: Icons.palette_outlined,
                tooltip: context.tr('كيف تُجيب بصيرة؟', 'How does Basirah answer?'),
                onTap: () => showToneLegend(context),
              ),
              if (hasMessages)
                _HeaderButton(icon: Icons.refresh_rounded, tooltip: context.tr('محادثة جديدة', 'New chat'), onTap: onClear),
            ],
          ),
        ),
      ),
    );
  }
}

/// «سياقي» at a glance: what answers are fitted to, tap to change.
class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.asker});

  final AskerContext asker;

  @override
  Widget build(BuildContext context) {
    final summary = contextSummary(context, asker);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => context.push('/context'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: BColors.surface.withValues(alpha: .85),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: BColors.goldDeep.withValues(alpha: .3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_pin_circle_outlined, size: 14, color: BColors.goldDeep),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  summary.isEmpty
                      ? context.tr('سياقي: لم يُحدَّد · حدِّده', 'My context: not set · set it')
                      : context.tr('سياقي: $summary', 'My context: $summary'),
                  style: BText.label(11.5, color: BColors.goldDeep, weight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Tooltip(
      message: tooltip,
      child: Material(
        color: BColors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(dimension: 42, child: Icon(icon, size: 20, color: BColors.ink)),
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.suggestions, required this.onPick});

  final List<String> suggestions;
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 24),
      children: [
        SoftCard(
          glow: BColors.sand,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('ما الذي يشغلك؟', 'What is on your mind?'), style: BText.display(24)),
              const SizedBox(height: 6),
              Text(
                context.tr(
                  'اكتب سؤالك عن الإسلام بالعربية أو بالإنجليزية. ستصلك الإجابة بلغة سؤالك في بطاقات ملوّنة مع أدلتها، أو إحالة إلى أهل العلم إن كانت حالتك شخصية.',
                  'Ask your question about Islam in English or Arabic. The answer comes in the language of your question, as colour-coded cards with their evidence — or a referral to scholars if your case is personal.',
                ),
                style: BText.body(14, color: BColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(context.tr('جرّب', 'Try'), style: BText.label(14)),
        ),
        const SizedBox(height: 10),
        for (final s in suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(
              radius: 18,
              onTap: () => onPick(s),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(child: Text(s, style: BText.body(14.5, height: 1.5))),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward_rounded, size: 18, color: BColors.textFaint),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text, {super.key});

  final String text;

  @override
  // The user's own messages sit on the right in both languages.
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.only(top: 10, bottom: 12, left: 48),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        color: BColors.ink,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: Text(text, style: BText.body(15, color: BColors.onInk, height: 1.6), textDirection: textDirectionOf(text)),
    ),
  );
}

class _Thinking extends StatefulWidget {
  const _Thinking();

  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking> {
  static const _steps = [
    ('يفهم السؤال ويحدّد مستواه…', 'Understanding the question and its level…'),
    ('يبحث في القرآن الكريم والتفسير…', 'Searching the Quran and tafsir…'),
    ('يقرأ التفسير في الدرر السنية…', 'Reading the tafsir on Dorar…'),
    ('يختار الآية المناسبة ويتحقق منها…', 'Choosing the right verse and checking it…'),
    ('يُعدّ البطاقات…', 'Preparing the cards…'),
  ];
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      if (mounted) setState(() => _i = (_i + 1) % _steps.length);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: SoftCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const BrandLogo(size: 30, motion: LogoMotion.twinkle),
          const SizedBox(width: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              context.tr(_steps[_i].$1, _steps[_i].$2),
              key: ValueKey(_i),
              style: BText.label(13.5, color: BColors.goldDeep),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AssistantMessage extends ConsumerWidget {
  const _AssistantMessage({required this.message, required this.kb, this.onRetryLive});

  final ChatMessage message;
  final KnowledgeBase kb;

  /// Offered when a stored answer was shown instead of a live one.
  final VoidCallback? onRetryLive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = message.outcome!;
    final a = outcome.answer;
    final saved = ref.watch(savedProvider).any((s) => s.key == a.key);
    final matched = a.origin == AnswerOrigin.kb && a.entryId != null ? kb.entry(a.entryId!) : null;
    final related = [for (final id in a.related) ?kb.entry(id)];
    final offTopic = a.kind == AnswerKind.offTopic;
    final notice = switch (outcome.notice) {
      null => null,
      AskNotice.noServer => context.tr(
        'الإجابة الحية تحتاج إلى خادم بصيرة، فعُرضت إجابة من المحتوى الموثّق المحفوظ في التطبيق.',
        'Live answers need the Basirah server, so this answer comes from the documented content stored in the app.',
      ),
      AskNotice.noAi => context.tr(
        'الخادم يعمل دون مفتاح الذكاء الاصطناعي، فعُرضت إجابة من المحتوى الموثّق المحفوظ.',
        'The server is running without an AI key, so this answer comes from the stored documented content.',
      ),
      AskNotice.busy => context.tr(
        'خدمة الذكاء الاصطناعي مشغولة الآن، فعُرضت إجابة من المحتوى الموثّق المحفوظ.',
        'The AI service is busy right now, so this answer comes from the stored documented content.',
      ),
      AskNotice.rateLimited => context.tr(
        'بلغتَ الحد المؤقت للأسئلة، فعُرضت إجابة من المحتوى الموثّق المحفوظ. حاول بعد قليل.',
        'You reached the temporary question limit, so this answer comes from the stored documented content. Try again shortly.',
      ),
      AskNotice.network => context.tr(
        'تعذّر الاتصال بالخادم، فعُرضت إجابة من المحتوى الموثّق المحفوظ.',
        'Could not reach the server, so this answer comes from the stored documented content.',
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A refusal for a non-Islamic question has no content level.
          if (!offTopic) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                LevelChip(a.level, compact: true),
                InfoPill(icon: a.origin.icon, label: a.origin.labelFor(context.lang)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (matched != null && matched.question != message.text) ...[
            Text(context.tr('أقرب سؤال موثّق: ${matched.question}', 'Closest documented question: ${matched.question}'), style: BText.label(12.5)),
            const SizedBox(height: 8),
          ],
          if (notice != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.info_outline_rounded, size: 15, color: BColors.goldDeep),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(notice, style: BText.label(12, color: BColors.goldDeep))),
              ],
            ),
            const SizedBox(height: 10),
          ],
          AnswerCards(answer: a, compact: true),
          if (a.research.isNotEmpty) ResearchTrail(steps: a.research),
          FeedbackBar(answer: a),
          if (related.isNotEmpty) ...[
            Text(context.tr('أسئلة قريبة موثّقة', 'Related documented questions'), style: BText.label(12.5)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in related)
                  ActionChip(
                    label: Text(e.question, style: BText.label(12.5, color: BColors.ink, weight: FontWeight.w400)),
                    backgroundColor: BColors.surface,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onPressed: () => context.push('/faq/${e.id}'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (!offTopic)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SecondaryButton(
                  label: context.tr('عرض كامل', 'Full view'),
                  icon: Icons.open_in_full_rounded,
                  onTap: () => context.push('/answer', extra: a),
                ),
                SecondaryButton(
                  label: saved ? context.tr('محفوظة', 'Saved') : context.tr('حفظ', 'Save'),
                  icon: saved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                  onTap: () => ref.read(savedProvider.notifier).toggle(a),
                ),
                if (outcome.isStored && outcome.notice != null && onRetryLive != null)
                  SecondaryButton(
                    label: context.tr('أعد المحاولة بإجابة حية', 'Retry with a live answer'),
                    icon: Icons.auto_awesome_outlined,
                    onTap: onRetryLive!,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.category,
    required this.onClearCategory,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final Category? category;
  final VoidCallback onClearCategory;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      color: BColors.bg,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (category != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InputChip(
                  avatar: CoverArt(category: category!, size: 22, radius: 11),
                  label: Text(context.tr('في: ${category!.title}', 'In: ${category!.title}'), style: BText.label(12.5, color: BColors.ink)),
                  onDeleted: onClearCategory,
                  backgroundColor: BColors.surface,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 600,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: BText.body(15, height: 1.5),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: context.tr('اكتب سؤالك… (لا تشارك بيانات شخصية)', 'Type your question… (no personal data)'),
                      hintStyle: BText.body(14, color: BColors.textFaint, height: 1.4),
                      filled: true,
                      fillColor: BColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Opacity(
                  opacity: busy ? .4 : 1,
                  child: Material(
                    color: BColors.ink,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: busy ? null : onSend,
                      child: const SizedBox.square(
                        dimension: 50,
                        child: Icon(Icons.arrow_upward_rounded, color: BColors.onInk),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
