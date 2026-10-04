import 'package:flutter/material.dart';
import 'package:basirah_core/basirah_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../core/kb_provider.dart';
import '../../shared/widgets.dart';
import 'page_scaffold.dart';

/// «المرجعية والمنهجية»: the reference pack made visible — response levels,
/// approved sources, and the binding scientific standard with how Basirah
/// implements each point.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: context.tr('المرجعية والمنهجية', 'References & method'),
      subtitle: context.tr(
        'مأخوذة من «المرجعية والحزمة العلمية والبيانات» لتحدي الذكاء الاصطناعي في خدمة المحتوى الإسلامي',
        'Taken from the “Reference, scholarly package and data” document of the AI Challenge Serving Islamic Content',
      ),
      child: KbBuilder(
        builder: (context, kb) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (kb.pack.scope.isNotEmpty) ...[
              _Heading(context.tr('نطاق المحتوى المعتمد', 'Approved content scope'), _packNote(context)),
              _Panel(
                child: Text(
                  kb.pack.scope.join('\n\n'),
                  style: BText.body(14, height: 1.75),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
            _Heading(
              context.tr('مستويات المحتوى وضبط الاستجابة', 'Content levels and response control'),
              context.tr(
                'كل سؤال يُصنَّف في أحد أربعة مستويات، ولكل مستوى طريقة تعامل ملزمة.',
                'Every question falls into one of four levels, and each level has a binding way of handling it.',
              ),
            ),
            for (final l in kb.levels)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: l.level.color.withValues(alpha: .35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: l.level.color.withValues(alpha: .14), shape: BoxShape.circle),
                          child: Text(l.level.letterFor(context.lang), style: BText.display(17, color: l.level.color)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.tr('المستوى (${l.level.letterAr}): ${l.title}', 'Level ${l.level.code}: ${l.title}'),
                            style: BText.title(15, color: l.level.color),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _KV(context.tr('النطاق', 'Scope'), l.scope),
                    const SizedBox(height: 6),
                    _KV(context.tr('التعامل المعتمد', 'Approved handling'), l.handling),
                  ],
                ),
              ),
            _Heading(
              context.tr('المرجعية العلمية المعتمدة', 'Approved scholarly references'),
              context.tr(
                'لا تستشهد بصيرة إلا بما يرجع إلى هذه المصادر، ومع كل دليل رابط للتحقق منه.',
                'Basirah only cites what goes back to these sources, and every piece of evidence has a link to verify it.',
              ),
            ),
            for (final s in kb.sources)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Tones.principle.top, Tones.principle.bottom]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.field, style: BText.title(15.5, color: BColors.goldDeep)),
                    const SizedBox(height: 6),
                    Text(s.content, style: BText.body(14, height: 1.7)),
                    const SizedBox(height: 6),
                    _KV(context.tr('قاعدة الاستخدام', 'Usage rule'), s.rule),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final l in s.links)
                          TextButton.icon(
                            onPressed: () => launchUrl(Uri.parse(l.url), mode: LaunchMode.externalApplication),
                            icon: const Icon(Icons.open_in_new_rounded, size: 15),
                            label: Text(l.label, style: BText.label(12.5, color: BColors.gold)),
                            style: TextButton.styleFrom(foregroundColor: BColors.gold, visualDensity: VisualDensity.compact),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (kb.pack.associationAbout.isNotEmpty) ...[
              _Heading(
                context.tr('المرجعيات العلمية للمحتوى الإسلامي باللغات', 'Scholarly references for Islamic content in languages'),
                _packNote(context),
              ),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kb.pack.associationAbout, style: BText.body(14, height: 1.75), textDirection: TextDirection.rtl),
                    const SizedBox(height: 8),
                    for (final (item, text) in kb.pack.associationFacts) ...[
                      _KV(item, text),
                      const SizedBox(height: 4),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      kb.pack.associationMcp,
                      style: BText.label(12.5, color: BColors.goldDeep),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
            ],
            for (final section in {for (final p in kb.platforms) p.section}) ...[
              _Heading(section, null),
              // The pack introduces the external platforms before their first
              // section.
              if (kb.platforms.firstWhere((p) => p.section == section).section == _firstExternal(kb) &&
                  kb.pack.externalIntro.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${kb.pack.externalIntro}\n${kb.pack.externalNote}',
                    style: BText.label(12.5, weight: FontWeight.w400),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              for (final p in kb.platforms.where((p) => p.section == section)) _PlatformCard(p),
            ],
            _Heading(
              context.tr('المعيار العلمي الملزم، وكيف نطبّقه', 'The binding scholarly standard, and how we apply it'),
              context.tr(
                'ثمانية معايير يشترطها التحدي في مخرجات الحلول، ومقابل كل معيار ما تفعله بصيرة فعلاً.',
                'Eight standards the challenge requires of every solution’s output, and next to each one what Basirah actually does.',
              ),
            ),
            for (final st in kb.standards)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BColors.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(st.title, style: BText.title(15.5)),
                    const SizedBox(height: 6),
                    Text(st.text, style: BText.body(14, color: BColors.textMuted, height: 1.7)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Tones.guidance.top,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 18, color: Tones.guidance.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.tr('في بصيرة: ${st.applied}', 'In Basirah: ${st.applied}'),
                              style: BText.body(13.5, color: Tones.guidance.accent, height: 1.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            _Heading(context.tr('حالة المحتوى', 'Content status'), null),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BColors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                context.isEn
                    ? 'The current knowledge base (${kb.entries.length} questions and ${kb.evidence.length} texts, version ${kb.version}) '
                          'was prepared from the approved references above; every entry is marked “pending review” until it passes the team’s '
                          'human review against the approved sources. Every verse is checked against the King Fahd Complex Mushaf, and every hadith '
                          'and its grade against the Dorar.net hadith encyclopedia. English meanings of verses are from the Hilali & Khan '
                          'translation (King Fahd Complex, via QuranEnc). Live answers cite hadith from HadeethEnc, with its approved '
                          'translation; the English meanings of the stored hadith are the team’s translation, pending review.'
                    : 'قاعدة المعرفة الحالية (${kb.entries.length} سؤالاً و${kb.evidence.length} دليلاً، الإصدار ${kb.version}) '
                          'أُعدّت من المراجع المعتمدة أعلاه، وكل مدخل فيها مُعلَّم «بانتظار المراجعة» حتى تتم مراجعته بشرياً مقابل المصادر المعتمدة. '
                          'يُراجَع نص كل آية على مصحف مجمع الملك فهد، وكل حديث ودرجته على الموسوعة الحديثية في الدرر السنية. '
                          'وفي الإجابات الحية تُؤخذ الأحاديث من موسوعة الأحاديث النبوية بنصها ومصدرها وحكمها.',
                style: BText.body(14, color: BColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _packNote(BuildContext context) => context.tr(
  'بنص «المرجعية والحزمة العلمية والبيانات» (نسخة 1448/3/20)',
  'In the Arabic of the reference pack (edition 1448/3/20), verbatim',
);

/// The first section of platforms outside the association (p. 11 onwards).
String? _firstExternal(KnowledgeBase kb) => kb.platforms
    .map((p) => p.section)
    .where((s) => s != kb.platforms.first.section && !s.contains('الحرمين'))
    .firstOrNull;

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(24)),
    child: child,
  );
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard(this.p);
  final ApprovedPlatform p;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(p.name, style: BText.title(15, color: BColors.goldDeep), textDirection: TextDirection.rtl),
            ),
            if (p.mcp) const _Tag('MCP'),
          ],
        ),
        const SizedBox(height: 6),
        for (final c in p.content)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              c,
              style: BText.body(13.5, color: BColors.textMuted, height: 1.65),
              textDirection: TextDirection.rtl,
            ),
          ),
        if (p.basirahUse != null)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Tones.guidance.top, borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: Tones.guidance.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.tr('تستخدمه بصيرة: ${p.basirahUse}', 'Used by Basirah: ${p.basirahUse}'),
                    style: BText.body(13, color: Tones.guidance.accent, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 6,
          children: [
            for (final l in p.links)
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(l.url), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: Text(l.label, style: BText.label(12.5, color: BColors.gold)),
                style: TextButton.styleFrom(foregroundColor: BColors.gold, visualDensity: VisualDensity.compact),
              ),
          ],
        ),
      ],
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: BColors.gold.withValues(alpha: .14), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: BText.label(11.5, color: BColors.goldDeep, weight: FontWeight.w600)),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.subtitle);

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GoldText(title, style: BText.display(20)),
        if (subtitle != null) Text(subtitle!, style: BText.label(12.5, weight: FontWeight.w400)),
      ],
    ),
  );
}

class _KV extends StatelessWidget {
  const _KV(this.k, this.v);

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: '$k: ', style: BText.label(13, color: BColors.goldDeep)),
        TextSpan(text: v, style: BText.body(13.5, color: BColors.textMuted, height: 1.65)),
      ],
    ),
  );
}
