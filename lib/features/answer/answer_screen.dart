import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../core/kb_provider.dart';
import '../../core/state.dart';
import '../../shared/patterns.dart';
import '../../shared/web_frame.dart';
import '../../shared/widgets.dart';
import 'answer_cards.dart';
import 'feedback_bar.dart';
import 'share_card.dart';

/// Answer page for a curated question (`/faq/:id`).
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: KbBuilder(
      builder: (context, kb) {
        final entry = kb.entry(id);
        if (entry == null) {
          return EmptyNote(
            icon: Icons.search_off_rounded,
            title: context.tr('السؤال غير موجود', 'Question not found'),
            body: context.tr(
              'ربما حُذف هذا السؤال من قاعدة المعرفة.',
              'It may have been removed from the knowledge base.',
            ),
          );
        }
        final related = [
          for (final e in kb.entriesIn(entry.categoryId))
            if (e.id != entry.id) e.id,
        ].take(3).toList();
        return AnswerView(
          answer: BasirahAnswer.fromEntry(entry, kb, related: related),
          kb: kb,
        );
      },
    ),
  );
}

/// Answer page for an answer produced in the Ask tab (`/answer`).
class AskedAnswerScreen extends StatelessWidget {
  const AskedAnswerScreen({super.key, required this.answer});

  final BasirahAnswer answer;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: KbBuilder(
      builder: (context, kb) => AnswerView(answer: answer, kb: kb),
    ),
  );
}

/// White circular icon button used in page headers.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: BColors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, size: 21, color: color ?? BColors.ink),
          ),
        ),
      ),
    ),
  );
}

class AnswerView extends ConsumerWidget {
  const AnswerView({super.key, required this.answer, required this.kb});

  final BasirahAnswer answer;
  final KnowledgeBase kb;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = answer;
    final entry = a.entryId == null ? null : kb.entry(a.entryId!);
    final category = entry == null ? null : kb.category(entry.categoryId);
    final saved = ref.watch(savedProvider).any((s) => s.key == a.key);
    final related = [for (final id in a.related) ?kb.entry(id)];

    return ReadingWidth(
      child: Stack(
        children: [
          const PatternBackdrop(height: 320),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                toolbarHeight: 64,
                backgroundColor: BColors.bg.withValues(alpha: .92),
                automaticallyImplyLeading: false,
                titleSpacing: 12,
                title: Row(
                  children: [
                    RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: context.tr('رجوع', 'Back'),
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go('/home'),
                    ),
                    const Spacer(),
                    if (canShareCard(a))
                      RoundIconButton(
                        icon: Icons.ios_share_rounded,
                        tooltip: context.tr('بطاقة للمشاركة', 'Share as a card'),
                        onTap: () => showShareCard(context, a),
                      ),
                    RoundIconButton(
                      icon: Icons.copy_rounded,
                      tooltip: context.tr('نسخ الإجابة', 'Copy answer'),
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: _plainText(a, context.lang)),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.tr(
                                'نُسخت الإجابة مع مصادرها',
                                'Answer copied with its sources',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    RoundIconButton(
                      icon: saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_add_outlined,
                      color: saved ? BColors.gold : null,
                      tooltip: saved
                          ? context.tr(
                              'إزالة من المحفوظات',
                              'Remove from saved',
                            )
                          : context.tr('حفظ', 'Save'),
                      onTap: () => ref.read(savedProvider.notifier).toggle(a),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                sliver: SliverList.list(
                  children: [
                    if (category != null) ...[
                      InkWell(
                        onTap: () => context.push('/category/${category.id}'),
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          children: [
                            CoverArt(category: category, size: 26, radius: 8),
                            const SizedBox(width: 8),
                            Text(
                              category.title,
                              style: BText.label(13.5, color: BColors.ink),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Reveal(
                      child: Text(
                        a.question,
                        style: BText.display(26),
                        textDirection: textDirectionOf(a.question),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (a.kind != AnswerKind.offTopic)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          LevelChip(a.level),
                          InfoPill(
                            icon: a.origin.icon,
                            label: a.origin.labelFor(context.lang),
                          ),
                        ],
                      ),
                    if (a.origin == AnswerOrigin.ai && entry != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        context.tr(
                          'استندت إلى السؤال الموثّق: ${entry.question}',
                          'Based on the documented question: ${entry.question}',
                        ),
                        style: BText.label(13),
                      ),
                    ],
                    const SizedBox(height: 22),
                    AnswerCards(answer: a),
                    if (a.research.isNotEmpty) ResearchTrail(steps: a.research),
                    FeedbackBar(answer: a, category: entry?.categoryId),
                    _TrustFooter(answer: a),
                  ],
                ),
              ),
              if (related.isNotEmpty)
                SliverToBoxAdapter(
                  child: SectionHeader(
                    context.tr('أسئلة ذات صلة', 'Related questions'),
                  ),
                ),
              SliverList.list(
                children: [
                  for (final (i, e) in related.indexed)
                    TrackTile(
                      index: i + 1,
                      title: e.question,
                      subtitle: kb.category(e.categoryId)?.title ?? '',
                      level: e.level,
                      kind: e.kind,
                      onTap: () => context.push('/faq/${e.id}'),
                    ),
                  const SizedBox(height: 48),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _plainText(BasirahAnswer a, String lang) {
    final en = lang == 'en';
    final b = StringBuffer()
      ..writeln('${en ? 'Q' : 'س'}: ${a.question}')
      ..writeln();
    void section(String title, String body) {
      if (body.trim().isEmpty) return;
      b
        ..writeln('【$title】')
        ..writeln(body)
        ..writeln();
    }

    String extra(String? label, String? text) =>
        text == null ? '' : '\n${label ?? ''}: $text';
    section(Tones.principle.titleFor(lang), a.principle);
    section(en ? 'What scholars agree on' : 'المتفق عليه', a.khilafAgreed);
    section(en ? 'Where they differ' : 'موضع الخلاف', a.khilafNote);
    section(
      Tones.refer.titleFor(lang),
      [a.referReason, a.referTo].where((s) => s.isNotEmpty).join('\n'),
    );
    section(
      (a.kind == AnswerKind.offTopic ? Tones.offTopic : Tones.abstain).titleFor(
        lang,
      ),
      a.abstainReason,
    );
    section(Tones.culture.titleFor(lang), a.culture);
    section(
      Tones.guidance.titleFor(lang),
      [for (final (i, g) in a.guidance.indexed) '${i + 1}. $g'].join('\n'),
    );
    section(
      Tones.evidence.titleFor(lang),
      [
        for (final e in a.evidence)
          (e.isQuran
                  ? '﴿${e.text}﴾ [${e.reference}]${en ? '' : extra(e.tafsirSource, e.tafsir)}'
                  : '«${e.text}» — ${e.source} (${e.grade})') +
              (en ? extra(e.translationSource, e.translation) : ''),
      ].join('\n\n'),
    );
    b.writeln(
      en
          ? '— Basirah: an AI tool that presents general information from approved references. It is not a mufti.'
          : '— بصيرة: أداة ذكاء اصطناعي تعرض معلومات عامة من مراجع معتمدة، وليست مفتياً.',
    );
    return b.toString();
  }
}

class _TrustFooter extends StatelessWidget {
  const _TrustFooter({required this.answer});

  final BasirahAnswer answer;

  @override
  Widget build(BuildContext context) {
    final review = switch (answer.review) {
      'reviewed' => context.tr(
        'روجعت بشرياً مقابل المصادر المعتمدة',
        'Human-reviewed against the approved sources',
      ),
      'pending' => context.tr(
        'بانتظار المراجعة البشرية مقابل المصادر المعتمدة',
        'Awaiting human review against the approved sources',
      ),
      _ => context.tr(
        'إجابة مولَّدة آلياً، لم يراجعها مختص',
        'Generated automatically; not reviewed by a specialist',
      ),
    };
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: BColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: BText.label(12.5, weight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: SoftCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          children: [
            line(
              Icons.info_outline_rounded,
              context.tr(
                'بصيرة أداة ذكاء اصطناعي تعرض معلومات عامة من مراجع معتمدة، وليست مفتياً ولا عالماً.',
                'Basirah is an AI tool that presents general information from approved references. It is not a mufti or a scholar.',
              ),
            ),
            line(
              Icons.fact_check_outlined,
              context.tr('حالة المراجعة: $review', 'Review status: $review'),
            ),
            if (answer.model != null)
              line(
                Icons.memory_rounded,
                context.tr(
                  'النموذج: ${answer.model}',
                  'Model: ${answer.model}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
