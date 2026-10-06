import 'package:basirah_core/basirah_core.dart';
import 'package:basirah_server/src/fixed_texts.dart';
import 'package:basirah_server/src/fixed_texts_i18n.dart';
import 'package:test/test.dart';

void main() {
  final en = RouterTexts.en;

  test('every language the server answers in has the fixed texts', () {
    // Each language detectLanguage can name, other than Arabic and English.
    const answered = [
      'fr', 'es', 'pt', 'de', 'nl', 'tr', 'az', 'id', 'tl', 'sw', 'so', 'ha', 'bs', 'sq', 'vi', //
      'fa', 'ur', 'ps', 'zh', 'ja', 'ko', 'hi', 'bn', 'as', 'ta', 'si', 'th', 'ru', 'am',
    ];
    for (final iso in answered) {
      final t = fixedTexts[iso];
      expect(t, isNotNull, reason: iso);
      for (final k in ['referReason', 'referTo', 'abstainReason', 'hadithReason', 'personalNote', 'offTopicReason', 'khilafFallback']) {
        expect((t![k] as String).trim(), isNotEmpty, reason: '$iso $k');
      }
      for (final k in ['referGuidance', 'abstainGuidance', 'hadithGuidance', 'offTopicGuidance']) {
        expect((t![k] as List).length, 3, reason: '$iso $k');
      }
      // What the language test reads: the reason, in the asker's language.
      for (final k in ['referReason', 'abstainReason', 'hadithReason', 'offTopicReason']) {
        expect(detectLanguage((t![k] as String).replaceAll('Basirah', '')), iso, reason: '$iso $k');
      }
    }
  });

  test("a guard's abstention to a French question is shown in French", () {
    final a = BasirahAnswer.fromJson({
      'question': 'Est-ce que tous les musulmans sont d’accord ?',
      'kind': 'abstain',
      'abstainReason': en.abstainReason,
      'guidance': en.abstainGuidance,
    });
    final fr = localizeFixedTexts(a, 'fr');
    expect(fr.abstainReason, fixedTexts['fr']!['abstainReason']);
    expect(fr.guidance, fixedTexts['fr']!['abstainGuidance']);
    expect(detectLanguage(fr.abstainReason), 'fr');
  });

  test('a referral, the hadith text and the off-topic text too', () {
    final refer = localizeFixedTexts(
      BasirahAnswer.fromJson({'kind': 'refer', 'referReason': en.referReason, 'referTo': en.referTo, 'guidance': en.referGuidance}),
      'id',
    );
    expect(refer.referReason, fixedTexts['id']!['referReason']);
    expect(refer.referTo, fixedTexts['id']!['referTo']);
    expect(refer.guidance, fixedTexts['id']!['referGuidance']);
    final hadith = localizeFixedTexts(BasirahAnswer.fromJson({'kind': 'abstain', 'abstainReason': en.hadithReason}), 'tr');
    expect(hadith.abstainReason, fixedTexts['tr']!['hadithReason']);
    final off = localizeFixedTexts(
      BasirahAnswer.fromJson({'kind': 'offTopic', 'abstainReason': en.offTopicReason, 'guidance': en.offTopicGuidance}),
      'ur',
    );
    expect(off.abstainReason, fixedTexts['ur']!['offTopicReason']);
    expect(off.guidance, fixedTexts['ur']!['offTopicGuidance']);
  });

  test('what the model wrote is never touched', () {
    final a = BasirahAnswer.fromJson({
      'kind': 'abstain',
      'abstainReason': 'Je ne trouve pas de source fiable pour cette question.',
      'guidance': ['Posez la question à un savant.'],
    });
    final fr = localizeFixedTexts(a, 'fr');
    expect(fr.abstainReason, a.abstainReason);
    expect(fr.guidance, a.guidance);
  });

  test('a language without the texts keeps the answer as it is', () {
    final a = BasirahAnswer.fromJson({'kind': 'abstain', 'abstainReason': en.abstainReason});
    expect(localizeFixedTexts(a, 'und').abstainReason, en.abstainReason);
  });
}
