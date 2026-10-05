import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../shared/web_frame.dart';
import 'baseline_screen.dart';
import 'page_scaffold.dart';

/// One box of the answer path: (title, what Basirah does there).
typedef _Box = (String, String);

/// «كيف تتحقق بصيرة من كل إجابة؟»: the path of every answer, drawn as a
/// flowchart (question → retrieval from the approved package → is the
/// evidence enough? → grounded writing and checking the references → the
/// answer with its citations, or abstention / referral), then what happens
/// at each step, the MCP connection, and the measured results.
class PipelineScreen extends ConsumerWidget {
  const PipelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boxes = <String, _Box>{
      'q': (context.tr('سؤال المستفيد', 'The question'), context.tr('بلغته، مع «سياقي» إن شاء', 'In the asker’s language, with “My context” if set')),
      'r': (
        context.tr('استرجاع من الحزمة المعتمدة', 'Retrieval from the approved package'),
        context.tr('المصحف، والتفسير، والأحاديث عبر MCP', 'The Mushaf, tafsir, and hadith via MCP'),
      ),
      'd': (context.tr('هل الدليل كافٍ؟', 'Is the evidence enough?'), context.tr('أو يحتاج تفصيلاً من السائل', 'Or is a detail needed from the asker')),
      'f': (
        context.tr('صياغة مسندة وفحص المراجع', 'Grounded writing, references checked'),
        context.tr('النموذج يكتب، والحارس يفحص', 'The model writes, the guard checks'),
      ),
      's': (
        context.tr('عرض الإجابة ومواضع الاستشهاد', 'The answer and its citations'),
        context.tr('كل دليل بمصدره ورابطه، وإيصال', 'Each source linked, with a receipt'),
      ),
      'a': (
        context.tr('امتناع أو إحالة إلى المراجعة', 'Abstain, or refer for review'),
        context.tr('أو مراسلة مختص شرعي', 'Or message a Sharia specialist'),
      ),
    };
    final labels = (
      yes: context.tr('نعم', 'Yes'),
      no: context.tr('لا', 'No'),
      passed: context.tr('اجتاز الفحص', 'Passed'),
      failed: context.tr('فشل التحقق', 'Check failed'),
    );
    return PageScaffold(
      title: context.tr('كيف تتحقق بصيرة من كل إجابة؟', 'How Basirah checks every answer'),
      subtitle: context.tr(
        'المسار الذي تمر به كل إجابة حية، من السؤال إلى عرضها أو الامتناع عنها. ولا تُعرض إجابة لم تجتز الفحص.',
        'The path every live answer takes, from the question to showing it or holding it back. No answer is shown unless it passes the check.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1A4A),
              borderRadius: BorderRadius.circular(24),
            ),
            child: isWebsite(context)
                ? AspectRatio(
                    aspectRatio: _Flow.width / _Flow.height,
                    child: FittedBox(child: SizedBox(width: _Flow.width, height: _Flow.height, child: _Flow(boxes: boxes, labels: labels))),
                  )
                : _FlowPhone(boxes: boxes, labels: labels),
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
          _Section(title: context.tr('ما الذي يحدث في كل خطوة', 'What happens at each step')),
          for (final (i, step) in _steps(context).indexed) _StepCard(index: i + 1, step: step),
          const SizedBox(height: 10),
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

typedef _Labels = ({String yes, String no, String passed, String failed});

/// The flowchart on a computer: right to left, as Arabic reads, on a fixed
/// canvas scaled to the width.
class _Flow extends StatelessWidget {
  const _Flow({required this.boxes, required this.labels});

  final Map<String, _Box> boxes;
  final _Labels labels;

  static const width = 1060.0;
  static const height = 400.0;

  /// Box rectangles (x from the left of the canvas).
  static const rects = {
    'q': Rect.fromLTWH(870, 40, 180, 110),
    'r': Rect.fromLTWH(645, 40, 195, 110),
    'd': Rect.fromLTWH(440, 40, 175, 110),
    'f': Rect.fromLTWH(210, 40, 200, 110),
    'a': Rect.fromLTWH(440, 270, 230, 110),
    's': Rect.fromLTWH(10, 270, 250, 110),
  };

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _ArrowsPainter())),
        for (final MapEntry(key: id, value: r) in rects.entries)
          Positioned.fromRect(
            rect: r,
            child: _BoxView(box: boxes[id]!, decision: id == 'd', outcome: id == 's' || id == 'a', good: id == 's'),
          ),
        _Label(text: labels.yes, at: const Offset(418, 18), color: _teal),
        _Label(text: labels.no, at: const Offset(535, 175), color: _muted),
        _Label(text: labels.failed, at: const Offset(330, 222), color: _muted),
        _Label(text: labels.passed, at: const Offset(84, 200), color: _teal),
      ],
    ),
  );
}

const _teal = Color(0xFF4FE3C1);
const _muted = Color(0xFFB9B6E3);

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.at, required this.color});

  final String text;
  final Offset at;
  final Color color;

  @override
  Widget build(BuildContext context) => Positioned(
    left: at.dx,
    top: at.dy,
    child: Text(text, textDirection: TextDirection.rtl, style: BText.label(15, color: color, weight: FontWeight.w600)),
  );
}

class _ArrowsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _teal
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    void line(List<Offset> pts, {bool arrow = true}) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final o in pts.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, p);
      if (!arrow) return;
      final end = pts.last;
      final from = pts[pts.length - 2];
      final dir = (end - from) / (end - from).distance;
      final normal = Offset(-dir.dy, dir.dx);
      final head = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo((end - dir * 11 + normal * 6).dx, (end - dir * 11 + normal * 6).dy)
        ..lineTo((end - dir * 11 - normal * 6).dx, (end - dir * 11 - normal * 6).dy)
        ..close();
      canvas.drawPath(head, Paint()..color = _teal);
    }

    // Main path, right to left.
    line([const Offset(870, 95), const Offset(842, 95)]);
    line([const Offset(645, 95), const Offset(617, 95)]);
    line([const Offset(440, 95), const Offset(412, 95)]);
    // «لا» from the decision, and «فشل التحقق» from the check, meet and go
    // down to abstain / refer.
    line([const Offset(527, 150), const Offset(527, 225)], arrow: false);
    line([const Offset(310, 150), const Offset(310, 225), const Offset(555, 225), const Offset(555, 268)]);
    // «اجتاز الفحص»: down the left to the answer.
    line([const Offset(210, 95), const Offset(70, 95), const Offset(70, 325), const Offset(8, 325)], arrow: false);
    line([const Offset(70, 268), const Offset(70, 272)]);
  }

  @override
  bool shouldRepaint(_ArrowsPainter old) => false;
}

class _BoxView extends StatelessWidget {
  const _BoxView({required this.box, this.decision = false, this.outcome = false, this.good = false});

  final _Box box;
  final bool decision;
  final bool outcome;
  final bool good;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: outcome ? (good ? const Color(0xFF173F45) : const Color(0xFF2C2A60)) : const Color(0xFF26245A),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: decision || good ? _teal : const Color(0xFF4A4790), width: decision || good ? 1.6 : 1),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          box.$1,
          textAlign: TextAlign.center,
          textDirection: Directionality.of(context),
          style: BText.title(17, color: Colors.white, weight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(box.$2, textAlign: TextAlign.center, style: BText.label(12.5, color: _muted, weight: FontWeight.w400)),
      ],
    ),
  );
}

/// The flowchart on a phone: top to bottom, with the two branches.
class _FlowPhone extends StatelessWidget {
  const _FlowPhone({required this.boxes, required this.labels});

  final Map<String, _Box> boxes;
  final _Labels labels;

  @override
  Widget build(BuildContext context) {
    Widget box(String id) => _BoxView(box: boxes[id]!, decision: id == 'd', outcome: id == 's' || id == 'a', good: id == 's');
    Widget down([String? label]) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.arrow_downward_rounded, color: _teal, size: 22),
          if (label != null) ...[const SizedBox(width: 6), Text(label, style: BText.label(13, color: _teal, weight: FontWeight.w600))],
        ],
      ),
    );
    Widget aside(String label) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: BText.label(12.5, color: _muted, weight: FontWeight.w600)),
          const SizedBox(width: 6),
          const Icon(Icons.subdirectory_arrow_left_rounded, color: _muted, size: 18),
          const SizedBox(width: 4),
          Flexible(child: Text(boxes['a']!.$1, style: BText.label(12.5, color: _muted, weight: FontWeight.w400))),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        box('q'),
        down(),
        box('r'),
        down(),
        box('d'),
        aside(labels.no),
        down(labels.yes),
        box('f'),
        aside(labels.failed),
        down(labels.passed),
        box('s'),
        const SizedBox(height: 14),
        box('a'),
      ],
    );
  }
}

/// (icon, tone, title, what happens, the technical detail).
List<(IconData, Tone, String, String, String)> _steps(BuildContext context) => [
  (
    Icons.chat_bubble_outline_rounded,
    Tones.guidance,
    context.tr('سؤال المستفيد', 'The question'),
    context.tr(
      'يكتب السائل سؤاله بلغته. قبل أي نموذج ذكاء اصطناعي تمر الرسالة بفحوص ثابتة في الكود: هل السؤال عن الإسلام؟ هل هو حالة شخصية تحتاج فتوى (المستوى د)؟ هل فيه تعليمات مدسوسة («تجاهل تعليماتك»)؟',
      'The asker writes in their own language. Before any AI model, fixed checks in code ask: is it about Islam? Is it a personal case needing a fatwa (level D)? Does it hide instructions (“ignore your instructions”)?',
    ),
    context.tr(
      'كاشف اللغة يحدد لغة الإجابة (أكثر من 25 لغة). نص السؤال يُعزل داخل وسم خاص فلا يستطيع تغيير التعليمات. ولا يُحفظ نص السؤال على الخادم.',
      'A language detector sets the answer’s language (25+ languages). The question is fenced inside its own tag, so it cannot change the instructions. The server never stores the question text.',
    ),
  ),
  (
    Icons.travel_explore_rounded,
    Tones.evidence,
    context.tr('استرجاع من الحزمة المعتمدة', 'Retrieval from the approved package'),
    context.tr(
      'النموذج (Claude Sonnet 5.5 من Anthropic) لا يجيب من ذاكرته: لديه ثلاث أدوات بحث فقط، ولا يتصفح الإنترنت.',
      'The model (Anthropic’s Claude Sonnet 5.5) does not answer from memory: it has three search tools only, and no web browsing.',
    ),
    context.tr(
      'search_quran: بحث في نص المصحف كاملاً (6236 آية من موسوعة القرآن الكريم، مفهرس محلياً). read_tafsir: قراءة تفسير الآية في موسوعة التفسير، الدرر السنية. search_hadith: بحث في موسوعة الأحاديث النبوية عبر خادم MCP للجمعية. ومعها إجابات قاعدة المعرفة التي كتبها الفريق من المراجع المعتمدة.',
      'search_quran: the whole Mushaf (6,236 verses from QuranEnc, indexed locally). read_tafsir: the verse’s tafsir in Dorar.net’s encyclopedia. search_hadith: HadeethEnc, through the association’s MCP server. Plus the knowledge-base answers the team wrote from the approved references.',
    ),
  ),
  (
    Icons.rule_rounded,
    Tones.clarify,
    context.tr('هل الدليل كافٍ؟', 'Is the evidence enough?'),
    context.tr(
      'يختار النموذج نوع الإجابة: إجابة موثقة، أو بيان خلاف بلا ترجيح، أو سؤال توضيحي حين يختلف الجواب باختلاف حالة السائل، أو إحالة، أو امتناع.',
      'The model chooses the kind of answer: documented, a scholarly difference without picking a side, a clarifying question when the answer depends on the asker’s case, a referral, or abstaining.',
    ),
    context.tr(
      'والحارس يفرض ذلك: إجابة بلا دليل ← امتناع؛ ثقة منخفضة ← امتناع؛ حالة شخصية ← إحالة فوراً ولا يُستوضح فيها.',
      'And the guard enforces it: an answer with no evidence → abstain; low confidence → abstain; a personal case → referral at once, never clarified.',
    ),
  ),
  (
    Icons.verified_user_rounded,
    Tones.principle,
    context.tr('صياغة مسندة وفحص المراجع', 'Grounded writing, references checked'),
    context.tr(
      'يكتب النموذج الشرح في بطاقات، ويشير إلى الآية برقمها والحديث بمعرّفه، ولا يكتب نصهما. ثم يفحص الحارس (كود ثابت، لا ذكاء اصطناعي) كل إجابة قبل أن تظهر.',
      'The model writes the explanation as cards and points to a verse by its number and a hadith by its id, never typing their text. Then the guard (fixed code, not AI) checks every answer before it is shown.',
    ),
    context.tr(
      'نص كل آية يُنسخ من المصحف؛ الآية التي لم يُقرأ تفسيرها تُحذف؛ الحديث الذي لم يُقرأ من مصدره، أو ليس صحيحاً ولا حسناً، يُحذف؛ أي نص قرآني كتبه النموذج من ذاكرته يُستبدل بموضعه؛ الإجابة بغير لغة السؤال تُرفض ويُعاد طلبها.',
      'Every verse text is copied from the Mushaf; a verse whose tafsir was not read is dropped; a hadith not read from its source, or neither sahih nor hasan, is dropped; any Quran wording the model typed is replaced by its reference; an answer in the wrong language is rejected and asked for again.',
    ),
  ),
  (
    Icons.receipt_long_rounded,
    Tones.culture,
    context.tr('عرض الإجابة ومواضع الاستشهاد', 'The answer and its citations'),
    context.tr(
      'بطاقات ملوّنة: الأصل الشرعي، والعرف، والإرشاد العملي، والأدلة. كل آية بنصها من المصحف وتفسيرها من الدرر ورابط صفحتها، وكل حديث بمصدره وحكمه ورابطه.',
      'Colour-coded cards: the principle, custom, practical guidance and evidence. Each verse with its Mushaf text, its tafsir from Dorar and a link to its page; each hadith with its source, grading and link.',
    ),
    context.tr(
      'و«إيصال بصيرة» تحت كل إجابة يبيّن ما فُحص فيها وما حذفه الحارس ولماذا، وخطوات البحث كلها.',
      'And the “Basirah receipt” under each answer shows what was checked, what the guard removed and why, and every research step.',
    ),
  ),
  (
    Icons.support_agent_rounded,
    Tones.refer,
    context.tr('امتناع أو إحالة إلى المراجعة', 'Abstain, or refer for review'),
    context.tr(
      'حين لا يكفي الدليل: «لا تتوفر إجابة موثقة» بدل التخمين. وحين تكون الحالة شخصية: معلومة عامة وإحالة إلى مختص شرعي، يراسله السائل أو يحجز معه مكالمة من داخل بصيرة.',
      'When the evidence is not enough: “no documented answer” instead of a guess. For a personal case: general information and a referral to a Sharia specialist, whom the asker can message or book a call with inside Basirah.',
    ),
    context.tr(
      'وإن تعطّل النموذج أو تجاوز وقته، تُعرض الإجابة الموثقة المحفوظة أو الإحالة أو الامتناع بقواعد ثابتة في الكود، مع تنبيه يقول ذلك.',
      'If the model fails or runs out of time, the stored documented answer, a referral or abstention is shown by fixed rules in code, with a notice saying so.',
    ),
  ),
];

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Text(title, style: BText.display(isWebsite(context) ? 24 : 20, weight: FontWeight.w600)),
  );
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.index, required this.step});

  final int index;
  final (IconData, Tone, String, String, String) step;

  @override
  Widget build(BuildContext context) {
    final (icon, tone, title, body, detail) = step;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [tone.top, tone.bottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tone.accent, shape: BoxShape.circle),
            child: Text('$index', style: BText.label(14, color: Colors.white, weight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: tone.accent),
                    const SizedBox(width: 6),
                    Flexible(child: Text(title, style: BText.title(15.5, color: tone.accent))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(body, style: BText.body(14, height: 1.7)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7), borderRadius: BorderRadius.circular(12)),
                  child: Text(detail, style: BText.body(13, color: BColors.textMuted, height: 1.65)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Basirah ⇄ the association's MCP server ⇄ its indexed references; what
/// comes back is the source's id and link.
class _McpDiagram extends StatelessWidget {
  const _McpDiagram();

  @override
  Widget build(BuildContext context) {
    final nodes = [
      (Icons.auto_awesome_rounded, context.tr('بصيرة تطلب', 'Basirah asks'), context.tr('بحث بنص السؤال', 'A search with the question’s words')),
      (Icons.dns_rounded, context.tr('خادم MCP للجمعية', 'The association’s MCP server'), 'mcp.islamiccontent.org'),
      (Icons.library_books_rounded, context.tr('فهرس المراجع', 'The indexed references'), context.tr('مصادر محددة ومعتمدة', 'Defined, approved sources')),
    ];
    final tools = [
      ('search', context.tr('البحث في موسوعة الأحاديث النبوية', 'Search HadeethEnc')),
      ('get_quran_audio', context.tr('تلاوة كل آية بصوت القارئ', 'Each verse recited by a reciter')),
      ('browse_library', context.tr('إصدارات الجمعية في دار الإسلام بلغة السائل', 'The association’s IslamHouse titles in the asker’s language')),
    ];
    final wide = isWebsite(context);
    final row = [
      for (final (i, (icon, title, sub)) in nodes.indexed) ...[
        if (i > 0)
          Icon(wide ? Icons.sync_alt_rounded : Icons.swap_vert_rounded, color: _teal, size: 26),
        _wrap(
          wide,
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF26245A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: i == 1 ? _teal : const Color(0xFF4A4790)),
            ),
            child: Column(
              children: [
                Icon(icon, color: _teal, size: 22),
                const SizedBox(height: 4),
                Text(title, textAlign: TextAlign.center, style: BText.title(14.5, color: Colors.white)),
                Text(sub, textAlign: TextAlign.center, style: BText.label(12, color: _muted, weight: FontWeight.w400)),
              ],
            ),
          ),
        ),
      ],
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1A4A), borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          wide ? Row(children: row) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: row),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'تعود النتيجة بمعرّف المصدر ورابطه، فتعرض بصيرة النص كما نشره صاحبه وتربطه بصفحته. وتفاصيل الحديث (الحكم والشرح والترجمة المعتمدة) تُقرأ من واجهة موسوعة الأحاديث النبوية نفسها.',
              'The result comes back with the source’s id and link, so Basirah shows the text as its publisher published it and links to its page. Hadith details (grading, explanation, approved translation) are read from HadeethEnc’s own API.',
            ),
            style: BText.body(13.5, color: _muted, height: 1.7),
          ),
          const SizedBox(height: 8),
          for (final (tool, use) in tools)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF26245A), borderRadius: BorderRadius.circular(6)),
                    child: Text(tool, textDirection: TextDirection.ltr, style: BText.label(12, color: _teal, weight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(use, style: BText.label(13, color: Colors.white, weight: FontWeight.w400))),
                ],
              ),
            ),
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
                context.tr('$cases سؤال اختبار، بأربعة أنواع: إجابات اجتازت كل الفحوص', '$cases test questions of four kinds: answers that passed every check'),
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
