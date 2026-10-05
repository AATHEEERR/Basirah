import 'package:basirah_core/basirah_core.dart';
import 'package:basirah_server/basirah_server.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final kb = loadKnowledgeBase('../assets/kb');
  final quran = loadFixtureQuran();
  const noSignals = SafetySignals(
    personalCase: false,
    hadithRequest: false,
    hostileTone: false,
    translationRequest: false,
    matched: [],
  );

  (BasirahAnswer, GuardReport) run(
    Map<String, dynamic> raw, {
    Set<String> read = const {'60:8'},
    SafetySignals signals = noSignals,
  }) {
    final report = GuardReport();
    final a = guardAnswer(
      raw: raw,
      question: 'q',
      kb: kb,
      model: 'test',
      signals: signals,
      report: report,
      quran: quran,
      readRefs: read,
      tafsirText: fakePassage,
      tafsirSource: FakeTafsir(),
    );
    return (a, report);
  }

  test('cited verse that was read gets its verified text and tafsir', () {
    final (a, report) = run(submission());
    expect(a.kind, AnswerKind.answer);
    final v = a.evidence.first;
    expect(v.isQuran, isTrue);
    expect(v.reference, 'الممتحنة: 8');
    expect(v.text, quran.verse('60:8')!.uthmani);
    expect(v.tafsir, 'شرح الآية 60:8');
    expect(v.tafsirSource, fakeLabel('60:8'));
    expect(v.note, contains('البر'));
    expect(a.evidence.map((e) => e.id), contains('h_asma'));
    expect(report.clean, isTrue);
  });

  test('verse cited without reading its tafsir is dropped', () {
    final (a, report) = run(submission(quran: const [
      {'ref': '60:8', 'why': 'x'},
      {'ref': '2:256', 'why': 'y'},
    ]));
    expect(a.evidence.where((e) => e.isQuran).map((e) => e.surah), [60]);
    expect(report.actions.single, contains('2:256'));
  });

  test('unknown verse refs are dropped', () {
    final (a, report) = run(submission(quran: const [
      {'ref': '999:1', 'why': 'x'},
    ], hadithIds: const []), read: const {});
    expect(a.evidence.where((e) => e.isQuran), isEmpty);
    expect(report.actions.single, contains('999:1'));
  });

  test('ungrounded answer becomes abstain, with no evidence', () {
    final (a, _) = run(submission(quran: const [], hadithIds: const [], entries: const []));
    expect(a.kind, AnswerKind.abstain);
    expect(a.abstainReason, isNotEmpty);
    expect(a.evidence, isEmpty);
  });

  test('low confidence answer becomes abstain and loses its citations', () {
    final (a, report) = run(submission(confidence: 'low'));
    expect(a.kind, AnswerKind.abstain);
    expect(a.evidence, isEmpty); // the verse and hadith it cited are not shown
    expect(report.actions, contains('abstain: dropped 2 cited item(s)'));
  });

  test('a referral shows no evidence, whatever the model cited', () {
    final (a, report) = run(submission(kind: 'refer', level: 'D'));
    expect(a.kind, AnswerKind.refer);
    expect(a.evidence, isEmpty);
    expect(report.actions, contains('refer: dropped 2 cited item(s)'));
  });

  test('a hadith cited without a reason is dropped; the reason is shown with it', () {
    final (a, report) = run({
      ...submission(),
      'hadith': [
        {'id': 'h_asma', 'why': 'يدل على جواز صلة الأم غير المسلمة.'},
        {'id': 'h_muadh', 'why': ''},
      ],
    });
    final hadith = [for (final e in a.evidence) if (!e.isQuran) e];
    expect(hadith.map((e) => e.id), ['h_asma']);
    expect(hadith.single.note, 'يدل على جواز صلة الأم غير المسلمة.');
    expect(report.actions, contains('dropped h_muadh: cited without a reason'));
  });

  test('a scholarly-difference answer is always level C', () {
    final (a, _) = run({
      ...submission(kind: 'khilaf', level: 'A'),
      'khilafAgreed': 'اتفقوا على العدد.',
      'khilafNote': 'واختلفوا في المراد به.',
    });
    expect(a.kind, AnswerKind.khilaf);
    expect(a.level, ContentLevel.c);
  });

  test('a model abstention that cites something shows no evidence', () {
    final (a, _) = run(submission(kind: 'abstain', level: 'B'));
    expect(a.kind, AnswerKind.abstain);
    expect(a.evidence, isEmpty);
  });

  test('level D is never answered', () {
    final (a, _) = run(submission(level: 'D'));
    expect(a.kind, AnswerKind.refer);
    expect(a.referTo, isNotEmpty);
  });

  test('personal case without curated backing becomes refer', () {
    const personal = SafetySignals(
      personalCase: true,
      hadithRequest: false,
      hostileTone: false,
      translationRequest: false,
      matched: [],
    );
    expect(run(submission(entries: const []), signals: personal).$1.kind, AnswerKind.refer);
  });

  group('no verse wording typed by the model reaches the prose', () {
    test('a quotation that is not in the Quran is removed', () {
      final a = run(submission(principle: 'قال تعالى ﴿هذه ليست آية من القرآن﴾ وانتهى')).$1;
      expect(a.principle, 'قال تعالى وانتهى');
    });

    test('a real verse in ﴿ ﴾ is replaced by its reference', () {
      final a = run(submission(principle: 'قال تعالى ﴿لَا إِكْرَاهَ فِي الدِّينِ﴾ وانتهى')).$1;
      expect(a.principle, 'قال تعالى (البقرة: 256) وانتهى');
    });

    test('a real verse in « » is replaced by its reference too', () {
      final a = run(submission(principle: 'قال تعالى «لا إكراه في الدين» وانتهى')).$1;
      expect(a.principle, 'قال تعالى (البقرة: 256) وانتهى');
    });

    test('words found in several verses stay as plain text, not as a quotation', () {
      // «ما ليس لك به علم» is in both al-Isra 36 and Luqman 15.
      final a = run(submission(principle: 'لا تتبع «ما ليس لك به علم» أبداً')).$1;
      expect(a.principle, 'لا تتبع ما ليس لك به علم أبداً');
    });
  });

  test('submit tool is strict; hadith ids are checked by the guard, not trusted', () {
    final tool = submitAnswerTool(kb);
    expect(tool['strict'], isTrue);
    // An id that is neither in the registry nor read in this run is dropped.
    final (a, report) = run({
      ...submission(),
      'hadith': [
        {'id': 'he:999999', 'why': 'حديث لم يُقرأ في هذه الإجابة.'},
        {'id': 'q_2_256', 'why': 'آية مكان حديث.'},
      ],
    });
    expect(a.evidence.where((e) => !e.isQuran), isEmpty);
    expect(report.actions, containsAll(['dropped unknown hadith id he:999999', 'dropped unknown hadith id q_2_256']));
  });

  group('Quran library', () {
    test('parses refs in several notations', () {
      expect(quran.parseRef('60:8'), '60:8');
      expect(quran.parseRef('٦٠:٨'), '60:8');
      expect(quran.parseRef('60/8'), '60:8');
      expect(quran.parseRef('60:99'), isNull);
    });

    test('search finds a verse from its tafsir wording and from a phrase', () {
      expect(quran.search('أن تبروهم وتقسطوا إليهم').first.verse.key, '60:8');
      expect(quran.search('الإكراه على الدخول في الإسلام').first.verse.key, '2:256');
    });
  });

  group('a clarifying question', () {
    Map<String, dynamic> clarify({List<String> options = const ['أقل من 80 كم', '80 كم أو أكثر', 'لا أعرف']}) => {
      ...submission(kind: 'clarify', level: 'B'),
      'clarifyQuestion': 'كم مسافة سفرك؟',
      'clarifyOptions': options,
    };

    test('is kept with its options, and nothing is answered or cited yet', () {
      final (a, _) = run(clarify());
      expect(a.kind, AnswerKind.clarify);
      expect(a.clarifyQuestion, 'كم مسافة سفرك؟');
      expect(a.clarifyOptions, ['أقل من 80 كم', '80 كم أو أكثر', 'لا أعرف']);
      expect(a.evidence, isEmpty);
      expect(a.principle, isEmpty);
      expect(a.guidance, isEmpty);
    });

    test('a personal case is referred at once instead', () {
      const personal = SafetySignals(personalCase: true, hadithRequest: false, hostileTone: false, translationRequest: false, matched: ['هل يجوز لي']);
      final (a, report) = run(clarify(), signals: personal);
      expect(a.kind, AnswerKind.refer);
      expect(a.clarifyOptions, isEmpty);
      expect(report.actions, contains('personal case: clarifying question forced to refer'));
    });

    test('without at least two options it is not shown', () {
      final (a, _) = run(clarify(options: const ['نعم']));
      expect(a.kind, AnswerKind.abstain);
      expect(a.clarifyQuestion, isEmpty);
    });
  });
}
