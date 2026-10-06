import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'meaning.dart';
import 'ui_strings.dart';

/// The interface languages: Arabic, and every language with an approved
/// translation of the meanings on موسوعة القرآن الكريم (the same 25, in the
/// same order): (ISO code, native name, right-to-left).
final uiLanguages = <(String, String, bool)>[
  ('ar', 'العربية', true),
  for (final (_, iso, native, _, rtl, _) in meaningLanguages) (iso, native, rtl),
];

bool isUiLanguage(String code) => uiLanguages.any((l) => l.$1 == code);

bool isRtlLanguage(String code) => uiLanguages.any((l) => l.$1 == code && l.$3);

/// The app's name in the interface language's own script: «Basirah» in the
/// Latin-script languages, the Arabic name in the Arabic-script ones, and a
/// transliteration of «بصيرة» in the others.
String appNameFor(String ui) => switch (ui) {
  'ar' => 'بصيرة',
  'ur' => 'بصیرہ',
  'fa' || 'ps' => 'بصیره',
  'hi' => 'बसीरा',
  'si' => 'බසීරා',
  'ta' => 'பஸீரா',
  'as' => 'বাছিৰা',
  'zh' => '巴希拉',
  'ja' => 'バシーラ',
  _ => 'Basirah',
};

/// The language of the content the interface shows (the reviewed answers,
/// the categories' questions): Arabic in the Arabic interface, English in
/// every other one.
String contentLang(String ui) => ui == 'ar' ? 'ar' : 'en';

/// Interface language: 'ar' (default), 'en', or another of [uiLanguages].
/// Remembered on the device.
class LangNotifier extends Notifier<String> {
  static const _key = 'basirah.lang.v1';

  @override
  String build() {
    // A link can choose the language, e.g. https://…/?lang=fr (demos, sharing).
    final fromLink = Uri.base.queryParameters['lang'];
    if (fromLink != null && isUiLanguage(fromLink)) {
      set(fromLink);
    } else {
      _load();
    }
    UiStrings.current = 'ar';
    UiStrings.name = appNameFor('ar');
    return 'ar';
  }

  Future<void> _save(String lang) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, lang);
    } on Exception {
      // Non-critical.
    }
  }

  Future<void> _load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      if (saved != null && saved != 'ar' && isUiLanguage(saved)) await set(saved, save: false);
    } on Exception {
      // Storage unavailable: keep the default.
    }
  }

  /// Shows the interface in [lang] once its strings are loaded.
  Future<void> set(String lang, {bool save = true}) async {
    if (!isUiLanguage(lang)) return;
    await UiStrings.ensure(lang);
    UiStrings.current = lang;
    UiStrings.name = appNameFor(lang);
    state = lang;
    if (save) await _save(lang);
  }

  Future<void> toggle() => set(state == 'ar' ? 'en' : 'ar');
}

final langProvider = NotifierProvider<LangNotifier, String>(LangNotifier.new);

/// The interface language for the widgets below it (placed by the app).
class UiLangScope extends InheritedWidget {
  const UiLangScope({super.key, required this.lang, required super.child});

  final String lang;

  @override
  bool updateShouldNotify(UiLangScope oldWidget) => oldWidget.lang != lang;
}

/// Direction of a piece of text from its letters: Latin text reads
/// left-to-right, Arabic right-to-left — e.g. an English answer shown in the
/// Arabic interface, or an Arabic verse inside an English answer.
TextDirection textDirectionOf(String text) {
  var arabic = 0;
  var latin = 0;
  for (final r in text.runes) {
    if ((r >= 0x0600 && r <= 0x06FF) || (r >= 0xFB50 && r <= 0xFDFF) || (r >= 0xFE70 && r <= 0xFEFF)) {
      arabic++;
    } else if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A) || (r >= 0xC0 && r <= 0x24F)) {
      latin++;
    }
  }
  return latin > arabic ? TextDirection.ltr : TextDirection.rtl;
}

extension Tr on BuildContext {
  /// The interface language: 'ar', 'en', or another of [uiLanguages].
  String get uiLang {
    final scope = dependOnInheritedWidgetOfExactType<UiLangScope>();
    if (scope != null) return scope.lang;
    return Localizations.maybeLocaleOf(this)?.languageCode == 'en' ? 'en' : 'ar';
  }

  /// The content language: 'ar' in the Arabic interface, 'en' otherwise.
  String get lang => contentLang(uiLang);
  bool get isEn => lang == 'en';

  /// The string for the interface language: the Arabic, the English, or the
  /// English one's translation.
  String tr(String ar, String en) => uiLang == 'ar' ? ar : UiStrings.fromEnglish(en);
}
