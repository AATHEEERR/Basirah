import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A language with an approved translation of the meanings on موسوعة القرآن
/// الكريم (the server's `meaningLanguages`, same order): (QuranEnc key, ISO
/// code, native name, Arabic name, right-to-left, recorded voice). The last
/// 12 have the text only.
const meaningLanguages = [
  ('english_rwwad', 'en', 'English', 'الإنجليزية', false, true),
  ('tagalog_rwwad', 'tl', 'Filipino (Tagalog)', 'الفلبينية (التاغالوغية)', false, true),
  ('french_rashid', 'fr', 'Français', 'الفرنسية', false, true),
  ('chinese_suliman', 'zh', '中文', 'الصينية', false, true),
  ('vietnamese_rwwad', 'vi', 'Tiếng Việt', 'الفيتنامية', false, true),
  ('sinhalese_mahir', 'si', 'සිංහල', 'السنهالية', false, true),
  ('tamil_omar_brief', 'ta', 'தமிழ்', 'التاميلية', false, true),
  ('somali_yacob', 'so', 'Soomaali', 'الصومالية', false, true),
  ('persian_ih', 'fa', 'فارسی', 'الفارسية', true, true),
  ('portuguese_nasr', 'pt', 'Português', 'البرتغالية', false, true),
  ('dutch_center', 'nl', 'Nederlands', 'الهولندية', false, true),
  ('azeri_musayev', 'az', 'Azərbaycan', 'الأذرية', false, true),
  ('assamese_rafeeq', 'as', 'অসমীয়া', 'الأسامية', false, true),
  ('urdu_junagarhi', 'ur', 'اردو', 'الأردية', true, false),
  ('indonesian_complex', 'id', 'Bahasa Indonesia', 'الإندونيسية', false, false),
  ('turkish_rwwad', 'tr', 'Türkçe', 'التركية', false, false),
  ('spanish_garcia', 'es', 'Español', 'الإسبانية', false, false),
  ('german_bubenheim', 'de', 'Deutsch', 'الألمانية', false, false),
  ('hindi_omari', 'hi', 'हिन्दी', 'الهندية', false, false),
  ('swahili_rwwad', 'sw', 'Kiswahili', 'السواحيلية', false, false),
  ('hausa_gummi', 'ha', 'Hausa', 'الهوسا', false, false),
  ('bosnian_rwwad', 'bs', 'Bosanski', 'البوسنية', false, false),
  ('albanian_rwwad', 'sq', 'Shqip', 'الألبانية', false, false),
  ('pashto_rwwad', 'ps', 'پښتو', 'البشتو', true, false),
  ('japanese_saeedsato', 'ja', '日本語', 'اليابانية', false, false),
];

/// The language the asker hears the meaning in («اسمعها بلغتك»), kept on
/// this device only; null = recitation only.
class MeaningLangNotifier extends Notifier<String?> {
  static const _key = 'basirah.meaning.v1';

  @override
  String? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      if (saved != null && meaningLanguages.any((l) => l.$1 == saved)) state = saved;
    } on Exception {
      // Storage unavailable: no language.
    }
  }

  Future<void> set(String? key) async {
    state = key;
    try {
      final prefs = await SharedPreferences.getInstance();
      key == null ? await prefs.remove(_key) : await prefs.setString(_key, key);
    } on Exception {
      // Kept for this session only.
    }
  }
}

final meaningLangProvider = NotifierProvider<MeaningLangNotifier, String?>(MeaningLangNotifier.new);
