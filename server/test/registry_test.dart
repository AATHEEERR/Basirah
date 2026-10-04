import 'dart:convert';
import 'dart:io';

import 'package:basirah_core/basirah_core.dart';
import 'package:basirah_server/basirah_server.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Evidence verse(String surah, String ayah, String text) =>
    Evidence(id: 'q', kind: EvidenceKind.quran, text: text, surah: int.parse(surah), ayah: ayah);

void main() {
  final sample = loadFixtureQuran();

  group('registry verses must be the exact Mushaf wording', () {
    test('an excerpt of whole words, copied from the dataset, passes', () {
      final full = sample.verse('17:36')!.uthmani;
      final excerpt = full.split(' ').take(6).join(' ');
      expect(checkRegistryVerse(verse('17', '36', excerpt), sample), isNull);
    });

    test('the same words in simplified script fail', () {
      expect(checkRegistryVerse(verse('17', '36', 'وَلَا تَقْفُ مَا لَيْسَ لَكَ بِهِ عِلْمٌ'), sample), isNotNull);
    });

    test('one missing mark fails', () {
      final full = sample.verse('17:36')!.uthmani;
      expect(checkRegistryVerse(verse('17', '36', full.replaceFirst('ْ', '')), sample), isNotNull);
    });

    test('part of a word fails', () {
      final full = sample.verse('17:36')!.uthmani;
      expect(checkRegistryVerse(verse('17', '36', full.substring(2)), sample), isNotNull);
    });

    test('a range is checked verse by verse', () {
      final text = [for (var a = 1; a <= 4; a++) sample.verse('112:$a')!.uthmani].join(' ۝ ');
      expect(checkRegistryVerse(verse('112', '1–4', text), sample), isNull);
    });
  });

  // The full dataset is built on first server start and is not in the repo.
  final quran = QuranLibrary.tryLoad('data/quran.json');
  test('every Quran text in assets/kb matches the KFGQPC Uthmani text exactly', () {
    final registry = jsonDecode(File('../assets/kb/evidence.json').readAsStringSync()) as Map<String, dynamic>;
    final en = (jsonDecode(File('../assets/kb/en.json').readAsStringSync()) as Map<String, dynamic>)['quran']
        as Map<String, dynamic>;
    final problems = <String>[];
    var checked = 0;
    for (final item in (registry['evidence'] as List).cast<Map<String, dynamic>>()) {
      final e = Evidence.fromJson(item);
      if (!e.isQuran) continue;
      checked++;
      final p = checkRegistryVerse(e, quran!);
      if (p != null) problems.add('${e.id}: $p');
      final arabic = (en[e.id] as Map<String, dynamic>?)?['arabic'] as String?;
      final q = arabic == null ? null : checkFullVerses(e, arabic, quran);
      if (q != null) problems.add('${e.id}: $q');
    }
    expect(checked, greaterThan(0));
    expect(problems, isEmpty);
  }, skip: quran == null ? 'data/quran.json not built yet' : false);
}
