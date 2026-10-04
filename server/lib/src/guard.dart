import 'package:basirah_core/basirah_core.dart';

import 'hadith.dart';
import 'quran.dart';
import 'tafsir.dart';

/// What the guard changed, for logs and the evaluation report.
class GuardReport {
  final List<String> actions = [];
  void add(String a) => actions.add(a);
  bool get clean => actions.isEmpty;
}

final _quranQuote = RegExp('﴿([^﴾]*)﴾');
final _guillemets = RegExp('«([^»]*)»');

/// Turns the model's `submit_answer` input into a [BasirahAnswer] and
/// enforces the reference pack's rules deterministically:
///
/// * a Quran citation must be a real verse whose tafsir (موسوعة التفسير in
///   الدرر السنية) the model read in this run; its text is taken from the
///   KFGQPC dataset, never the model, and the tafsir shown under it is the
///   source's own wording;
/// * hadith citations must come from the verified registry;
/// * no Quran wording typed by the model reaches the prose (see below);
/// * an "answer" with no grounding (no evidence, no reference answer) or with
///   low confidence becomes "abstain" — and an abstention shows no verse and
///   no hadith: evidence next to "no reliable answer" would look like support;
/// * level D can never be answered — it becomes "refer".
BasirahAnswer guardAnswer({
  required Map<String, dynamic> raw,
  required String question,
  required KnowledgeBase kb,
  required String model,
  required SafetySignals signals,
  required GuardReport report,
  QuranLibrary? quran,
  Set<String> readRefs = const {},
  String? Function(String key)? tafsirText,
  TafsirSource? tafsirSource,
  Map<String, HadithFound> hadithRead = const {},
  List<String> research = const [],
}) {
  // [kb] is localized to the answer's language: fixed texts, hadith meanings
  // and surah names follow it.
  final t = RouterTexts.of(kb.lang);
  final en = kb.lang == 'en';
  var kind = AnswerKind.parse(raw['kind'] as String?);
  final level = ContentLevel.parse(raw['level'] as String?);
  final confidence = (raw['confidence'] as String?) ?? 'low';

  // ── Quran evidence: real verse + tafsir read in this run ──
  final quranEvidence = <Evidence>[];
  final seen = <String>{};
  for (final item in (raw['quran'] as List? ?? const [])) {
    if (item is! Map) continue;
    final ref = item['ref']?.toString() ?? '';
    final key = quran?.parseRef(ref);
    if (key == null) {
      report.add('dropped unknown verse ref $ref');
      continue;
    }
    if (!readRefs.contains(key)) {
      report.add('dropped $key: cited without reading its tafsir');
      continue;
    }
    if (!seen.add(key) || quranEvidence.length >= 3) continue;
    final v = quran!.verse(key)!;
    final why = _plain(item['why']?.toString() ?? '');
    // The tafsir source's own words, verbatim (Arabic), in the Arabic
    // interface; the English interface shows the King Fahd Complex
    // translation of the meaning instead.
    final shown = en ? null : tafsirSource?.shownUnder(key, tafsirText?.call(key), v.simple);
    quranEvidence.add(Evidence(
      id: 'q:$key',
      kind: EvidenceKind.quran,
      text: v.uthmani,
      surah: v.surah,
      surahName: quran.surahName(v.surah, lang: kb.lang),
      ayah: '${v.ayah}',
      tafsir: shown?.text,
      tafsirSource: shown?.label,
      tafsirUrl: tafsirSource?.urlFor(key),
      note: why.isEmpty ? null : why,
      translation: en && v.english.isNotEmpty ? v.english : null,
      translationSource: en && v.english.isNotEmpty ? KnowledgeBase.quranTranslationSource : null,
    ));
  }

  // ── Hadith: read from HadeethEnc in this run, or from the registry —
  // each with the model's reason for citing it. Text, source, grade and
  // explanation come from the publisher's record, never from the model.
  // A hadith cited without saying what it supports is dropped: that is how
  // unrelated citations (e.g. the pillars of Islam in an answer about
  // Maryam) are kept out.
  final registryEvidence = <Evidence>[];
  final seenHadith = <String>{};
  for (final item in (raw['hadith'] as List? ?? const [])) {
    if (item is! Map) continue;
    final id = item['id']?.toString() ?? '';
    final why = _plain(item['why']?.toString() ?? '');
    final found = hadithRead[id];
    final e = found != null ? _hadeethEncEvidence(found, en) : kb.evidence[id];
    if (e == null || e.isQuran) {
      report.add('dropped unknown hadith id $id');
      continue;
    }
    if (why.length < 8) {
      report.add('dropped $id: cited without a reason');
      continue;
    }
    if (seenHadith.add(id) && registryEvidence.length < 3) registryEvidence.add(e.copyWith(note: why));
  }

  final entryIds = [
    for (final id in (raw['basedOnEntries'] as List? ?? const []))
      if (kb.entry(id.toString()) != null) id.toString(),
  ];

  // ── Quotation check on prose ──
  // Verse text is shown only in the evidence cards, copied from the Mushaf.
  // A verse the model quotes in the prose is replaced by its reference (when
  // the words belong to exactly one verse), so no verse wording typed by the
  // model reaches the reader.
  final registryTexts = [
    for (final e in kb.evidence.values)
      if (!e.isQuran) normalizeArabic(e.text).replaceAll(' ', ''),
    for (final f in hadithRead.values) normalizeArabic(f.arabic.text).replaceAll(' ', ''),
  ];
  bool inRegistry(String inner) {
    final c = normalizeArabic(inner).replaceAll(' ', '');
    return c.length >= 6 && registryTexts.any((t) => t.contains(c));
  }

  String refOf(String key) {
    final v = quran!.verse(key)!;
    final name = quran.surahName(v.surah, lang: kb.lang);
    return en ? '($name ${v.key})' : '($name: ${v.ayah})';
  }

  String? verseRef(String inner) {
    final keys = quran?.locateQuote(inner) ?? const <String>[];
    return keys.length == 1 ? refOf(keys.single) : null;
  }

  // Quran text written without quotation marks — six or more words in a row,
  // within a verse or across neighbouring verses, as when the model obeys
  // «write the surah from memory» — is replaced by its reference, or removed
  // when the same words occur in several surahs.
  String stripVerseRuns(String s) {
    if (quran == null || s.isEmpty) return s;
    final words = s.split(RegExp(r'\s+'));
    final runs = quran.verseRuns(words);
    if (runs.isEmpty) return s;
    final out = <String>[];
    var i = 0;
    for (final r in runs) {
      out.addAll(words.sublist(i, r.start));
      if (r.spans.length == 1) {
        final sp = r.spans.single;
        final name = quran.surahName(sp.surah, lang: kb.lang);
        final ayat = sp.from == sp.to ? '${sp.from}' : '${sp.from}–${sp.to}';
        out.add(en ? '($name ${sp.surah}:$ayat)' : '($name: $ayat)');
      }
      report.add('replaced unquoted Quran wording (${r.spans.map((sp) => '${sp.surah}:${sp.from}').join(', ')})');
      i = r.end;
    }
    out.addAll(words.sublist(i));
    return out.join(' ');
  }

  String clean(Object? v) {
    var s = (v as String?)?.trim() ?? '';
    s = s.replaceAllMapped(_quranQuote, (m) {
      final ref = verseRef(m[1]!);
      report.add(ref == null ? 'removed Quran quotation' : 'replaced Quran quotation with its reference');
      return ref ?? '';
    });
    // Registry text keeps its « »; verse text becomes its reference; any
    // other text in « » stays as plain text, never as a quotation.
    s = s.replaceAllMapped(_guillemets, (m) {
      final inner = m[1]!;
      if (inner.trim().isEmpty) return '';
      if (inRegistry(inner)) return m[0]!;
      final ref = verseRef(inner);
      if (ref != null) report.add('replaced Quran quotation with its reference');
      return ref ?? inner;
    });
    s = stripVerseRuns(s);
    return s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  var principle = clean(raw['principle']);
  final culture = clean(raw['culture']);
  var guidance = [
    for (final g in (raw['guidance'] as List? ?? const [])) clean(g),
  ].where((g) => g.isNotEmpty).take(5).toList();
  var khilafAgreed = clean(raw['khilafAgreed']);
  var khilafNote = clean(raw['khilafNote']);
  var referReason = clean(raw['referReason']);
  var referTo = clean(raw['referTo']);
  var abstainReason = clean(raw['abstainReason']);

  final evidence = [...quranEvidence, ...registryEvidence];

  // ── Kind enforcement ──
  if (kind == AnswerKind.offTopic) {
    // Not about Islam: never answered, nothing cited.
    return BasirahAnswer(
      question: question,
      kind: AnswerKind.offTopic,
      level: ContentLevel.b,
      origin: AnswerOrigin.ai,
      abstainReason: abstainReason.isEmpty ? t.offTopicReason : abstainReason,
      guidance: t.offTopicGuidance,
      review: 'generated',
      model: model,
      research: research,
    );
  }
  // A referral forced here overrides an answer the model wrote for a case it
  // should not have answered (for example after an instruction in the
  // question talked it into a fatwa): none of that text is kept.
  var forcedRefer = false;
  if (level == ContentLevel.d && kind != AnswerKind.refer && kind != AnswerKind.abstain) {
    report.add('level D forced to refer');
    kind = AnswerKind.refer;
    forcedRefer = true;
  }
  if (signals.personalCase && kind == AnswerKind.answer && entryIds.isEmpty) {
    report.add('personal case without curated backing forced to refer');
    kind = AnswerKind.refer;
    forcedRefer = true;
  }
  if (forcedRefer) {
    principle = '';
    guidance = const [];
    referReason = referTo = '';
  }
  if (kind == AnswerKind.answer && evidence.isEmpty && entryIds.isEmpty) {
    report.add('ungrounded answer forced to abstain');
    kind = AnswerKind.abstain;
  }
  if (kind == AnswerKind.answer && confidence == 'low') {
    report.add('low-confidence answer forced to abstain');
    kind = AnswerKind.abstain;
  }

  // No reliable answer, or a question that needs a specialist → no evidence:
  // whatever the model cited is dropped, so a verse or hadith never appears
  // to settle a question Basirah does not answer.
  final citesNothing = kind == AnswerKind.abstain || kind == AnswerKind.refer;
  if (citesNothing && evidence.isNotEmpty) {
    report.add('${kind.name}: dropped ${evidence.length} cited item(s)');
  }

  switch (kind) {
    case AnswerKind.refer:
      if (referReason.isEmpty) referReason = t.referReason;
      if (referTo.isEmpty) referTo = t.referTo;
      if (guidance.isEmpty) guidance = t.referGuidance;
      khilafAgreed = khilafNote = abstainReason = '';
    case AnswerKind.abstain:
      if (abstainReason.isEmpty) {
        abstainReason = signals.hadithRequest ? t.hadithReason : t.abstainReason;
      }
      if (guidance.isEmpty) guidance = t.abstainGuidance;
      principle = '';
      khilafAgreed = khilafNote = referReason = referTo = '';
    case AnswerKind.khilaf:
      if (khilafNote.isEmpty) khilafNote = t.khilafFallback;
      referReason = referTo = abstainReason = '';
    case AnswerKind.answer:
      khilafAgreed = khilafNote = referReason = referTo = abstainReason = '';
    case AnswerKind.offTopic:
      break; // handled above
  }

  return BasirahAnswer(
    question: question,
    kind: kind,
    // The pack's levels: a referral is level D; stating a scholarly difference
    // is level C handling («بيان وجود الخلاف»).
    level: switch (kind) {
      AnswerKind.refer => ContentLevel.d,
      AnswerKind.khilaf => ContentLevel.c,
      _ => level,
    },
    origin: AnswerOrigin.ai,
    principle: principle,
    culture: kind == AnswerKind.abstain || forcedRefer ? '' : culture,
    guidance: guidance,
    khilafAgreed: khilafAgreed,
    khilafNote: khilafNote,
    referReason: referReason,
    referTo: referTo,
    abstainReason: abstainReason,
    evidence: citesNothing ? const [] : evidence,
    entryId: entryIds.isEmpty ? null : entryIds.first,
    related: entryIds.skip(1).take(3).toList(),
    review: 'generated',
    model: model,
    research: research,
  );
}

String _plain(String s) =>
    s.replaceAll(RegExp('[﴿﴾]'), '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
/// A HadeethEnc hadith as evidence: the Arabic narration verbatim; source
/// and grade as HadeethEnc recorded them (in English for an English answer);
/// HadeethEnc's explanation shown under it and linked; its key phrase used
/// for the الدرر السنية verification link.
Evidence _hadeethEncEvidence(HadithFound f, bool en) {
  final shown = en ? (f.local ?? f.arabic) : f.arabic;
  return Evidence(
    id: f.id,
    kind: EvidenceKind.hadith,
    text: f.arabic.text,
    source: shown.attribution,
    grade: shown.grade,
    search: f.arabic.title,
    tafsir: _shortExplanation(shown.explanation),
    tafsirSource: en ? 'Explanation — HadeethEnc (Encyclopedia of Translated Prophetic Hadiths)' : 'شرح موسوعة الأحاديث النبوية',
    tafsirUrl: shown.url,
    translation: en && f.local != null ? f.local!.text : null,
    translationSource: en && f.local != null ? 'Approved translation — HadeethEnc' : null,
  );
}

String? _shortExplanation(String s, {int max = 420}) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return null;
  if (t.length <= max) return t;
  final cut = [t.lastIndexOf('.', max), t.lastIndexOf('،', max), t.lastIndexOf('؛', max)].reduce((a, b) => a > b ? a : b);
  return '${t.substring(0, cut > max * .5 ? cut + 1 : max).trim()} …';
}
