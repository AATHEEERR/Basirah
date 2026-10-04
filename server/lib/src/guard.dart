import 'package:basirah_core/basirah_core.dart';

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
/// * a Quran citation must be a real verse whose tafsir (al-Tabari) the
///   model read in this run; its text is taken from the KFGQPC dataset, never
///   the model, and the tafsir shown under it is al-Tabari's own wording;
/// * hadith citations must come from the verified registry;
/// * a ﴿…﴾ quotation in prose must match the Quran verbatim or it is removed;
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
  String Function(String key)? tafsirUrl,
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
    quranEvidence.add(Evidence(
      id: 'q:$key',
      kind: EvidenceKind.quran,
      text: v.uthmani,
      surah: v.surah,
      surahName: quran.surahName(v.surah, lang: kb.lang),
      ayah: '${v.ayah}',
      // Al-Tabari's own statement of the meaning, verbatim (Arabic), in the
      // Arabic interface; the English interface shows the King Fahd Complex
      // translation of the meaning instead.
      tafsir: en ? null : tabariSummary(tafsirText?.call(key)),
      tafsirSource: en ? null : tabariLabel,
      tafsirUrl: tafsirUrl?.call(key),
      note: why.isEmpty ? null : why,
      translation: en && v.english.isNotEmpty ? v.english : null,
      translationSource: en && v.english.isNotEmpty ? KnowledgeBase.quranTranslationSource : null,
    ));
  }

  // ── Hadith: registry only, each with the model's reason for citing it ──
  // A hadith cited without saying what it supports is dropped: that is how
  // unrelated citations (e.g. the pillars of Islam in an answer about
  // Maryam) are kept out.
  final registryEvidence = <Evidence>[];
  final seenHadith = <String>{};
  for (final item in (raw['hadith'] as List? ?? const [])) {
    if (item is! Map) continue;
    final id = item['id']?.toString() ?? '';
    final why = _plain(item['why']?.toString() ?? '');
    final e = kb.evidence[id];
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
  ];
  bool inRegistry(String inner) {
    final c = normalizeArabic(inner).replaceAll(' ', '');
    return c.length >= 6 && registryTexts.any((t) => t.contains(c));
  }

  String? verseRef(String inner) {
    final keys = quran?.locateQuote(inner) ?? const <String>[];
    if (keys.length != 1) return null;
    final v = quran!.verse(keys.single)!;
    final name = quran.surahName(v.surah, lang: kb.lang);
    return en ? '($name ${v.key})' : '($name: ${v.ayah})';
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
    return s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  var principle = clean(raw['principle']);
  final culture = clean(raw['culture']);
  var guidance = [
    for (final g in (raw['guidance'] as List? ?? const []))
      if (clean(g).isNotEmpty) clean(g),
  ].take(5).toList();
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
  if (level == ContentLevel.d && kind != AnswerKind.refer && kind != AnswerKind.abstain) {
    report.add('level D forced to refer');
    kind = AnswerKind.refer;
  }
  if (signals.personalCase && kind == AnswerKind.answer && entryIds.isEmpty) {
    report.add('personal case without curated backing forced to refer');
    kind = AnswerKind.refer;
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
    culture: kind == AnswerKind.abstain ? '' : culture,
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
