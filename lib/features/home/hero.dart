import 'dart:convert';

import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../shared/brand.dart';
import '../library/baseline_screen.dart';

/// The meaning of Yusuf 12:108 in each approved translation on QuranEnc,
/// verbatim (`server/tool/hero_verse.dart`): {ISO code: {key, text}}.
final heroVerseProvider = FutureProvider<Map<String, dynamic>>(
  (_) async => ((jsonDecode(await rootBundle.loadString('assets/kb/hero_verse.json')) as Map)['meanings'] as Map)
      .cast<String, dynamic>(),
);

/// The word the name comes from, drawn in gold inside the verse.
const _basirah = 'بَصِيرَةٍ';

/// The opening of the home page: the name, the verse it is taken from, what
/// Basirah does in one breath, the measured proof, and the ways in.
class HomeHero extends ConsumerWidget {
  const HomeHero({super.key, required this.kb, required this.search, required this.wide});

  final KnowledgeBase kb;

  /// The search pill, which opens «اسأل».
  final Widget search;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verse = kb.evidence['q_12_108'];
    final ui = context.uiLang;
    final meanings = ref.watch(heroVerseProvider).valueOrNull;
    final meaning = ui == 'ar' ? null : ((meanings?[ui] ?? meanings?['en']) as Map?)?.cast<String, dynamic>();
    final baseline = ref.watch(baselineProvider).valueOrNull;
    final cases = baseline?['cases'] as int?;
    final passed = cases == null ? null : cases - ((baseline!['basirah'] as Map)['answersWithProblem'] as num).toInt();

    final chips = [
      (Icons.menu_book_rounded, context.tr('الآية بنصها من مصحف مجمع الملك فهد', 'Verses word for word from the King Fahd Complex Mushaf')),
      (Icons.verified_rounded, context.tr('الحديث بمصدره ودرجته', 'Every hadith with its source and grading')),
      (Icons.link_rounded, context.tr('رابط تحقّق لكل دليل', 'A link to check every piece of evidence')),
      (Icons.translate_rounded, context.tr('معاني الآيات بـ25 لغة', 'Verse meanings in 25 languages')),
      if (passed != null) (Icons.fact_check_rounded, context.tr('$passed من $cases في اختبار الموثوقية', '$passed of $cases in the reliability test')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wide) ...[
          Wordmark(style: BText.brand(context.isEn ? 50 : 60)),
          const SizedBox(height: 8),
        ],
        if (verse != null) _Verse(verse: verse, meaning: meaning, wide: wide),
        SizedBox(height: wide ? 20 : 14),
        // One scale for the block: the name, the verse, then this line a
        // step smaller, its key words in the verse's gold.
        Text.rich(_headline(context, BText.display(wide ? (context.isEn ? 25 : 27) : 21, weight: FontWeight.w500))),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            context.tr(
              'بصيرة رفيقك في أسئلة الإسلام الأولى: تقرأ القرآن والسنة الصحيحة قبل أن تجيب، وتجيبك بلغتك، وتفرّق لك بين ما يقرّره الدين وما هو عادة وثقافة. '
                  'وحين تكون المسألة حالتك أنت، تصلك بمختص شرعي.',
              'Basirah is your companion for your first questions about Islam: it reads the Quran and the authentic Sunnah before it answers, '
                  'answers in your language, and separates what the religion establishes from custom and culture. '
                  'And when the question is about your own situation, it connects you with a Sharia specialist.',
            ),
            style: BText.body(wide ? 16.5 : 15, color: BColors.textMuted, height: 1.75),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (icon, label) in chips)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(99)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: BColors.goldDeep),
                    const SizedBox(width: 6),
                    Text(label, style: BText.label(12.5, color: BColors.ink, weight: FontWeight.w500)),
                  ],
                ),
              ),
          ],
        ),
        SizedBox(height: wide ? 22 : 16),
        search,
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => context.go('/explore'),
              style: FilledButton.styleFrom(backgroundColor: BColors.ink, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: Text(context.tr('اكتشف الأقسام', 'Explore the topics'), style: BText.label(14, color: BColors.onInk, weight: FontWeight.w600)),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/pipeline'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
              icon: const Icon(Icons.account_tree_rounded, size: 18, color: BColors.ink),
              label: Text(context.tr('كيف نتحقق من كل إجابة؟', 'How every answer is checked'), style: BText.label(14, color: BColors.ink, weight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }
}

/// ﴿The verse﴾ [Yusuf: 108], with «بصيرة» in gold, a link to its page on
/// QuranEnc, and its meaning in the interface's language.
class _Verse extends StatelessWidget {
  const _Verse({required this.verse, required this.meaning, required this.wide});

  final Evidence verse;
  final Map<String, dynamic>? meaning;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final text = verse.fullText ?? verse.text;
    final at = text.indexOf(_basirah);
    final style = BText.quran(wide ? 21 : 19);
    final key = meaning?['key'] as String?;
    final url = verse.urlFor(context.lang, quranEncKey: key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: style,
            children: [
              const TextSpan(text: '﴿'),
              if (at < 0)
                TextSpan(text: text)
              else ...[
                TextSpan(text: text.substring(0, at)),
                TextSpan(text: _basirah, style: style.copyWith(color: BColors.goldDeep)),
                TextSpan(text: text.substring(at + _basirah.length)),
              ],
              const TextSpan(text: '﴾'),
            ],
          ),
          textDirection: TextDirection.rtl,
        ),
        InkWell(
          onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              context.tr('[${verse.reference}] · تحقّق من النص في موسوعة القرآن الكريم', '[${verse.reference}] · check the text on QuranEnc'),
              style: BText.label(12.5, color: BColors.goldDeep, weight: FontWeight.w600),
            ),
          ),
        ),
        if (meaning != null) ...[
          const SizedBox(height: 6),
          Text(
            meaning!['text'] as String,
            textDirection: textDirectionOf(meaning!['text'] as String),
            style: BText.body(wide ? 15 : 13.5, color: BColors.textMuted, height: 1.6).copyWith(fontStyle: FontStyle.italic),
          ),
          Text(
            context.tr('ترجمة معاني معتمدة من موسوعة القرآن الكريم', 'An approved translation of the meanings, from QuranEnc'),
            style: BText.label(11.5, color: BColors.textFaint, weight: FontWeight.w400),
          ),
        ],
      ],
    );
  }
}

/// «كل جواب هنا بدليله، وكل دليل تتحقق منه بنفسك», its two key words in
/// gold in Arabic and English; one plain line in the other languages.
TextSpan _headline(BuildContext context, TextStyle style) {
  final gold = style.copyWith(color: BColors.goldDeep);
  return switch (context.uiLang) {
    'ar' => TextSpan(
      style: style,
      children: [
        const TextSpan(text: 'كل جواب هنا '),
        TextSpan(text: 'بدليله', style: gold),
        const TextSpan(text: '، وكل دليل تتحقق منه '),
        TextSpan(text: 'بنفسك', style: gold),
      ],
    ),
    'en' => TextSpan(
      style: style,
      children: [
        const TextSpan(text: 'Every answer comes with its '),
        TextSpan(text: 'evidence', style: gold),
        const TextSpan(text: ', and every piece of evidence you can check '),
        TextSpan(text: 'yourself', style: gold),
      ],
    ),
    _ => TextSpan(
      text: context.tr('كل جواب هنا بدليله، وكل دليل تتحقق منه بنفسك', 'Every answer comes with its evidence, and every piece of evidence you can check yourself'),
      style: style,
    ),
  };
}
