import 'package:basirah_server/basirah_server.dart';
import 'package:test/test.dart';

void main() {
  group('tabariSummary: al-Tabari\'s own statement, verbatim, without narrations', () {
    test('skips the heading line and stops at the first chain of narration', () {
      expect(
        tabariSummary('القول في تأويل قوله تعالى: {…}\nيقول تعالى ذكره: المعنى كذا.\n* ذكر من قال ذلك:\n12 - حدثنا فلان'),
        'يقول تعالى ذكره: المعنى كذا.',
      );
    });

    test('a heading inside the first line starts at the statement after it', () {
      expect(
        tabariSummary('شهر رمضان القول في تأويل قوله تعالى : { شهر رمضان } قال أبو جعفر : الشهر أصله من الشهرة .'),
        'قال أبو جعفر : الشهر أصله من الشهرة .',
      );
    });

    test('a narration marker inside a line cuts the excerpt there', () {
      expect(
        tabariSummary('ذُكر أن المشركين سألوا عن نسب ربّ العزّة، فأنزل الله هذه السورة جوابا لهم. ذكر من قال: أنزلت جوابا'),
        'ذُكر أن المشركين سألوا عن نسب ربّ العزّة، فأنزل الله هذه السورة جوابا لهم.',
      );
    });

    test('print-edition footnote marks are removed; long text ends at a sentence', () {
      final long = 'يقول تعالى ذكره: ${'كلام، ' * 120}(1) وتمامه= هنا.';
      final s = tabariSummary(long)!;
      expect(s, isNot(contains('(1)')));
      expect(s, isNot(contains('=')));
      expect(s.length, lessThanOrEqualTo(452));
      expect(s, endsWith('…'));
    });

    test('nothing usable → null', () {
      expect(tabariSummary(null), isNull);
      expect(tabariSummary('القول في تأويل قوله تعالى: {…}\n1 - حدثنا فلان'), isNull);
    });
  });

  group('موسوعة التفسير (dorar.net/tafseer)', () {
    test('the surah page lists its passages and the verses each covers', () {
      const html = '<select><option value="1">\n الآيات (1-3)\n</option><option value="2"> الآية (4) </option>'
          '<option value="3">الآيتان (5-6)</option></select><select><option value="1">الآيات (1-3)</option></select>';
      expect(parseDorarIndex(html), [(n: 1, from: 1, to: 3), (n: 2, from: 4, to: 4), (n: 3, from: 5, to: 6)]);
    });

    test('a passage page gives the overall meaning and the tafsir, without footnotes or styles', () {
      const html = '<style>.x{}</style><h3>المعنى الإجماليُّ:</h3><p>يأمر الله بالبر</p>'
          '<p>[12]</p><p>يُنظر: ((تفسير ابن كثير)) (1/2).</p>'
          '<h3>تفسيرُ الآيتَينِ:</h3><p>لَا يَنْهَاكُمُ اللَّهُ عَنِ الَّذِينَ (8).</p><p>أي: لا ينهاكم الله عن برهم.</p>'
          '<p>[13] يُنظر: ((تفسير السعدي)) (ص: 9).</p><h3>بلاغةُ الآيتَينِ:</h3><p>بلاغة</p>';
      final text = dorarPassageText(html)!;
      expect(text, '[المعنى الإجمالي]\nيأمر الله بالبر\n[تفسير الآيات]\nلَا يَنْهَاكُمُ اللَّهُ عَنِ الَّذِينَ (8). أي: لا ينهاكم الله عن برهم.');
    });

    test('the explanation of the verse itself is found after its number, past «سبب النزول»', () {
      const text = '[المعنى الإجمالي]\nمعنى عام.\n[تفسير الآيات]\nآية سابقة (7). أي: شرح السابقة. '
          'لَا يَنْهَاكُمُ اللَّهُ عَنِ الَّذِينَ لَمْ يُقَاتِلُوكُمْ (8). سبب النزول: قصة. '
          'أي: لا ينهاكم الله عن الإحسان إليهم يُنظر: ((تفسير الطبري)) (22/574).. والعدل معهم. آية تالية (9). أي: شرح التالية.';
      expect(
        dorarVerseExplanation(text, 'لا ينهاكم الله عن الذين لم يقاتلوكم'),
        'أي: لا ينهاكم الله عن الإحسان إليهم والعدل معهم.',
      );
      // No such verse in the passage: nothing is shown in its name.
      expect(dorarVerseExplanation(text, 'قل هو الله أحد'), isNull);
    });

    test('the model reads the overall meaning, then the tafsir from where the verse is quoted', () {
      const text = '[المعنى الإجمالي]\nمعنى عام.\n[تفسير الآيات]\nآية سابقة (7). أي: شرح السابقة. '
          'لَا يَنْهَاكُمُ اللَّهُ عَنِ الَّذِينَ (8). أي: شرح الآية.';
      expect(
        tafsirForVerse(text, 'لا ينهاكم الله عن الذين'),
        '[المعنى الإجمالي]\nمعنى عام.\n[تفسير الآية]\nلَا يَنْهَاكُمُ اللَّهُ عَنِ الَّذِينَ (8). أي: شرح الآية.',
      );
    });
  });
}
