import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Interface language: 'ar' (default) or 'en'. Remembered on the device.
class LangNotifier extends Notifier<String> {
  static const _key = 'basirah.lang.v1';

  @override
  String build() {
    // A link can choose the language, e.g. https://…/?lang=en (demos, sharing).
    final fromLink = Uri.base.queryParameters['lang'];
    if (fromLink == 'ar' || fromLink == 'en') {
      _save(fromLink!);
      return fromLink;
    }
    _load();
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
      if (saved == 'en' || saved == 'ar') state = saved!;
    } on Exception {
      // Storage unavailable: keep the default.
    }
  }

  Future<void> set(String lang) async {
    if (lang != 'ar' && lang != 'en') return;
    state = lang;
    await _save(lang);
  }

  Future<void> toggle() => set(state == 'ar' ? 'en' : 'ar');
}

final langProvider = NotifierProvider<LangNotifier, String>(LangNotifier.new);

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
  /// Current interface language.
  String get lang => Localizations.localeOf(this).languageCode == 'en' ? 'en' : 'ar';
  bool get isEn => lang == 'en';

  /// Picks the Arabic or English string for the current interface language.
  String tr(String ar, String en) => isEn ? en : ar;
}
