import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Builds the Quran dataset (`data/quran.json`) from the sources the
/// approved reference names:
///
/// * **QuranEnc** (quranenc.com, جمعية خدمة المحتوى الإسلامي باللغات):
///   the Mushaf text — King Fahd Complex, Hafs (`arabic_text`, what the app
///   shows); the English meanings — The Noble Quran, al-Hilali & Khan, King
///   Fahd Complex (`english_hilali_khan`); and al-Tafsir al-Muyassar
///   (`arabic_moyassar`), used only as a search index — never shown, cited
///   or given to the model.
/// * **Quranpedia** (quranpedia.net, mushaf 1: مصحف حفص — مجمع الملك فهد): the
///   same verses in modern (imlaei) spelling, used only to search and to match
///   wording; and the Arabic surah names.
///
/// Basirah searches it to find candidate verses; the tafsir (موسوعة التفسير,
/// الدرر السنية) is read per verse at answer time. About 345 requests.
const _quranEnc = 'https://quranenc.com/api/v1';
const _quranpedia = 'https://api.quranpedia.net/v1';

final _client = http.Client();

Future<Object?> _get(String url) async {
  for (var attempt = 1; ; attempt++) {
    try {
      final res = await _client
          .get(Uri.parse(url), headers: {'user-agent': 'basirah-dataset-builder/2.0'})
          .timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) return jsonDecode(utf8.decode(res.bodyBytes));
      throw HttpException('HTTP ${res.statusCode} for $url');
    } on Exception catch (e) {
      if (attempt >= 5) rethrow;
      stderr.writeln('  retry $attempt: $e');
      await Future<void>.delayed(Duration(seconds: 3 * attempt));
    }
  }
}

Future<List<Map<String, dynamic>>> _quranEncSura(String key, int n) async =>
    (((await _get('$_quranEnc/translation/sura/$key/$n')) as Map)['result'] as List).cast<Map<String, dynamic>>();

/// «3. Who believe in the Ghaib [1] and …» → «Who believe in the Ghaib and …»:
/// the verse number and the footnote markers go; the translators' own
/// bracketed explanations stay.
String cleanEnglish(String s) => s
    .replaceFirst(RegExp(r'^\s*\d+\.\s*'), '')
    .replaceAll(RegExp(r'\s*\[\d+\]'), '')
    .replaceAll(RegExp(r'\s{2,}'), ' ')
    .trim();

String _plain(String s) => s.replaceAll('﻿', '').replaceAll(RegExp(r'\s+'), ' ').trim();

Future<Map<String, dynamic>> _chapter(int n, int count) async {
  final english = await _quranEncSura('english_hilali_khan', n);
  final muyassar = await _quranEncSura('arabic_moyassar', n);
  final imlaei = ((await _get('$_quranpedia/mushafs/1/$n')) as List).cast<Map<String, dynamic>>();
  if (english.length != count || muyassar.length != count || imlaei.length != count) {
    throw StateError('surah $n: expected $count verses, got ${english.length}/${muyassar.length}/${imlaei.length}');
  }
  String key(Map<String, dynamic> v, String field) => '$n:${v[field]}';
  final gloss = {for (final v in muyassar) key(v, 'aya'): _plain(v['translation'] as String? ?? '')};
  final simple = {for (final v in imlaei) key(v, 'number'): _plain(v['text'] as String)};
  // al-Muyassar sometimes explains 2–3 consecutive verses in one entry keyed
  // by the first; later verses of the group inherit it ('g' = group start).
  var groupKey = '';
  var groupText = '';
  return {
    'verses': [
      for (final v in english)
        () {
          final k = key(v, 'aya');
          final arabic = _plain(v['arabic_text'] as String);
          final own = gloss[k] ?? '';
          if (own.isNotEmpty) {
            groupKey = k;
            groupText = own;
          }
          return {
            'k': k,
            'u': arabic,
            'i': simple[k] ?? '',
            'm': own.isNotEmpty ? own : groupText,
            if (own.isEmpty && groupKey.isNotEmpty) 'g': groupKey,
            'e': cleanEnglish(v['translation'] as String? ?? ''),
          };
        }(),
    ],
  };
}

/// Downloads the dataset to [outPath]. Returns a one-line summary.
Future<String> fetchQuranDataset(String outPath, {void Function(String)? progress}) async {
  final out = File(outPath);
  final list = ((await _get('$_quranpedia/surahs')) as List).cast<Map<String, dynamic>>();
  if (list.length != 114) throw StateError('Expected 114 surahs, got ${list.length}');
  final surahs = [
    for (final s in list)
      {
        'n': s['id'],
        'name': surahLabel(s['translated_name'] as String),
        'en': _surahNamesEn[(s['id'] as int) - 1],
        'count': s['number_of_ayahs'],
      },
  ];

  final results = List<Map<String, dynamic>?>.filled(115, null);
  var next = 1;
  // Two workers keep Quranpedia well under its 120 requests a minute.
  Future<void> worker() async {
    while (next <= 114) {
      final n = next++;
      results[n] = await _chapter(n, surahs[n - 1]['count'] as int);
      progress?.call('surah $n/114');
    }
  }

  await Future.wait([worker(), worker()]);
  final verses = [for (var n = 1; n <= 114; n++) ...(results[n]!['verses'] as List)];
  if (verses.length != 6236) throw StateError('Expected 6236 verses, got ${verses.length}');
  final missingSimple = verses.where((v) => (v as Map)['i'] == '').length;
  if (missingSimple > 0) throw StateError('$missingSimple verses without modern spelling');
  final missingGloss = verses.where((v) => (v as Map)['m'] == '').length;

  out.parent.createSync(recursive: true);
  out.writeAsStringSync(jsonEncode({
    'source': {
      'text': 'QuranEnc (quranenc.com) — arabic_text: King Fahd Complex Mushaf, Hafs',
      'imlaei': 'Quranpedia (quranpedia.net) — mushaf 1 (مصحف حفص — مجمع الملك فهد), modern spelling; search and matching only',
      'tafsir': 'التفسير الميسر — مجمع الملك فهد، via QuranEnc arabic_moyassar; search index only',
      'english': 'The Noble Quran — al-Hilali & Khan, King Fahd Complex, via QuranEnc english_hilali_khan',
      'fetched': DateTime.now().toUtc().toIso8601String(),
    },
    'surahs': surahs,
    'verses': verses,
  }));
  return 'Wrote ${out.path}: ${verses.length} verses, ${surahs.length} surahs'
      '${missingGloss == 0 ? '' : ', $missingGloss verses without al-Muyassar'} '
      '(${(out.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB)';
}

/// Transliterated surah names for the English interface (labels only; the
/// sources above give the Arabic names).
const _surahNamesEn = [
  "Al-Fatihah", "Al-Baqarah", "Ali 'Imran", "An-Nisa", "Al-Ma'idah", "Al-An'am",
  "Al-A'raf", "Al-Anfal", "At-Tawbah", "Yunus", "Hud", "Yusuf",
  "Ar-Ra'd", "Ibrahim", "Al-Hijr", "An-Nahl", "Al-Isra", "Al-Kahf",
  "Maryam", "Taha", "Al-Anbya", "Al-Hajj", "Al-Mu'minun", "An-Nur",
  "Al-Furqan", "Ash-Shu'ara", "An-Naml", "Al-Qasas", "Al-'Ankabut", "Ar-Rum",
  "Luqman", "As-Sajdah", "Al-Ahzab", "Saba", "Fatir", "Ya-Sin",
  "As-Saffat", "Sad", "Az-Zumar", "Ghafir", "Fussilat", "Ash-Shuraa",
  "Az-Zukhruf", "Ad-Dukhan", "Al-Jathiyah", "Al-Ahqaf", "Muhammad", "Al-Fath",
  "Al-Hujurat", "Qaf", "Adh-Dhariyat", "At-Tur", "An-Najm", "Al-Qamar",
  "Ar-Rahman", "Al-Waqi'ah", "Al-Hadid", "Al-Mujadila", "Al-Hashr", "Al-Mumtahanah",
  "As-Saf", "Al-Jumu'ah", "Al-Munafiqun", "At-Taghabun", "At-Talaq", "At-Tahrim",
  "Al-Mulk", "Al-Qalam", "Al-Haqqah", "Al-Ma'arij", "Nuh", "Al-Jinn",
  "Al-Muzzammil", "Al-Muddaththir", "Al-Qiyamah", "Al-Insan", "Al-Mursalat", "An-Naba",
  "An-Nazi'at", "'Abasa", "At-Takwir", "Al-Infitar", "Al-Mutaffifin", "Al-Inshiqaq",
  "Al-Buruj", "At-Tariq", "Al-A'la", "Al-Ghashiyah", "Al-Fajr", "Al-Balad",
  "Ash-Shams", "Al-Layl", "Ad-Duhaa", "Ash-Sharh", "At-Tin", "Al-'Alaq",
  "Al-Qadr", "Al-Bayyinah", "Az-Zalzalah", "Al-'Adiyat", "Al-Qari'ah", "At-Takathur",
  "Al-'Asr", "Al-Humazah", "Al-Fil", "Quraysh", "Al-Ma'un", "Al-Kawthar",
  "Al-Kafirun", "An-Nasr", "Al-Masad", "Al-Ikhlas", "Al-Falaq", "An-Nas",
];

/// A surah name as a label: Quranpedia writes some names with vowel marks
/// («النّور») and others without; labels drop them (hamza forms stay).
String surahLabel(String name) => name.replaceAll(RegExp('[ً-ْ]'), '').trim();
