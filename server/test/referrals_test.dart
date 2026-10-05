import 'dart:io';
import 'dart:math';

import 'package:basirah_server/basirah_server.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late String file;
  final now = DateTime.utc(2026, 10, 5, 12);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('referrals');
    file = '${dir.path}/referrals.json';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Referrals open() => Referrals(file: file, random: Random(1));

  test('a written request is kept, read back only with its token, and answered', () {
    final r = open().create(question: 'هل يجب الاغتسال عند الإسلام؟', conversation: '', context: '', lang: 'ar', mode: 'message', now: now)!;
    expect(r['meetUrl'], isNull);
    final again = open();
    expect(again.forAsker(r['id'] as String, 'wrong'), isNull);
    final mine = again.forAsker(r['id'] as String, r['token'] as String)!;
    expect(mine['question'], 'هل يجب الاغتسال عند الإسلام؟');
    expect(mine.containsKey('token'), isFalse);
    expect(again.reply(r['id'] as String, text: 'نعم يُشرع…', now: now), isTrue);
    final read = open().forAsker(r['id'] as String, r['token'] as String)!;
    expect(read['status'], 'answered');
    expect((read['messages'] as List).single['from'], 'specialist');
    expect(open().all(now: now).single.containsKey('token'), isFalse);
  });

  test('a call needs a time in the next two weeks and gets a private room', () {
    final ref = open();
    expect(ref.create(question: 'q', conversation: '', context: '', lang: 'ar', mode: 'video', now: now), isNull);
    expect(
      ref.create(question: 'q', conversation: '', context: '', lang: 'ar', mode: 'audio', slot: now.add(const Duration(days: 20)), now: now),
      isNull,
    );
    final r = ref.create(question: 'q', conversation: '', context: '', lang: 'fr', mode: 'video', slot: now.add(const Duration(days: 2)), now: now)!;
    expect(r['meetUrl'] as String, startsWith('https://meet.jit.si/Basirah-${r['id']}-'));
  });

  test('bad input is refused', () {
    final ref = open();
    expect(ref.create(question: ' ', conversation: '', context: '', lang: 'ar', mode: 'message', now: now), isNull);
    expect(ref.create(question: 'q', conversation: '', context: '', lang: 'ar', mode: 'fax', now: now), isNull);
    expect(ref.create(question: 'q' * 1300, conversation: '', context: '', lang: 'ar', mode: 'message', now: now), isNull);
    expect(ref.create(question: 'q', conversation: '', context: '', lang: '../x', mode: 'message', now: now), isNull);
    final r = ref.create(question: 'q', conversation: '', context: '', lang: 'ar', mode: 'message', now: now)!;
    expect(ref.reply(r['id'] as String, status: 'deleted'), isFalse);
    expect(ref.askerMessage(r['id'] as String, r['token'] as String, ''), isFalse);
  });

  test('requests are deleted after 30 days', () {
    final ref = open();
    ref.create(question: 'old', conversation: '', context: '', lang: 'ar', mode: 'message', now: now);
    expect(ref.all(now: now.add(const Duration(days: 29))), hasLength(1));
    expect(ref.all(now: now.add(const Duration(days: 31))), isEmpty);
    expect(open().length, 0);
  });
}
