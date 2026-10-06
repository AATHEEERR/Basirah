import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/config.dart';
import '../../core/feedback.dart';
import '../../core/lang.dart';
import '../../shared/web_frame.dart';
import 'page_scaffold.dart';

/// «لوحة الأثر»: what happens in Basirah, in numbers — anonymous totals from
/// the server (no question text, IP address or user id is ever stored).
class ImpactScreen extends ConsumerWidget {
  const ImpactScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    return PageScaffold(
      title: context.tr('لوحة الأثر', 'Impact board'),
      subtitle: context.tr(
        'ما يحدث في بصيرة بالأرقام. أعداد فقط: لا نحفظ نص أي سؤال، ولا عنوان IP، ولا أي معرّف للمستخدم.',
        'What happens in Basirah, in numbers. Counts only: no question text, IP address or user id is ever stored.',
      ),
      child: stats.when(
        loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        error: (_, _) => _Note(
          icon: Icons.cloud_off_rounded,
          text: context.tr('تعذّر الوصول إلى الخادم. حاول بعد قليل.', 'Could not reach the server. Try again shortly.'),
        ),
        data: (s) {
          if (s == null) {
            return _Note(
              icon: Icons.cloud_off_rounded,
              text: context.tr('لوحة الأثر تحتاج الاتصال بخادم بصيرة.', 'The impact board needs the Basirah server.'),
            );
          }
          final n = s['questions'] as int;
          if (n == 0) {
            return _Note(
              icon: Icons.insights_rounded,
              text: context.tr('لا توجد بيانات بعد. تظهر الأرقام هنا بعد أول سؤال.', 'No data yet. Numbers appear here after the first question.'),
            );
          }
          return _Board(s: s);
        },
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.s});

  final Map<String, dynamic> s;

  @override
  Widget build(BuildContext context) {
    final n = s['questions'] as int;
    final kinds = (s['kinds'] as Map).cast<String, int>();
    final fb = (s['feedback'] as Map).cast<String, dynamic>();
    final fbTotal = fb['total'] as int;
    final reasons = (fb['reasons'] as Map).cast<String, int>();
    final guard = s['guardCatches'] as int? ?? 0;

    final kindRows = [
      ('answer', context.tr('إجابة موثقة', 'Documented answer'), Tones.principle),
      ('khilaf', context.tr('مسألة خلافية', 'Scholarly difference'), Tones.khilaf),
      ('refer', context.tr('إحالة إلى مختص', 'Referred'), Tones.refer),
      ('abstain', context.tr('امتناع لعدم كفاية المرجع', 'Declined: not enough reference'), Tones.abstain),
      ('offTopic', context.tr('خارج النطاق', 'Out of scope'), Tones.offTopic),
      ('clarify', context.tr('سؤال توضيحي قبل الإجابة', 'A clarifying question first'), Tones.clarify),
    ];
    final reasonRows = [
      for (final (id, ar, en) in helpfulReasons) (id, context.tr(ar, en), Tones.culture),
      for (final (id, ar, en) in unhelpfulReasons) (id, context.tr(ar, en), Tones.refer),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s['since'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _since(context, s['since'] as String),
              style: BText.label(12.5, color: BColors.goldDeep, weight: FontWeight.w600),
            ),
          ),
        ImpactTiles(s: s),
        const SizedBox(height: 12),
        // What «the guard» is, and what it did.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(18)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_rounded, color: Tones.guidance.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  guard == 0
                      ? context.tr(
                          'الحارس كود ثابت يفحص كل إجابة قبل أن تظهر: يحذف الآية التي لم يُقرأ تفسيرها، والحديث غير المقبول، وأي نص قرآني كتبه النموذج من ذاكرته. لم يحتج إلى حذف شيء من أي إجابة حتى الآن: التزم النموذج بالقواعد في كل الإجابات.',
                          'The guard is fixed code that checks every answer before it is shown: it removes a verse whose tafsir was not read, an unaccepted hadith, and any Quran text the model wrote from memory. It has not needed to remove anything from any answer so far: the model kept to the rules every time.',
                        )
                      : context.tr(
                          'الحارس كود ثابت يفحص كل إجابة قبل أن تظهر: يحذف الآية التي لم يُقرأ تفسيرها، والحديث غير المقبول، وأي نص قرآني كتبه النموذج من ذاكرته. تدخّل في $guard من $n إجابة قبل عرضها.',
                          'The guard is fixed code that checks every answer before it is shown: it removes a verse whose tafsir was not read, an unaccepted hadith, and any Quran text the model wrote from memory. It stepped in on $guard of $n answers before they were shown.',
                        ),
                  style: BText.body(13.5, color: BColors.textMuted, height: 1.65),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Bars(title: context.tr('كيف أجابت بصيرة', 'How Basirah answered'), total: n, rows: [for (final (id, label, tone) in kindRows) (label, kinds[id] ?? 0, tone)]),
        const SizedBox(height: 16),
        _Bars(
          title: context.tr('أسباب التقييم', 'Why people rated as they did'),
          total: fbTotal,
          rows: [for (final (id, label, tone) in reasonRows) (label, reasons[id] ?? 0, tone)],
          empty: context.tr('لم يُقيَّم أي جواب بعد.', 'No ratings yet.'),
        ),
        const SizedBox(height: 16),
        _Bars(
          title: context.tr('الأدلة في الإجابات', 'Evidence in the answers'),
          total: n,
          rows: [
            (context.tr('فيها آية من المصحف', 'cite a verse'), s['withVerses'] as int, Tones.evidence),
            (context.tr('فيها حديث بحكمه', 'cite a graded hadith'), s['withHadith'] as int, Tones.evidence),
            (context.tr('أُجيبت فوراً من الذاكرة المؤقتة', 'served at once from the cache'), s['cached'] as int, Tones.guidance),
          ],
        ),
      ],
    );
  }
}

/// «منذ 4 أكتوبر 2026» from the first event's hour («2026-10-04T17:00Z»).
String _since(BuildContext context, String hour) {
  const ar = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  final d = DateTime.parse(hour).toLocal();
  // The month in the interface language, from the date data where it has
  // that language (Tagalog is «fil» there), in English otherwise.
  final ui = context.uiLang;
  final locale = ui == 'tl' ? 'fil' : ui;
  final month = ui == 'ar' ? ar[d.month - 1] : DateFormat.MMMM(DateFormat.localeExists(locale) ? locale : 'en').format(d);
  return context.tr('منذ ${d.day} $month ${d.year}', 'Since ${d.day} $month ${d.year}');
}

/// A titled card of horizontal bars, each a share of [total].
class _Bars extends StatelessWidget {
  const _Bars({required this.title, required this.total, required this.rows, this.empty});

  final String title;
  final int total;
  final List<(String, int, Tone)> rows;
  final String? empty;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(22)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: BText.title(15)),
        const SizedBox(height: 10),
        if (total == 0 && empty != null)
          Text(empty!, style: BText.label(13, weight: FontWeight.w400))
        else
          for (final (label, value, tone) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: isWebsite(context) ? 220 : 140,
                    child: Text(label, style: BText.label(13, color: BColors.ink, weight: FontWeight.w400)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : value / total,
                        minHeight: 9,
                        backgroundColor: BColors.bg,
                        valueColor: AlwaysStoppedAnimation(tone.accent),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text('$value', textAlign: TextAlign.end, style: BText.label(13, color: BColors.ink, weight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Icon(icon, size: 36, color: BColors.goldDeep),
        const SizedBox(height: 10),
        Text(text, textAlign: TextAlign.center, style: BText.label(14, weight: FontWeight.w400)),
      ],
    ),
  );
}

/// The board's numbers, as tiles: the rows are full, and a last row that
/// is not is centred.
class ImpactTiles extends StatelessWidget {
  const ImpactTiles({super.key, required this.s});

  final Map<String, dynamic> s;

  @override
  Widget build(BuildContext context) {
    final n = s['questions'] as int? ?? 0;
    final kinds = ((s['kinds'] as Map?) ?? const {}).cast<String, int>();
    final fb = ((s['feedback'] as Map?) ?? const {}).cast<String, dynamic>();
    final fbTotal = fb['total'] as int? ?? 0;
    final helpful = fb['helpful'] as int? ?? 0;
    final median = s['medianMs'] as int?;
    final sign = context.lang == 'ar' ? '٪' : '%';
    String pct(int part, int whole) => whole == 0 ? '—' : '${(100 * part / whole).round()}$sign';
    // Answers given, and how many cite a verse or hadith from the approved
    // sources (referrals and abstentions are not answers: they cite nothing).
    final answered = s['answered'] as int? ?? ((kinds['answer'] ?? 0) + (kinds['khilaf'] ?? 0));
    final grounded = s['answeredWithEvidence'] as int? ?? 0;
    final referred = kinds['refer'] ?? 0;

    final tiles = [
      (context.tr('سؤالاً طُرح', 'questions asked'), '$n', Tones.guidance),
      (
        context.tr('من إجاباتنا بدليل من المصادر المعتمدة ($grounded من $answered)', 'of our answers cite the approved sources ($grounded of $answered)'),
        pct(grounded, answered),
        Tones.principle,
      ),
      (
        referred == 1
            ? context.tr('حالة أُحيلت إلى مختص', 'case referred to a specialist')
            : context.tr('حالات أُحيلت إلى مختص', 'cases referred to a specialist'),
        '$referred',
        Tones.refer,
      ),
      (context.tr('رضا من قيّموا ($fbTotal)', 'helpful, of $fbTotal ratings'), pct(helpful, fbTotal), Tones.culture),
      (
        context.tr('الوقت الوسيط للإجابة', 'median answer time'),
        median == null ? '—' : '${(median / 1000).toStringAsFixed(1)} ${context.tr('ث', 's')}',
        Tones.evidence,
      ),
    ];
    final columns = isWebsite(context) ? 3 : 2;
    const gap = 10.0;
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        // Low tiles on the website; on a phone they keep their shape.
        final height = columns == 3 ? 136.0 : width / 1.45;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (label, value, tone) in tiles)
              Container(
                width: width,
                height: height,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [tone.top, tone.bottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(value, style: BText.brand(30, color: tone.accent)),
                    Text(label, style: BText.label(12.5, color: BColors.ink, weight: FontWeight.w500)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// «لوحة الأثر» on the home page: the board's numbers themselves, and the
/// way to the details. Hidden without a server.
class ImpactTeaser extends ConsumerWidget {
  const ImpactTeaser({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppConfig.hasApi) return const SizedBox.shrink();
    final s = ref.watch(statsProvider).valueOrNull;
    if (s == null || (s['questions'] as int? ?? 0) == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                [
                  if (s['since'] != null) _since(context, s['since'] as String),
                  context.tr('أعداد فقط، دون حفظ نص أي سؤال', 'counts only, with no question text stored'),
                ].join(' · '),
                style: BText.label(12.5, color: BColors.goldDeep, weight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push('/impact'),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: BColors.ink),
              label: Text(context.tr('التفاصيل', 'Details'), style: BText.label(13, color: BColors.ink, weight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ImpactTiles(s: s),
      ],
    );
  }
}
