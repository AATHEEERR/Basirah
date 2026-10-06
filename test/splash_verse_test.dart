import 'dart:convert';
import 'dart:io';

import 'package:basirah/features/splash/splash_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the splash verse is the Mushaf text of Yusuf 108, up to «عَلَىٰ بَصِيرَةٍ»', () {
    final evidence = (jsonDecode(File('assets/kb/evidence.json').readAsStringSync()) as Map)['evidence'] as List;
    final verse = evidence.cast<Map>().firstWhere((e) => e['id'] == 'q_12_108');
    expect((verse['full'] as String).startsWith(splashVerse), isTrue);
    // It ends at the word the name comes from.
    expect(splashVerse.split(' ').last.replaceAll(RegExp('[ً-ٰٟۖ-ۭ]'), ''), 'بصيرة');
  });
}
