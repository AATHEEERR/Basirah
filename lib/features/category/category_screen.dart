import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../core/kb_provider.dart';
import '../../core/state.dart';
import '../../shared/patterns.dart';
import '../../shared/widgets.dart';
import '../answer/answer_screen.dart';

/// A category: a deep "photo" hero card, then its questions as rows.
class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: KbBuilder(
        builder: (context, kb) {
          final category = kb.category(id);
          if (category == null) {
            return EmptyNote(icon: Icons.search_off_rounded, title: context.tr('التصنيف غير موجود', 'Category not found'), body: '');
          }
          final entries = kb.entriesIn(id);
          final levels = entries.map((e) => e.level.letterFor(context.lang)).toSet().join(context.tr('، ', ', '));

          void askHere() {
            ref.read(askDraftProvider.notifier).state = AskDraft(categoryId: id);
            context.go('/ask');
          }

          return Stack(
            children: [
              const PatternBackdrop(height: 300),
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    toolbarHeight: 64,
                    automaticallyImplyLeading: false,
                    backgroundColor: BColors.bg.withValues(alpha: .92),
                    titleSpacing: 12,
                    title: Row(
                      children: [
                        RoundIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: context.tr('رجوع', 'Back'),
                          onTap: () => context.canPop() ? context.pop() : context.go('/home'),
                        ),
                        const SizedBox(width: 8),
                        Text(context.tr('تصنيف', 'Category'), style: BText.label(14)),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: SizedBox(
                        height: 220,
                        child: CategoryBackdrop(
                          category: category,
                          radius: 28,
                          patternSize: 240,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    IconBubble(
                                      icon: category.iconData,
                                      color: category.accent,
                                      fill: Colors.white.withValues(alpha: .75),
                                      size: 56,
                                    ),
                                    const Spacer(),
                                    CountPill(category: category, count: entries.length),
                                  ],
                                ),
                                const Spacer(),
                                Text(category.title, style: BText.display(28)),
                                Text(category.subtitle, style: BText.label(13.5, weight: FontWeight.w400)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(category.description, style: BText.body(15, color: BColors.textMuted)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    InfoPill(icon: Icons.layers_outlined, label: context.tr('المستويات: $levels', 'Levels: $levels')),
                                  ],
                                ),
                              ),
                              GoldCircleButton(
                                icon: Icons.forum_outlined,
                                tooltip: context.tr('اسأل في هذا الموضوع', 'Ask about this topic'),
                                onTap: askHere,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: SectionHeader(context.tr('الأسئلة', 'Questions'))),
                  SliverList.list(
                    children: [
                      for (final (i, e) in entries.indexed)
                        TrackTile(
                          index: i + 1,
                          title: e.question,
                          subtitle: context.tr(
                            'مستوى ${e.level.letterAr} · ${_kindLabel(e.kind.name, 'ar')}',
                            'Level ${e.level.code} · ${_kindLabel(e.kind.name, 'en')}',
                          ),
                          level: e.level,
                          kind: e.kind,
                          onTap: () => context.push('/faq/${e.id}'),
                        ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 48),
                      child: SoftCard(
                        glow: BColors.sand,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('لم تجد سؤالك؟', "Didn't find your question?"), style: BText.display(20)),
                            const SizedBox(height: 4),
                            Text(
                              context.tr(
                                'اكتب سؤالك الخاص، وستجيبك بصيرة من المراجع المعتمدة بالبطاقات نفسها، أو تخبرك بصدق أنها لا تملك إجابة موثقة.',
                                'Write your own question. Basirah answers from the approved references with the same cards — or tells you honestly that it has no documented answer.',
                              ),
                              style: BText.body(14, color: BColors.textMuted),
                            ),
                            const SizedBox(height: 14),
                            PrimaryButton(
                              label: context.tr('اسأل سؤالك الخاص', 'Ask your own question'),
                              icon: Icons.arrow_forward_rounded,
                              onTap: askHere,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static String _kindLabel(String kind, String lang) => switch (kind) {
    'khilaf' => lang == 'en' ? 'Scholarly difference' : 'مسألة خلافية',
    'refer' => lang == 'en' ? 'Needs a specialist' : 'يحتاج إلى مختص',
    _ => lang == 'en' ? 'Documented answer' : 'إجابة موثقة',
  };
}
