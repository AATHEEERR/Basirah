import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../shared/web_frame.dart';
import 'baseline_screen.dart';
import 'page_scaffold.dart';

/// A branch of a step: (when, what happens, its tone).
typedef _Branch = (String, String, Tone);

/// One step of the path: (icon, title, what happens, technical detail,
/// branches that leave the path here).
typedef _Step = (IconData, String, String, String, List<_Branch>);

/// «كيف تتحقق بصيرة من كل إجابة؟»: the path every question takes, step by
/// step as the code runs it (server/lib/src/pipeline.dart, agent.dart,
/// guard.dart), with every branch that leaves it; then the MCP connection
/// and the measured results.
class PipelineScreen extends ConsumerWidget {
  const PipelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps = _steps(context);
    return PageScaffold(
      title: context.tr('كيف تتحقق بصيرة من كل إجابة؟', 'How Basirah checks every answer'),
      subtitle: context.tr(
        'كل سؤال يمرّ بهذا المسار نفسه في الكود، كل مرة؛ والفروع تحدّد أين ينتهي. ولا تُعرض إجابة لم تمرّ على الحارس.',
        'Every question goes through this same path in the code, every time; the branches decide where it ends. No answer is shown without passing the guard.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(24)),
            child: Column(
              children: [
                for (final (i, step) in steps.indexed) _PathStep(index: i + 1, step: step, last: i == steps.length - 1),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'وجود الاستشهاد وحده لا يثبت صحة الاستنتاج؛ لذلك تقرأ بصيرة تفسير الآية قبل أن تستشهد بها، وتكتب «وجه الاستدلال» موسوماً بأنه مولَّد، وتُعرض المصادر للتحقق بنفسك.',
              'A citation alone does not prove the conclusion; so Basirah reads a verse’s tafsir before citing it, labels its “why this verse” as generated, and shows the sources for you to check.',
            ),
            style: BText.label(12.5, weight: FontWeight.w400),
          ),
          const SizedBox(height: 18),
          _Section(title: context.tr('الاتصال بخادم MCP للجمعية', 'The connection to the association’s MCP server')),
          const _McpDiagram(),
          const SizedBox(height: 18),
          _Section(title: context.tr('الإثبات: كيف نعرف أن هذا يعمل', 'The proof: how we know it works')),
          const _Proof(),
        ],
      ),
    );
  }
}

/// The path, as the code runs it.
List<_Step> _steps(BuildContext context) => [
  (
    Icons.chat_bubble_outline_rounded,
    context.tr('سؤال المستفيد', 'The question'),
    context.tr('يكتب السائل سؤاله بأي لغة، ومعه «سياقي» إن شاء، وأسئلته السابقة في المحادثة نفسها.', 'The asker writes in any language, with “My context” if set, and the earlier questions of the same conversation.'),
    context.tr(
      'يُعزل نص السؤال داخل وسم خاص في التعليمات، فلا يستطيع تغييرها. ولا يحفظ الخادم نص السؤال (إلا ما يوافق السائل على إرساله إلى مختص).',
      'The question is fenced inside its own tag in the instructions, so it cannot change them. The server does not keep the question text (except what the asker agrees to send to a specialist).',
    ),
    const [],
  ),
  (
    Icons.rule_folder_outlined,
    context.tr('فحص أولي بالكود، بلا نموذج', 'A first check in code, no model'),
    context.tr(
      'يحدّد لغة السؤال، ويبحث في الإجابات الموثقة التي كتبها الفريق، ويرصد إشارات: حالة شخصية تحتاج فتوى، طلب حديث، طلب ترجمة.',
      'It detects the question’s language, searches the documented answers the team wrote, and flags signals: a personal case needing a fatwa, a hadith request, a translation request.',
    ),
    context.tr('قواعد ثابتة وقوائم كلمات بالعربية والإنجليزية؛ وفي اللغات الأخرى يحكم النموذج على النطاق بالقواعد نفسها.', 'Fixed rules and word lists in Arabic and English; in other languages the model judges the scope by the same rules.'),
    [
      (
        context.tr('ليس عن الإسلام بوضوح', 'Clearly not about Islam'),
        context.tr('اعتذار مباشر، دون استدعاء أي نموذج', 'Declined at once, with no model called'),
        Tones.offTopic,
      ),
    ],
  ),
  (
    Icons.history_rounded,
    context.tr('هل سُئل بالصيغة نفسها من قبل؟', 'Asked in the same words before?'),
    context.tr('السؤال الأول في المحادثة، بالكلمات واللغة والسياق نفسها.', 'The first question of a conversation, in the same words, language and context.'),
    context.tr('تُحفظ الإجابة بلا نص السؤال، باسم ملف مشفّر. ولا تُحفظ إجابات الحالات الشخصية والإحالات.', 'The answer is kept without the question’s text, under a hashed file name. Answers to personal cases and referrals are never kept.'),
    [
      (
        context.tr('نعم', 'Yes'),
        context.tr('تُعرض الإجابة التي اجتازت الحارس من قبل، فوراً', 'The answer that passed the guard before is shown at once'),
        Tones.guidance,
      ),
    ],
  ),
  (
    Icons.travel_explore_rounded,
    context.tr('النموذج يبحث ويقرأ', 'The model searches and reads'),
    context.tr(
      'Claude Sonnet 5.5 لا يجيب من ذاكرته ولا يتصفح الإنترنت: يبحث بأدوات محددة فقط، حتى ست جولات وفي حدود 75 ثانية.',
      'Claude Sonnet 5.5 does not answer from memory or browse the web: it searches with set tools only, up to six rounds and within 75 seconds.',
    ),
    context.tr(
      'search_quran: المصحف كاملاً (6236 آية). read_tafsir: تفسير الآية في الدرر السنية. search_hadith: موسوعة الأحاديث عبر خادم MCP للجمعية، الصحيح والحسن فقط. submit_answer: تسليم الإجابة. وإن طابق السؤال إجابة موثقة قُرئ تفسير آياتها قبل استدعاء النموذج.',
      'search_quran: the whole Mushaf (6,236 verses). read_tafsir: the verse’s tafsir on Dorar. search_hadith: the hadith encyclopedia through the association’s MCP server, sahih and hasan only. submit_answer: hands in the answer. When the question matches a documented answer, its verses’ tafsir is read before the model is called.',
    ),
    [
      (
        context.tr('خطأ من النموذج أو ضغط عليه', 'The model errors or is overloaded'),
        context.tr('يُسأل النموذج التالي: Claude Haiku 4.5 ثم Gemini', 'The next model is asked: Claude Haiku 4.5, then Gemini'),
        Tones.clarify,
      ),
      (
        context.tr('تجاوز 75 ثانية، أو تعذّرت النماذج كلها', 'Past 75 seconds, or every model failed'),
        context.tr('الإجابة الموثقة المحفوظة إن طابقت السؤال، أو إحالة أو امتناع، مع تنبيه يقول ذلك', 'The stored documented answer if it matches, or a referral or abstention, with a notice saying so'),
        Tones.abstain,
      ),
    ],
  ),
  (
    Icons.call_split_rounded,
    context.tr('النموذج يختار نوع الإجابة', 'The model chooses the kind of answer'),
    context.tr(
      'إجابة موثقة، أو بيان خلاف دون ترجيح، أو سؤال توضيحي حين يختلف الجواب باختلاف حال السائل، أو إحالة، أو امتناع، أو اعتذار لأنه خارج النطاق.',
      'A documented answer, a scholarly difference without picking a side, a clarifying question when the answer depends on the asker’s case, a referral, abstaining, or declining as out of scope.',
    ),
    context.tr(
      'يشير إلى الآية برقمها والحديث بمعرّفه ولا يكتب نصهما. وإجابة عربية لسؤال إنجليزي أو العكس تُرفض ويُطلب غيرها مرة.',
      'It points to a verse by its number and a hadith by its id, never typing their text. An Arabic answer to an English question, or the reverse, is rejected and asked for again once.',
    ),
    const [],
  ),
  (
    Icons.verified_user_rounded,
    context.tr('الحارس: كود ثابت يفحص كل إجابة', 'The guard: fixed code checks every answer'),
    context.tr(
      'ينسخ نص كل آية من المصحف، ويحذف الآية التي لم يُقرأ تفسيرها والحديث الذي لم يُقرأ من مصدره، ويستبدل أي نص قرآني كتبه النموذج بموضعه.',
      'It copies every verse’s text from the Mushaf, drops a verse whose tafsir was not read and a hadith not read from its source, and replaces any Quran wording the model typed with its reference.',
    ),
    context.tr('كل ما فعله الحارس يُسجَّل في «إيصال بصيرة» تحت الإجابة.', 'Everything the guard did is listed in the “Basirah receipt” under the answer.'),
    [
      (
        context.tr('فتوى أو حالة شخصية', 'A fatwa or a personal case'),
        context.tr('إحالة إلى مختص شرعي، يراسله السائل أو يحجز معه مكالمة', 'Referred to a Sharia specialist, whom the asker can message or call'),
        Tones.refer,
      ),
      (
        context.tr('إجابة بلا دليل أو بثقة منخفضة', 'An answer with no evidence, or low confidence'),
        context.tr('امتناع: «لا تتوفر إجابة موثقة» بدل التخمين', 'Abstain: “no documented answer” instead of a guess'),
        Tones.abstain,
      ),
      (
        context.tr('سؤال توضيحي بلا خيارات', 'A clarifying question with no options'),
        context.tr('امتناع', 'Abstain'),
        Tones.abstain,
      ),
    ],
  ),
  (
    Icons.receipt_long_rounded,
    context.tr('عرض الإجابة', 'The answer is shown'),
    context.tr(
      'بطاقات ملوّنة: الأصل الشرعي، والعرف، والإرشاد العملي، والأدلة؛ كل آية بنصها من المصحف وتفسيرها ورابط صفحتها، وكل حديث بمصدره وحكمه ورابطه.',
      'Colour-coded cards: the principle, custom, practical guidance and evidence; each verse with its Mushaf text, its tafsir and a link to its page, each hadith with its source, grading and link.',
    ),
    context.tr(
      'وبلغة غير العربية والإنجليزية: معنى كل آية بترجمة معتمدة من موسوعة القرآن الكريم، والحديث بترجمته المعتمدة إن وُجدت.',
      'In a language other than Arabic and English: each verse’s meaning in an approved QuranEnc translation, and the hadith in its approved translation where there is one.',
    ),
    const [],
  ),
];

/// One step on the path: a numbered mark on the line, what happens, the
/// technical detail, and the branches that leave the path here.
class _PathStep extends StatelessWidget {
  const _PathStep({required this.index, required this.step, required this.last});

  final int index;
  final _Step step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final (icon, title, body, detail, branches) = step;
    final wide = isWebsite(context);
    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 19, color: BColors.goldDeep),
            const SizedBox(width: 6),
            Flexible(child: Text(title, style: BText.title(15.5))),
          ],
        ),
        const SizedBox(height: 4),
        Text(body, style: BText.body(14, height: 1.7)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: BColors.bg, borderRadius: BorderRadius.circular(12)),
          child: Text(detail, style: BText.body(13, color: BColors.textMuted, height: 1.65)),
        ),
      ],
    );
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final b in branches) _BranchPill(b)],
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The path: a numbered mark and the line down to the next step.
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: BColors.goldDeep, shape: BoxShape.circle),
                  child: Text('$index', style: BText.label(13.5, color: Colors.white, weight: FontWeight.w700)),
                ),
                if (!last) Expanded(child: Container(width: 2, color: BColors.sand)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: wide && branches.isNotEmpty
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: main),
                        const SizedBox(width: 14),
                        Expanded(flex: 2, child: side),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        main,
                        if (branches.isNotEmpty) ...[const SizedBox(height: 8), side],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «when → what happens», in the tone of where it ends.
class _BranchPill extends StatelessWidget {
  const _BranchPill(this.branch);

  final _Branch branch;

  @override
  Widget build(BuildContext context) {
    final (condition, then, tone) = branch;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [tone.top, tone.bottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.subdirectory_arrow_left_rounded, size: 17, color: tone.accent),
              const SizedBox(width: 4),
              Flexible(child: Text(condition, style: BText.label(13, color: tone.accent, weight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 2),
          Text(then, style: BText.body(13, color: BColors.ink, height: 1.55)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Text(title, style: BText.display(isWebsite(context) ? 24 : 20, weight: FontWeight.w600)),
  );
}

/// Basirah's server ⇄ the association's MCP server ⇄ its platforms, the three
/// tools Basirah calls, and what it reads directly from each source instead.
class _McpDiagram extends StatelessWidget {
  const _McpDiagram();

  @override
  Widget build(BuildContext context) {
    final nodes = [
      (
        Icons.auto_awesome_rounded,
        context.tr('خادم بصيرة', 'Basirah’s server'),
        context.tr('النموذج يكتب عبارة البحث، والخادم يرسل الطلب', 'The model writes the search words; the server sends the request'),
      ),
      (Icons.dns_rounded, context.tr('خادم MCP للجمعية', 'The association’s MCP server'), 'mcp.islamiccontent.org'),
      (
        Icons.library_books_rounded,
        context.tr('منصات الجمعية', 'The association’s platforms'),
        context.tr('موسوعة الأحاديث النبوية، ودار الإسلام، وملفات التلاوة', 'HadeethEnc, IslamHouse, and the recitation files'),
      ),
    ];
    final tools = [
      ('search', context.tr('البحث في الأحاديث وحدها، ويعيد أرقامها', 'Searches the hadith only, and returns their numbers')),
      ('get_quran_audio', context.tr('رابط ملف التلاوة لكل آية، بصوت قارئ يختاره السائل من ثمانية', 'The recitation file link for each verse, in a reciter the asker picks from eight')),
      ('browse_library', context.tr('إصدارات الفريق العلمي للجمعية في دار الإسلام بلغة السائل', 'The association’s scholarly team’s publications on IslamHouse, in the asker’s language')),
    ];
    final direct = [
      (context.tr('نص الحديث وراويه وحكمه وشرحه وترجمته', 'A hadith’s text, narrator, grading, explanation and translation'), context.tr('واجهة موسوعة الأحاديث النبوية', 'HadeethEnc’s API')),
      (context.tr('نص المصحف وترجمات المعاني', 'The Mushaf text and the translations of the meanings'), context.tr('واجهة موسوعة القرآن الكريم', 'QuranEnc’s API')),
      (context.tr('تفسير الآية', 'A verse’s tafsir'), context.tr('موسوعة التفسير، الدرر السنية', 'Dorar’s tafsir encyclopedia')),
    ];
    final wide = isWebsite(context);
    final row = [
      for (final (i, (icon, title, sub)) in nodes.indexed) ...[
        if (i > 0)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(wide ? Icons.sync_alt_rounded : Icons.swap_vert_rounded, color: BColors.goldDeep, size: 24),
          ),
        _wrap(
          wide,
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: i == 1 ? BColors.sandSoft : BColors.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: i == 1 ? BColors.goldDeep : BColors.stroke, width: i == 1 ? 1.5 : 1),
            ),
            child: Column(
              children: [
                Icon(icon, color: BColors.goldDeep, size: 22),
                const SizedBox(height: 4),
                Text(title, textAlign: TextAlign.center, style: BText.title(14.5)),
                Text(sub, textAlign: TextAlign.center, style: BText.label(12, weight: FontWeight.w400)),
              ],
            ),
          ),
        ),
      ],
    ];
    Widget line(String a, String b, {bool code = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: BColors.sandSoft, borderRadius: BorderRadius.circular(8)),
            child: Text(a, textDirection: code ? TextDirection.ltr : null, style: BText.label(12.5, color: BColors.goldDeep, weight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(b, style: BText.body(13, color: BColors.ink, height: 1.55))),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: row)
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: row),
          const SizedBox(height: 14),
          Text(context.tr('الأدوات الثلاث التي تستدعيها بصيرة', 'The three tools Basirah calls'), style: BText.title(14.5)),
          const SizedBox(height: 6),
          for (final (tool, use) in tools) line(tool, use, code: true),
          const SizedBox(height: 8),
          Text(context.tr('ومباشرة من المصدر، دون MCP', 'And directly from the source, without MCP'), style: BText.title(14.5)),
          const SizedBox(height: 6),
          for (final (what, from) in direct) line(from, what),
        ],
      ),
    );
  }

  static Widget _wrap(bool wide, Widget child) => wide ? Expanded(child: child) : child;
}

/// The measured results, from the app's copy of the evaluation reports.
class _Proof extends ConsumerWidget {
  const _Proof();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(baselineProvider).valueOrNull;
    if (d == null) return const SizedBox.shrink();
    final cases = d['cases'] as int;
    final byType = ((d['byType'] as Map?) ?? const {}).cast<String, dynamic>();
    final lang = (d['languages'] as Map?)?.cast<String, dynamic>();
    final types = [
      ('covered', context.tr('سؤال تغطيه المصادر', 'A question the sources cover'), context.tr('إجابة مرتبطة بالمادة مع إحالة دقيقة إلى موضعها', 'An answer tied to the material, citing its exact place')),
      ('personal', context.tr('حالة شخصية (فتوى)', 'A personal case (fatwa)'), context.tr('معلومة عامة وإحالة إلى مختص، بلا حكم', 'General information and a referral, no ruling')),
      ('outside', context.tr('سؤال خارج التغطية أو النطاق', 'Outside the coverage or scope'), context.tr('توضيح الحدود أو الاعتذار، بلا تخمين', 'State the limits or decline, no guessing')),
      ('injection', context.tr('تعليمات دخيلة داخل السؤال', 'Hidden instructions in the question'), context.tr('تجاهل الأمر المدسوس ومتابعة القواعد', 'Ignore the planted instruction, keep the rules')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(22)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('$cases سؤال اختبار، بأربعة أنواع: إجابات اجتازت الفحوص الستة', '$cases test questions of four kinds: answers that passed all six checks'),
                style: BText.title(15),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Text(context.tr('نوع الاختبار والسلوك المتوقع', 'Test and expected behaviour'), style: BText.label(12.5))),
                  SizedBox(width: 70, child: Text(context.tr('نموذج عام', 'General model'), textAlign: TextAlign.center, style: BText.label(12))),
                  if (d['prompted'] != null)
                    SizedBox(width: 70, child: Text(context.tr('نموذج بتعليمات', 'Instructed model'), textAlign: TextAlign.center, style: BText.label(12))),
                  SizedBox(width: 64, child: Text(context.tr('بصيرة', 'Basirah'), textAlign: TextAlign.center, style: BText.label(12, color: Tones.guidance.accent))),
                ],
              ),
              const Divider(height: 16),
              for (final (id, title, expected) in types)
                if (byType[id] case final Map t)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: BText.title(14)),
                              Text(expected, style: BText.label(12, weight: FontWeight.w400)),
                            ],
                          ),
                        ),
                        SizedBox(width: 70, child: _Score(n: t['general'] as int, of: t['cases'] as int)),
                        if (d['prompted'] != null) SizedBox(width: 70, child: _Score(n: t['prompted'] as int, of: t['cases'] as int)),
                        SizedBox(width: 64, child: _Score(n: t['basirah'] as int, of: t['cases'] as int, ours: true)),
                      ],
                    ),
                  ),
              Text(
                context.tr(
                  'الفحوص الستة نفسها في كل الأعمدة، والنموذج نفسه. وأغلب إخفاقات النموذجين الآخرين آيات كتبها النموذج من ذاكرته بدل نسخها من المصحف؛ والنموذج المزوَّد بالتعليمات لم ينفّذ أي تعليمة مدسوسة ولم يترك حالة شخصية بلا إحالة.',
                  'The same six checks in every column, with the same model. Most failures of the other two are verses the model wrote from memory instead of copying them from the Mushaf; the instructed model followed no hidden instruction and left no personal case unreferred.',
                ),
                style: BText.label(12, weight: FontWeight.w400),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => context.push('/baseline'),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: Text(context.tr('طريقة القياس وكل سؤال بإجابته', 'How it was measured, and every answer'), style: BText.label(13, color: BColors.goldDeep, weight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        if (lang != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(22)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('اختبار اللغات: ${lang['questions']} سؤالاً بـ${lang['languages']} لغة', 'Languages test: ${lang['questions']} questions in ${lang['languages']} languages'),
                  style: BText.title(15),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    'أُجيب ${lang['answered']} من ${lang['questions']}؛ ${lang['inLanguage']} بلغة السؤال نفسها؛ و${lang['translated']} عرضت كل آية فيها بترجمة معانٍ معتمدة بلغة السائل.',
                    '${lang['answered']} of ${lang['questions']} answered; ${lang['inLanguage']} in the question’s own language; ${lang['translated']} showed every verse with an approved translation of its meaning in the asker’s language.',
                  ),
                  style: BText.body(14, color: BColors.textMuted, height: 1.7),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.n, required this.of, this.ours = false});

  final int n;
  final int of;
  final bool ours;

  @override
  Widget build(BuildContext context) {
    final all = n == of;
    final color = all ? Tones.guidance.accent : Tones.refer.accent;
    return Column(
      children: [
        Icon(all ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 20),
        Text('$n/$of', style: BText.label(12.5, color: color, weight: FontWeight.w700)),
      ],
    );
  }
}
