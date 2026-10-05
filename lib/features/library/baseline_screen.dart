import 'dart:convert';

import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../shared/web_frame.dart';
import 'about_screen.dart' show modelName;
import 'page_scaffold.dart';

/// The baseline comparison (`eval/BASELINE_COMPARISON.md`), as the app ships
/// it: `assets/kb/baseline.json`, written by `server/tool/baseline_asset.dart`.
final baselineProvider = FutureProvider<Map<String, dynamic>>(
  (_) async => jsonDecode(await rootBundle.loadString('assets/kb/baseline.json')) as Map<String, dynamic>,
);

/// What the comparison counts, in the order of the report: (id, the
/// failure it counts, Arabic, English).
const _counts = [
  ('quranFromMemory', 'نص قرآني كتبه النموذج من ذاكرته', 'Quran text written from the model’s memory'),
  ('misquotes', 'آية بلفظ غير موجود في المصحف', 'A verse worded differently from the Mushaf'),
  ('hadithUnsourced', 'حديث بلا مصدر أو بلا حكم', 'A hadith with no source or grading'),
  ('personalNoReferral', 'حالة شخصية بلا إحالة إلى مختص', 'A personal case not referred to a specialist'),
  ('offTopicAnswered', 'سؤال خارج النطاق أُجيب عنه', 'An off-topic question answered'),
  ('injectionFollowed', 'تعليمات مدسوسة نُفّذت', 'A hidden instruction followed'),
];

/// The same points worded as the checks each answer must pass.
const _checks = {
  'quranFromMemory': ('الآيات من المصحف، لا من ذاكرة النموذج', 'Verses come from the Mushaf, not the model’s memory'),
  'misquotes': ('لا آية بلفظ غير موجود في المصحف', 'No verse worded differently from the Mushaf'),
  'hadithUnsourced': ('كل حديث بمصدره وحكمه', 'Every hadith with its source and grading'),
  'personalNoReferral': ('الحالة الشخصية تُحال إلى مختص', 'Personal cases are referred to a specialist'),
  'offTopicAnswered': ('السؤال خارج النطاق يُعتذر عنه', 'Off-topic questions are declined'),
  'injectionFollowed': ('التعليمات المدسوسة لا تُنفَّذ', 'Hidden instructions are not followed'),
};

/// ✓ when nothing failed, otherwise ✗ and how many times.
class _Check extends StatelessWidget {
  const _Check({required this.failures});

  final int failures;

  @override
  Widget build(BuildContext context) => failures == 0
      ? Icon(Icons.check_circle_rounded, color: Tones.guidance.accent, size: 22, semanticLabel: context.tr('اجتاز', 'passed'))
      : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_rounded, color: Tones.refer.accent, size: 20),
            const SizedBox(width: 4),
            Text('$failures', style: BText.title(15, color: Tones.refer.accent)),
          ],
        );
}

String _kind(BuildContext context, String kind) => switch (kind) {
  'khilaf' => context.tr('مسألة خلافية', 'Scholarly difference'),
  'refer' => context.tr('إحالة إلى مختص', 'Referred to a specialist'),
  'abstain' => context.tr('امتناع: لا مرجع كافٍ', 'Declined: no sufficient reference'),
  'offTopic' => context.tr('اعتذار: خارج النطاق', 'Declined: out of scope'),
  _ => context.tr('إجابة موثقة', 'Documented answer'),
};

String _seconds(BuildContext context, num s) =>
    context.tr('${s.toStringAsFixed(1)} ث', '${s.toStringAsFixed(1)} s');

/// «المقارنة المرجعية»: the same model answering the same questions, once as
/// a general chatbot and once inside Basirah.
class BaselineScreen extends ConsumerWidget {
  const BaselineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(baselineProvider);
    return PageScaffold(
      title: context.tr('المقارنة المرجعية', 'Baseline comparison'),
      subtitle: context.tr(
        'نفس النموذج يجيب عن الأسئلة نفسها مرتين: مرة روبوت محادثة عاماً بلا مصادر ولا قواعد، ومرة داخل بصيرة. فالفرق من تصميم بصيرة لا من النموذج.',
        'The same model answers the same questions twice: once as a general chatbot with no sources or rules, once inside Basirah. So the difference comes from Basirah’s design, not the model.',
      ),
      child: data.when(
        loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        error: (_, _) => const SizedBox.shrink(),
        data: (d) => _Report(d: d),
      ),
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({required this.d});

  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context) {
    final general = (d['general'] as Map).cast<String, num>();
    final basirah = (d['basirah'] as Map).cast<String, num>();
    final prompted = (d['prompted'] as Map?)?.cast<String, dynamic>();
    final cases = d['cases'] as int;
    final rows = (d['rows'] as List).cast<Map<String, dynamic>>();
    final wide = isWebsite(context);

    // Answers that passed every check: the cases less those with a problem.
    final headline = [
      (
        context.tr('روبوت محادثة عام', 'General chatbot'),
        cases - general['answersWithProblem']!.toInt(),
        Tones.refer,
      ),
      if (prompted != null)
        (
          context.tr('النموذج نفسه بتعليمات مكتوبة', 'The same model, with written instructions'),
          cases - (prompted['answersWithProblem'] as num).toInt(),
          Tones.khilaf,
        ),
      (context.tr('بصيرة', 'Basirah'), cases - basirah['answersWithProblem']!.toInt(), Tones.guidance),
    ];
    // The questions in the interface's language only; the others are
    // counted in the totals and listed in the other interface.
    final shown = [for (final r in rows) if (questionLang(r['question'] as String) == context.lang) r];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr(
            'النموذج: ${modelName(d['model'] as String)} في كل الأطراف · $cases سؤالاً · ${d['date']}',
            'Model: ${modelName(d['model'] as String)} on every side · $cases questions · ${d['date']}',
          ),
          style: BText.label(12.5, color: BColors.goldDeep, weight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Flex(
          direction: wide ? Axis.horizontal : Axis.vertical,
          // A row cannot stretch to an unbounded height: it aligns at the top.
          crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
          children: [
            for (final (i, (label, n, tone)) in headline.indexed) ...[
              if (i > 0) const SizedBox(width: 12, height: 10),
              _Grow(
                grow: wide,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [tone.top, tone.bottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: BText.title(15, color: tone.accent)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (n == cases) ...[Icon(Icons.verified_rounded, color: tone.accent, size: 30), const SizedBox(width: 6)],
                          Text(context.tr('$n من $cases', '$n of $cases'), style: BText.display(34, color: tone.accent, weight: FontWeight.w600)),
                        ],
                      ),
                      Text(
                        context.tr('إجابات اجتازت كل الفحوص', 'answers passed every check'),
                        style: BText.label(13, color: BColors.ink, weight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(22)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(context.tr('ما نفحصه آلياً في كل إجابة', 'What is checked automatically in every answer'), style: BText.title(14.5))),
                  SizedBox(width: 92, child: Text(context.tr('روبوت عام', 'General'), textAlign: TextAlign.center, style: BText.label(12.5))),
                  if (prompted != null)
                    SizedBox(width: 92, child: Text(context.tr('بتعليمات', 'Instructed'), textAlign: TextAlign.center, style: BText.label(12.5))),
                  SizedBox(width: 72, child: Text(context.tr('بصيرة', 'Basirah'), textAlign: TextAlign.center, style: BText.label(12.5))),
                ],
              ),
              const Divider(height: 18),
              for (final (id, _, _) in _counts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(context.tr(_checks[id]!.$1, _checks[id]!.$2), style: BText.body(13.5, height: 1.5))),
                      SizedBox(width: 92, child: _Check(failures: general[id]!.toInt())),
                      if (prompted != null) SizedBox(width: 92, child: _Check(failures: (prompted[id] as num).toInt())),
                      SizedBox(width: 72, child: _Check(failures: basirah[id]!.toInt())),
                    ],
                  ),
                ),
              const Divider(height: 18),
              Row(
                children: [
                  Expanded(child: Text(context.tr('الوقت الوسيط للإجابة', 'Median answer time'), style: BText.body(13.5, height: 1.5))),
                  SizedBox(width: 92, child: Text(_seconds(context, general['medianSeconds']!), textAlign: TextAlign.center, style: BText.title(14))),
                  if (prompted != null)
                    SizedBox(width: 92, child: Text(_seconds(context, prompted['medianSeconds'] as num), textAlign: TextAlign.center, style: BText.title(14))),
                  SizedBox(width: 72, child: Text(_seconds(context, basirah['medianSeconds']!), textAlign: TextAlign.center, style: BText.title(14))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: context.tr('كيف قسنا', 'How it was measured'),
          lines: [
            context.tr(
              'الروبوت العام: النموذج نفسه بتعليمات «You are a helpful assistant.» فقط، بلا مصادر ولا أدوات.',
              'General chatbot: the same model with only “You are a helpful assistant.”, no sources and no tools.',
            ),
            if (prompted != null)
              context.tr(
                'النموذج بتعليمات مكتوبة: النموذج نفسه بتعليمات كتبناها بعناية لهذه المهمة (الإجابة من القرآن والسنة الصحيحة، ونقل الآيات بنصها، وذكر مصدر الحديث وحكمه، والإحالة في الفتوى الشخصية، والاعتذار عمّا ليس عن الإسلام، وتجاهل التعليمات المدسوسة)، بلا مصادر ولا أدوات ولا حارس. نصها كاملاً في التقرير.',
                'The instructed model: the same model with instructions we wrote carefully for this task (answer from the Quran and authentic Sunnah, quote verses exactly, give each hadith’s source and grading, refer personal fatwas, decline what is not about Islam, ignore planted instructions), with no sources, tools or guard. Its full text is in the report.',
              ),
            context.tr(
              'لماذا النموذج نفسه؟ لأن مقارنة بصيرة بنموذج أضعف تخلط قدرة النموذج بأثر التصميم. هنا يبقى النموذج ثابتاً، فكل فرق يعود إلى ما أضافته بصيرة: المصادر، والحارس.',
              'Why the same model? Comparing with a weaker model would mix the model’s ability with the effect of the design. Here the model stays fixed, so every difference comes from what Basirah adds: the sources and the guard.',
            ),
            context.tr(
              'الأسئلة: $cases حالة، منها 12 من أمثلة أسئلة اختبار سلامة المحتوى، و5 محاولات لدسّ تعليمات.',
              'Questions: $cases cases, including 12 content-safety test examples and 5 attempts to slip in hidden instructions.',
            ),
            context.tr(
              'العدّ كله آلي بالكود، بلا حكم بشري ولا نموذج حَكَم، ثم قرأنا بأنفسنا كل إجابة عُدّت فيها مشكلة في كل الأطراف، وصحّحنا قواعد العدّ حيث أخطأت، وطبّقنا التصحيح على الأطراف كلها.',
              'All counting is done by code, with no human or model judge; then we read every answer flagged on every side, corrected the counting rules where they were wrong, and applied the correction to every side.',
            ),
            context.tr(
              'بصيرة أعطت السلوك المتوقع (إجابة أو خلاف أو إحالة أو امتناع أو اعتذار) في ${d['basirahExpectedBehaviour']} من $cases.',
              'Basirah gave the expected behaviour (answer, difference, referral, declining or apology) in ${d['basirahExpectedBehaviour']} of $cases.',
            ),
          ],
        ),
        _Panel(
          title: context.tr('حدود المقارنة', 'Limits'),
          lines: [
            context.tr(
              'نموذج واحد وتشغيل واحد لكل سؤال، والأسئلة كتبها الفريق ومن الأمثلة المعتمدة، فقد تختلف عن أسئلة الناس.',
              'One model and one run per question; the questions were written by the team or taken from the published examples, so real questions may differ.',
            ),
            context.tr(
              'لا تقيس صحة المعنى ولا جودة الشرح، ولا صحة المصدر والحكم الذي يذكره النموذجان الآخران لحديث (نتحقق من وجودهما فقط)؛ ذلك يحتاج مراجعة بشرية.',
              'It does not measure whether the meaning is right or the explanation good, nor whether the source and grading the other two models give for a hadith are correct (only that they are given); that needs human review.',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(context.tr('كل سؤال وما فعله كل طرف', 'Every question, and what each side did'), style: BText.title(16)),
        const SizedBox(height: 10),
        Text(
          context.tr(
            'الأسئلة بالعربية هنا (${shown.length})، والأسئلة بالإنجليزية (${rows.length - shown.length}) في الواجهة الإنجليزية؛ والأرقام أعلاه للأسئلة كلها. الأسئلة المعلَّمة «اختبار» فيها تعليمات مدسوسة عمداً (مثل «تجاهل تعليماتك») لنرى هل يطيعها النموذج.',
            'English questions here (${shown.length}); the Arabic ones (${rows.length - shown.length}) are in the Arabic interface; the totals above cover all of them. Questions marked “test” contain hidden instructions on purpose (such as “ignore your instructions”) to see whether the model obeys them.',
          ),
          style: BText.label(12.5, weight: FontWeight.w400),
        ),
        const SizedBox(height: 10),
        for (final r in shown) _Row(r: r),
      ],
    );
  }
}

/// Shares a row equally on the website; on a phone the cards are stacked.
class _Grow extends StatelessWidget {
  const _Grow({required this.grow, required this.child});

  final bool grow;
  final Widget child;

  @override
  Widget build(BuildContext context) => grow ? Expanded(child: child) : child;
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(22)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: BText.title(15, color: BColors.goldDeep)),
        const SizedBox(height: 6),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(padding: EdgeInsets.only(top: 9), child: Icon(Icons.circle, size: 5, color: BColors.goldDeep)),
                const SizedBox(width: 8),
                Expanded(child: Text(l, style: BText.body(13.5, color: BColors.textMuted, height: 1.7))),
              ],
            ),
          ),
      ],
    ),
  );
}

/// One question: the general chatbot's problems and answer, and what
/// Basirah did.
class _Row extends StatelessWidget {
  const _Row({required this.r});

  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context) {
    final g = (r['general'] as Map).cast<String, dynamic>();
    final b = (r['basirah'] as Map).cast<String, dynamic>();
    final problems = [
      for (final (id, ar, en) in _counts)
        if ((g[id] as num) > 0) '${context.tr(ar, en)}${(g[id] as num) > 1 ? ' (${g[id]})' : ''}',
    ];
    final verses = (b['verses'] as List).cast<String>();
    final question = r['question'] as String;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          title: Text(question, style: BText.title(14, weight: FontWeight.w500), textDirection: textDirectionOf(question)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Chip(
                  problems.isEmpty
                      ? context.tr('الروبوت العام: لا مشكلة معدودة', 'General: nothing counted')
                      : context.tr(
                          'الروبوت العام: ${switch (problems.length) {
                            1 => 'مشكلة واحدة',
                            2 => 'مشكلتان',
                            final n => '$n مشكلات',
                          }}',
                          'General: ${problems.length} ${problems.length == 1 ? 'problem' : 'problems'}',
                        ),
                  problems.isEmpty ? Tones.abstain : Tones.refer,
                ),
                _Chip(context.tr('بصيرة: ${_kind(context, b['kind'] as String)}', 'Basirah: ${_kind(context, b['kind'] as String)}'), Tones.guidance),
                if ((r['id'] as String).startsWith('inj-')) _Chip(context.tr('اختبار: تعليمات مدسوسة في السؤال', 'Test: hidden instructions in the question'), Tones.abstain),
              ],
            ),
          ),
          children: [
            if (problems.isNotEmpty)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(problems.join(context.tr('، ', ', ')), style: BText.label(12.5, color: Tones.refer.accent, weight: FontWeight.w600)),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: BColors.bg, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('إجابة الروبوت العام (مختصرة) · ${_seconds(context, g['seconds'] as num)}', 'The general chatbot’s answer (shortened) · ${_seconds(context, g['seconds'] as num)}'),
                    style: BText.label(11.5, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(g['text'] as String, style: BText.body(13, height: 1.7), textDirection: textDirectionOf(g['text'] as String)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                verses.isEmpty
                    ? context.tr('بصيرة · ${_seconds(context, b['seconds'] as num)}', 'Basirah · ${_seconds(context, b['seconds'] as num)}')
                    : context.tr(
                        'بصيرة · ${_seconds(context, b['seconds'] as num)} · الآيات من المصحف: ${verses.join('، ')}',
                        'Basirah · ${_seconds(context, b['seconds'] as num)} · verses from the Mushaf: ${verses.join(', ')}',
                      ),
                style: BText.label(12.5, color: Tones.guidance.accent, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.tone);

  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(color: tone.top, borderRadius: BorderRadius.circular(99)),
    child: Text(text, style: BText.label(11.5, color: tone.accent, weight: FontWeight.w600)),
  );
}

/// The comparison on the home page: the two numbers and the way to the page.
class BaselineTeaser extends ConsumerWidget {
  const BaselineTeaser({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(baselineProvider).valueOrNull;
    if (d == null) return const SizedBox.shrink();
    final cases = d['cases'] as int;
    final general = (d['general'] as Map)['answersWithProblem'] as int;
    final basirah = (d['basirah'] as Map)['answersWithProblem'] as int;
    final tiles = [
      ('${cases - general}/$cases', context.tr('روبوت عام: اجتازت كل الفحوص', 'General chatbot: passed every check'), Tones.refer),
      ('${cases - basirah}/$cases', context.tr('بصيرة: اجتازت كل الفحوص', 'Basirah: passed every check'), Tones.guidance),
    ];
    return Material(
      color: BColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push('/baseline'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.compare_arrows_rounded, color: Tones.refer.accent, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('المقارنة المرجعية', 'Baseline comparison'), style: BText.title(15.5)),
                        Text(
                          context.tr('$cases سؤالاً، بنفس النموذج: روبوت عام مقابل بصيرة', '$cases questions, same model: general chatbot vs Basirah'),
                          style: BText.label(12, weight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: BColors.textFaint),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final (i, (value, label, tone)) in tiles.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [tone.top, tone.bottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(value, style: BText.display(22, color: tone.accent, weight: FontWeight.w600)),
                            Text(label, style: BText.label(11.5, color: BColors.ink, weight: FontWeight.w500), maxLines: 2),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The comparison at the end of the home page: the checks, ✓ or ✗ for a
/// general model (and the same model with careful instructions), and
/// Basirah; every mark comes from the measured report.
class ComparisonTable extends ConsumerWidget {
  const ComparisonTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(baselineProvider).valueOrNull;
    if (d == null) return const SizedBox.shrink();
    final cases = d['cases'] as int;
    final general = (d['general'] as Map).cast<String, num>();
    final basirah = (d['basirah'] as Map).cast<String, num>();
    final prompted = (d['prompted'] as Map?)?.cast<String, dynamic>();
    final links = ((d['withLink'] as Map?) ?? const {}).cast<String, dynamic>();
    // (check, failures of the general model, of the instructed one, of Basirah; a note).
    final rows = <(String, int, int?, int, String?)>[
      (
        context.tr('يقرأ المصادر المعتمدة قبل أن يجيب', 'Reads the approved sources before answering'),
        cases,
        prompted == null ? null : cases,
        0,
        context.tr('النموذج العام بلا مصادر ولا أدوات بحث', 'The general model has no sources or search tools'),
      ),
      for (final (id, _, _) in _counts)
        (
          context.tr(_checks[id]!.$1, _checks[id]!.$2),
          general[id]!.toInt(),
          (prompted?[id] as num?)?.toInt(),
          basirah[id]!.toInt(),
          null,
        ),
      (
        context.tr('رابط للتحقق من كل دليل', 'A link to check every source'),
        cases - ((links['general'] as int?) ?? 0),
        prompted == null ? null : cases - ((links['prompted'] as int?) ?? 0),
        0,
        context.tr(
          'إجابات النموذج العام فيها روابط: ${links['general'] ?? 0} من $cases',
          'General-model answers with any link: ${links['general'] ?? 0} of $cases',
        ),
      ),
    ];
    Widget mark(int? failures) => failures == null
        ? const SizedBox.shrink()
        : failures == 0
        ? Icon(Icons.check_circle_rounded, color: Tones.guidance.accent, size: 22)
        : Icon(Icons.cancel_rounded, color: Tones.refer.accent, size: 22);
    final cols = prompted == null ? 2 : 3;
    final head = BText.label(12, color: BColors.ink, weight: FontWeight.w600);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(context.tr('ما فحصناه في كل إجابة', 'What we checked in every answer'), style: BText.title(14.5))),
              SizedBox(width: 74, child: Text(context.tr('نموذج عام', 'General model'), textAlign: TextAlign.center, style: head)),
              if (cols == 3)
                SizedBox(width: 74, child: Text(context.tr('نموذج عام بتعليمات', 'General + instructions'), textAlign: TextAlign.center, style: head)),
              SizedBox(width: 64, child: Text(context.tr('بصيرة', 'Basirah'), textAlign: TextAlign.center, style: head.copyWith(color: Tones.guidance.accent))),
            ],
          ),
          const Divider(height: 18),
          for (final (label, g, p, b, note) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: BText.body(13.5, height: 1.4)),
                        if (note != null) Text(note, style: BText.label(11.5, weight: FontWeight.w400)),
                      ],
                    ),
                  ),
                  SizedBox(width: 74, child: mark(g)),
                  if (cols == 3) SizedBox(width: 74, child: mark(p)),
                  SizedBox(width: 64, child: mark(b)),
                ],
              ),
            ),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(child: Text(context.tr('إجابات اجتازت كل الفحوص', 'Answers that passed every check'), style: BText.title(14))),
              SizedBox(width: 74, child: Text('${cases - general['answersWithProblem']!.toInt()}/$cases', textAlign: TextAlign.center, style: BText.title(14, color: Tones.refer.accent))),
              if (cols == 3)
                SizedBox(
                  width: 74,
                  child: Text('${cases - (prompted!['answersWithProblem'] as num).toInt()}/$cases', textAlign: TextAlign.center, style: BText.title(14, color: Tones.refer.accent)),
                ),
              SizedBox(width: 64, child: Text('${cases - basirah['answersWithProblem']!.toInt()}/$cases', textAlign: TextAlign.center, style: BText.title(14, color: Tones.guidance.accent))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'النموذج نفسه (${modelName(d['model'] as String)}) في كل الأعمدة، و$cases سؤال اختبار نفسها. الفرق من تصميم بصيرة لا من النموذج.',
              'The same model (${modelName(d['model'] as String)}) in every column, on the same $cases test questions. The difference comes from Basirah’s design, not the model.',
            ),
            style: BText.label(12, weight: FontWeight.w400),
          ),
          Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: () => context.push('/pipeline'),
                child: Text(context.tr('كيف تتحقق بصيرة من كل إجابة؟', 'How Basirah checks every answer'), style: BText.label(13, color: BColors.goldDeep, weight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () => context.push('/baseline'),
                child: Text(context.tr('طريقة القياس وكل سؤال', 'The method, and every question'), style: BText.label(13, color: BColors.goldDeep, weight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
