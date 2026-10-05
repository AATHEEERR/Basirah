import 'dart:convert';
import 'dart:io';

/// Builds `assets/kb/guides.json`: «مرشد الحالة», short yes/no trees for a new
/// Muslim's questions on ghusl and wudu. Every answer is copied verbatim
/// from الموسوعة الفقهية in الدرر السنية (dorar.net/feqhia) — the page's own
/// question-and-answer summary — and linked to its page:
///
/// * where Dorar reports consensus or the agreement of the four schools, the
///   leaf is «clear»: the answer is given;
/// * where Dorar says the scholars differ («اختلف»), the leaf is «khilaf»:
///   the views are quoted, Basirah does not choose, and the asker can send
///   their case file to a Sharia specialist.
///
/// Run from `server/`: `dart run tool/build_guides.dart`.
Future<void> main() async {
  final client = HttpClient();
  Future<String> page(int id) async {
    final req = await client.getUrl(Uri.parse('https://dorar.net/feqhia/$id'));
    req.headers.set('user-agent', 'Mozilla/5.0 (compatible; Basirah/1.0)');
    final res = await req.close();
    if (res.statusCode != 200) throw StateError('feqhia/$id: HTTP ${res.statusCode}');
    final html = await res.transform(utf8.decoder).join();
    return html
        .replaceAll(RegExp(r'<script[\s\S]*?</script>'), '')
        .replaceAll(RegExp(r'<br\s*/?>|</p>|</h\d>|</div>|</li>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&quot;', '"')
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((l) => l.isNotEmpty && !RegExp(r'^\d+$').hasMatch(l))
        .join('\n');
  }

  final texts = <int, String>{};

  /// The page title (its heading) and its question-and-answer summary:
  /// [(question, answer)], verbatim.
  Future<(String, List<(String, String)>)> read(int id) async {
    final text = texts[id] = await page(id);
    final lines = text.split('\n');
    final title = lines.firstWhere((l) => l.contains('الموسوعة الفقهية')).split(' - ').first.trim();
    final start = lines.indexWhere((l) => l.contains('المادة في سؤال وجواب'));
    if (start < 0) throw StateError('feqhia/$id: no question-and-answer summary');
    final qa = <(String, String)>[];
    for (var i = start + 1; i + 1 < lines.length; i++) {
      if (!lines[i].endsWith('؟')) continue;
      // A short line without a full stop under a question is a heading
      // («الدليل من القرآن», «الدليل من السنة:»): the answer is the line
      // after it.
      final next = lines[i + 1];
      final heading = next.length < 30 && !next.endsWith('.') && !next.endsWith('؟');
      final answer = heading && i + 2 < lines.length ? lines[i + 2] : next;
      if (answer.endsWith('؟')) continue;
      qa.add((lines[i], answer));
    }
    return (title, qa);
  }

  final pages = <int, (String, List<(String, String)>)>{};
  for (final id in [397, 399, 422, 424, 446, 466, 471, 477, 479]) {
    pages[id] = await read(id);
    stdout.writeln('feqhia/$id: ${pages[id]!.$1}');
  }
  client.close();

  /// A leaf from page [id]: its first answer, plus the answer to the
  /// question matching [also] (e.g. who reported the consensus, or the
  /// Quran evidence), or the page's own sentence matching [other] (the
  /// other view, when the summary names only the majority's).
  Map<String, dynamic> leaf(int id, String kind, {String? also, RegExp? other, required String en}) {
    final (title, qa) = pages[id]!;
    final first = qa.first;
    final extra = also == null ? null : qa.skip(1).where((p) => p.$1.contains(also) || p.$2.contains(also)).firstOrNull?.$2;
    final otherView = other?.firstMatch(texts[id]!)?[0];
    if (other != null && otherView == null) throw StateError('feqhia/$id: the other view was not found');
    // A difference only where Dorar states one, in its own words.
    if (kind == 'khilaf' && !first.$2.startsWith('اختلف') && otherView == null) throw StateError('feqhia/$id is not stated as a difference');
    return {
      'kind': kind,
      'source': title,
      'url': 'https://dorar.net/feqhia/$id',
      'question': first.$1,
      'answer': first.$2,
      if (extra != null) 'more': extra,
      if (otherView != null) 'other': otherView,
      'en': en,
    };
  }

  final guides = [
    {
      'id': 'ghusl',
      'title': 'هل يجب عليك الغُسل؟',
      'titleEn': 'Do you need to take a ghusl?',
      'subtitle': 'أسئلة قصيرة بنعم أو لا عن حالتك',
      'subtitleEn': 'A few yes-or-no questions about your situation',
      'start': 'new',
      'nodes': {
        'new': {
          'q': 'هل أسلمتَ حديثاً ولم تغتسل بعد إسلامك؟',
          'qEn': 'Did you embrace Islam recently and have not taken a ghusl since?',
          'yes': 'new_before',
          'no': 'intercourse',
        },
        'new_before': {
          'q': 'قبل إسلامك: هل حصل منك جماع، أو خروج منيّ، أو حيض أو نفاس؟',
          'qEn': 'Before Islam, did you have intercourse, an emission of semen, or menstruation or postnatal bleeding?',
          'yes': 'convert',
          'no': 'convert',
        },
        'intercourse': {
          'q': 'هل حصل منك جماع، ولو بلا إنزال؟',
          'qEn': 'Have you had intercourse, even without ejaculation?',
          'yes': 'after_intercourse',
          'no': 'semen',
        },
        'semen': {
          'q': 'هل خرج منك منيّ وأنت مستيقظ، دفقاً بلذّة؟',
          'qEn': 'Was semen emitted while you were awake, in spurts with pleasure?',
          'yes': 'after_semen',
          'no': 'bleeding',
        },
        'bleeding': {
          'q': 'هل انقطع عنكِ دم الحيض أو النفاس؟',
          'qEn': 'Has your menstrual or postnatal bleeding ended?',
          'yes': 'after_bleeding',
          'no': 'none',
        },
        'convert': leaf(479, 'khilaf', other: RegExp(r'لكنْ أوجَبَ بعضُهم[^.]*\.'),
            en: 'Ghusl is recommended for a person who embraces Islam: the view of the majority (Hanafi, the well-known Maliki view, Shafi\'i). '
                'Other scholars hold it obligatory, notably when something requiring ghusl happened before Islam.'),
        'after_intercourse': leaf(471, 'clear', also: 'الإجماع',
            en: 'Ghusl is obligatory after intercourse, even without ejaculation: the four schools agree, and consensus has been reported.'),
        'after_semen': leaf(466, 'clear', also: 'الدليل من القرآن',
            en: 'Ghusl is obligatory when semen is emitted while awake, in spurts with pleasure: the majority view (Hanafi, Maliki, Hanbali), with the Quran\'s «If you are in a state of janabah, purify yourselves» [al-Ma\'idah: 6].'),
        'after_bleeding': leaf(477, 'clear',
            en: 'Ghusl is obligatory when menstrual or postnatal bleeding ends.'),
        'none': {
          'kind': 'none',
          'url': 'https://dorar.net/feqhia/460',
          'source': 'الفصل الأوَّل: تعريف الغُسل، وموجِباتُه',
        },
      },
    },
    {
      'id': 'wudu',
      'title': 'هل انتقض وضوؤك؟',
      'titleEn': 'Has your wudu been broken?',
      'subtitle': 'أسئلة قصيرة بنعم أو لا عمّا حدث منذ توضأت',
      'subtitleEn': 'A few yes-or-no questions about what happened since your wudu',
      'start': 'toilet',
      'nodes': {
        'toilet': {
          'q': 'هل خرج منك بول أو غائط؟',
          'qEn': 'Did you pass urine or stool?',
          'yes': 'urine',
          'no': 'wind',
        },
        'wind': {
          'q': 'هل خرجت منك ريح؟',
          'qEn': 'Did you pass wind?',
          'yes': 'passed_wind',
          'no': 'touch',
        },
        'touch': {
          'q': 'هل مسستَ فرجك بيدك مباشرة، بلا حائل؟',
          'qEn': 'Did you touch your private part with your hand, with nothing in between?',
          'yes': 'touch_who',
          'no': 'camel',
        },
        'touch_who': {
          'q': 'من الذي مسّ؟',
          'qEn': 'Who touched?',
          'options': [
            {'label': 'رجل مسّ ذكره', 'labelEn': 'A man, his private part', 'to': 'touch_man'},
            {'label': 'امرأة مسّت فرجها', 'labelEn': 'A woman, her private part', 'to': 'touch_woman'},
          ],
        },
        'camel': {
          'q': 'هل أكلتَ لحم إبل؟',
          'qEn': 'Did you eat camel meat?',
          'yes': 'ate_camel',
          'no': 'none',
        },
        'urine': leaf(397, 'clear', also: 'الإجماع',
            en: 'Passing urine or stool from its usual outlet breaks wudu; consensus on this has been reported.'),
        'passed_wind': leaf(399, 'clear', also: 'الإجماع',
            en: 'Passing wind breaks wudu; consensus on this has been reported.'),
        'touch_man': leaf(422, 'khilaf',
            en: 'Scholars differ: the majority (Maliki, Shafi\'i, Hanbali) hold that a man touching his private part without a barrier breaks wudu; the Hanafis hold that it does not.'),
        'touch_woman': leaf(424, 'khilaf',
            en: 'Scholars differ: the Hanafis, the Malikis and one report from Ahmad hold that it does not break wudu; the Shafi\'is and the Hanbalis hold that it does.'),
        'ate_camel': leaf(446, 'khilaf',
            en: 'Scholars differ: the majority hold that eating camel meat does not break wudu; the Hanbalis hold that it does.'),
        'none': {
          'kind': 'none',
          'url': 'https://dorar.net/feqhia/393',
          'source': 'الفصل الأوَّل: تعريفُ نواقض الوضوء، وما يَنقُض الوضوء وما لا يَنقُضه',
        },
      },
    },
  ];

  // Every branch must lead to a node that exists.
  for (final g in guides) {
    final nodes = g['nodes'] as Map<String, dynamic>;
    for (final MapEntry(key: id, value: n) in nodes.entries) {
      final targets = [n['yes'], n['no'], for (final o in (n['options'] as List? ?? const [])) o['to']].whereType<String>();
      for (final t in targets) {
        if (!nodes.containsKey(t)) throw StateError('${g['id']}/$id → $t: no such node');
      }
    }
  }

  File('../assets/kb/guides.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
    '_note': 'Generated by server/tool/build_guides.dart. Every answer is copied verbatim from the question-and-answer summary of its page in الموسوعة الفقهية (dorar.net/feqhia); "en" is the team\'s English summary of it.',
    'guides': guides,
  }));
  stdout.writeln('assets/kb/guides.json written');
}
