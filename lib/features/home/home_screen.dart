import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/config.dart';
import '../../core/lang.dart';
import '../../core/kb_provider.dart';
import '../../core/state.dart';
import '../../shared/brand.dart';
import '../../shared/lang_toggle.dart';
import '../../shared/patterns.dart';
import '../../shared/web_frame.dart';
import '../../shared/widgets.dart';
import '../answer/answer_cards.dart';
import '../library/baseline_screen.dart';
import '../library/impact_screen.dart';
import 'hero.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void ask([AskDraft? draft]) {
      ref.read(askDraftProvider.notifier).state = draft;
      context.go('/ask');
    }

    if (isWebsite(context)) {
      return Scaffold(
        body: KbBuilder(
          builder: (context, kb) => Stack(
            children: [
              const PatternBackdrop(height: 560),
              _WideHome(kb: kb, ask: ask),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: KbBuilder(
        builder: (context, kb) => Stack(
          children: [
            const PatternBackdrop(height: 380),
            // The website's order, at the phone's size.
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _TopBar()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: HomeHero(kb: kb, wide: false, search: _SearchPill(onTap: () => ask())),
                  ),
                ),
                // How every answer is built, right under the opening.
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.fromLTRB(16, 26, 16, 0), child: _AnswerSample()),
                ),
                if (AppConfig.hasApi) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      context.tr('لوحة الأثر', 'Impact board'),
                      eyebrow: context.tr('الأثر بالأرقام', 'Impact in numbers'),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ImpactTeaser()),
                  ),
                ],
                SliverToBoxAdapter(
                  child: SectionHeader(
                    context.tr('أربعة وعود في كل إجابة', 'Four promises in every answer'),
                    eyebrow: context.tr('لماذا تثق ببصيرة؟', 'Why trust Basirah?'),
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(child: _Promises()),
                ),
                SliverToBoxAdapter(
                  child: SectionHeader(
                    context.tr('ابدأ من هنا', 'Start here'),
                    eyebrow: context.tr('أكثر ما يشغل المسلم الجديد', 'What new Muslims ask most'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 300,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: kb.categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _FeaturedCard(category: kb.categories[i], kb: kb),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: SectionHeader(context.tr('الأكثر سؤالاً', 'Most asked'), eyebrow: context.tr('الأسئلة', 'Questions'))),
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
                SliverToBoxAdapter(child: _AiCard(onTap: () => ask())),
                SliverToBoxAdapter(child: _ReferencesPromo(kb: kb)),
                SliverToBoxAdapter(
                  child: SectionHeader(
                    context.tr('بصيرة ونموذج عام على الأسئلة نفسها', 'Basirah and a general model on the same questions'),
                    eyebrow: context.tr('مقارنة', 'Comparison'),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: ComparisonSection()),
                ),
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
        // As the website header: the name at the start and the language at
        // the end, side by side, so a long language name never covers the
        // name. («عن بصيرة» is in the bar at the bottom.)
        child: Row(
          children: [
            const BrandLogo(size: 36),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wordmark(style: BText.brand(context.isEn ? 21 : 24)),
              ),
            ),
            const SizedBox(width: 12),
            const LangToggle(compact: true),
            const SizedBox(width: 8),
            Tooltip(
              message: context.tr('لوحة المختصين', 'Specialists’ panel'),
              child: Material(
                color: BColors.surfaceMuted,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.push('/specialist'),
                  child: const SizedBox.square(dimension: 44, child: Icon(Icons.badge_outlined, color: BColors.ink, size: 21)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                context.tr('ما الذي تودّ أن تعرفه عن الإسلام؟', 'What would you like to know about Islam?'),
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

/// Deep "photo" card with a black badge and white title.
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

/// «بصيرة AI» card with a warm sand glow.
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

/// Soft footer with a laurel badge — a statement of method,
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
                  child: HomeHero(kb: kb, wide: true, search: _SearchPill(onTap: () => ask())),
                ),
                const SizedBox(width: 40),
                const Expanded(flex: 5, child: _AnswerSample()),
              ],
            ),
          ),
        ),
        if (AppConfig.hasApi)
          _WideSection(
            eyebrow: context.tr('الأثر بالأرقام', 'Impact in numbers'),
            title: context.tr('لوحة الأثر', 'Impact board'),
            child: const ImpactTeaser(),
          ),
        _WideSection(
          eyebrow: context.tr('لماذا تثق ببصيرة؟', 'Why trust Basirah?'),
          title: context.tr('أربعة وعود في كل إجابة', 'Four promises in every answer'),
          child: const _Promises(),
        ),
        _WideSection(
          eyebrow: context.tr('أكثر ما يشغل المسلم الجديد', 'What new Muslims ask most'),
          title: context.tr('ابدأ من هنا', 'Start here'),
          // Every category, four to a row.
          child: GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: .95,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [for (final c in kb.categories) _FeaturedCard(category: c, kb: kb, width: null)],
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
          eyebrow: context.tr('مقارنة', 'Comparison'),
          title: context.tr('بصيرة ونموذج عام على الأسئلة نفسها', 'Basirah and a general model on the same questions'),
          child: const ComparisonSection(),
        ),
        const SliverPadding(
          padding: EdgeInsets.only(bottom: 56),
          sliver: SliverToBoxAdapter(child: _TrustLaurel()),
        ),
      ],
    );
  }
}

/// A website section: a hairline above, a small gold eyebrow, the title,
/// then the content.
class _WideSection extends StatelessWidget {
  const _WideSection({required this.eyebrow, required this.title, required this.child});

  final String eyebrow;
  final String title;
  final Widget child;

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
            Text(eyebrow, style: BText.label(13.5, color: BColors.goldDeep, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(title, style: BText.display(28, weight: FontWeight.w600)),
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

/// Basirah's four promises, as cards with a coloured tag (the style of the
/// project's plan page): what every answer does, worded as the system
/// actually behaves.
List<(Tone, String, String, String, String, String, String)> _promises() => const [
  (
    Tones.culture,
    'من المصحف',
    'From the Mushaf',
    'نص الآية من مصحف مجمع الملك فهد',
    'The verse from the King Fahd Complex Mushaf',
    'يختار الذكاء الاصطناعي الآية برقمها فقط، ويُنسخ نصها من المصحف، ومعها رابط صفحتها للتحقق.',
    'The AI picks the verse by its number only; its text is copied from the Mushaf, with a link to its page to check it.',
  ),
  (
    Tones.principle,
    'يقرأ قبل أن يجيب',
    'Reads before it answers',
    'التفسير من الدرر السنية',
    'Tafsir from Dorar.net',
    'لا يستشهد بآية قبل أن يقرأ تفسيرها في موسوعة التفسير.',
    'It cites no verse before reading its tafsir in Dorar’s tafsir encyclopedia.',
  ),
  (
    Tones.guidance,
    'الحديث المقبول فقط',
    'Accepted hadith only',
    'الحديث بمصدره وحكمه',
    'Hadith with its source and grading',
    'يُعرض الحديث بنصه ومصدره وحكمه، ولا يُقبل إلا الصحيح والحسن.',
    'Each hadith is shown with its text, source and grading; only sahih and hasan are accepted.',
  ),
  (
    Tones.refer,
    'يحيل ولا يفتي',
    'Refers, never rules',
    'الحالة الشخصية لأهل العلم',
    'Personal cases go to scholars',
    'بصيرة أداة ذكاء اصطناعي وليست مفتياً؛ تعطي المعلومة العامة وتحيل الحالة الشخصية إلى مختص شرعي، تراسله أو تحجز معه مكالمة من داخل بصيرة.',
    'Basirah is an AI tool, not a mufti: it gives general information and refers personal cases to a Sharia specialist, whom you can message or book a call with inside Basirah.',
  ),
];

class _PromiseCard extends StatelessWidget {
  const _PromiseCard(this.p);

  final (Tone, String, String, String, String, String, String) p;

  @override
  Widget build(BuildContext context) {
    final (tone, tagAr, tagEn, titleAr, titleEn, bodyAr, bodyEn) = p;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: tone.top, borderRadius: BorderRadius.circular(99)),
            child: Text(context.tr(tagAr, tagEn), style: BText.label(12, color: tone.accent, weight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          Text(context.tr(titleAr, titleEn), style: BText.title(16.5)),
          const SizedBox(height: 6),
          Text(context.tr(bodyAr, bodyEn), style: BText.body(13.5, color: BColors.textMuted, height: 1.7)),
        ],
      ),
    );
  }
}

/// The promises: one row of four on the website, a column on a phone.
class _Promises extends StatelessWidget {
  const _Promises();

  @override
  Widget build(BuildContext context) {
    final cards = [for (final p in _promises()) _PromiseCard(p)];
    if (!isWebsite(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in cards.indexed) ...[if (i > 0) const SizedBox(height: 10), c],
        ],
      );
    }
    // Each card grows with its text (never clipped); the minimum height
    // keeps the row level in the usual case.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, c) in cards.indexed) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 210),
              child: DecoratedBox(
                decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(22)),
                child: c,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
