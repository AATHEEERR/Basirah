import 'arabic.dart';
import 'models.dart';
import 'retriever.dart';
import 'safety.dart';

/// Language of a typed question: 'ar' when mostly Arabic script, else 'en'.
String questionLang(String question) => isMostlyArabic(question) ? 'ar' : 'en';

/// Fixed texts for answers the router builds itself (no curated entry).
class RouterTexts {
  const RouterTexts._({
    required this.referReason,
    required this.referTo,
    required this.referGuidance,
    required this.abstainReason,
    required this.abstainGuidance,
    required this.hadithReason,
    required this.hadithGuidance,
    required this.personalNote,
    required this.offTopicReason,
    required this.offTopicGuidance,
    required this.khilafFallback,
  });

  final String referReason;
  final String referTo;
  final List<String> referGuidance;
  final String abstainReason;
  final List<String> abstainGuidance;
  final String hadithReason;
  final List<String> hadithGuidance;
  final String personalNote;
  final String offTopicReason;
  final List<String> offTopicGuidance;
  final String khilafFallback;

  static RouterTexts of(String lang) => lang == 'en' ? en : ar;

  static const ar = RouterTexts._(
    referReason:
        'سؤالك يتعلق بحالة شخصية أو واقعة بعينها، والحكم فيها يحتاج إلى مفتٍ مؤهل '
        'يسمع التفاصيل كاملة. بصيرة تقدّم المعلومات العامة الموثقة فقط، ولا تُصدر '
        'فتوى شخصية.',
    referTo:
        'مفتٍ مؤهل أو جهة إفتاء رسمية في بلدك، أو مختص شرعي في مركز إسلامي معتمد '
        'يرعى المسلمين الجدد.',
    referGuidance: [
      'اكتب سؤالك مع تفاصيله كاملة قبل التواصل مع المختص.',
      'اذكر بلدك وظروفك؛ فالحكم قد يختلف باختلاف الأحوال.',
      'اطّلع على الأسئلة العامة ذات الصلة أدناه لفهم الأصل العام.',
    ],
    abstainReason:
        'لم أجد في المراجع المعتمدة لديّ ما يكفي للإجابة عن هذا السؤال بثقة، '
        'ولا أقدّم إجابة غير موثقة.',
    abstainGuidance: [
      'جرّب إعادة صياغة السؤال، أو اختيار تصنيف قريب منه.',
      'اطّلع على الأسئلة القريبة المقترحة إن وُجدت.',
      'اسأل أهل العلم الموثوقين عن هذه المسألة.',
    ],
    hadithReason:
        'لم أجد حديثاً صحيحاً مطابقاً لطلبك في المصادر المتاحة لديّ، ولا أنسب إلى '
        'النبي ﷺ كلاماً دون مصدر موثق وحكم معتمد.',
    hadithGuidance: [
      'ابحث في الموسوعة الحديثية بمنصة الدرر السنية (dorar.net/hadith) مع مراجعة حكم الحديث.',
      'لا تنشر حديثاً قبل التأكد من صحته ومصدره.',
      'اسأل أهل الحديث المختصين عن الروايات التي لم تتأكد منها.',
    ],
    personalNote: 'إن كانت لسؤالك تفاصيل تخص حالتك بعينها، فاعرضها على مفتٍ مؤهل.',
    offTopicReason:
        'بصيرة مخصّصة للأسئلة عن الإسلام فقط: العقيدة، والعبادات، والأحكام، '
        'والقرآن والسنة، وحياة المسلم. هذا السؤال خارج هذا النطاق، لذلك لا أجيب عنه.',
    offTopicGuidance: [
      'اسأل مثلاً: هل يجب أن أغيّر اسمي بعد الإسلام؟',
      'أو: هل يمكنني زيارة عائلتي غير المسلمة؟',
      'وإن كان سؤالك عن حكم شيء في الإسلام فاذكر ذلك صراحة، مثل: «هل … حلال؟».',
    ],
    khilafFallback: 'هذه مسألة اختلف فيها العلماء المعتبرون، ولا أرجّح فيها قولاً.',
  );

  static const en = RouterTexts._(
    referReason:
        'Your question is about a personal situation. A ruling on it needs a qualified '
        'mufti who hears all the details. Basirah only gives general, documented '
        'information and does not issue personal fatwas.',
    referTo:
        'A qualified mufti or an official fatwa body in your country, or a Sharia '
        'specialist at a recognised Islamic centre that cares for new Muslims.',
    referGuidance: [
      'Write down your question with all its details before contacting the specialist.',
      'Mention your country and circumstances; the answer can differ with the situation.',
      'Read the related general questions below to understand the general principle.',
    ],
    abstainReason:
        'I did not find enough in the approved references to answer this question with '
        'confidence, and I do not give undocumented answers.',
    abstainGuidance: [
      'Try rephrasing the question, or choose a related category.',
      'Look at the suggested related questions, if any.',
      'Ask trusted people of knowledge about this matter.',
    ],
    hadithReason:
        'I did not find an authentic hadith matching your request in the sources '
        'available to me, and I never attribute words to the Prophet ﷺ without a '
        'documented source and an approved grading.',
    hadithGuidance: [
      'Search the hadith encyclopedia on Dorar.net (dorar.net/hadith) and check the grading.',
      'Do not share a hadith before confirming its authenticity and source.',
      'Ask hadith specialists about narrations you are unsure of.',
    ],
    personalNote: 'If your question involves details of your own situation, ask a qualified mufti.',
    offTopicReason:
        'Basirah only answers questions about Islam: belief, worship, rulings, the '
        'Quran and Sunnah, and Muslim life. This question is outside that scope, so I '
        'will not answer it.',
    offTopicGuidance: [
      'Try, for example: "Do I have to change my name after becoming Muslim?"',
      'Or: "Can I visit my non-Muslim family?"',
      'If you are asking whether something is allowed in Islam, say so, e.g. "Is … halal?"',
    ],
    khilafFallback:
        'Recognised scholars differ on this matter, and I do not choose between their views.',
  );
}

/// Result of routing a question without a language model.
class RouteResult {
  const RouteResult({
    required this.answer,
    required this.hits,
    required this.signals,
    required this.strong,
    this.offTopic = false,
  });

  final BasirahAnswer answer;
  final List<RetrievalHit> hits;
  final SafetySignals signals;

  /// True when a curated entry answers the question directly.
  final bool strong;

  /// True when the question is clearly not about Islam.
  final bool offTopic;
}

/// Deterministic question router. Implements the reference pack's response
/// rules without a model: curated answer when the question is covered,
/// referral for personal cases, a polite refusal for non-Islamic questions,
/// and abstention otherwise — never a guess.
///
/// Build it on a [KnowledgeBase.localized] base to get answers in that
/// language.
class OfflineRouter {
  OfflineRouter(this.kb) : retriever = Retriever(kb);

  final KnowledgeBase kb;
  final Retriever retriever;

  RouterTexts get texts => RouterTexts.of(kb.lang);

  /// [previousQuestion]: the question before this one in a conversation, so a
  /// follow-up such as «وماذا عن أمي؟» is judged in context, not declined as
  /// off-topic on its own.
  RouteResult route(String question, {String? categoryId, String? previousQuestion}) {
    final t = texts;
    final signals = SafetySignals.detect(question);
    final hits = retriever.search(question, categoryId: categoryId, limit: 6);
    final top = hits.isEmpty ? null : hits.first;
    List<String> relatedExcept(String? id) => [
      for (final h in hits)
        if (h.entry.id != id && h.score >= Retriever.relatedThreshold) h.entry.id,
    ].take(3).toList();

    // 1. The question is covered by a curated entry.
    if (top != null && Retriever.isStrong(hits)) {
      final entry = top.entry;
      final extra = signals.personalCase && entry.kind == AnswerKind.answer
          ? [t.personalNote]
          : const <String>[];
      return RouteResult(
        answer: BasirahAnswer.fromEntry(
          entry,
          kb,
          question: question,
          related: relatedExcept(entry.id),
          extraGuidance: extra,
        ),
        hits: hits,
        signals: signals,
        strong: true,
      );
    }

    // 2. A request to translate/explain an approved glossary term.
    final term = glossaryMatch(question);
    if (term != null && (signals.translationRequest || tokenize(question).length <= 6)) {
      return RouteResult(
        answer: glossaryAnswer(question, term),
        hits: hits,
        signals: signals,
        strong: false,
      );
    }

    // 3. Clearly not about Islam: decline politely, cite nothing.
    final scopeText = previousQuestion == null ? question : '$previousQuestion $question';
    final contextScore = previousQuestion == null
        ? (top?.score ?? 0)
        : [top?.score ?? 0, ...retriever.search(scopeText, limit: 1).map((h) => h.score)].reduce((a, b) => a > b ? a : b);
    if (ScopeCheck.clearlyOffTopic(scopeText, bestCuratedScore: contextScore)) {
      return RouteResult(
        answer: offTopicAnswer(question),
        hits: hits,
        signals: signals,
        strong: false,
        offTopic: true,
      );
    }

    // 4. Asked to produce a hadith we do not hold: refuse to fabricate.
    // No reliable answer → no evidence card: a verse or hadith next to a
    // refusal would look like support for an answer that was not given.
    if (signals.hadithRequest) {
      return RouteResult(
        answer: BasirahAnswer(
          question: question,
          kind: AnswerKind.abstain,
          level: ContentLevel.a,
          origin: AnswerOrigin.offline,
          abstainReason: t.hadithReason,
          guidance: t.hadithGuidance,
          related: relatedExcept(null),
          review: 'generated',
        ),
        hits: hits,
        signals: signals,
        strong: false,
      );
    }

    // 5. A personal case / fatwa request: general info + referral.
    if (signals.personalCase) {
      return RouteResult(
        answer: BasirahAnswer(
          question: question,
          kind: AnswerKind.refer,
          level: ContentLevel.d,
          origin: AnswerOrigin.offline,
          referReason: t.referReason,
          referTo: t.referTo,
          guidance: t.referGuidance,
          related: relatedExcept(null),
          review: 'generated',
        ),
        hits: hits,
        signals: signals,
        strong: false,
      );
    }

    // 6. Not covered: abstain rather than guess.
    return RouteResult(
      answer: BasirahAnswer(
        question: question,
        kind: AnswerKind.abstain,
        level: ContentLevel.b,
        origin: AnswerOrigin.offline,
        abstainReason: t.abstainReason,
        guidance: t.abstainGuidance,
        related: relatedExcept(null),
        review: 'generated',
      ),
      hits: hits,
      signals: signals,
      strong: false,
    );
  }

  BasirahAnswer offTopicAnswer(String question, {AnswerOrigin origin = AnswerOrigin.offline}) =>
      BasirahAnswer(
        question: question,
        kind: AnswerKind.offTopic,
        level: ContentLevel.b,
        origin: origin,
        abstainReason: texts.offTopicReason,
        guidance: texts.offTopicGuidance,
        review: 'generated',
      );

  /// Finds an approved glossary term mentioned in the question.
  GlossaryTerm? glossaryMatch(String question) {
    final q = ' ${normalizeArabic(question)} ';
    for (final g in kb.glossary) {
      for (final key in [g.term, g.english, ...g.keys]) {
        final k = normalizeArabic(key);
        if (k.isNotEmpty && q.contains(' $k ')) return g;
      }
    }
    return null;
  }

  BasirahAnswer glossaryAnswer(String question, GlossaryTerm term) {
    final en = kb.lang == 'en';
    return BasirahAnswer(
      question: question,
      kind: AnswerKind.answer,
      level: ContentLevel.a,
      origin: AnswerOrigin.offline,
      principle: en
          ? 'The approved English equivalent of «${term.term}» is: ${term.english}.'
          : 'المقابل المعتمد لمصطلح «${term.term}» في الإنجليزية: ${term.english}.',
      culture: en ? 'Usage rule: ${term.rule}' : 'ضابط الاستخدام: ${term.rule}',
      guidance: en
          ? const [
              'When translating, keep the Islamic term as it is and explain its meaning the first time you use it.',
              'Avoid literal translations that narrow or change the meaning.',
            ]
          : const [
              'عند الترجمة أبقِ المصطلح الشرعي كما هو، واشرح معناه عند أول ذكر له.',
              'تجنّب الترجمة الحرفية التي قد تُضيّق المعنى أو تغيّره.',
            ],
      sourceNote: en
          ? 'Glossary of core terms — the approved reference, and the al-Jamhara encyclopedia of Islamic-content terms (islamic-content.com/dictionary).'
          : 'قاموس المصطلحات الأساسية — المرجعية المعتمدة، وموسوعة الجمهرة لمفردات المحتوى الإسلامي (islamic-content.com/dictionary).',
      review: 'generated',
    );
  }
}
