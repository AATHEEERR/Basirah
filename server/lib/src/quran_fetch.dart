import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Builds the Quran dataset (`data/quran.json`): the full Quran text
/// (Uthmani, KFGQPC Hafs, as served by the Quran.com API) in Uthmani and
/// simple (imlaei) script, plus al-Tafsir al-Muyassar for every verse (a
/// search-index aid only — never shown or cited).
/// Basirah searches it to find candidate verses; Tafsir al-Tabari is fetched
/// per verse at answer time. About 350 requests, ~15 s.
const _api = 'https://api.quran.com/api/v4';
const _muyassarId = 16;

final _client = http.Client();

Future<Map<String, dynamic>> _get(String path) async {
  for (var attempt = 1; ; attempt++) {
    try {
      final res = await _client
          .get(Uri.parse('$_api$path'), headers: {'user-agent': 'basirah-dataset-builder/1.0'})
          .timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      throw HttpException('HTTP ${res.statusCode} for $path');
    } on Exception catch (e) {
      if (attempt >= 4) rethrow;
      stderr.writeln('  retry $attempt: $e');
      await Future<void>.delayed(Duration(seconds: 2 * attempt));
    }
  }
}

final _tags = RegExp(r'<[^>]+>');
String _clean(String html) => html
    .replaceAll(RegExp(r'</p>\s*'), '\n')
    .replaceAll(_tags, '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll(RegExp(r'[ \t]+'), ' ')
    .replaceAll(RegExp(r'\n\s*\n+'), '\n')
    .trim();

const _hilaliKhanId = 203;

String _cleanTranslation(String s) => s
    .replaceAll(RegExp(r'<sup[^>]*>.*?</sup>'), '')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .trim();

Future<Map<String, dynamic>> _chapter(int n) async {
  final uthmani = await _get('/quran/verses/uthmani?chapter_number=$n');
  final imlaei = await _get('/quran/verses/imlaei?chapter_number=$n');
  final tafsir = <String, String>{};
  for (var page = 1; ; page++) {
    final t = await _get('/tafsirs/$_muyassarId/by_chapter/$n?per_page=50&page=$page');
    for (final row in (t['tafsirs'] as List).cast<Map<String, dynamic>>()) {
      tafsir[row['verse_key'] as String] = _clean(row['text'] as String);
    }
    if ((t['pagination'] as Map)['next_page'] == null) break;
  }
  final simple = {
    for (final v in (imlaei['verses'] as List).cast<Map<String, dynamic>>())
      v['verse_key'] as String: (v['text_imlaei'] as String).trim(),
  };
  // English meanings: The Noble Quran (al-Hilali & Khan, King Fahd Complex).
  // The chapter endpoint lists verses in order without keys; check the count.
  final english = ((await _get('/quran/translations/$_hilaliKhanId?chapter_number=$n'))['translations'] as List)
      .cast<Map<String, dynamic>>()
      .map((t) => _cleanTranslation(t['text'] as String))
      .toList();
  final verseCount = (uthmani['verses'] as List).length;
  if (english.length != verseCount) {
    throw StateError('surah $n: ${english.length} translations for $verseCount verses');
  }
  // al-Muyassar sometimes explains 2–3 consecutive verses in one entry keyed
  // by the first; later verses of the group inherit it ('g' = group start).
  var groupKey = '';
  var groupText = '';
  return {
    'verses': [
      for (final v in (uthmani['verses'] as List).cast<Map<String, dynamic>>())
        () {
          final k = v['verse_key'] as String;
          final own = (tafsir[k] ?? '').trim();
          if (own.isNotEmpty) {
            groupKey = k;
            groupText = own;
          }
          final ayah = int.parse(k.split(':')[1]);
          return {
            'k': k,
            'u': (v['text_uthmani'] as String).trim(),
            'i': simple[k] ?? '',
            'm': own.isNotEmpty ? own : groupText,
            if (own.isEmpty && groupKey.isNotEmpty) 'g': groupKey,
            'e': english[ayah - 1],
          };
        }(),
    ],
  };
}

/// Downloads the dataset to [outPath]. Returns a one-line summary.
Future<String> fetchQuranDataset(String outPath, {void Function(String)? progress}) async {
  final out = File(outPath);
  final chapters = (await _get('/chapters?language=ar'))['chapters'] as List;
  final surahs = [
    for (final c in chapters.cast<Map<String, dynamic>>())
      {'n': c['id'], 'name': c['name_arabic'], 'en': c['name_simple'], 'count': c['verses_count']},
  ];

  final results = List<Map<String, dynamic>?>.filled(115, null);
  var next = 1;
  Future<void> worker() async {
    while (next <= 114) {
      final n = next++;
      results[n] = await _chapter(n);
      progress?.call('surah $n/114');
    }
  }

  await Future.wait([for (var i = 0; i < 4; i++) worker()]);
  final verses = [for (var n = 1; n <= 114; n++) ...(results[n]!['verses'] as List)];
  final missingTafsir = verses.where((v) => (v as Map)['m'] == '').length;
  if (verses.length != 6236) {
    throw StateError('Expected 6236 verses, got ${verses.length}');
  }

  out.parent.createSync(recursive: true);
  out.writeAsStringSync(jsonEncode({
    'source': {
      'text': 'Quran.com API v4 — text_uthmani (KFGQPC Uthmani Hafs) and text_imlaei',
      'tafsir': 'التفسير الميسر — مجمع الملك فهد لطباعة المصحف الشريف (Quran.com tafsir id $_muyassarId)',
      'english': 'The Noble Quran — al-Hilali & Khan, King Fahd Complex (Quran.com translation id $_hilaliKhanId)',
      'fetched': DateTime.now().toUtc().toIso8601String(),
    },
    'surahs': surahs,
    'verses': verses,
  }));
  return 'Wrote ${out.path}: ${verses.length} verses, ${surahs.length} surahs'
      '${missingTafsir == 0 ? '' : ', $missingTafsir verses without tafsir'} '
      '(${(out.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB)';
}
