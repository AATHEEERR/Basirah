import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A language whose approved translation of the meanings of the Quran has
/// a recorded human voice on موسوعة القرآن الكريم (QuranEnc), checked one by
/// one on 4 Oct 2026.
class MeaningLanguage {
  const MeaningLanguage(this.key, this.iso, this.native, this.ar);

  /// QuranEnc translation key.
  final String key;

  /// ISO code (also IslamHouse's path for the language).
  final String iso;
  final String native;
  final String ar;

  Map<String, dynamic> toJson() => {'key': key, 'iso': iso, 'native': native, 'ar': ar, 'islamhouse': 'https://islamhouse.com/$iso/main/'};
}

const meaningLanguages = [
  MeaningLanguage('english_rwwad', 'en', 'English', 'الإنجليزية'),
  MeaningLanguage('tagalog_rwwad', 'tl', 'Filipino (Tagalog)', 'الفلبينية (التاغالوغية)'),
  MeaningLanguage('french_rashid', 'fr', 'Français', 'الفرنسية'),
  MeaningLanguage('chinese_suliman', 'zh', '中文', 'الصينية'),
  MeaningLanguage('vietnamese_rwwad', 'vi', 'Tiếng Việt', 'الفيتنامية'),
  MeaningLanguage('sinhalese_mahir', 'si', 'සිංහල', 'السنهالية'),
  MeaningLanguage('tamil_omar_brief', 'ta', 'தமிழ்', 'التاميلية'),
  MeaningLanguage('somali_yacob', 'so', 'Soomaali', 'الصومالية'),
  MeaningLanguage('persian_ih', 'fa', 'فارسی', 'الفارسية'),
  MeaningLanguage('portuguese_nasr', 'pt', 'Português', 'البرتغالية'),
  MeaningLanguage('dutch_center', 'nl', 'Nederlands', 'الهولندية'),
  MeaningLanguage('azeri_musayev', 'az', 'Azərbaycan', 'الأذرية'),
  MeaningLanguage('assamese_rafeeq', 'as', 'অসমীয়া', 'الأسامية'),
];

/// One verse's approved translation in a language: its text from the
/// QuranEnc API, its recorded voice from QuranEnc's audio files.
class VerseMeaning {
  const VerseMeaning({required this.ayah, required this.text, required this.audio});

  final int ayah;
  final String text;
  final String audio;

  Map<String, dynamic> toJson() => {'ayah': ayah, 'text': text, 'audio': audio};
}

/// The approved translations of the meanings (موسوعة القرآن الكريم,
/// quranenc.com, a platform of the association), cached on disk.
class MeaningSource {
  MeaningSource({http.Client? client, this.cacheDir = 'cache/meaning'}) : _http = client ?? http.Client();

  final http.Client _http;
  final String cacheDir;
  final _titles = <String, String>{};

  static String audioUrl(String key, int surah, int ayah) =>
      'https://d.quranenc.com/data/audio/$key/${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3';

  /// [surah]:[ayah] in [lang], or null when it cannot be read.
  Future<VerseMeaning?> verse(int surah, int ayah, MeaningLanguage lang) async {
    final file = File('$cacheDir/${lang.key}/${surah}_$ayah.json');
    Map<String, dynamic>? j;
    if (file.existsSync()) {
      j = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } else {
      try {
        final res = await _http
            .get(Uri.parse('https://quranenc.com/api/v1/translation/aya/${lang.key}/$surah/$ayah'))
            .timeout(const Duration(seconds: 20));
        if (res.statusCode != 200) return null;
        final r = (jsonDecode(utf8.decode(res.bodyBytes)) as Map)['result'] as Map?;
        final text = r?['translation'] as String?;
        if (text == null || text.trim().isEmpty) return null;
        j = {'text': cleanMeaning(text, ayah)};
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(jsonEncode(j));
      } on Exception {
        return null;
      }
    }
    return VerseMeaning(ayah: ayah, text: j['text'] as String, audio: audioUrl(lang.key, surah, ayah));
  }

  /// The translation's title, e.g. «Filipino Translation (Tagalog) - Rowwad
  /// Translation Center», from QuranEnc's list (fetched once).
  Future<String?> title(MeaningLanguage lang) async {
    if (_titles.isEmpty) {
      try {
        final res = await _http.get(Uri.parse('https://quranenc.com/api/v1/translations/list')).timeout(const Duration(seconds: 20));
        if (res.statusCode == 200) {
          final list = (jsonDecode(utf8.decode(res.bodyBytes)) as Map)['translations'] as List? ?? const [];
          for (final t in list.cast<Map>()) {
            _titles[t['key'] as String] = t['title'] as String;
          }
        }
      } on Exception {
        // The title is optional.
      }
    }
    return _titles[lang.key];
  }
}

/// A translation as QuranEnc gives it, without the verse number some
/// translations start with («186. Markay…») and footnote markers («[1]»).
String cleanMeaning(String text, int ayah) =>
    text.trim().replaceFirst(RegExp('^\\(?$ayah\\)?[.\\-\\s]+'), '').replaceAll(RegExp(r'\[\d+\]'), '').trim();
