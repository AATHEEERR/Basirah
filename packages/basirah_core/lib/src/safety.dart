import 'arabic.dart';

/// Deterministic signals detected before any model is involved. They drive the
/// offline router directly and are passed to the model as hints.
class SafetySignals {
  const SafetySignals({
    required this.personalCase,
    required this.hadithRequest,
    required this.hostileTone,
    required this.translationRequest,
    required this.matched,
  });

  /// The question describes the asker's own situation and asks for a ruling
  /// on it (level D: marriage, divorce, inheritance, contracts, "in my case").
  final bool personalCase;

  /// The asker wants a hadith produced to support a claim.
  final bool hadithRequest;

  /// Hostile or mocking phrasing: answer calmly, do not mirror it.
  final bool hostileTone;

  /// The asker wants a term translated or explained.
  final bool translationRequest;

  /// Which markers fired (for logs and tests, never the question itself).
  final List<String> matched;

  static const _strongPersonal = [
    'زوجي', 'زوجتي', 'زوجها', 'زوجنا', 'زواجي', 'زواجنا', 'طلاق', 'طلقت',
    'طلقني', 'طليقي', 'ميراث', 'الميراث', 'ورثه', 'الورثه', 'حضانه', 'خلع',
    'عقد زواج', 'حالتي', 'وضعي', 'ظروفي', 'قضيتي', 'قرضي', 'my husband',
    'my wife', 'my spouse', 'my marriage', 'divorce', 'inheritance',
    'custody', 'my case', 'my situation', 'my loan', 'my contract',
  ];

  static const _weakPersonal = [
    'هل يجوز لي', 'هل يحل لي', 'هل علي', 'ماذا افعل', 'هل يصح لي',
    'can i', 'am i allowed', 'is it ok for me', 'should i',
  ];

  static final _country = RegExp(
    r'(انا|اعيش|مقيم|اقيم)\s*(في|ب)\s*(دوله|بلد|بلاد)|in my country|i live in',
  );

  static const _hadithWords = ['حديث', 'حديثا', 'احاديث', 'hadith', 'hadeeth'];
  static const _produceWords = [
    'اعطني', 'اذكر', 'هات', 'ابغي', 'اريد', 'اعطيني', 'يثبت', 'يدل', 'give me',
    'quote', 'prove', 'proves', 'find me', 'show me',
  ];

  static const _hostile = [
    'متخلف', 'ارهاب', 'ارهابي', 'وحشي', 'سخيف', 'همجي', 'تافه', 'رجعي',
    'خرافه', 'backward', 'barbaric', 'terrorist', 'stupid', 'violent religion',
    'primitive', 'ridiculous',
  ];

  static const _translation = [
    'ترجم', 'ترجمه', 'بالانجليزي', 'بالانجليزيه', 'بالانجليزيه', 'translate',
    'translation', 'in english', 'meaning of', 'what does', 'معني كلمه',
    'معني مصطلح',
  ];

  static SafetySignals detect(String question) {
    final q = normalizeArabic(question);
    final matched = <String>[];
    bool any(List<String> words, String label) {
      for (final w in words) {
        if (_containsPhrase(q, w)) {
          matched.add('$label:$w');
          return true;
        }
      }
      return false;
    }

    final strong = any(_strongPersonal, 'personal');
    final weak = any(_weakPersonal, 'personal-weak');
    final country = _country.hasMatch(q);
    if (country) matched.add('personal:country');
    final hadith = any(_hadithWords, 'hadith') && any(_produceWords, 'produce');

    return SafetySignals(
      personalCase: strong || (country && weak),
      hadithRequest: hadith,
      hostileTone: any(_hostile, 'hostile'),
      translationRequest: any(_translation, 'translate'),
      matched: matched,
    );
  }

  Map<String, dynamic> toJson() => {
    'personalCase': personalCase,
    'hadithRequest': hadithRequest,
    'hostileTone': hostileTone,
    'translationRequest': translationRequest,
  };
}

/// Is a question about Islam at all?
///
/// Basirah answers questions about Islam — belief, worship, rulings, the
/// Quran and Sunnah, the Prophet ﷺ, Muslim life, and Islam's position on
/// anything (including other religions, or whether a food is halal). It
/// declines everything else: restaurants, sport, technology, general
/// knowledge, and another religion's doctrines for their own sake.
///
/// The lexical check below only decides the *clear* cases: no Islamic
/// vocabulary, no "is it allowed / what is the ruling" phrasing, and no
/// close curated question. Anything uncertain goes to the model, which has
/// its own `offTopic` kind.
abstract final class ScopeCheck {
  static const _islamicAr = [
    'الله', 'رب', 'اله', 'الاسلام', 'اسلام', 'اسلامي', 'مسلم', 'مسلمه', 'مسلمين', 'مسلمون',
    'اسلمت', 'اسلم', 'مهتدي', 'دين', 'ديني', 'الدين', 'ايمان', 'مومن', 'كفر', 'كافر',
    'شرك', 'توحيد', 'عقيده', 'قران', 'القران', 'ايه', 'ايات', 'سوره', 'تفسير', 'حديث',
    'احاديث', 'سنه', 'نبي', 'النبي', 'انبيا', 'رسول', 'الرسول', 'محمد', 'صحابه', 'صحابي',
    'سيره', 'ملايكه', 'جبريل', 'جنه', 'الجنه', 'جهنم', 'القيامه', 'الاخره',
    'عرش', 'قدر', 'غيب', 'صلاه', 'صلاتي', 'اصلي', 'يصلي', 'الصلوات', 'وضو', 'وضوء',
    'غسل', 'اغتسال', 'طهاره', 'نجاسه', 'اذان', 'مسجد', 'امام', 'جمعه', 'صيام', 'صوم',
    'اصوم', 'رمضان', 'زكاه', 'صدقه', 'حج', 'عمره', 'كعبه', 'الكعبه', 'مكه', 'قبله',
    'دعا', 'دعاء', 'اذكار', 'استغفار', 'توبه', 'ذنب', 'ذنوب', 'معصيه', 'حلال', 'حرام',
    'مباح', 'مكروه', 'واجب', 'فرض', 'مستحب', 'بدعه', 'يجوز', 'جايز', 'حكم', 'فتوي',
    'مفتي', 'شيخ', 'علما', 'العلما', 'فقه', 'مذهب', 'مذاهب', 'شريعه', 'الشريعه', 'شرعي',
    'حجاب', 'نقاب', 'عوره', 'محرم', 'زواج', 'نكاح', 'طلاق', 'عده', 'ولي', 'مهر',
    'ميراث', 'خمر', 'خنزير', 'ربا', 'جهاد', 'شهاده', 'الشهادتين', 'عيد', 'الاضحي',
    'الفطر', 'ختان', 'عيسي', 'موسي', 'مريم', 'ابراهيم', 'نوح', 'ادم', 'يوسف', 'بسمله',
    'فاتحه', 'الفاتحه', 'ركعه', 'سجود', 'تشهد', 'تجويد', 'مصحف', 'اخلاق', 'بر',
  ];

  static const _islamicEn = [
    'allah', 'god', 'islam', 'islamic', 'muslim', 'muslims', 'quran', 'koran', 'quranic',
    'surah', 'ayah', 'verse', 'tafsir', 'hadith', 'sunnah', 'prophet', 'prophets',
    'muhammad', 'messenger', 'sahaba', 'companions', 'angel', 'angels', 'paradise',
    'heaven', 'hell', 'jannah', 'judgment', 'judgement', 'afterlife', 'pray', 'prayer',
    'prayers', 'salah', 'salat', 'wudu', 'ablution', 'ghusl', 'mosque', 'masjid', 'imam',
    'fast', 'fasting', 'ramadan', 'zakat', 'charity', 'hajj', 'umrah', 'kaaba', 'mecca',
    'makkah', 'medina', 'qibla', 'dua', 'dhikr', 'repent', 'repentance', 'sin', 'sins',
    'halal', 'haram', 'permissible', 'makruh', 'fard', 'bidah', 'fatwa', 'mufti', 'sheikh',
    'scholar', 'scholars', 'fiqh', 'madhhab', 'sharia', 'shariah', 'hijab', 'niqab',
    'awrah', 'mahram', 'nikah', 'marriage', 'divorce', 'talaq', 'iddah', 'inheritance',
    'alcohol', 'pork', 'riba', 'jihad', 'shahada', 'convert', 'converted', 'revert',
    'eid', 'circumcision', 'tawhid', 'tawheed', 'iman', 'faith', 'religion', 'jesus',
    'moses', 'mary', 'abraham', 'ibrahim', 'isa', 'musa', 'noah', 'adam', 'worship',
    'creed', 'aqeedah', 'bismillah', 'fatiha', 'quran',
  ];

  /// Phrasing that asks for a religious ruling or permission.
  static const _rulingAr = [
    'هل يجوز', 'هل يحل', 'ما حكم', 'هل يجب', 'هل علي', 'هل يصح', 'هل هو حرام',
    'هل هذا حرام', 'هل هذا حلال', 'يغضب الله', 'هل اثم',
  ];
  static const _rulingEn = [
    'is it allowed', 'am i allowed', 'can i', 'can a', 'is it ok', 'is it okay',
    'should i', 'must i', 'do i have to', 'is it permissible', 'is it a sin', 'ruling',
  ];

  static final Set<String> _stems = {
    for (final w in _islamicAr) lightStem(normalizeArabic(w)),
    for (final w in _islamicAr) normalizeArabic(w),
  };
  static final Set<String> _en = {..._islamicEn};

  /// True when the question contains Islamic vocabulary.
  static bool hasIslamicCue(String question) {
    final words = normalizeArabic(question).split(' ');
    for (final w in words) {
      if (w.isEmpty) continue;
      if (_en.contains(w)) return true;
      if (_stems.contains(w) || _stems.contains(lightStem(w))) return true;
      // Clitic-prefixed forms: «وبالصلاة», «للمسجد», «فالحج».
      for (final p in const ['وال', 'بال', 'فال', 'لل', 'ال', 'و', 'ب', 'ف', 'ل']) {
        if (w.startsWith(p) && w.length - p.length >= 2) {
          final rest = w.substring(p.length);
          if (_stems.contains(rest) || _stems.contains(lightStem(rest))) return true;
        }
      }
    }
    return false;
  }

  /// True when the question asks whether something is allowed / its ruling.
  static bool asksRuling(String question) {
    final q = normalizeArabic(question);
    return [..._rulingAr, ..._rulingEn].any((p) => q.contains(normalizeArabic(p)));
  }

  /// Another religion, named on its own.
  static const _otherReligion = [
    'هندوس', 'هندوسي', 'هندوسيه', 'بوذا', 'بوذي', 'بوذيه', 'مسيحي', 'مسيحيه', 'مسيحيين',
    'نصراني', 'نصاري', 'يهودي', 'يهود', 'يهوديه', 'كنيسه', 'معبد', 'انجيل', 'توراه',
    'سيخ', 'hindu', 'hindus', 'hinduism', 'buddha', 'buddhist', 'buddhists', 'buddhism',
    'christian', 'christians', 'christianity', 'jewish', 'jews', 'judaism', 'church',
    'bible', 'torah', 'temple', 'sikh', 'sikhism', 'karma', 'trinity',
  ];

  /// The asker's own life (family, friends, work): a new Muslim living with
  /// people of another faith — in scope even without Islamic vocabulary.
  static const _lifeContext = [
    'عايلتي', 'عايله', 'اهلي', 'اهل', 'امي', 'ابي', 'والدي', 'والدتي', 'والداي', 'زوجي',
    'زوجتي', 'اولادي', 'ابني', 'ابنتي', 'اخي', 'اختي', 'صديقي', 'صديقتي', 'اصدقايي',
    'جاري', 'جيراني', 'عملي', 'زميلي', 'زملايي', 'مديري', 'انا', 'نفسي', 'لي',
    'family', 'parents', 'mother', 'father', 'mom', 'mum', 'dad', 'husband', 'wife',
    'children', 'son', 'daughter', 'brother', 'sister', 'friend', 'friends', 'colleague',
    'colleagues', 'coworker', 'neighbour', 'neighbor', 'boss', 'my', 'me', 'i',
  ];

  static final Set<String> _otherSet = {for (final w in _otherReligion) normalizeArabic(w)};
  static final Set<String> _lifeSet = {for (final w in _lifeContext) normalizeArabic(w)};

  static bool _anyWord(String question, Set<String> set) {
    for (final w in normalizeArabic(question).split(' ')) {
      if (w.isEmpty) continue;
      if (set.contains(w)) return true;
      for (final p in const ['وال', 'بال', 'ال', 'و', 'ب', 'ل']) {
        if (w.startsWith(p) && set.contains(w.substring(p.length))) return true;
      }
    }
    return false;
  }

  /// Clearly not about Islam:
  /// * no Islamic vocabulary, no ruling phrasing and no close curated
  ///   question ([bestCuratedScore] from the retriever); or
  /// * about another religion on its own terms («ما هي أعياد الهندوس؟»),
  ///   with no Islamic vocabulary, no ruling phrasing and nothing about the
  ///   asker's own family, friends or work («هل أشارك عائلتي في أعيادهم؟»
  ///   stays in scope).
  static bool clearlyOffTopic(String question, {double bestCuratedScore = 0}) {
    if (hasIslamicCue(question) || asksRuling(question)) return false;
    if (bestCuratedScore < 0.3) return true;
    return _anyWord(question, _otherSet) && !_anyWord(question, _lifeSet);
  }
}

bool _containsPhrase(String normalized, String phrase) {
  final p = normalizeArabic(phrase);
  if (p.isEmpty) return false;
  if (!p.contains(' ')) {
    // Whole-word match, allowing common Arabic clitics before the word.
    return RegExp('(^|\\s)(و|ف|ب|ل|وب|ول|فب)?${RegExp.escape(p)}(\\s|\$)')
        .hasMatch(normalized);
  }
  return normalized.contains(p);
}
