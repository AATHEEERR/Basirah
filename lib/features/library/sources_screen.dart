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
        'مستويات الاستجابة والمصادر والمعايير التي تعمل بها بصيرة، بنصها من المرجعية المعتمدة',
        'The response levels, sources and standards Basirah works by, in the words of the approved reference',
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
                'كل سؤال يُصنَّف في أحد أربعة مستويات، ولكل مستوى طريقة تعامل ثابتة.',
                'Every question falls into one of four levels, and each level has a fixed way of handling it.',
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
                  ],
                ),
              ),
            ],
            for (final section in {for (final p in kb.platforms) p.section}) ...[
              _Heading(section, null),
              // «المصادر الآتية من إنتاج الجمعية…» introduces the association's
              // own platforms.
              if (section == kb.platforms.first.section && kb.pack.associationMcp.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    kb.pack.associationMcp,
                    style: BText.label(13, color: BColors.goldDeep),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              // Exactly what Basirah takes from that server, tool by tool.
              if (section == kb.platforms.first.section)
                _Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('ما تأخذه بصيرة من خادم MCP للجمعية', 'What Basirah takes from the association’s MCP server'), style: BText.title(14.5)),
                      const SizedBox(height: 6),
                      for (final (tool, ar, en) in const [
                        ('search', 'البحث عن الأحاديث في موسوعة الأحاديث النبوية', 'Searching the hadith encyclopedia'),
                        ('get_quran_audio', 'تلاوة كل آية بصوت القارئ (رابط ملف صوتي لكل آية)', 'Each verse recited (an audio link per verse)'),
                        ('browse_library', 'إصدارات الفريق العلمي للجمعية في دار الإسلام بلغة السائل', 'The association’s scholarly team’s publications on IslamHouse, in the asker’s language'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tool, style: BText.label(12.5, color: BColors.goldDeep, weight: FontWeight.w600), textDirection: TextDirection.ltr),
                              const SizedBox(width: 8),
                              Expanded(child: Text(context.tr(ar, en), style: BText.body(13, color: BColors.textMuted, height: 1.55))),
                            ],
                          ),
                        ),
                      Text(
                        context.tr(
                          'أما نص المصحف وترجمات المعاني فمن واجهة موسوعة القرآن الكريم، وتفاصيل الحديث من واجهة موسوعة الأحاديث، والتفسير من الدرر السنية.',
                          'The Mushaf text and the translations of the meanings come from QuranEnc’s API, the hadith details from HadeethEnc’s, and the tafsir from Dorar.',
                        ),
                        style: BText.label(12.5, weight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
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
              context.tr('المعايير التي نتبعها، وكيف نطبّقها', 'The standards we follow, and how we apply them'),
              context.tr(
                'ثمانية معايير نتبعها في كل ما تعرضه بصيرة، ومقابل كل معيار ما تفعله فعلاً.',
                'Eight standards we follow in everything Basirah shows, and next to each one what it actually does.',
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
            _Heading(
              context.tr('حالة المحتوى', 'Content status'),
              context.tr('من أين يأتي كل نص في بصيرة، وما الذي روجع منه', 'Where every text in Basirah comes from, and what has been reviewed'),
            ),
            _ContentStatus(kb: kb),
          ],
        ),
      ),
    );
  }
}

String _packNote(BuildContext context) => context.tr(
  'بنص المرجعية المعتمدة',
  'In the Arabic of the approved reference, verbatim',
);

/// The first section of platforms outside the association (p. 11 onwards).
String? _firstExternal(KnowledgeBase kb) => kb.platforms
    .map((p) => p.section)
    .where((s) => s != kb.platforms.first.section && !s.contains('الحرمين'))
    .firstOrNull;

/// «حالة المحتوى»: one row per kind of text, with where it comes from and
/// its review state, counted from the knowledge base itself.
class _ContentStatus extends StatelessWidget {
  const _ContentStatus({required this.kb});

  final KnowledgeBase kb;

  @override
  Widget build(BuildContext context) {
    final reviewed = kb.entries.where((e) => e.review == 'reviewed').length;
    final total = kb.entries.length;
    final rows = [
      (
        Icons.menu_book_rounded,
        Tones.evidence,
        context.tr('نص الآيات', 'Verse text'),
        context.tr(
          'يُنسخ نص كل آية من مصحف مجمع الملك فهد كما تنشره موسوعة القرآن الكريم. النموذج يختار رقم الآية فقط ولا يكتب نصها.',
          'Every verse is copied from the King Fahd Complex Mushaf as published by QuranEnc. The model only picks the verse number; it never writes its text.',
        ),
      ),
      (
        Icons.translate_rounded,
        Tones.culture,
        context.tr('معاني الآيات بغير العربية', 'Verse meanings in other languages'),
        context.tr(
          'من ترجمات المعاني المعتمدة في موسوعة القرآن الكريم، بنصها وصوتها، ولا يترجم النموذج آية بنفسه.',
          'From QuranEnc’s approved translations of the meanings, text and voice; the model never translates a verse itself.',
        ),
      ),
      (
        Icons.format_quote_rounded,
        Tones.guidance,
        context.tr('الأحاديث', 'Hadith'),
        context.tr(
          'في الإجابات الحية من موسوعة الأحاديث النبوية بنصها ومصدرها وحكمها، ولا يُقبل إلا الصحيح والحسن. والأحاديث المحفوظة في القاعدة مذكورة بمصدرها ودرجتها، ومع كل منها رابط للتحقق في الموسوعة الحديثية في الدرر السنية.',
          'In live answers, from HadeethEnc with its text, source and grading; only sahih and hasan are accepted. The hadith stored in the knowledge base carry their source and grading, each with a link to check it on Dorar.net.',
        ),
      ),
      (
        Icons.auto_stories_rounded,
        Tones.principle,
        context.tr('التفسير', 'Tafsir'),
        context.tr(
          'لا تستشهد بصيرة بآية قبل أن تقرأ تفسيرها في موسوعة التفسير في الدرر السنية، وتعرض كلام المفسر منفصلاً عن الآية.',
          'Basirah cites no verse before reading its tafsir in Dorar.net’s encyclopedia, and shows the mufassir’s words apart from the verse.',
        ),
      ),
      (
        Icons.fact_check_rounded,
        Tones.refer,
        context.tr('المراجعة البشرية', 'Human review'),
        context.tr(
          'قاعدة المعرفة (الإصدار ${String.fromCharCode(0x2066)}${kb.version}${String.fromCharCode(0x2069)}): $total سؤالاً و${kb.evidence.length} دليلاً، كتب الفريق شروحها من المراجع أعلاه. روجع منها بشرياً $reviewed من $total، والباقي يظهر عليه «بانتظار المراجعة» حتى يُراجَع.',
          'Knowledge base (version ${kb.version}): $total questions and ${kb.evidence.length} texts, explained by the team from the references above. $reviewed of $total have been human-reviewed; the rest show “pending review” until they are.',
        ),
      ),
    ];
    return _Panel(
      child: Column(
        children: [
          for (final (i, (icon, tone, title, body)) in rows.indexed) ...[
            if (i > 0) const Divider(height: 22, color: BColors.stroke),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBubble(icon: icon, color: tone.accent, fill: tone.top, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: BText.title(14.5, color: tone.accent)),
                      const SizedBox(height: 2),
                      Text(body, style: BText.body(13.5, color: BColors.textMuted, height: 1.7)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

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
          )
        else
          // Named in the reference package, but nothing in Basirah reads it:
          // said plainly, so it is not taken for a source of the answers.
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: BColors.bg, borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.remove_circle_outline_rounded, size: 16, color: BColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.tr('مذكورة في الحزمة المرجعية، ولا تستخدمها بصيرة في إجاباتها حالياً.', 'Named in the reference package; Basirah does not use it in its answers at present.'),
                    style: BText.body(13, color: BColors.textMuted, height: 1.6),
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
