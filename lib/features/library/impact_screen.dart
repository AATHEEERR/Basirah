import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
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
    final helpful = fb['helpful'] as int;
    final reasons = (fb['reasons'] as Map).cast<String, int>();
    final median = s['medianMs'] as int?;
    String pct(int part, int whole) => whole == 0 ? '—' : '${(100 * part / whole).round()}٪';
    final answered = (kinds['answer'] ?? 0) + (kinds['khilaf'] ?? 0);

    final tiles = [
      (context.tr('سؤالاً طُرح', 'questions asked'), '$n', Tones.guidance),
      (context.tr('أُجيبت من المصادر', 'answered from the sources'), pct(answered, n), Tones.principle),
      (context.tr('أُحيلت إلى مختص', 'referred to a specialist'), pct(kinds['refer'] ?? 0, n), Tones.refer),
      (
        context.tr('رضا من قيّموا ($fbTotal)', 'helpful, of $fbTotal ratings'),
        pct(helpful, fbTotal),
        Tones.culture,
      ),
      (
        context.tr('الوقت الوسيط للإجابة', 'median answer time'),
        median == null ? '—' : context.tr('${(median / 1000).toStringAsFixed(1)} ث', '${(median / 1000).toStringAsFixed(1)} s'),
        Tones.evidence,
      ),
      (context.tr('مرات تدخّل الحارس', 'guard interventions'), '${s['guardCatches']}', Tones.abstain),
    ];

    final kindRows = [
      ('answer', context.tr('إجابة موثقة', 'Documented answer'), Tones.principle),
      ('khilaf', context.tr('مسألة خلافية', 'Scholarly difference'), Tones.khilaf),
      ('refer', context.tr('إحالة إلى مختص', 'Referred'), Tones.refer),
      ('abstain', context.tr('امتناع لعدم كفاية المرجع', 'Declined: not enough reference'), Tones.abstain),
      ('offTopic', context.tr('خارج النطاق', 'Out of scope'), Tones.offTopic),
    ];
    final reasonRows = [
      for (final (id, ar, en) in helpfulReasons) (id, context.tr(ar, en), Tones.culture),
      for (final (id, ar, en) in unhelpfulReasons) (id, context.tr(ar, en), Tones.refer),
    ];

    final columns = isWebsite(context) ? 3 : 2;
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
        GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: columns == 3 ? 1.9 : 1.45,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            for (final (label, value, tone) in tiles)
              Container(
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
        ),
        const SizedBox(height: 24),
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
  const en = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final d = DateTime.parse(hour).toLocal();
  return context.tr('منذ ${d.day} ${ar[d.month - 1]} ${d.year}', 'Since ${d.day} ${en[d.month - 1]} ${d.year}');
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
