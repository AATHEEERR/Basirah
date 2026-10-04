/// Lightweight Arabic text processing for retrieval: normalisation,
/// tokenisation, stop-word removal, light stemming, and a small
/// English→Arabic bridge so English questions can reach the Arabic corpus.
library;

bool _isDiacritic(int c) =>
    (c >= 0x0610 && c <= 0x061A) ||
    (c >= 0x064B && c <= 0x065F) ||
    c == 0x0670 ||
    (c >= 0x06D6 && c <= 0x06ED) ||
    c == 0x0640;

bool _isWordChar(int c) =>
    (c >= 0x30 && c <= 0x39) || // 0-9
    (c >= 0x61 && c <= 0x7A) || // a-z (input is lower-cased)
    (c >= 0xC0 && c <= 0x024F && c != 0xD7 && c != 0xF7) || // Latin letters
    (c >= 0x0620 && c <= 0x064A) || // Arabic letters
    (c >= 0x0660 && c <= 0x0669) || // Arabic-Indic digits
    (c >= 0x066E && c <= 0x06D3) || // extended Arabic letters
    (c >= 0x06F0 && c <= 0x06FF);

/// Normalises Arabic spelling variants so that «إسلامٌ» and «اسلام» compare
/// equal: strips diacritics and tatweel, unifies alef/ya/ta-marbuta forms,
/// drops hamza-on-line and punctuation, lower-cases Latin text.
/// Single pass over code units (a Unicode-property regex was ~2 ms/verse).
String normalizeArabic(String input) {
  final out = <int>[];
  var pendingSpace = false;
  for (final raw in input.toLowerCase().codeUnits) {
    if (_isDiacritic(raw)) continue;
    final c = switch (raw) {
      0x0622 || 0x0623 || 0x0625 || 0x0671 => 0x0627, // آ أ إ ٱ → ا
      0x0649 => 0x064A, // ى → ي
      0x0629 => 0x0647, // ة → ه
      0x0624 => 0x0648, // ؤ → و
      0x0626 => 0x064A, // ئ → ي
      _ => raw,
    };
    if (c == 0x0621 || c == 0x27 || c == 0x2019 || c == 0x2018) continue; // ء, apostrophes
    if (_isWordChar(c)) {
      if (pendingSpace && out.isNotEmpty) out.add(0x20);
      pendingSpace = false;
      out.add(c);
    } else {
      pendingSpace = true;
    }
  }
  return String.fromCharCodes(out);
}

final _arabicLetter = RegExp('[ء-ي]');
final _latinLetter = RegExp('[A-Za-z]');

/// True when the question is written mostly in Arabic script. Curated
/// entries are Arabic; other languages are answered by the model instead.
bool isMostlyArabic(String input) {
  final ar = _arabicLetter.allMatches(input).length;
  final la = _latinLetter.allMatches(input).length;
  return ar >= la;
}

/// Words that carry no topical meaning for matching (normalised spellings).
const Set<String> stopWords = {
  // Arabic particles and pronouns
  'من', 'في', 'على', 'علي', 'الى', 'عن', 'ما', 'ماذا', 'هل', 'ان', 'او', 'ثم',
  'لا', 'لم', 'لن', 'قد', 'كل', 'هذا', 'هذه', 'ذلك', 'تلك', 'التي', 'الذي',
  'الذين', 'انا', 'انت', 'انتم', 'هو', 'هي', 'نحن', 'هم', 'لي', 'لك', 'له',
  'لها', 'لنا', 'يا', 'مع', 'عند', 'بعد', 'قبل', 'كيف', 'لماذا', 'متي', 'اين',
  'اي', 'و', 'ب', 'ل', 'ك', 'ف', 'به', 'بها', 'فيه', 'فيها', 'عليه', 'عليها',
  'منه', 'منها', 'ايضا', 'جدا', 'كان', 'كانت', 'يكون', 'تكون', 'اكون', 'لكي',
  'كي', 'حتي', 'اذا', 'لو', 'بين', 'غير', 'بل', 'لكن', 'ام', 'وهو', 'وهي',
  'وانا', 'اني', 'انني', 'انه', 'انها', 'الا', 'اما', 'مثل', 'هناك', 'هنا',
  'لاكون', 'ليكون', 'وان', 'فان', 'بان', 'لان', 'اذ', 'كما', 'وقد', 'فقد',
  // Generic question verbs that appear in almost every question
  'يجب', 'يجوز', 'يمكن', 'يمكنني', 'ينبغي', 'حكم', 'ممكن', 'اريد', 'اعرف',
  'سوال', 'اسال', 'عندي', 'شي', 'اشياء', 'مثلا', 'فعلا', 'هنالك', 'يعني',
  'ارجو', 'افيدوني', 'السلام', 'عليكم', 'سمحت', 'يلزمني', 'علينا', 'عليا',
  'معني', 'كلمه', 'اخبرني', 'اشرح', 'وضح', 'استطيع', 'يستطيع', 'اقدر', 'ابغي',
  'وهم', 'فهل', 'زال', 'زلت', 'يقول', 'الي',
  // English
  'the', 'a', 'an', 'is', 'are', 'am', 'i', 'my', 'me', 'to', 'of', 'in',
  'on', 'for', 'and', 'or', 'can', 'should', 'do', 'does', 'did', 'it', 'be',
  'with', 'what', 'why', 'how', 'if', 'still', 'after', 'at', 'as', 'this',
  'that', 'islam', 'islamic', 'you', 'your', 'about', 'have', 'has', 'will',
  'from', 'by', 'there', 'their', 'they', 'we', 'us', 'need', 'must', 'really',
  'was', 'were', 'so', 'any', 'all', 'just', 'when', 'who', 'which', 'allowed',
  'mean', 'means', 'meaning', 'not', 'into', 'than', 'only', 'people',
};

/// Minimal English→Arabic bridge. Values are natural Arabic words; they go
/// through the same normaliser and stemmer as the corpus.
const Map<String, List<String>> englishBridge = {
  'name': ['اسم'],
  'names': ['اسم'],
  'surname': ['اسم', 'عائلة'],
  'father': ['أبي'],
  'fathers': ['أبي'],
  'family': ['عائلة', 'أهل', 'أسرة'],
  'parents': ['والدين', 'أهل'],
  'mother': ['أمي'],
  'visit': ['زيارة'],
  'relatives': ['أقارب', 'أهل'],
  'tell': ['أخبر'],
  'celebrate': ['أعياد'],
  'christmas': ['أعياد', 'عيد'],
  'holiday': ['أعياد', 'عيد'],
  'holidays': ['أعياد', 'عيد'],
  'husband': ['زوجي'],
  'wife': ['زوجتي'],
  'spouse': ['زوجي'],
  'married': ['زواج'],
  'marriage': ['زواج'],
  'arabic': ['العربية', 'عربي'],
  'language': ['اللغة'],
  'clothes': ['لباس', 'ملابس'],
  'clothing': ['لباس', 'ملابس'],
  'dress': ['لباس'],
  'wear': ['لبس'],
  'pray': ['الصلاة'],
  'prayer': ['الصلاة'],
  'prayers': ['الصلاة'],
  'salah': ['الصلاة'],
  'ghusl': ['الاغتسال', 'غسل'],
  'shower': ['الاغتسال', 'غسل'],
  'bath': ['الاغتسال'],
  'convert': ['دخول', 'أسلم'],
  'converting': ['دخول', 'أسلم'],
  'converted': ['أسلم'],
  'revert': ['أسلم'],
  'muslim': ['مسلم'],
  'muslims': ['المسلمون'],
  'become': ['دخول'],
  'witnesses': ['شهود'],
  'certificate': ['شهادة'],
  'shahada': ['الشهادتين'],
  'tawhid': ['التوحيد'],
  'tawheed': ['التوحيد'],
  'monotheism': ['التوحيد'],
  'oneness': ['التوحيد'],
  'quran': ['القرآن'],
  'koran': ['القرآن'],
  'written': ['تأليف'],
  'author': ['تأليف'],
  'wrote': ['تأليف'],
  'muhammad': ['محمد'],
  'sins': ['ذنوبي'],
  'forgiven': ['تغفر'],
  'past': ['ماضي'],
  'job': ['عملي', 'وظيفتي'],
  'work': ['عملي'],
  'haram': ['حرام'],
  'hijab': ['الحجاب'],
  'veil': ['الحجاب'],
  'niqab': ['النقاب'],
  'face': ['الوجه'],
  'cover': ['تغطية'],
  'circumcision': ['الختان'],
  'circumcised': ['الختان'],
  'scholars': ['العلماء'],
  'disagree': ['اختلاف'],
  'differ': ['اختلاف'],
  'different': ['مختلفة'],
  'agree': ['يتفق'],
  'fatwa': ['الفتوى'],
  'mufti': ['مفتي'],
  'kaaba': ['الكعبة'],
  'mecca': ['الكعبة', 'القبلة'],
  'qibla': ['القبلة'],
  'worship': ['يعبدون', 'عبادة'],
  'sword': ['السيف'],
  'force': ['إكراه'],
  'forced': ['إكراه'],
  'spread': ['انتشر'],
  'violence': ['عنف'],
  'alcohol': ['الخمر'],
  'wine': ['الخمر'],
  'drinking': ['الخمر'],
  'beer': ['الخمر'],
  'forbidden': ['يحرم', 'تحريم'],
  'forbid': ['يحرم', 'تحريم'],
  'gradual': ['التدرج'],
  'learn': ['تعلم'],
};

const _prefixes = ['وال', 'بال', 'فال', 'كال', 'لل', 'ال'];
const _suffixes = [
  'هما', 'كما', 'ات', 'ون', 'ين', 'ها', 'هم', 'كم', 'نا', 'ا', 'ي', 'ه',
];

/// Light stemmer: strips the most common clitic prefixes and suffixes while
/// leaving at least three letters. Applied identically to queries and corpus.
String lightStem(String word) {
  var w = word;
  if (w.length > 4) {
    for (final p in _prefixes) {
      if (w.startsWith(p) && w.length - p.length >= 3) {
        w = w.substring(p.length);
        break;
      }
    }
  }
  var strippedSuffix = false;
  for (var pass = 0; pass < 2; pass++) {
    var changed = false;
    for (final s in _suffixes) {
      if (w.endsWith(s) && w.length - s.length >= 3) {
        w = w.substring(0, w.length - s.length);
        changed = strippedSuffix = true;
        break;
      }
    }
    if (!changed) break;
  }
  // «صلاتي» → «صلات» → «صلا», meeting «الصلاة» → «صلاه» → «صلا».
  if (strippedSuffix && w.length >= 4 && w.endsWith('ت')) {
    w = w.substring(0, w.length - 1);
  }
  return w;
}

/// Normalised, stop-word-free, stemmed tokens. English words are bridged to
/// Arabic stems (and kept as-is, so Latin glossary keys still match).
List<String> tokenize(String input) {
  final out = <String>[];
  for (final raw in normalizeArabic(input).split(' ')) {
    if (raw.isEmpty || stopWords.contains(raw)) continue;
    final bridged = englishBridge[raw];
    if (bridged != null) {
      for (final ar in bridged) {
        for (final part in normalizeArabic(ar).split(' ')) {
          out.add(lightStem(part));
        }
      }
      out.add(raw);
      continue;
    }
    if (raw.length < 2) continue;
    out.add(lightStem(raw));
  }
  return out;
}

/// Word-internal character 4-grams of the normalised text (words of three
/// letters are kept whole). Robust to Arabic clitics: «بإحسانكم» and
/// «الإحسان» share «حسان».
List<String> charGrams(String input) {
  final out = <String>[];
  for (final w in normalizeArabic(input).split(' ')) {
    if (w.length < 3 || stopWords.contains(w)) continue;
    if (w.length == 3) {
      out.add(w);
      continue;
    }
    for (var i = 0; i + 4 <= w.length; i++) {
      out.add(w.substring(i, i + 4));
    }
  }
  return out;
}

/// Character trigrams of the normalised text (spaces kept as boundaries).
Set<String> trigrams(String input) {
  final t = ' ${normalizeArabic(input)} ';
  final grams = <String>{};
  for (var i = 0; i + 3 <= t.length; i++) {
    grams.add(t.substring(i, i + 3));
  }
  return grams;
}

/// Sørensen–Dice similarity of two trigram sets (0–1).
double dice(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final inter = a.intersection(b).length;
  return 2 * inter / (a.length + b.length);
}
