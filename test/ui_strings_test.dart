import 'package:basirah/core/lang.dart';
import 'package:basirah/core/ui_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    UiStrings.debugSet('fr', {
      'Close': 'Fermer',
      '{0} questions': '{0} questions',
      '{0} of {1}': '{1} au total, dont {0}',
      'Basirah: {0}': 'Basirah : {0}',
      '{0}: {1}': 'NEVER USED',
      ' · text': ' · texte',
    });
    UiStrings.current = 'fr';
  });

  tearDown(() => UiStrings.current = 'ar');

  test('a whole string is found as it is', () {
    expect(UiStrings.fromEnglish('Close'), 'Fermer');
    expect(UiStrings.fromEnglish(' · text'), ' · texte');
  });

  test('a string with values is matched as a pattern, in the translation’s order', () {
    expect(UiStrings.fromEnglish('24 questions'), '24 questions');
    expect(UiStrings.fromEnglish('7 of 31'), '31 au total, dont 7');
    // The value can itself be a translated string.
    expect(UiStrings.fromEnglish('Basirah: Réponse documentée'), 'Basirah : Réponse documentée');
  });

  test('a pattern with no words of its own is never used', () {
    expect(UiStrings.fromEnglish('Model: Claude'), 'Model: Claude');
  });

  test('what has no translation stays in English', () {
    expect(UiStrings.fromEnglish('Something new'), 'Something new');
  });

  test('Arabic and English need no table', () {
    UiStrings.current = 'en';
    expect(UiStrings.fromEnglish('Close'), 'Close');
  });

  test('the interface languages: Arabic and the 25 with approved meanings', () {
    expect(uiLanguages.length, 26);
    expect(uiLanguages.first.$1, 'ar');
    expect(isRtlLanguage('ur'), isTrue);
    expect(isRtlLanguage('fr'), isFalse);
    expect(contentLang('fr'), 'en');
    expect(contentLang('ar'), 'ar');
  });
}
