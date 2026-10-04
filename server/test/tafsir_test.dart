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
}
