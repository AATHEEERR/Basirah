import 'package:basirah/features/answer/receipt.dart';
import 'package:basirah_core/basirah_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Every action server/lib/src/guard.dart writes, as it writes it.
  const actions = {
    'dropped unknown verse ref 2:999': 'حُذفت إشارة إلى آية غير موجودة (2:999)',
    'dropped 2:256: cited without reading its tafsir': 'حُذف الاستشهاد بالآية (2:256) لأن تفسيرها لم يُقرأ في هذه الإجابة',
    'dropped unknown hadith id h_x': 'حُذف حديث لم يُعثر عليه في المصادر المعتمدة',
    'dropped h_asma: cited without a reason': 'حُذف حديث استُشهد به دون بيان ما يدل عليه',
    'replaced unquoted Quran wording (112:1)': 'استُبدل نص قرآني كتبه النموذج من ذاكرته بمرجع الآية',
    'removed Quran quotation': 'حُذف نص قرآني كتبه النموذج من ذاكرته ولم يطابق آية بعينها',
    'replaced Quran quotation with its reference': 'استُبدل نص قرآني كتبه النموذج من ذاكرته بمرجع الآية',
    'level D forced to refer': 'حالة شخصية: حُوّلت الإجابة إلى إحالة إلى مختص',
    'personal case without curated backing forced to refer': 'حالة شخصية: حُوّلت الإجابة إلى إحالة إلى مختص',
    'ungrounded answer forced to abstain': 'لا أدلة كافية: حُوّلت الإجابة إلى امتناع',
    'low-confidence answer forced to abstain': 'لا أدلة كافية: حُوّلت الإجابة إلى امتناع',
    'refer: dropped 2 cited item(s)': 'حُذفت أدلة (2) لأن الإحالة والامتناع لا يستشهدان بشيء',
  };

  test('every guard action reads as a sentence, never as the raw note', () {
    actions.forEach((raw, ar) => expect(guardNote(raw, 'ar'), ar, reason: raw));
    for (final raw in actions.keys) {
      expect(guardNote(raw, 'en'), isNot(contains('dropped')), reason: raw);
    }
  });

  test('notes that are not a change to the answer are left out', () {
    for (final note in [
      'answered from cache',
      'gemini:gemini-3.8-flash daily quota exhausted',
      'claude:claude-sonnet-5-5 unavailable (529)',
      'no model available',
      'time budget reached (75 s)',
    ]) {
      expect(guardNote(note, 'ar'), isNull, reason: note);
    }
  });

  test('a live answer lists only the checks that ran on it', () {
    final verse = Evidence.fromJson({'id': 'q_60_8', 'kind': 'quran', 'text': 'لَّا يَنۡهَىٰكُمُ', 'surah': 60, 'ayah': '8', 'tafsir': 'شرح'});
    final a = BasirahAnswer(
      question: 'هل أزور أهلي؟',
      kind: AnswerKind.answer,
      level: ContentLevel.parse('B'),
      origin: AnswerOrigin.ai,
      evidence: [verse],
    );
    final titles = [for (final (t, _) in receiptChecks(a, 'ar')) t];
    expect(titles.first, startsWith('نص الآيات منقول من مصحف مجمع الملك فهد'));
    expect(titles, contains('قُرئ تفسير كل آية في موسوعة التفسير (الدرر السنية) قبل الاستشهاد بها'));
    expect(titles.any((t) => t.startsWith('الحديث')), isFalse); // no hadith cited
  });
}
