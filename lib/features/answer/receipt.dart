import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../shared/web_frame.dart';

/// «إيصال بصيرة»: how Basirah checked this answer before showing it — the
/// checks that ran on it, what the guard removed and why, and the research
/// steps. Open by default on the website, folded on a phone.
class AnswerReceipt extends StatefulWidget {
  const AnswerReceipt({super.key, required this.answer});

  final BasirahAnswer answer;

  @override
  State<AnswerReceipt> createState() => _AnswerReceiptState();
}

class _AnswerReceiptState extends State<AnswerReceipt> {
  bool? _open;

  @override
  Widget build(BuildContext context) {
    final a = widget.answer;
    final checks = receiptChecks(a, context.lang);
    final removed = [for (final g in a.guard) ?guardNote(g, context.lang)];
    final open = _open ?? isWebsite(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: BColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: BColors.goldDeep.withValues(alpha: .25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => _open = !open),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: BColors.goldDeep, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('كيف تحققت بصيرة من هذه الإجابة؟', 'How did Basirah check this answer?'),
                        style: BText.title(14),
                      ),
                    ),
                    _Pill(text: context.tr('${_arChecks(checks.length)} ✓', '${checks.length} ${checks.length == 1 ? 'check' : 'checks'} ✓'), tone: Tones.culture),
                    if (removed.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _Pill(text: context.tr('حذف ${removed.length}', '${removed.length} removed'), tone: Tones.refer),
                    ],
                    const SizedBox(width: 4),
                    Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: BColors.textMuted),
                  ],
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (title, note) in checks) _Line(ok: true, title: title, note: note),
                    for (final r in removed) _Line(ok: false, title: r, note: null),
                    if (a.research.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(context.tr('خطوات البحث', 'Research steps'), style: BText.label(12, weight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in a.research)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: BColors.bg, borderRadius: BorderRadius.circular(99)),
                              child: Text(s, style: BText.label(12, color: BColors.ink, weight: FontWeight.w400)),
                            ),
                        ],
                      ),
                    ],
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => context.push('/pipeline'),
                        icon: const Icon(Icons.account_tree_outlined, size: 16, color: BColors.goldDeep),
                        label: Text(
                          context.tr('المسار الكامل لكل إجابة بالرسم', 'The full path of every answer, drawn'),
                          style: BText.label(12.5, color: BColors.goldDeep, weight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// «فحص واحد» / «فحصان» / «3 فحوص» / «11 فحصاً».
String _arChecks(int n) => switch (n) {
  1 => 'فحص واحد',
  2 => 'فحصان',
  >= 3 && <= 10 => '$n فحوص',
  _ => '$n فحصاً',
};

/// The checks that ran on [a], as (title, note): only what the system
/// actually does for this kind of answer.
List<(String, String?)> receiptChecks(BasirahAnswer a, String lang) {
  String t(String ar, String en) => lang == 'en' ? en : ar;
  final verses = [for (final e in a.evidence) if (e.isQuran) e];
  final hadith = [for (final e in a.evidence) if (!e.isQuran) e];
  final live = a.origin == AnswerOrigin.ai;
  return [
    if (!live)
      (t('من قاعدة المعرفة الموثقة: إجابة كُتبت مسبقاً بأدلتها', 'From the documented knowledge base: an answer written in advance with its evidence'), null),
    if (verses.isNotEmpty)
      (
        live
            ? t('نص الآيات منقول من مصحف مجمع الملك فهد، لا من ذاكرة الذكاء الاصطناعي', 'The verse text is copied from the King Fahd Complex Mushaf, not from the AI’s memory')
            : t('نص الآيات مطابق لمصحف مجمع الملك فهد، ويُفحص آلياً', 'The verse text matches the King Fahd Complex Mushaf, checked automatically'),
        live ? t('اختار النموذج رقم الآية فقط', 'The model chose only the verse number') : null,
      ),
    if (live && verses.isNotEmpty && verses.every((e) => (e.tafsir ?? '').isNotEmpty))
      (t('قُرئ تفسير كل آية في موسوعة التفسير (الدرر السنية) قبل الاستشهاد بها', 'Each verse’s tafsir was read in Dorar’s tafsir encyclopedia before it was cited'), null),
    if (hadith.isNotEmpty)
      (
        t('الحديث بنصه ومصدره وحكمه، ولا يُقبل إلا الصحيح والحسن', 'Each hadith with its text, source and grading; only sahih and hasan are accepted'),
        hadith.any((e) => e.id.startsWith('he:'))
            ? t('من موسوعة الأحاديث النبوية', 'From the Encyclopedia of Translated Prophetic Hadiths')
            : t('من سجل موثّق للأحاديث', 'From a documented hadith register'),
      ),
    switch (a.kind) {
      AnswerKind.refer => (t('حالة شخصية: معلومة عامة وإحالة إلى مختص، بلا فتوى ولا استشهاد', 'A personal case: general information and a referral, no ruling and no citations'), null),
      AnswerKind.abstain => (t('لا مرجع كافياً: امتنعت بصيرة بدل التخمين، ولم تستشهد بشيء', 'Not enough reference: Basirah declined instead of guessing, citing nothing'), null),
      AnswerKind.khilaf => (t('مسألة خلافية: عُرض المتفق عليه وبيان الخلاف دون ترجيح', 'A matter of scholarly difference: what is agreed, with the difference stated and no side taken'), null),
      AnswerKind.offTopic => (t('خارج نطاق المحتوى الإسلامي: اعتذرت بصيرة دون أي استشهاد', 'Outside Islamic content: Basirah declined without citing anything'), null),
      AnswerKind.clarify => (t('الجواب يختلف باختلاف حالتك: سألتك بصيرة سؤالاً توضيحياً قبل أن تجيب، ولم تستشهد بشيء بعد', 'The answer depends on your situation: Basirah asked one clarifying question before answering, citing nothing yet'), null),
      AnswerKind.answer => (t('سؤال عام (المستوى ${a.level.letterAr})، وليس حالة شخصية تحتاج مفتياً', 'A general question (level ${a.level.code}), not a personal case that needs a mufti'), null),
    },
    if (live) (t('الإجابة بلغة السؤال', 'The answer is in the language of the question'), null),
  ];
}

/// What a guard action means, for the reader; null for notes that are not
/// a change to the answer.
String? guardNote(String g, String lang) {
  String t(String ar, String en) => lang == 'en' ? en : ar;
  RegExpMatch? m;
  if ((m = RegExp(r'^dropped (\S+): cited without reading its tafsir').firstMatch(g)) != null) {
    return t('حُذف الاستشهاد بالآية (${m![1]}) لأن تفسيرها لم يُقرأ في هذه الإجابة', 'Removed the verse (${m[1]}): its tafsir was not read for this answer');
  }
  if ((m = RegExp(r'^dropped unknown verse ref (.+)$').firstMatch(g)) != null) {
    return t('حُذفت إشارة إلى آية غير موجودة (${m![1]})', 'Removed a reference to a verse that does not exist (${m[1]})');
  }
  if (g.startsWith('dropped unknown hadith id')) {
    return t('حُذف حديث لم يُعثر عليه في المصادر المعتمدة', 'Removed a hadith not found in the approved sources');
  }
  if (RegExp(r'^dropped \S+: cited without a reason').hasMatch(g)) {
    return t('حُذف حديث استُشهد به دون بيان ما يدل عليه', 'Removed a hadith cited without saying what it supports');
  }
  if (g.startsWith('replaced unquoted Quran wording') || g == 'replaced Quran quotation with its reference') {
    return t('استُبدل نص قرآني كتبه النموذج من ذاكرته بمرجع الآية', 'Replaced Quran wording the model wrote from memory with the verse reference');
  }
  if (g == 'removed Quran quotation') {
    return t('حُذف نص قرآني كتبه النموذج من ذاكرته ولم يطابق آية بعينها', 'Removed Quran wording the model wrote from memory that matched no single verse');
  }
  if (g == 'level D forced to refer' || g == 'personal case without curated backing forced to refer') {
    return t('حالة شخصية: حُوّلت الإجابة إلى إحالة إلى مختص', 'A personal case: the answer was turned into a referral');
  }
  if (g == 'ungrounded answer forced to abstain' || g == 'low-confidence answer forced to abstain') {
    return t('لا أدلة كافية: حُوّلت الإجابة إلى امتناع', 'Not enough evidence: the answer was turned into a refusal');
  }
  if ((m = RegExp(r'^\w+: dropped (\d+) cited item').firstMatch(g)) != null) {
    return t('حُذفت أدلة (${m![1]}) لأن الإحالة والامتناع لا يستشهدان بشيء', 'Removed ${m[1]} cited item(s): referrals and refusals cite nothing');
  }
  if (g == 'answered from cache' || RegExp(r'^(gemini|claude):|^no model available|^time budget').hasMatch(g)) return null;
  return t('عدّل الحارس جزءاً من الإجابة', 'The guard changed part of the answer');
}

class _Line extends StatelessWidget {
  const _Line({required this.ok, required this.title, required this.note});

  final bool ok;
  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final tone = ok ? Tones.culture : Tones.refer;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tone.top, shape: BoxShape.circle),
            child: Text(ok ? '✓' : '!', style: BText.label(12, color: tone.accent, weight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: BText.body(13.5, height: 1.55)),
                if (note != null) Text(note!, style: BText.label(12, weight: FontWeight.w400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.tone});

  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
    decoration: BoxDecoration(color: tone.top, borderRadius: BorderRadius.circular(99)),
    child: Text(text, style: BText.label(11.5, color: tone.accent, weight: FontWeight.w600)),
  );
}
