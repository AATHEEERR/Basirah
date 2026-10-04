import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../core/kb_provider.dart';
import '../../core/state.dart';
import '../../shared/patterns.dart';
import '../../shared/web_frame.dart';
import '../../shared/widgets.dart';
import '../home/home_screen.dart';

/// Search across curated questions + category grid.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final q = _query.text.trim();
    return Scaffold(
      body: KbBuilder(
        builder: (context, kb) {
          final hits = q.isEmpty || router == null
              ? const []
              : router.retriever.search(q, limit: 8).where((h) => h.score >= .18).toList();
          return Stack(
            children: [
              const PatternBackdrop(height: 320),
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 30, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('استكشف', 'Explore'), style: pageTitleStyle(context)),
                            Text(
                              context.tr(
                                '${kb.entries.length} سؤالاً موثقاً في ${kb.categories.length} تصنيفات',
                                '${kb.entries.length} documented questions in ${kb.categories.length} categories',
                              ),
                              style: BText.label(14, weight: FontWeight.w400),
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              controller: _query,
                              onChanged: (_) => setState(() {}),
                              style: BText.body(15, height: 1.3),
                              decoration: InputDecoration(
                                hintText: context.tr('بحث… مثلاً: اسمي، أهلي، الصلاة', 'Search… e.g. name, family, prayer'),
                                hintStyle: BText.body(15, color: BColors.textFaint, height: 1.3),
                                prefixIcon: const Padding(
                                  padding: EdgeInsetsDirectional.only(start: 16, end: 8),
                                  child: Icon(Icons.search_rounded, color: BColors.ink, size: 26),
                                ),
                                suffixIcon: q.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.close_rounded),
                                        onPressed: () => setState(_query.clear),
                                      ),
                                filled: true,
                                fillColor: BColors.surface,
                                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(99),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (q.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                        child: Text(
                          hits.isEmpty
                              ? context.tr('لا توجد أسئلة مطابقة', 'No matching questions')
                              : context.tr('نتائج البحث', 'Search results'),
                          style: BText.label(14),
                        ),
                      ),
                    ),
                    SliverList.list(
                      children: [
                        for (final (i, h) in hits.indexed)
                          TrackTile(
                            index: i + 1,
                            title: h.entry.question,
                            subtitle: kb.category(h.entry.categoryId)?.title ?? '',
                            level: h.entry.level,
                            kind: h.entry.kind,
                            onTap: () => context.push('/faq/${h.entry.id}'),
                          ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: PrimaryButton(
                            label: context.tr('لم تجد سؤالك؟ اسأل بصيرة', "Didn't find it? Ask Basirah"),
                            icon: Icons.arrow_forward_rounded,
                            onTap: () {
                              ref.read(askDraftProvider.notifier).state = AskDraft(question: q);
                              context.go('/ask');
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (q.isEmpty)
                    SliverToBoxAdapter(
                      child: SectionHeader(context.tr('كل التصنيفات', 'All categories'), eyebrow: context.tr('استكشف', 'Explore')),
                    ),
                  if (q.isEmpty)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: isWebsite(context) ? 20 : 16),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWebsite(context) ? 4 : 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: isWebsite(context) ? 1.4 : .98,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => CategoryTile(category: kb.categories[i], kb: kb),
                          childCount: kb.categories.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
