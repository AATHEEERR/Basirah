import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../core/referral.dart';
import '../../core/state.dart';
import '../../shared/lang_toggle.dart';
import '../../shared/patterns.dart';
import '../../shared/web_frame.dart';
import '../../shared/widgets.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedProvider);
    final tiles = [
      _NavTile(
        icon: Icons.person_pin_circle_outlined,
        title: context.tr('سياقي', 'My context'),
        route: '/context',
        ink: BColors.goldDeep,
        fill: Tones.principle.top,
      ),
      _NavTile(
        icon: Icons.spellcheck_rounded,
        title: context.tr('قاموس المصطلحات', 'Glossary'),
        route: '/glossary',
        ink: BColors.mintInk,
        fill: BColors.mint,
      ),
      _NavTile(
        icon: Icons.menu_book_rounded,
        title: context.tr('المرجعية والمنهجية', 'References & method'),
        route: '/sources',
        ink: BColors.beigeInk,
        fill: BColors.beige,
      ),
      _NavTile(
        icon: Icons.account_tree_outlined,
        title: context.tr('كيف تتحقق بصيرة؟', 'How Basirah checks'),
        route: '/pipeline',
        ink: Tones.guidance.accent,
        fill: Tones.guidance.top,
      ),
      _NavTile(
        icon: Icons.info_outline_rounded,
        title: context.tr('عن بصيرة', 'About Basirah'),
        route: '/about',
        ink: BColors.lilacInk,
        fill: BColors.lilac,
      ),
    ];
    return Scaffold(
      body: Stack(
        children: [
          const PatternBackdrop(height: 320),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('مكتبتي', 'My library'), style: pageTitleStyle(context)),
                        Text(
                          context.tr('محفوظاتك، والمصطلحات، والمرجعية المعتمدة', 'Your saved answers, the glossary and the approved references'),
                          style: BText.label(14, weight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Two rows of two on a phone; one row of four on the website.
              for (final row in isWebsite(context) ? [tiles] : [tiles.sublist(0, 2), tiles.sublist(2)])
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, row.first == tiles.first ? 18 : 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        for (final (i, t) in row.indexed) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(child: t),
                        ],
                      ],
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: SoftCard(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Row(
                      children: [
                        const IconBubble(icon: Icons.language_rounded, color: BColors.ink, fill: BColors.surfaceMuted, size: 42),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.tr('لغة التطبيق', 'App language'), style: BText.title(14.5, weight: FontWeight.w500)),
                              Text(
                                context.tr('الإجابة تأتي دائماً بلغة سؤالك', 'Answers always come in the language of your question'),
                                style: BText.label(12, weight: FontWeight.w400),
                              ),
                            ],
                          ),
                        ),
                        const LangToggle(),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: SoftCard(
                    onTap: () => context.push('/impact'),
                    glow: Tones.culture.top,
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Row(
                      children: [
                        IconBubble(icon: Icons.insights_rounded, color: Tones.culture.accent, fill: Tones.culture.top, size: 42),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.tr('لوحة الأثر', 'Impact board'), style: BText.title(14.5, weight: FontWeight.w500)),
                              Text(
                                context.tr('أرقام الاستخدام ورضا المستخدمين، دون حفظ أي سؤال', 'Usage and ratings in numbers, with no question stored'),
                                style: BText.label(12, weight: FontWeight.w400),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: BColors.textFaint),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: SoftCard(
                    onTap: () => context.push('/baseline'),
                    glow: Tones.refer.top,
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Row(
                      children: [
                        IconBubble(icon: Icons.compare_arrows_rounded, color: Tones.refer.accent, fill: Tones.refer.top, size: 42),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.tr('المقارنة المرجعية', 'Baseline comparison'), style: BText.title(14.5, weight: FontWeight.w500)),
                              Text(
                                context.tr('نفس النموذج: روبوت عام مقابل بصيرة، على الأسئلة نفسها', 'Same model: a general chatbot vs Basirah, on the same questions'),
                                style: BText.label(12, weight: FontWeight.w400),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: BColors.textFaint),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: SoftCard(
                    onTap: () => context.push('/referrals'),
                    glow: Tones.guidance.top,
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Row(
                      children: [
                        IconBubble(icon: Icons.support_agent_rounded, color: Tones.guidance.accent, fill: Tones.guidance.top, size: 42),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.tr('طلباتي مع المختص', 'My requests to a specialist'), style: BText.title(14.5, weight: FontWeight.w500)),
                              Text(
                                context.tr(
                                  ref.watch(myReferralsProvider).isEmpty
                                      ? 'رسائلك ومواعيدك مع المختص الشرعي'
                                      : '${ref.watch(myReferralsProvider).length} · رسائلك ومواعيدك مع المختص الشرعي',
                                  ref.watch(myReferralsProvider).isEmpty
                                      ? 'Your messages and appointments with a Sharia specialist'
                                      : '${ref.watch(myReferralsProvider).length} · your messages and appointments with a Sharia specialist',
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
                ),
              ),
              // The other side of the requests: the specialists' panel (it asks
              // for the panel key).
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => context.push('/specialist'),
                      icon: const Icon(Icons.badge_outlined, size: 18, color: BColors.goldDeep),
                      label: Text(
                        context.tr('أنت مختص شرعي؟ لوحة المختصين', 'Are you a Sharia specialist? The specialists’ panel'),
                        style: BText.label(13, color: BColors.goldDeep, weight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SectionHeader(
                  context.tr('المحفوظات', 'Saved'),
                  subtitle: saved.isEmpty
                      ? null
                      : context.tr(
                          '${switch (saved.length) {
                            1 => 'إجابة واحدة محفوظة',
                            2 => 'إجابتان محفوظتان',
                            >= 3 && <= 10 => '${saved.length} إجابات محفوظة',
                            _ => '${saved.length} إجابة محفوظة',
                          }} على جهازك',
                          '${saved.length} ${saved.length == 1 ? 'answer' : 'answers'} saved on your device',
                        ),
                ),
              ),
              if (saved.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyNote(
                    icon: Icons.bookmark_border_rounded,
                    title: context.tr('لا توجد محفوظات بعد', 'Nothing saved yet'),
                    body: context.tr(
                      'احفظ أي إجابة بعلامة الحفظ لتعود إليها لاحقاً. تبقى المحفوظات على جهازك فقط.',
                      'Save any answer with the bookmark to come back to it later. Saved answers stay on your device only.',
                    ),
                  ),
                )
              else
                SliverList.list(
                  children: [
                    for (final (i, a) in saved.indexed)
                      TrackTile(
                        index: i + 1,
                        title: a.question,
                        subtitle: a.origin.labelFor(context.lang),
                        level: a.level,
                        kind: a.kind,
                        onTap: () => a.entryId != null && a.key.startsWith('kb:')
                            ? context.push('/faq/${a.entryId}')
                            : context.push('/answer', extra: a),
                      ),
                  ],
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ],
      ),
    );
  }
}

/// White tile with a pastel icon bubble (Nusuk's quick services).
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.route,
    required this.ink,
    required this.fill,
  });

  final IconData icon;
  final String title;
  final String route;
  final Color ink;
  final Color fill;

  @override
  Widget build(BuildContext context) => SoftCard(
    onTap: () => context.push(route),
    glow: fill,
    glowAlignment: const Alignment(-1, 1),
    padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
    child: SizedBox(
      height: 104,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBubble(icon: icon, color: ink, fill: fill, size: 46),
          const Spacer(),
          Text(title, style: BText.title(14, weight: FontWeight.w500), maxLines: 2),
        ],
      ),
    ),
  );
}
