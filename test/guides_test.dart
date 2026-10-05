import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// «مرشد الحالة»: every branch leads somewhere, every answer has its Dorar
/// page, and a difference is one Dorar states in its own words.
void main() {
  final guides = ((jsonDecode(File('assets/kb/guides.json').readAsStringSync()) as Map)['guides'] as List).cast<Map<String, dynamic>>();

  test('every branch leads to a node, and every node can be reached', () {
    for (final g in guides) {
      final nodes = (g['nodes'] as Map).cast<String, dynamic>();
      final reached = <String>{g['start'] as String};
      final queue = [g['start'] as String];
      while (queue.isNotEmpty) {
        final n = (nodes[queue.removeLast()] as Map).cast<String, dynamic>();
        final next = [n['yes'], n['no'], for (final o in (n['options'] as List? ?? const [])) o['to']].whereType<String>();
        for (final t in next) {
          expect(nodes.containsKey(t), isTrue, reason: '${g['id']} → $t');
          if (reached.add(t)) queue.add(t);
        }
      }
      expect(reached, nodes.keys.toSet(), reason: '${g['id']}: unreachable nodes');
    }
  });

  test('every answer is quoted with its page; a difference is stated by Dorar', () {
    for (final g in guides) {
      for (final MapEntry(key: id, value: raw) in (g['nodes'] as Map).cast<String, dynamic>().entries) {
        final n = (raw as Map).cast<String, dynamic>();
        if (!n.containsKey('kind')) {
          expect(n['q'], isNotEmpty);
          expect(n['qEn'], isNotEmpty);
          continue;
        }
        expect(n['url'] as String, startsWith('https://dorar.net/feqhia/'), reason: id);
        if (n['kind'] == 'none') continue;
        expect(n['answer'], isNotEmpty, reason: id);
        expect(n['en'], isNotEmpty, reason: id);
        if (n['kind'] == 'khilaf') {
          expect((n['answer'] as String).startsWith('اختلف') || n['other'] != null, isTrue, reason: id);
        }
      }
    }
  });
}
