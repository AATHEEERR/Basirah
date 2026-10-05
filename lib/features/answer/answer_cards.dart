import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../specialist/specialist.dart';
import 'recitation_bar.dart';
import '../../shared/patterns.dart';
import '../../shared/widgets.dart';

/// Renders a [BasirahAnswer] as a stack of colour-coded cards:
///
/// * answer  → الأصل الشرعي · العرف والثقافة · الإرشاد العملي · الأدلة
/// * khilaf  → مسألة خلافية · الإرشاد العملي · الأدلة
/// * refer   → يحتاج إلى مختص · الإرشاد العملي · الأدلة
/// * abstain → لا تتوفر إجابة موثقة · الإرشاد العملي
/// * offTopic → خارج نطاق بصيرة · الإرشاد العملي (example questions)
class AnswerCards extends StatelessWidget {
  const AnswerCards({super.key, required this.answer, this.compact = false, this.animate = true, this.specialist = true});

  final BasirahAnswer answer;
  final bool compact;
  final bool animate;

  /// «تحدّث مع مختص شرعي» under a scholarly difference or a referral.
  final bool specialist;

  @override
  Widget build(BuildContext context) {
    final a = answer;
    // Cards are written in the question's language; lay them out in it.
    final dir = questionLang(a.question) == 'en' ? TextDirection.ltr : TextDirection.rtl;
    final cards = <Widget>[
      switch (a.kind) {
        AnswerKind.answer => ToneCard(contentDirection: dir, tone: Tones.principle, compact: compact, child: _Para(a.principle)),
        AnswerKind.khilaf => ToneCard(
          contentDirection: dir,
          tone: Tones.khilaf,
          compact: compact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (a.khilafAgreed.isNotEmpty) ...[
                _SubLabel(context.tr('المتفق عليه', 'What scholars agree on'), Tones.khilaf),
                _Para(a.khilafAgreed),
                const SizedBox(height: 12),
              ],
              _SubLabel(context.tr('موضع الخلاف', 'Where they differ'), Tones.khilaf),
              _Para(a.khilafNote),
              const SizedBox(height: 12),
              _Notice(
                icon: Icons.do_not_disturb_on_outlined,
                text: context.tr(
                  'بصيرة لا ترجّح بين أقوال العلماء في المسائل الاجتهادية.',
                  'Basirah does not choose between scholarly views on matters of ijtihad.',
                ),
                tone: Tones.khilaf,
              ),
              if (specialist) SpecialistCta(answer: a, tone: Tones.khilaf),
            ],
          ),
        ),
        AnswerKind.refer => ToneCard(
          contentDirection: dir,
          tone: Tones.refer,
          compact: compact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Para(a.referReason),
              if (a.principle.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SubLabel(context.tr('المعلومة العامة', 'General information'), Tones.refer),
                _Para(a.principle),
              ],
              if (a.referTo.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SubLabel(context.tr('إلى من تتوجّه؟', 'Who to ask'), Tones.refer),
                _Para(a.referTo),
              ],
              if (specialist) SpecialistCta(answer: a, tone: Tones.refer),
            ],
          ),
        ),
        AnswerKind.abstain => ToneCard(contentDirection: dir, tone: Tones.abstain, compact: compact, child: _Para(a.abstainReason)),
        AnswerKind.offTopic => ToneCard(contentDirection: dir, tone: Tones.offTopic, compact: compact, child: _Para(a.abstainReason)),
      },
      if (a.culture.isNotEmpty)
        ToneCard(contentDirection: dir, tone: Tones.culture, compact: compact, child: _Para(a.culture)),
      if (a.guidance.isNotEmpty)
        ToneCard(contentDirection: dir, tone: Tones.guidance, compact: compact, child: _Steps(a.guidance)),
      if (a.evidence.isNotEmpty || a.sourceNote.isNotEmpty)
        ToneCard(
          contentDirection: dir,
          tone: Tones.evidence,
          compact: compact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, e) in a.evidence.indexed) ...[
                if (i > 0) Divider(height: 28, color: Tones.evidence.accent.withValues(alpha: .15)),
                EvidenceView(e, answerLang: detectLanguage(a.question)),
              ],
              if (a.sourceNote.isNotEmpty) ...[
                if (a.evidence.isNotEmpty) const Divider(height: 28),
                _Para(a.sourceNote, size: 13.5, color: BColors.textMuted),
              ],
            ],
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, card) in cards.indexed)
          Padding(
            padding: EdgeInsets.only(bottom: compact ? 10 : 12),
            child: animate ? Reveal(delay: Duration(milliseconds: 90 * i), child: card) : card,
          ),
      ],
    );
  }
}

/// One colour-coded pastel card with its title, icon bubble and faint pattern.
class ToneCard extends StatelessWidget {
  const ToneCard({super.key, required this.tone, required this.child, this.compact = false, this.contentDirection});

  final Tone tone;
  final Widget child;
  final bool compact;

  /// Direction of the card's content — the answer's language, which may
  /// differ from the interface (the title stays in the interface language).
  final TextDirection? contentDirection;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? 22 : 26);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [tone.top, tone.bottom],
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            PositionedDirectional(
              top: -46,
              end: -46,
              width: 180,
              height: 180,
              child: CustomPaint(painter: StarLatticePainter(color: tone.accent, opacity: .10, cell: 56)),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 16 : 20, compact ? 14 : 18, compact ? 16 : 20, compact ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconBubble(icon: tone.icon, color: tone.accent, fill: Colors.white.withValues(alpha: .75), size: 34),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(tone.titleFor(context.lang), style: BText.title(compact ? 14.5 : 15.5, color: tone.accent)),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 10 : 14),
                  if (contentDirection != null) Directionality(textDirection: contentDirection!, child: child) else child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A verse or hadith exactly as in the evidence registry, with a
/// verification link to the approved platform.
class EvidenceView extends StatelessWidget {
  const EvidenceView(this.evidence, {super.key, this.answerLang});

  final Evidence evidence;

  /// The answer's language (see [RecitationBar.answerLang]).
  final String? answerLang;

  @override
  Widget build(BuildContext context) {
    final e = evidence;
    final accent = Tones.evidence.accent;
    final platform = e.platformNameFor(context.lang);
    final link = TextButton.icon(
      onPressed: () => launchUrl(Uri.parse(e.urlFor(context.lang)), mode: LaunchMode.externalApplication),
      icon: const Icon(Icons.open_in_new_rounded, size: 15),
      label: Text(
        e.isQuran
            ? context.tr('تحقّق من نص الآية في $platform', 'Check this verse on $platform')
            : context.tr('تحقّق من الحديث في $platform', 'Check this hadith on $platform'),
        style: BText.label(12, color: BColors.goldDeep, weight: FontWeight.w600),
      ),
      style: TextButton.styleFrom(
        foregroundColor: BColors.goldDeep,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
    // English answers: the Arabic text stays the evidence; the meaning is
    // shown under it, labelled with its translator.
    final translation = e.translation == null
        ? null
        : _SourceBlock(
            label: e.translationSource ?? 'Translation of the meaning',
            icon: Icons.translate_rounded,
            text: e.translation!,
            fill: Colors.white.withValues(alpha: .75),
          );
    final note = e.note == null
        ? null
        : _SourceBlock(
            label: e.isQuran
                ? context.tr('وجه الاستدلال · شرح مولَّد بالذكاء الاصطناعي', 'Why this verse · AI-generated explanation')
                : context.tr('وجه الاستدلال · شرح مولَّد بالذكاء الاصطناعي', 'Why this hadith · AI-generated explanation'),
            icon: Icons.auto_awesome_outlined,
            text: e.note!,
            fill: BColors.lilac.withValues(alpha: .6),
            italic: true,
          );
    if (e.isQuran) {
      // A cited part of a verse is shown inside the whole verse, highlighted.
      final full = e.fullText;
      final at = full == null ? -1 : full.indexOf(e.text);
      final verse = at < 0
          ? Text('﴿${e.text}﴾', style: BText.quran(19.5), textAlign: TextAlign.center, textDirection: TextDirection.rtl)
          : Text.rich(
              TextSpan(
                style: BText.quran(19.5, color: const Color(0xFF7A6A52)),
                children: [
                  const TextSpan(text: '﴿'),
                  TextSpan(text: full!.substring(0, at)),
                  TextSpan(
                    text: e.text,
                    style: BText.quran(19.5).copyWith(backgroundColor: BColors.gold.withValues(alpha: .22)),
                  ),
                  TextSpan(text: full.substring(at + e.text.length)),
                  const TextSpan(text: '﴾'),
                ],
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          verse,
          if (at >= 0)
            Text(
              context.tr('المظلَّل موضع الاستشهاد من الآية', 'The highlighted words are the part cited'),
              textAlign: TextAlign.center,
              style: BText.label(11, weight: FontWeight.w400),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Flexible(child: Text('[${e.reference}]', style: BText.label(12.5, color: accent, weight: FontWeight.w600))),
              const Spacer(),
              link,
            ],
          ),
          RecitationBar(evidence: e, answerLang: answerLang),
          if (translation != null) ...[
            const SizedBox(height: 8),
            translation,
          ],
          if (e.tafsir != null) ...[
            const SizedBox(height: 8),
            _SourceBlock(
              label: e.tafsirSource ?? context.tr('التفسير', 'Tafsir'),
              icon: Icons.menu_book_outlined,
              text: e.tafsir!,
              fill: Colors.white.withValues(alpha: .75),
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: 8),
            note,
          ],
          // Tafsir in Dorar's encyclopedia (the reference pack's platform):
          // the passage the model read, or the surah for a stored answer.
          if ((e.tafsirUrl ?? e.dorarTafsirUrl) case final url?)
            Wrap(
              children: [
                _TafsirLink(
                  url: url,
                  label: context.tr('اقرأ التفسير كاملاً في الدرر السنية', 'Full tafsir on Dorar.net (Arabic)'),
                ),
              ],
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (e.narrator != null) Text(e.narrator!, style: BText.label(12.5), textDirection: textDirectionOf(e.narrator!)),
        const SizedBox(height: 4),
        // HadeethEnc gives the whole narration («عن … قال: «…»»), already
        // quoted; registry texts are the Prophet's words alone.
        Text(e.text.contains('«') ? e.text : '«${e.text}»', style: BText.hadith(17.5), textDirection: TextDirection.rtl),
        if (translation != null) ...[
          const SizedBox(height: 8),
          translation,
        ],
        // The publisher's own explanation (HadeethEnc), labelled and linked.
        if (e.tafsir != null) ...[
          const SizedBox(height: 8),
          _SourceBlock(
            label: e.tafsirSource ?? context.tr('الشرح', 'Explanation'),
            icon: Icons.menu_book_outlined,
            text: e.tafsir!,
            fill: Colors.white.withValues(alpha: .75),
          ),
        ],
        if (note != null) ...[
          const SizedBox(height: 8),
          note,
        ],
        if (e.tafsirUrl case final url?)
          Wrap(
            children: [
              _TafsirLink(
                url: url,
                label: context.tr('الحديث وشرحه في موسوعة الأحاديث النبوية', 'The hadith and its explanation on HadeethEnc'),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(e.source ?? '', style: BText.label(12, color: accent), textDirection: textDirectionOf(e.source ?? '')),
            if (e.grade != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: BColors.mint, borderRadius: BorderRadius.circular(99)),
                child: Text(e.grade!, style: BText.label(11.5, color: BColors.mintInk, weight: FontWeight.w600)),
              ),
            link,
          ],
        ),
      ],
    );
  }
}

class _TafsirLink extends StatelessWidget {
  const _TafsirLink({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    icon: const Icon(Icons.open_in_new_rounded, size: 15),
    label: Text(label, style: BText.label(12, color: BColors.goldDeep, weight: FontWeight.w600)),
    style: TextButton.styleFrom(foregroundColor: BColors.goldDeep, visualDensity: VisualDensity.compact),
  );
}

/// A labelled quotation box: keeps the mufassir's words and the AI's
/// explanation visibly separate from the Quran text.
class _SourceBlock extends StatelessWidget {
  const _SourceBlock({
    required this.label,
    required this.icon,
    required this.text,
    required this.fill,
    this.italic = false,
  });

  final String label;
  final IconData icon;
  final String text;
  final Color fill;
  final bool italic;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(14)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: BColors.textMuted),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: BText.label(11.5, weight: FontWeight.w600))),
          ],
        ),
        const SizedBox(height: 4),
        SelectableText(
          text,
          // English meaning or note inside Arabic (or the reverse) reads in
          // its own direction.
          textDirection: textDirectionOf(text),
          style: BText.body(13.5, height: 1.75).copyWith(fontStyle: italic ? FontStyle.italic : null),
        ),
      ],
    ),
  );
}

/// «خطوة بحث واحدة» / «خطوتا بحث» / «3 خطوات بحث» / «11 خطوة بحث».
String _arSteps(int n) => switch (n) {
  1 => 'خطوة بحث واحدة',
  2 => 'خطوتا بحث',
  >= 3 && <= 10 => '$n خطوات بحث',
  _ => '$n خطوة بحث',
};

/// «كيف وصلت بصيرة إلى الأدلة؟» — the live research steps, collapsed by
/// default.
class ResearchTrail extends StatelessWidget {
  const ResearchTrail({super.key, required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: BColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: const Icon(Icons.travel_explore_rounded, color: BColors.goldDeep, size: 20),
          title: Text(
            context.tr('كيف وصلت بصيرة إلى الأدلة؟', 'How did Basirah find the evidence?'),
            style: BText.title(13.5, weight: FontWeight.w500),
          ),
          subtitle: Text(
            context.tr(
              '${_arSteps(steps.length)} في المصادر المعتمدة',
              '${steps.length} research ${steps.length == 1 ? 'step' : 'steps'} in the approved sources',
            ),
            style: BText.label(11.5, weight: FontWeight.w400),
          ),
          children: [
            for (final (i, s) in steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 2),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: BColors.beige, shape: BoxShape.circle),
                      child: Text('${i + 1}', style: BText.label(11, color: BColors.beigeInk, weight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s, style: BText.body(13, height: 1.6), textDirection: textDirectionOf(s))),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Para extends StatelessWidget {
  const _Para(this.text, {this.size = 15.5, this.color});

  final String text;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SelectableText(text, style: BText.body(size, color: color));
}

class _SubLabel extends StatelessWidget {
  const _SubLabel(this.text, this.tone);

  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: BText.label(12.5, color: tone.accent, weight: FontWeight.w600)),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, required this.tone});

  final IconData icon;
  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16, color: tone.accent),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: BText.label(12.5, color: tone.accent, weight: FontWeight.w600))),
      ],
    ),
  );
}

class _Steps extends StatelessWidget {
  const _Steps(this.steps);

  final List<String> steps;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, s) in steps.indexed)
        Padding(
          padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Tones.guidance.accent),
                child: Text('${i + 1}', style: BText.label(12, color: Colors.white, weight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(s, style: BText.body(15))),
            ],
          ),
        ),
    ],
  );
}

/// The path of a live answer, as the server runs it (pipeline, agent and
/// guard), in five plain steps.
class PipelineSteps extends StatelessWidget {
  const PipelineSteps({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        Icons.rule_rounded,
        Tones.refer,
        context.tr('فحص السؤال قبل النموذج', 'The question is checked first'),
        context.tr(
          'قواعد ثابتة في الكود: هل السؤال عن الإسلام؟ هل هو حالة شخصية تحتاج مختصاً (المستوى د)؟ هل فيه تعليمات مدسوسة؟ الحالة الشخصية تُحال ولا يُفتى فيها.',
          'Fixed rules in code: is it about Islam? Is it a personal case that needs a specialist (level D)? Does it hide instructions? A personal case is referred, never ruled on.',
        ),
      ),
      (
        Icons.travel_explore_rounded,
        Tones.evidence,
        context.tr('البحث في المصادر المعتمدة', 'Research in the approved sources'),
        context.tr(
          'يبحث النموذج في نص المصحف، ويقرأ تفسير الآية في موسوعة التفسير (الدرر السنية) قبل أن يستشهد بها، ويبحث عن الأحاديث في موسوعة الأحاديث النبوية عبر خادم MCP لجمعية خدمة المحتوى الإسلامي باللغات.',
          'The model searches the Mushaf text, reads a verse’s tafsir in Dorar.net’s encyclopedia before citing it, and looks up hadith on HadeethEnc through the MCP server of the association serving Islamic content in languages.',
        ),
      ),
      (
        Icons.edit_note_rounded,
        Tones.principle,
        context.tr('الكتابة من المصادر فقط', 'Writing from the sources only'),
        context.tr(
          'يكتب النموذج الشرح في بطاقات، ويشير إلى الآية برقمها والحديث بمعرّفه، ولا يكتب نصهما بنفسه.',
          'The model writes the explanation as cards and points to a verse by its number and a hadith by its id; it never types their text.',
        ),
      ),
      (
        Icons.verified_user_rounded,
        Tones.guidance,
        context.tr('الحارس يتحقق', 'The guard checks'),
        context.tr(
          'كود ثابت بعد النموذج: يأخذ نص كل آية من المصحف، ويحذف الآية التي لم يُقرأ تفسيرها والحديث الذي لم يُقرأ من مصدره، ويقبل الصحيح والحسن فقط، ويستبدل أي نص قرآني كتبه النموذج بموضعه، ويحوّل الحالة الشخصية إلى إحالة.',
          'Fixed code after the model: every verse text comes from the Mushaf; a verse whose tafsir was not read, or a hadith not read from its source, is dropped; only sahih and hasan are accepted; any Quran wording the model typed is replaced by its reference; a personal case becomes a referral.',
        ),
      ),
      (
        Icons.receipt_long_rounded,
        Tones.culture,
        context.tr('إيصال بصيرة', 'The Basirah receipt'),
        context.tr(
          'تحت كل إجابة إيصال يبيّن ما فُحص فيها، ومع كل دليل رابط للتحقق منه بنفسك.',
          'Under every answer, a receipt shows what was checked, and every piece of evidence has a link to check it yourself.',
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, (icon, tone, title, body)) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [tone.top, tone.bottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: tone.accent, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: BText.label(13, color: Colors.white, weight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(icon, size: 17, color: tone.accent),
                            const SizedBox(width: 6),
                            Flexible(child: Text(title, style: BText.title(14.5, color: tone.accent))),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(body, style: BText.body(13.5, height: 1.65)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Legend: how an answer is made, and what the card colours mean.
Future<void> showToneLegend(BuildContext context, {Tone? focus}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .72,
      maxChildSize: .92,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(context.tr('كيف تُجيب بصيرة؟', 'How does Basirah answer?'), style: BText.display(24)),
          const SizedBox(height: 4),
          Text(context.tr('من سؤالك إلى الإجابة، في خمس خطوات', 'From your question to the answer, in five steps'), style: BText.label(13.5)),
          const SizedBox(height: 12),
          const PipelineSteps(),
          const SizedBox(height: 20),
          Text(context.tr('ألوان البطاقات', 'The card colours'), style: BText.title(17)),
          const SizedBox(height: 4),
          Text(
            context.tr(
              'كل إجابة تُعرض في بطاقات ملوّنة؛ لكل لون معنى ثابت، حتى تعرف مباشرة: ما الذي يقرّره الدين؟ وما الذي هو عادة؟ وماذا تفعل بعد ذلك؟',
              'Every answer is shown as colour-coded cards. Each colour always means the same thing, so you can tell at a glance: what does the religion establish? What is only custom? And what should you do next?',
            ),
            style: BText.body(14, color: BColors.textMuted),
          ),
          const SizedBox(height: 16),
          for (final t in Tones.all)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ToneCard(tone: t, compact: true, child: Text(t.explainFor(context.lang), style: BText.body(14.5))),
            ),
        ],
      ),
    ),
  );
}
