import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../core/kb_provider.dart';
import '../../core/state.dart';
import '../../shared/brand.dart';
import '../../shared/lang_toggle.dart';
import '../../shared/patterns.dart';
import '../../shared/web_frame.dart';
import '../../shared/widgets.dart';
import '../answer/answer_cards.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void ask([AskDraft? draft]) {
      ref.read(askDraftProvider.notifier).state = draft;
      context.go('/ask');
    }

    if (isWebsite(context)) {
      return Scaffold(body: KbBuilder(builder: (context, kb) => _WideHome(kb: kb, ask: ask)));
    }

    return Scaffold(
      body: KbBuilder(
        builder: (context, kb) => Stack(
          children: [
            const PatternBackdrop(height: 380),
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _TopBar()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('السلام عليكم', 'Assalamu alaikum'), style: BText.label(15, weight: FontWeight.w400)),
                        Text(context.tr('اسأل على بصيرة', 'Ask with insight'), style: BText.display(34, weight: FontWeight.w500)),
                        const SizedBox(height: 16),
                        _SearchPill(onTap: () => ask()),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _QuickRow(kb: kb)),
                SliverToBoxAdapter(
                  child: SectionHeader(
                    context.tr('ابدأ من هنا', 'Start here'),
                    eyebrow: context.tr('أكثر ما يشغل المسلم الجديد', 'What new Muslims ask most'),
                    onMore: () => context.go('/explore'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 300,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 4,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _FeaturedCard(category: kb.categories[i], kb: kb),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _AiCard(onTap: () => ask())),
                SliverToBoxAdapter(child: SectionHeader(context.tr('الأكثر سؤالاً', 'Most asked'))),
                SliverList.list(
                  children: [
                    for (final (i, e) in kb.popular.take(5).indexed)
                      TrackTile(
                        index: i + 1,
                        title: e.question,
                        subtitle: kb.category(e.categoryId)?.title ?? '',
                        level: e.level,
                        kind: e.kind,
                        onTap: () => context.push('/faq/${e.id}'),
                      ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: SectionHeader(
                    context.tr('استكشف حسب الفئة', 'Explore by category'),
                    linkLabel: context.tr('عرض الكل', 'See all'),
                    onLink: () => context.go('/explore'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: .98,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => CategoryTile(category: kb.categories[i], kb: kb),
                      childCount: kb.categories.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SectionHeader(
                    context.tr('كيف تُجيب بصيرة؟', 'How does Basirah answer?'),
                    subtitle: context.tr('لكل بطاقة لون ومعنى ثابت', 'Each card has a fixed colour and meaning'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in Tones.all)
                          ActionChip(
                            onPressed: () => showToneLegend(context, focus: t),
                            avatar: Icon(t.icon, size: 16, color: t.accent),
                            label: Text(t.titleFor(context.lang), style: BText.label(12.5, color: t.accent, weight: FontWeight.w600)),
                            backgroundColor: t.top,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _ReferencesPromo(kb: kb)),
                const SliverToBoxAdapter(child: _TrustLaurel()),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        // The wordmark stays centred whatever the width of the side actions.
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                _CircleAction(
                  icon: Icons.person_outline_rounded,
                  tooltip: context.tr('عن بصيرة', 'About Basirah'),
                  onTap: () => context.push('/about'),
                ),
                const Spacer(),
                const LangToggle(),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(size: 36),
                const SizedBox(width: 8),
                Text(context.tr('بصيرة', 'Basirah'), style: BText.brand(context.isEn ? 21 : 24)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: BColors.surfaceMuted,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(dimension: 50, child: Icon(icon, color: BColors.ink, size: 24)),
      ),
    ),
  );
}

class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: BColors.surface,
    borderRadius: BorderRadius.circular(99),
    child: InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: BColors.ink, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('اسأل عن أي شيء يشغلك في الإسلام…', 'Ask anything about Islam that is on your mind…'),
                style: BText.body(15, color: BColors.textFaint, height: 1.2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Quick-access category icons (white rounded squares + label).
class _QuickRow extends StatelessWidget {
  const _QuickRow({required this.kb});

  final KnowledgeBase kb;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        itemCount: kb.categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final c = kb.categories[i];
          return InkWell(
            onTap: () => context.push('/category/${c.id}'),
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              width: 78,
              child: Column(
                children: [
                  Container(
                    width: 74,
                    height: 70,
                    decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(22)),
                    child: Icon(c.iconData, size: 28, color: c.accent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.title.split(' ').first,
                    style: BText.label(13, color: BColors.ink, weight: FontWeight.w400),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Deep "photo" card with a black badge and white title (Nusuk content card).
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.category, required this.kb, this.width = 250});

  final Category category;
  final KnowledgeBase kb;

  /// Null to fill the space given (the website grid).
  final double? width;

  @override
  Widget build(BuildContext context) {
    final count = kb.entriesIn(category.id).length;
    return SizedBox(
      width: width,
      child: CategoryBackdrop(
        category: category,
        patternSize: 220,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => context.push('/category/${category.id}'),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconBubble(
                        icon: category.iconData,
                        color: category.accent,
                        fill: Colors.white.withValues(alpha: .75),
                        size: 52,
                      ),
                      const Spacer(),
                      CountPill(category: category, count: count),
                    ],
                  ),
                  const Spacer(),
                  Text(category.title, style: BText.display(21)),
                  const SizedBox(height: 2),
                  Text(
                    category.subtitle,
                    style: BText.label(12.5, weight: FontWeight.w400),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        context.tr('تصفّح الأسئلة', 'Browse questions'),
                        style: BText.label(13, color: category.accent, weight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: category.accent),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A category as a soft card in its own colour (same style as the answer
/// cards): icon bubble, title and question count.
class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.category, required this.kb});

  final Category category;
  final KnowledgeBase kb;

  @override
  Widget build(BuildContext context) {
    return CategoryBackdrop(
      category: category,
      radius: 24,
      patternSize: 150,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => context.push('/category/${category.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBubble(
                  icon: category.iconData,
                  color: category.accent,
                  fill: Colors.white.withValues(alpha: .75),
                  size: 42,
                ),
                const Spacer(),
                Text(category.title, style: BText.title(15, weight: FontWeight.w600), maxLines: 2),
                const SizedBox(height: 2),
                Text(
                  context.tr('${kb.entriesIn(category.id).length} أسئلة', '${kb.entriesIn(category.id).length} questions'),
                  style: BText.label(12, color: category.accent, weight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «بصيرة AI» card with a warm sand glow (Nusuk AI card).
class _AiCard extends StatelessWidget {
  const _AiCard({required this.onTap, this.padding = const EdgeInsets.fromLTRB(16, 26, 16, 0)});

  final VoidCallback onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SoftCard(
        onTap: onTap,
        glow: BColors.sand,
        glowAlignment: const Alignment(-1, 1),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: SizedBox(
          height: 170,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined, size: 18, color: BColors.textMuted),
                  const SizedBox(width: 6),
                  Text(context.tr('بصيرة AI', 'Basirah AI'), style: BText.label(13)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('ساعدني في فهم سؤال يشغلني عن الإسلام', 'Help me understand a question about Islam'),
                style: BText.display(22, weight: FontWeight.w400),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(context.tr('اسأل واحصل على إجابة موثقة', 'Ask and get a documented answer'), style: BText.label(13)),
                  const SizedBox(width: 8),
                  const _MiniDots(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniDots extends StatelessWidget {
  const _MiniDots();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final s in const [4.0, 5.0, 6.5])
        Container(
          width: s,
          height: s,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: const BoxDecoration(color: BColors.ink, shape: BoxShape.circle),
        ),
    ],
  );
}

class _ReferencesPromo extends StatelessWidget {
  const _ReferencesPromo({required this.kb, this.padding = const EdgeInsets.fromLTRB(16, 28, 16, 0)});

  final KnowledgeBase kb;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SoftCard(
        onTap: () => context.push('/sources'),
        glow: BColors.beige,
        glowAlignment: const Alignment(1, -1),
        child: Row(
          children: [
            const IconBubble(icon: Icons.menu_book_rounded, color: BColors.beigeInk, fill: BColors.beige, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('المرجعية المعتمدة', 'Approved references'), style: BText.title(16, weight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    context.tr(
                      '${kb.evidence.length} دليلاً موثقاً · ${kb.sources.length} مجالات مرجعية · 4 مستويات لضبط الاستجابة',
                      '${kb.evidence.length} documented texts · ${kb.sources.length} reference fields · 4 response levels',
                    ),
                    style: BText.label(12, weight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: BColors.textFaint),
          ],
        ),
      ),
    );
  }
}

/// Soft footer in the spirit of Nusuk's laurel badge — a statement of method,
/// not a usage claim.
class _TrustLaurel extends StatelessWidget {
  const _TrustLaurel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.flip(flipX: true, child: const Icon(Icons.spa_outlined, color: BColors.textFaint, size: 34)),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              children: [
                Text(context.tr('مبنيّة على', 'Built on'), style: BText.label(12, color: BColors.textFaint, weight: FontWeight.w400)),
                Text(
                  context.tr('المرجعية العلمية المعتمدة', 'the approved scholarly references'),
                  textAlign: TextAlign.center,
                  style: BText.title(15, color: BColors.textFaint, weight: FontWeight.w500),
                ),
                Text(
                  context.tr('وليست بديلاً عن أهل العلم', 'and no substitute for scholars'),
                  style: BText.label(12, color: BColors.textFaint, weight: FontWeight.w400),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.spa_outlined, color: BColors.textFaint, size: 34),
        ],
      ),
    );
  }
}


/// The home page laid out as a website (a computer): a hero with the title,
/// the search and a sample of how an answer is built; then sections in
/// grids, divided by hairlines, instead of the phone's carousels.
class _WideHome extends StatelessWidget {
  const _WideHome({required this.kb, required this.ask});

  final KnowledgeBase kb;
  final void Function([AskDraft? draft]) ask;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 44, 20, 40),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('السلام عليكم', 'Assalamu alaikum'), style: BText.label(15, color: BColors.goldDeep, weight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(context.tr('اسأل على بصيرة', 'Ask with insight'), style: BText.brand(context.isEn ? 46 : 54)),
                      const SizedBox(height: 14),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Text(
                          context.tr(
                            'إجابات عن أسئلتك في الإسلام من المصادر المعتمدة: الآية من مصحف مجمع الملك فهد، والحديث بمصدره وحكمه، وما يحتاج إلى مختص يُحال إلى أهله.',
                            'Answers to your questions about Islam from approved sources: the verse from the King Fahd Complex Mushaf, the hadith with its source and grading, and anything that needs a specialist is referred to one.',
                          ),
                          style: BText.body(17, color: BColors.textMuted, height: 1.75),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _SearchPill(onTap: () => ask()),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in kb.categories)
                            ActionChip(
                              onPressed: () => context.push('/category/${c.id}'),
                              avatar: Icon(c.iconData, size: 17, color: c.accent),
                              label: Text(c.title, style: BText.label(13, color: BColors.ink)),
                              backgroundColor: BColors.surface,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 40),
                const Expanded(flex: 5, child: _AnswerSample()),
              ],
            ),
          ),
        ),
        _WideSection(
          eyebrow: context.tr('أكثر ما يشغل المسلم الجديد', 'What new Muslims ask most'),
          title: context.tr('ابدأ من هنا', 'Start here'),
          linkLabel: context.tr('عرض الكل', 'See all'),
          onLink: () => context.go('/explore'),
          child: SizedBox(
            height: 290,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, c) in kb.categories.take(4).indexed) ...[
                  if (i > 0) const SizedBox(width: 14),
                  Expanded(child: _FeaturedCard(category: c, kb: kb, width: null)),
                ],
              ],
            ),
          ),
        ),
        _WideSection(
          eyebrow: context.tr('الأسئلة', 'Questions'),
          title: context.tr('الأكثر سؤالاً', 'Most asked'),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    for (final (i, e) in kb.popular.take(5).indexed)
                      TrackTile(
                        index: i + 1,
                        title: e.question,
                        subtitle: kb.category(e.categoryId)?.title ?? '',
                        level: e.level,
                        kind: e.kind,
                        padding: const EdgeInsets.only(bottom: 10),
                        onTap: () => context.push('/faq/${e.id}'),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _AiCard(onTap: () => ask(), padding: EdgeInsets.zero),
                    _ReferencesPromo(kb: kb, padding: const EdgeInsets.only(top: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
        _WideSection(
          eyebrow: context.tr('استكشف', 'Explore'),
          title: context.tr('حسب الفئة', 'By category'),
          linkLabel: context.tr('عرض الكل', 'See all'),
          onLink: () => context.go('/explore'),
          child: GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.55,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [for (final c in kb.categories) CategoryTile(category: c, kb: kb)],
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.only(bottom: 56),
          sliver: SliverToBoxAdapter(child: _TrustLaurel()),
        ),
      ],
    );
  }
}

/// A website section: a hairline above, a small gold eyebrow, the title, an
/// optional «عرض الكل» link, then the content.
class _WideSection extends StatelessWidget {
  const _WideSection({required this.eyebrow, required this.title, required this.child, this.linkLabel, this.onLink});

  final String eyebrow;
  final String title;
  final Widget child;
  final String? linkLabel;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    sliver: SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.only(top: 32, bottom: 40),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: BColors.stroke))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(eyebrow, style: BText.label(13.5, color: BColors.goldDeep, weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(title, style: BText.display(28, weight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (linkLabel != null)
                  TextButton.icon(
                    onPressed: onLink,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: BColors.ink),
                    label: Text(linkLabel!, style: BText.label(14, color: BColors.ink, weight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    ),
  );
}

/// The hero's side panel: how every Basirah answer is built, one coloured
/// card per part. Opens the full legend.
class _AnswerSample extends StatelessWidget {
  const _AnswerSample();

  @override
  Widget build(BuildContext context) {
    const tones = [Tones.principle, Tones.culture, Tones.guidance, Tones.evidence];
    return Material(
      color: BColors.surface,
      borderRadius: BorderRadius.circular(28),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => showToneLegend(context),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [BoxShadow(color: Color(0x1A141416), blurRadius: 40, offset: Offset(0, 18), spreadRadius: -22)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.tr('كيف تُجيب بصيرة؟', 'How does Basirah answer?'), style: BText.title(16)),
              Text(
                context.tr('كل إجابة من أربع بطاقات، لكل بطاقة لون ومعنى ثابت', 'Every answer has four cards, each with a fixed colour and meaning'),
                style: BText.label(13, weight: FontWeight.w400),
              ),
              const SizedBox(height: 14),
              for (final t in tones)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [t.top, t.bottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(t.icon, size: 20, color: t.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.titleFor(context.lang), style: BText.label(14, color: t.accent, weight: FontWeight.w600)),
                            Text(t.explainFor(context.lang), style: BText.label(12.5, color: BColors.ink, weight: FontWeight.w400)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
