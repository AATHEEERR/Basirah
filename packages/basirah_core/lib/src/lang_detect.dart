/// The language a question is written in, as an ISO 639-1 code: by its
/// script, the letters only one language of that script uses, and, for the
/// Latin script, common short words. Text in a language it cannot name
/// returns 'und' (undetermined): the answer is then written in whatever
/// language the question is in.
///
/// It decides the answer's language. Arabic and English keep the curated
/// knowledge base in their language; any other language is answered live in
/// that language, with the approved translations of the meanings when
/// QuranEnc has one.
String detectLanguage(String text) {
  var arabic = 0, latin = 0, cjkHan = 0, kana = 0, hangul = 0, devanagari = 0, bengali = 0, tamil = 0, sinhala = 0;
  var thai = 0, cyrillic = 0, ethiopic = 0;
  for (final r in text.runes) {
    if (r >= 0x0600 && r <= 0x06FF || r >= 0x0750 && r <= 0x077F || r >= 0xFB50 && r <= 0xFEFF) {
      arabic++;
    } else if (r >= 0x41 && r <= 0x5A || r >= 0x61 && r <= 0x7A || r >= 0xC0 && r <= 0x24F || r >= 0x1E00 && r <= 0x1EFF) {
      latin++;
    } else if (r >= 0x3040 && r <= 0x30FF) {
      kana++;
    } else if (r >= 0x4E00 && r <= 0x9FFF) {
      cjkHan++;
    } else if (r >= 0xAC00 && r <= 0xD7AF) {
      hangul++;
    } else if (r >= 0x0900 && r <= 0x097F) {
      devanagari++;
    } else if (r >= 0x0980 && r <= 0x09FF) {
      bengali++;
    } else if (r >= 0x0B80 && r <= 0x0BFF) {
      tamil++;
    } else if (r >= 0x0D80 && r <= 0x0DFF) {
      sinhala++;
    } else if (r >= 0x0E00 && r <= 0x0E7F) {
      thai++;
    } else if (r >= 0x0400 && r <= 0x04FF) {
      cyrillic++;
    } else if (r >= 0x1200 && r <= 0x137F) {
      ethiopic++;
    }
  }
  final scripts = {
    'arabic': arabic,
    'latin': latin,
    'ja': kana,
    'zh': cjkHan,
    'ko': hangul,
    'hi': devanagari,
    'bengali': bengali,
    'ta': tamil,
    'si': sinhala,
    'th': thai,
    'ru': cyrillic,
    'am': ethiopic,
  };
  final top = scripts.entries.reduce((a, b) => b.value > a.value ? b : a);
  if (top.value == 0) return 'und';
  switch (top.key) {
    case 'arabic':
      return _arabicScript(text);
    case 'latin':
      return _latinScript(text);
    case 'zh':
      // Japanese mixes kana with kanji.
      return kana > 0 ? 'ja' : 'zh';
    case 'bengali':
      // Assamese uses ৰ and ৱ, Bengali does not.
      return RegExp('[ৰৱ]').hasMatch(text) ? 'as' : 'bn';
    default:
      return top.key;
  }
}

/// Arabic, Persian, Urdu or Pashto, by the letters only they use.
String _arabicScript(String t) {
  if (RegExp('[ټډړښږځڅېۍ]').hasMatch(t)) return 'ps';
  if (RegExp('[ٹڈڑںےۓ]').hasMatch(t)) return 'ur';
  // Persian writes ی and ک where Arabic writes ي and ك, and uses پ چ ژ گ.
  final persian = RegExp('[پچژگکی]').allMatches(t).length;
  final arabicOnly = RegExp('[يكةى]').allMatches(t).length;
  if (persian >= 2 && persian > arabicOnly) return 'fa';
  return 'ar';
}

/// Common short words (and letters) of the Latin-script languages Basirah
/// has approved translations for.
const _latinWords = {
  'en': ['the', 'is', 'are', 'what', 'why', 'how', 'can', 'do', 'does', 'i', 'my', 'and', 'of', 'to', 'in', 'muslim', 'allowed'],
  'fr': ['le', 'la', 'les', 'est', 'pourquoi', 'que', 'qui', 'je', 'mon', 'ma', 'des', 'du', 'et', 'pour', 'une', 'un', 'dans', 'musulman', 'musulmans', 'peut', 'est-ce', 'il', 'elle', 'ils', 'ne', 'pas', 'au', 'aux', 'ce', 'cette', 'ces', 'sont', 'sur', 'avec', 'plus', 'vous', 'nous', 'mais', 'ou', 'été', 'être', 'comme', 'leur'],
  'es': ['el', 'los', 'las', 'es', 'por', 'qué', 'que', 'cómo', 'puedo', 'mi', 'y', 'de', 'una', 'un', 'en', 'musulmán', 'musulmanes', 'para', 'con', 'del', 'su', 'sus', 'pero', 'como', 'también', 'sobre', 'muy', 'más', 'porque', 'este', 'esta', 'al', 'lo'],
  'pt': ['o', 'os', 'as', 'é', 'por', 'que', 'porque', 'posso', 'meu', 'minha', 'e', 'de', 'uma', 'um', 'em', 'muçulmano', 'muçulmanos', 'não', 'para', 'com', 'do', 'dos', 'das', 'no', 'na', 'seu', 'sua', 'mas', 'também', 'são', 'muito', 'mais', 'ao', 'foi', 'isso'],
  'de': ['der', 'die', 'das', 'ist', 'warum', 'was', 'wie', 'ich', 'mein', 'meine', 'und', 'von', 'zu', 'ein', 'eine', 'muslim', 'muslime', 'darf', 'nicht'],
  'nl': ['de', 'het', 'een', 'is', 'waarom', 'wat', 'hoe', 'ik', 'mijn', 'en', 'van', 'te', 'moslim', 'moslims', 'mag', 'niet'],
  'tr': ['bir', 've', 'ne', 'neden', 'nasıl', 'mi', 'mı', 'mu', 'mü', 'ben', 'benim', 'için', 'müslüman', 'müslümanlar', 'bu', 'da', 'de', 'olan', 'olarak', 'ile', 'gibi', 'daha', 'çok', 'değil', 'her', 'kadar', 'sonra', 'ise', 'veya', 'ki'],
  'az': ['bir', 'və', 'nə', 'niyə', 'necə', 'mən', 'mənim', 'üçün', 'müsəlman', 'bu', 'da', 'də'],
  'id': ['apa', 'apakah', 'mengapa', 'kenapa', 'bagaimana', 'saya', 'yang', 'dan', 'di', 'ke', 'dari', 'boleh', 'muslim', 'tidak', 'untuk', 'itu', 'ini'],
  'tl': ['ang', 'ng', 'mga', 'bakit', 'ano', 'paano', 'ako', 'ko', 'sa', 'at', 'na', 'ba', 'muslim', 'hindi', 'pwede'],
  'sw': ['na', 'ya', 'wa', 'kwa', 'nini', 'kwa nini', 'je', 'mimi', 'yangu', 'ni', 'katika', 'muislamu', 'waislamu', 'si'],
  'so': ['waa', 'iyo', 'maxaa', 'maxay', 'sababta', 'sidee', 'aniga', 'ku', 'ka', 'la', 'u', 'waxa', 'waxaa', 'muslim', 'muslimiinta', 'muslimiintu', 'ma'],
  'ha': ['da', 'na', 'me', 'yaya', 'shin', 'ni', 'ina', 'a', 'musulmi', 'musulmai', 'ba', 'za', 'ya'],
  'bs': ['je', 'li', 'zašto', 'šta', 'kako', 'ja', 'moj', 'moja', 'i', 'u', 'na', 'musliman', 'muslimani', 'da', 'se', 'ne', 'su', 'od', 'za', 'koji', 'koja', 'što', 'sa', 'iz', 'ali', 'kao', 'nije'],
  'sq': ['është', 'pse', 'çfarë', 'si', 'unë', 'im', 'ime', 'dhe', 'në', 'të', 'një', 'mysliman', 'myslimanët', 'a', 'nuk'],
  'vi': ['là', 'tại', 'sao', 'gì', 'tôi', 'của', 'và', 'có', 'không', 'người', 'hồi', 'giáo'],
};

String _latinScript(String text) {
  final t = text.toLowerCase();
  // Letters only one language uses. (â ê ô also occur in French, Turkish
  // and Portuguese, and đ in Bosnian: they do not point to Vietnamese.)
  if (RegExp('[ơư]|[ạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹ]').hasMatch(t)) return 'vi';
  if (t.contains('ə')) return 'az';
  if (RegExp('[ıİğ]').hasMatch(t)) return 'tr';
  if (RegExp('[ñ¿¡]').hasMatch(t)) return 'es';
  if (RegExp('[ãõ]').hasMatch(t)) return 'pt';
  if (t.contains('ß')) return 'de';
  final words = t.split(RegExp(r"[^\p{L}'-]+", unicode: true)).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return 'und';
  var best = 'en';
  var bestScore = 0;
  for (final MapEntry(key: lang, value: list) in _latinWords.entries) {
    final set = list.toSet();
    final score = words.where(set.contains).length;
    if (score > bestScore) {
      best = lang;
      bestScore = score;
    }
  }
  return bestScore == 0 ? 'und' : best;
}

/// The language's name in English, for the model's instructions.
String languageName(String iso) => const {
  'ar': 'Arabic',
  'en': 'English',
  'fr': 'French',
  'es': 'Spanish',
  'pt': 'Portuguese',
  'de': 'German',
  'nl': 'Dutch',
  'tr': 'Turkish',
  'az': 'Azerbaijani',
  'id': 'Indonesian',
  'tl': 'Filipino (Tagalog)',
  'sw': 'Swahili',
  'so': 'Somali',
  'ha': 'Hausa',
  'bs': 'Bosnian',
  'sq': 'Albanian',
  'vi': 'Vietnamese',
  'fa': 'Persian',
  'ur': 'Urdu',
  'ps': 'Pashto',
  'zh': 'Chinese',
  'ja': 'Japanese',
  'ko': 'Korean',
  'hi': 'Hindi',
  'bn': 'Bengali',
  'as': 'Assamese',
  'ta': 'Tamil',
  'si': 'Sinhala',
  'th': 'Thai',
  'ru': 'Russian',
  'am': 'Amharic',
  'und': 'the language the question is written in',
}[iso] ??
    iso;
