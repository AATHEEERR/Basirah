import 'package:basirah_server/basirah_server.dart';
import 'package:test/test.dart';

/// The submissions the guard would overrule are recognised by the agent, so
/// in other languages the model can write the abstention or referral itself.
void main() {
  test('an answer with nothing cited is overruled', () {
    expect(ResearchAgent.overruled({'kind': 'answer', 'level': 'B', 'confidence': 'high'}), isNotNull);
  });

  test('an answer citing a verse, a hadith or a documented answer stands', () {
    for (final cited in [
      {'quran': [{'ref': '2:255'}]},
      {'hadith': [{'id': 'he:123'}]},
      {'basedOnEntries': ['id-name']},
    ]) {
      expect(ResearchAgent.overruled({'kind': 'answer', 'level': 'B', 'confidence': 'high', ...cited}), isNull);
    }
  });

  test('a fatwa-level answer must be a referral', () {
    expect(ResearchAgent.overruled({'kind': 'answer', 'level': 'D', 'basedOnEntries': ['x']}), isNotNull);
    expect(ResearchAgent.overruled({'kind': 'refer', 'level': 'D'}), isNull);
  });

  test('a clarifying question needs its options', () {
    expect(ResearchAgent.overruled({'kind': 'clarify', 'clarifyQuestion': 'Why?', 'clarifyOptions': ['a']}), isNotNull);
    expect(ResearchAgent.overruled({'kind': 'clarify', 'clarifyQuestion': 'Why?', 'clarifyOptions': ['a', 'b']}), isNull);
  });

  test('a low-confidence answer is overruled', () {
    expect(ResearchAgent.overruled({'kind': 'answer', 'confidence': 'low', 'quran': [{'ref': '1:1'}]}), isNotNull);
  });

  test('abstentions, referrals and differences are left alone', () {
    for (final kind in ['abstain', 'refer', 'khilaf', 'offTopic']) {
      expect(ResearchAgent.overruled({'kind': kind, 'level': 'B'}), isNull);
    }
  });
}
