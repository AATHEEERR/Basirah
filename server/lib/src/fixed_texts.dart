import 'package:basirah_core/basirah_core.dart';

import 'fixed_texts_i18n.dart';

/// [a] with the guard's fixed English texts (RouterTexts.en: the default
/// abstention, referral, hadith and off-topic texts) in [iso], for a question
/// in a language other than Arabic and English. A text the model wrote is
/// never touched: only an exact fixed text is replaced, and only when
/// [fixedTexts] has the language.
BasirahAnswer localizeFixedTexts(BasirahAnswer a, String iso) {
  final t = fixedTexts[iso];
  if (t == null) return a;
  final en = RouterTexts.en;
  String one(String text, Map<String, String> fixed) {
    for (final MapEntry(:key, :value) in fixed.entries) {
      if (text == value) return t[key]! as String;
    }
    return text;
  }

  List<String> many(List<String> list) {
    for (final (key, value) in [
      ('referGuidance', en.referGuidance),
      ('abstainGuidance', en.abstainGuidance),
      ('hadithGuidance', en.hadithGuidance),
      ('offTopicGuidance', en.offTopicGuidance),
    ]) {
      if (list.length == value.length && List.generate(list.length, (i) => list[i] == value[i]).every((x) => x)) {
        return (t[key]! as List).cast<String>();
      }
    }
    // A personal-case note added to a curated answer's guidance.
    return [for (final s in list) s == en.personalNote ? t['personalNote']! as String : s];
  }

  return a.copyWith(
    referReason: one(a.referReason, {'referReason': en.referReason}),
    referTo: one(a.referTo, {'referTo': en.referTo}),
    abstainReason: one(a.abstainReason, {
      'abstainReason': en.abstainReason,
      'hadithReason': en.hadithReason,
      'offTopicReason': en.offTopicReason,
    }),
    khilafNote: one(a.khilafNote, {'khilafFallback': en.khilafFallback}),
    guidance: many(a.guidance),
  );
}
