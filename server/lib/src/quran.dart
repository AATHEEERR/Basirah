import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:basirah_core/basirah_core.dart';

/// One verse of the full Quran dataset (`data/quran.json`).
class Verse {
  Verse({
    required this.surah,
    required this.ayah,
    required this.uthmani,
    required this.simple,
    required this.muyassar,
    this.groupStart,
    this.english = '',
  });

  final int surah;
  final int ayah;

  /// KFGQPC Uthmani Hafs text — what the app displays.
  final String uthmani;

  /// Simple (imlaei) script — used for matching quotations and search.
  final String simple;

  /// al-Tafsir al-Muyassar (King Fahd Complex) for this verse — used only
  /// to index the verse for search. It is never shown, cited or given to
  /// the model: the tafsir Basirah reads and shows is موسوعة التفسير (الدرر السنية).
  final String muyassar;

  /// When al-Muyassar explains this verse together with earlier ones, the
  /// key of the first verse of that group.
  final String? groupStart;

  /// English meaning: The Noble Quran (al-Hilali & Khan, King Fahd Complex).
  final String english;

  String get key => '$surah:$ayah';
}

/// A search hit over the Quran.
class VerseHit {
  const VerseHit(this.verse, this.score);
  final Verse verse;
  final double score;
}

/// The whole Quran, plus a BM25 index over each verse's text and a
/// plain-language gloss of it (al-Muyassar). The gloss lets a concept
/// («زيارة الأهل غير المسلمين») reach the verse that expresses it in Quranic
/// wording («أن تبروهم وتقسطوا إليهم»). It is a search aid only: what the
/// model reads, and what the app shows, is the verse and Dorar's tafsir.
class QuranLibrary {
  QuranLibrary._(this.verses, this.surahNames, this.source, [this.surahNamesEn = const {}]) {
    for (final v in verses) {
      _byKey[v.key] = v;
    }
    _buildIndex();
  }

  final List<Verse> verses;
  final Map<int, String> surahNames;
  final Map<int, String> surahNamesEn;
  final Map<String, dynamic> source;
  final _byKey = <String, Verse>{};

  static QuranLibrary? tryLoad(String path) {
    final f = File(path);
    if (!f.existsSync()) return null;
    final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    return fromJson(j);
  }

  static QuranLibrary fromJson(Map<String, dynamic> j) {
    final names = {
      for (final s in (j['surahs'] as List).cast<Map<String, dynamic>>())
        s['n'] as int: s['name'] as String,
    };
    final verses = <Verse>[
      for (final v in (j['verses'] as List).cast<Map<String, dynamic>>())
        () {
          final parts = (v['k'] as String).split(':');
          return Verse(
            surah: int.parse(parts[0]),
            ayah: int.parse(parts[1]),
            uthmani: v['u'] as String,
            simple: (v['i'] as String?) ?? '',
            muyassar: (v['m'] as String?) ?? '',
            groupStart: v['g'] as String?,
            english: (v['e'] as String?) ?? '',
          );
        }(),
    ];
    final namesEn = {
      for (final s in (j['surahs'] as List).cast<Map<String, dynamic>>())
        if (s['en'] != null) s['n'] as int: s['en'] as String,
    };
    return QuranLibrary._(verses, names, (j['source'] as Map<String, dynamic>?) ?? const {}, namesEn);
  }

  int get length => verses.length;

  Verse? verse(String key) => _byKey[key];

  String surahName(int n, {String lang = 'ar'}) =>
      (lang == 'en' ? surahNamesEn[n] : null) ?? surahNames[n] ?? '$n';

  static final _eastern = RegExp('[٠-٩]');
  static final _refPattern = RegExp(r'^\s*(\d{1,3})\s*[:/\-.،,]\s*(\d{1,3})\s*$');

  /// Parses «60:8», «٦٠:٨», «60/8» into a canonical key, or null.
  String? parseRef(String ref) {
    final latin = ref.replaceAllMapped(_eastern, (m) => '${m[0]!.codeUnitAt(0) - 0x0660}');
    final m = _refPattern.firstMatch(latin);
    if (m == null) return null;
    final key = '${int.parse(m[1]!)}:${int.parse(m[2]!)}';
    return _byKey.containsKey(key) ? key : null;
  }

  // ─── Quotation check ─────────────────────────────────────────────────────

  static String _compact(String s) => normalizeArabic(s).replaceAll(' ', '');

  late final List<String> _compactSimple = [for (final v in verses) _compact(v.simple)];
  late final List<String> _compactUthmani = [for (final v in verses) _compact(v.uthmani)];

  /// True when [quote] (at least a few words) appears verbatim, ignoring
  /// diacritics and spacing, inside a single verse.
  bool containsQuote(String quote) {
    final q = _compact(quote);
    if (q.length < 6) return false;
    for (var i = 0; i < verses.length; i++) {
      if (_compactSimple[i].contains(q) || _compactUthmani[i].contains(q)) return true;
    }
    return false;
  }

  /// The verse keys whose text contains [quote].
  List<String> locateQuote(String quote) {
    final q = _compact(quote);
    if (q.length < 6) return const [];
    return [
      for (var i = 0; i < verses.length; i++)
        if (_compactSimple[i].contains(q) || _compactUthmani[i].contains(q)) verses[i].key,
    ];
  }

  late final List<_SurahText> _surahTexts = () {
    final out = <_SurahText>[];
    for (var i = 0; i < verses.length; i++) {
      if (out.isEmpty || out.last.surah != verses[i].surah) out.add(_SurahText(verses[i].surah));
      out.last.add(i, _compactSimple[i], _compactUthmani[i]);
    }
    return out;
  }();

  /// Where [quote] (ignoring diacritics and spacing) occurs as consecutive
  /// Quran text — within one verse or running across neighbouring verses of
  /// one surah: one span per surah that contains it.
  List<({int surah, int from, int to})> locateSpan(String quote) {
    final q = _compact(quote);
    if (q.length < 6) return const [];
    final spans = <({int surah, int from, int to})>[];
    for (final s in _surahTexts) {
      for (final (text, offsets) in [(s.simple.toString(), s.offSimple), (s.uthmani.toString(), s.offUthmani)]) {
        final at = text.indexOf(q);
        if (at < 0) continue;
        int verseAt(int pos) {
          var k = 0;
          while (k + 1 < offsets.length && offsets[k + 1] <= pos) {
            k++;
          }
          return verses[s.verseIndexes[k]].ayah;
        }
        spans.add((surah: s.surah, from: verseAt(at), to: verseAt(at + q.length - 1)));
        break;
      }
    }
    return spans;
  }

  /// Runs of at least [minWords] consecutive words that are Quran text
  /// written without quotation marks (see [locateSpan]). `end` is exclusive.
  List<({int start, int end, List<({int surah, int from, int to})> spans})> verseRuns(
    List<String> words, {
    int minWords = 6,
  }) {
    final runs = <({int start, int end, List<({int surah, int from, int to})> spans})>[];
    var i = 0;
    while (i + minWords <= words.length) {
      var spans = locateSpan(words.sublist(i, i + minWords).join(' '));
      if (spans.isEmpty) {
        i++;
        continue;
      }
      var end = i + minWords;
      while (end < words.length) {
        final longer = locateSpan(words.sublist(i, end + 1).join(' '));
        if (longer.isEmpty) break;
        spans = longer;
        end++;
      }
      runs.add((start: i, end: end, spans: spans));
      i = end;
    }
    return runs;
  }

  // ─── Search: BM25 over stems + BM25 over character 4-grams ───────────────

  late final _Bm25 _stems;
  late final _Bm25 _grams;

  void _buildIndex() {
    _stems = _Bm25(verses.length);
    _grams = _Bm25(verses.length);
    for (var i = 0; i < verses.length; i++) {
      final v = verses[i];
      _stems.add(i, {
        for (final t in tokenize(v.simple)) t: 1.3,
      }, tokenize(v.muyassar));
      _grams.add(i, {
        for (final t in charGrams(v.simple)) t: 1.3,
      }, charGrams(v.muyassar));
    }
    _stems.finish();
    _grams.finish();
  }

  List<VerseHit> search(String query, {int limit = 8}) {
    final scores = <int, double>{};
    _stems.score(tokenize(query).toSet(), scores, 1.0);
    _grams.score(charGrams(query).toSet(), scores, .35);
    // Exact wording (e.g. a remembered phrase) is the strongest signal.
    final phrase = _compact(query);
    if (phrase.length >= 8) {
      for (var i = 0; i < verses.length; i++) {
        if (_compactSimple[i].contains(phrase) || _compactUthmani[i].contains(phrase)) {
          scores[i] = (scores[i] ?? 0) + 25;
        }
      }
    }
    final ranked = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in ranked.take(limit)) VerseHit(verses[e.key], e.value)];
  }
}

/// One surah's verses joined into a single compact string (simple and
/// Uthmani), with each verse's start offset, so a quotation running across
/// neighbouring verses can be located.
class _SurahText {
  _SurahText(this.surah);
  final int surah;
  final simple = StringBuffer();
  final uthmani = StringBuffer();
  final offSimple = <int>[];
  final offUthmani = <int>[];
  final verseIndexes = <int>[];

  void add(int index, String compactSimple, String compactUthmani) {
    verseIndexes.add(index);
    offSimple.add(simple.length);
    offUthmani.add(uthmani.length);
    simple.write(compactSimple);
    uthmani.write(compactUthmani);
  }
}

class _Bm25 {
  _Bm25(this.n);

  final int n;
  final _postings = <String, List<(int, double)>>{};
  final _len = <int, double>{};
  double _avg = 1;

  void add(int doc, Map<String, double> weighted, List<String> extra) {
    final tf = Map<String, double>.of(weighted);
    for (final t in extra) {
      tf[t] = (tf[t] ?? 0) + 1;
    }
    _len[doc] = tf.values.fold(0, (a, b) => a + b);
    tf.forEach((t, f) => _postings.putIfAbsent(t, () => []).add((doc, f)));
  }

  void finish() {
    final total = _len.values.fold<double>(0, (a, b) => a + b);
    _avg = _len.isEmpty ? 1 : total / _len.length;
  }

  void score(Set<String> terms, Map<int, double> into, double weight) {
    const k1 = 1.4, b = .72;
    for (final t in terms) {
      final list = _postings[t];
      if (list == null) continue;
      final idf = math.log(1 + (n - list.length + .5) / (list.length + .5));
      for (final (doc, f) in list) {
        final norm = f * (k1 + 1) / (f + k1 * (1 - b + b * _len[doc]! / _avg));
        into[doc] = (into[doc] ?? 0) + weight * idf * norm;
      }
    }
  }
}
