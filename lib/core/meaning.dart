import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A language with an approved translation of the meanings that has a
/// recorded voice on موسوعة القرآن الكريم (the server's
/// `meaningLanguages`, same order): (QuranEnc key, ISO code, native name,
/// Arabic name, right-to-left).
const meaningLanguages = [
  ('english_rwwad', 'en', 'English', 'الإنجليزية', false),
  ('tagalog_rwwad', 'tl', 'Filipino (Tagalog)', 'الفلبينية (التاغالوغية)', false),
  ('french_rashid', 'fr', 'Français', 'الفرنسية', false),
  ('chinese_suliman', 'zh', '中文', 'الصينية', false),
  ('vietnamese_rwwad', 'vi', 'Tiếng Việt', 'الفيتنامية', false),
  ('sinhalese_mahir', 'si', 'සිංහල', 'السنهالية', false),
  ('tamil_omar_brief', 'ta', 'தமிழ்', 'التاميلية', false),
  ('somali_yacob', 'so', 'Soomaali', 'الصومالية', false),
  ('persian_ih', 'fa', 'فارسی', 'الفارسية', true),
  ('portuguese_nasr', 'pt', 'Português', 'البرتغالية', false),
  ('dutch_center', 'nl', 'Nederlands', 'الهولندية', false),
  ('azeri_musayev', 'az', 'Azərbaycan', 'الأذرية', false),
  ('assamese_rafeeq', 'as', 'অসমীয়া', 'الأسامية', false),
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
