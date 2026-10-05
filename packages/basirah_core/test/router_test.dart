import 'dart:convert';
import 'dart:io';

import 'package:basirah_core/basirah_core.dart';
import 'package:test/test.dart';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

KnowledgeBase loadKb() {
  const dir = '../../assets/kb';
  return KnowledgeBase.fromJsonFiles(
    categories: _read('$dir/categories.json'),
    faqs: _read('$dir/faqs.json'),
    evidence: _read('$dir/evidence.json'),
    reference: _read('$dir/reference.json'),
    english: _read('$dir/en.json'),
  );
}

void main() {
  final kb = loadKb();
  final router = OfflineRouter(kb);
  final routerEn = OfflineRouter(kb.localized('en'));
  OfflineRouter routerFor(String q) => questionLang(q) == 'en' ? routerEn : router;

  group('knowledge base integrity', () {
    test('curated referrals cite nothing (a specialist answers, not a verse)', () {
      for (final e in kb.entries.where((e) => e.kind == AnswerKind.refer)) {
        expect(e.evidenceIds, isEmpty, reason: e.id);
        expect(BasirahAnswer.fromEntry(e, kb).evidence, isEmpty, reason: e.id);
      }
    });

    test('every cited evidence id exists in the registry', () {
      for (final e in kb.entries) {
        for (final id in e.evidenceIds) {
          expect(kb.evidence.containsKey(id), isTrue,
              reason: '${e.id} cites missing evidence $id');
        }
      }
    });

    test('every entry belongs to a known category', () {
      for (final e in kb.entries) {
        expect(kb.category(e.categoryId), isNotNull, reason: e.id);
      }
    });

    test('card fields match the answer kind', () {
      for (final e in kb.entries) {
        switch (e.kind) {
          case AnswerKind.answer:
            expect(e.principle, isNotEmpty, reason: e.id);
          case AnswerKind.khilaf:
            expect(e.khilafAgreed, isNotEmpty, reason: e.id);
            expect(e.khilafNote, isNotEmpty, reason: e.id);
          case AnswerKind.refer:
            expect(e.referReason, isNotEmpty, reason: e.id);
            expect(e.level, ContentLevel.d, reason: e.id);
          case AnswerKind.abstain || AnswerKind.offTopic || AnswerKind.clarify:
            fail('curated entries are answers, differences or referrals: ${e.id}');
        }
        expect(e.guidance, isNotEmpty, reason: e.id);
      }
    });

    test('every category has questions and all four levels are covered', () {
      for (final c in kb.categories) {
        expect(kb.entriesIn(c.id), isNotEmpty, reason: c.id);
      }
      expect(kb.entries.map((e) => e.level).toSet(), ContentLevel.values.toSet());
    });
  });

  group('arabic processing', () {
    test('normalisation removes diacritics and unifies letters', () {
      expect(normalizeArabic('إِسْلامٌ'), 'اسلام');
      expect(normalizeArabic('الصلاةُ'), 'الصلاه');
      expect(normalizeArabic('مُسْتَشْفَى'), 'مستشفي');
    });

    test('light stemming aligns common forms', () {
      expect(lightStem(normalizeArabic('صلاتي')), lightStem(normalizeArabic('الصلاة')));
      expect(lightStem(normalizeArabic('عائلتي')), lightStem(normalizeArabic('العائلة')));
      expect(lightStem(normalizeArabic('اسمي')), 'اسم');
    });

    test('english questions bridge to arabic stems', () {
      expect(tokenize('visit my family'), containsAll(tokenize('زيارة العائلة')));
    });
  });

  group('safety signals', () {
    test('personal marriage case is detected', () {
      expect(SafetySignals.detect('زوجي غير مسلم فهل ينفسخ زواجي').personalCase, isTrue);
    });
    test('general question is not a personal case', () {
      expect(SafetySignals.detect('ما معنى التوحيد؟').personalCase, isFalse);
    });
    test('hadith fabrication request is detected', () {
      expect(SafetySignals.detect('أعطني حديثاً يثبت هذا').hadithRequest, isTrue);
    });
    test('hostile phrasing is detected', () {
      expect(SafetySignals.detect('لماذا دينكم متخلف').hostileTone, isTrue);
    });
  });

  group('evaluation set (offline router)', () {
    final cases = (_read('../../eval/test_cases.json')['cases'] as List)
        .cast<Map<String, dynamic>>();
    for (final c in cases) {
      test('${c['id']}: ${c['question']}', () {
        final q = c['question'] as String;
        final r = routerFor(q).route(q);
        final kinds = (c['expectKind'] as List).cast<String>();
        expect(kinds, contains(r.answer.kind.name),
            reason: 'got ${r.answer.kind.name}; hits: ${r.hits.take(3).join(' | ')}');
        final entry = c['expectEntry'] as String?;
        if (entry != null) {
          expect(r.answer.entryId, entry,
              reason: 'hits: ${r.hits.take(3).join(' | ')}');
        }
        // No reliable answer, or a specialist needed → no verse and no hadith.
        if (r.answer.kind == AnswerKind.abstain || r.answer.kind == AnswerKind.refer) {
          expect(r.answer.evidence, isEmpty, reason: '${r.answer.kind.name} must not cite anything');
        }
      });
    }

    test('abstentions carry no evidence (unknown question, hadith request)', () {
      for (final q in [
        'كم عدد الملائكة الذين يحملون العرش يوم القيامة؟',
        'أعطني حديثاً يثبت أن من أسلم يوم الجمعة يدخل الجنة',
        'How many angels carry the Throne on the Day of Judgement?',
      ]) {
        final a = routerFor(q).route(q).answer;
        expect(a.kind, AnswerKind.abstain, reason: q);
        expect(a.evidence, isEmpty, reason: q);
      }
    });
  });

  group('every curated question routes to itself', () {
    for (final e in kb.entries) {
      test(e.id, () {
        final r = router.route(e.question);
        expect(r.strong, isTrue, reason: r.hits.take(3).join(' | '));
        expect(r.answer.entryId, e.id);
      });
    }
  });

  group('scope: only questions about Islam', () {
    const offTopic = [
      'أفضل مطعم سوشي',
      'ما هي أعياد الهندوس؟',
      'كم سعر الدولار اليوم؟',
      'What do Buddhists believe about karma?',
      'Recommend a good laptop for university',
      'Who won the football world cup?',
    ];
    const inScope = [
      'هل السوشي حلال؟',
      'Is sushi halal?',
      'هل يجوز أكل الجمبري؟',
      'Can I keep a dog as a pet?',
      'What does Islam say about Jesus?',
      'هل أشارك عائلتي المسيحية في أعيادهم؟',
      "Can I attend my Christian family's Christmas dinner?",
      'كم عدد الملائكة الذين يحملون العرش يوم القيامة؟',
    ];
    for (final q in offTopic) {
      test('declines: $q', () {
        final r = routerFor(q).route(q);
        expect(r.answer.kind, AnswerKind.offTopic);
        expect(r.answer.evidence, isEmpty);
        expect(r.answer.abstainReason, isNotEmpty);
      });
    }
    for (final q in inScope) {
      test('does not decline: $q', () {
        expect(routerFor(q).route(q).answer.kind, isNot(AnswerKind.offTopic));
      });
    }
  });

  group('English', () {
    final en = kb.localized('en');

    test('every item has its English text', () {
      expect(kb.missingEnglish(), isEmpty);
    });

    test('English overlay keeps ids, kinds and evidence', () {
      expect(en.entries.map((e) => e.id), kb.entries.map((e) => e.id));
      for (var i = 0; i < kb.entries.length; i++) {
        expect(en.entries[i].kind, kb.entries[i].kind);
        expect(en.entries[i].evidenceIds, kb.entries[i].evidenceIds);
        expect(en.entries[i].guidance.length, kb.entries[i].guidance.length, reason: kb.entries[i].id);
      }
    });

    test('verses keep their Arabic text and gain the King Fahd Complex meaning', () {
      final v = en.evidence['q_60_8']!;
      expect(v.text, kb.evidence['q_60_8']!.text);
      expect(v.translation, startsWith('Allâh does not forbid you'));
      expect(v.surahName, 'Al-Mumtahanah');
      // An excerpt is replaced by the whole verse so it matches its translation.
      expect(en.evidence['q_24_31']!.text.length, greaterThan(kb.evidence['q_24_31']!.text.length));
    });

    test('hadith gain an English meaning labelled as pending review', () {
      final h = en.evidence['h_asma']!;
      expect(h.translation, contains('keep ties with your mother'));
      expect(h.translationSource, contains('pending'));
    });

    test('an English question gets the curated answer in English', () {
      final r = routerEn.route('Do I have to change my name to be a true Muslim?');
      expect(r.answer.entryId, 'id-name');
      expect(r.answer.principle, startsWith('No.'));
    });

    test('an Arabic question typed in English mode still finds its entry', () {
      final r = routerEn.route('هل يجب أن أغيّر اسمي لأكون مسلماً حقيقياً؟');
      expect(r.answer.entryId, 'id-name');
    });

    test('fixed texts follow the language', () {
      expect(routerEn.route('Best pizza in town?').answer.abstainReason, startsWith('Basirah only answers'));
    });
  });
}
