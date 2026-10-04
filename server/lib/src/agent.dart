import 'dart:convert';

import 'package:basirah_core/basirah_core.dart';

import 'llm.dart';
import 'prompt.dart';
import 'quran.dart';
import 'tafsir.dart';

/// Result of one live research run.
class AgentOutcome {
  AgentOutcome({
    required this.submitted,
    required this.readRefs,
    required this.tafsirRead,
    required this.research,
    required this.model,
    required this.usage,
    required this.rounds,
    this.refused = false,
  });

  /// The `submit_answer` input, or null (refusal / no submission).
  final Map<String, dynamic>? submitted;

  /// Verse keys whose tafsir the model actually read in this run.
  final Set<String> readRefs;

  /// The al-Tabari text the model read, by verse key.
  final Map<String, String> tafsirRead;

  /// Human-readable research trail (Arabic), shown in the app.
  final List<String> research;
  final String model;
  final Map<String, int> usage;
  final int rounds;
  final bool refused;
}

/// Live research agent: the model (Claude or Gemini) searches the Quran,
/// reads al-Tabari's tafsir of the verses it wants to cite, then submits a
/// card-shaped answer. A manual tool loop over raw HTTP; every assistant turn
/// is echoed back unchanged so thinking blocks / thought signatures are
/// preserved.
class ResearchAgent {
  ResearchAgent({
    required this.llm,
    required this.kb,
    this.quran,
    this.tabari,
    this.maxRounds = 6,
  }) : _system = buildSystemPrompt(kb, quranTools: quran != null),
       _tools = [
         if (quran != null) searchQuranTool,
         if (quran != null) readTafsirTool,
         submitAnswerTool(kb),
       ];

  final LlmClient llm;
  final KnowledgeBase kb;
  final QuranLibrary? quran;
  final TafsirSource? tabari;
  final int maxRounds;
  final String _system;
  final List<Map<String, dynamic>> _tools;

  /// [lang] is the answer's language ('ar' or 'en'): it sets the language of
  /// the research trail and adds English verse meanings for English answers.
  ///
  /// [preread]: al-Tabari text already given to the model in [userTurn]
  /// (see `buildPrereadBlock`), by verse key; those verses count as read.
  Future<AgentOutcome> run(String userTurn, {String lang = 'ar', Map<String, String> preread = const {}}) async {
    final messages = <Map<String, dynamic>>[
      {'role': 'user', 'content': userTurn},
    ];
    final readRefs = <String>{...preread.keys};
    final tafsirRead = <String, String>{...preread};
    final research = <String>[
      for (final key in preread.keys)
        if (quran?.verse(key) case final v?)
          lang == 'en'
              ? 'Read Tafsir al-Tabari on ${quran!.surahName(v.surah, lang: 'en')} ${v.ayah}'
              : 'قراءة تفسير الطبري: ${quran!.surahName(v.surah)} ${v.ayah}',
    ];
    final usage = <String, int>{};
    var model = llm.model;
    var nudged = false;
    var languageCorrected = false;

    AgentOutcome outcome(int round, Map<String, dynamic>? submitted, {bool refused = false}) => AgentOutcome(
      submitted: submitted,
      readRefs: readRefs,
      tafsirRead: tafsirRead,
      research: research,
      model: model,
      usage: usage,
      rounds: round,
      refused: refused,
    );

    for (var round = 1; round <= maxRounds; round++) {
      final turn = await llm.send(system: _system, messages: messages, tools: _tools);
      model = turn.model.isEmpty ? model : turn.model;
      _addUsage(usage, turn.usage);

      if (turn.stopReason == 'refusal') return outcome(round, null, refused: true);
      if (turn.stopReason == 'max_tokens') {
        throw ModelException('response truncated (max_tokens)');
      }
      messages.add({'role': 'assistant', 'content': turn.content});

      final uses = turn.toolUses;
      final submit = uses.where((u) => u['name'] == 'submit_answer').firstOrNull;
      if (submit != null) {
        final input = (submit['input'] as Map).cast<String, dynamic>();
        // Written in the wrong language (e.g. an Arabic answer to an English
        // question): rejected once, with a request to resubmit.
        if (!languageCorrected && round < maxRounds && !inLanguage(input, lang)) {
          languageCorrected = true;
          messages.add({
            'role': 'user',
            'content': [
              for (final u in uses)
                identical(u, submit)
                    ? {
                        'type': 'tool_result',
                        'tool_use_id': u['id'],
                        'content': lang == 'en'
                            ? 'Rejected: the question is in English, so every text field must be written in English '
                                  '(keep only Islamic terms in Arabic or transliteration). Call submit_answer again, in English.'
                            : 'مرفوض: السؤال بالعربية، فاكتب جميع الحقول النصية بالعربية، ثم استدعِ submit_answer مجدداً.',
                        'is_error': true,
                      }
                    : await _execute(u, readRefs, tafsirRead, research, lang),
            ],
          });
          continue;
        }
        return outcome(round, input);
      }

      if (uses.isEmpty) {
        // Ended with plain text: ask once for the structured submission.
        if (nudged) break;
        nudged = true;
        messages.add({
          'role': 'user',
          'content': 'Please call submit_answer now with your final answer.',
        });
        continue;
      }

      final results = <Map<String, dynamic>>[
        for (final u in uses) await _execute(u, readRefs, tafsirRead, research, lang),
      ];
      final content = <Map<String, dynamic>>[
        ...results,
        if (round >= maxRounds - 1)
          {'type': 'text', 'text': 'Research budget reached — call submit_answer now.'},
      ];
      messages.add({'role': 'user', 'content': content});
    }
    throw ModelException('no answer submitted within $maxRounds rounds');
  }

  Future<Map<String, dynamic>> _execute(
    Map<String, dynamic> use,
    Set<String> readRefs,
    Map<String, String> tafsirRead,
    List<String> research,
    String lang,
  ) async {
    final id = use['id'] as String;
    final input = (use['input'] as Map?)?.cast<String, dynamic>() ?? const {};
    Map<String, dynamic> result(Object body, {bool error = false}) => {
      'type': 'tool_result',
      'tool_use_id': id,
      'content': body is String ? body : jsonEncode(body),
      if (error) 'is_error': true,
    };

    final q = quran;
    switch (use['name']) {
      case 'search_quran' when q != null:
        final query = (input['query'] as String?)?.trim() ?? '';
        if (query.isEmpty) return result('query must be a non-empty Arabic string', error: true);
        research.add(lang == 'en' ? 'Searched the Quran: “$query”' : 'بحث في القرآن الكريم: «$query»');
        final hits = q.search(query, limit: 8);
        return result({
          'results': [
            for (final h in hits)
              {
                'ref': h.verse.key,
                'surah': q.surahName(h.verse.surah),
                'verse': h.verse.simple,
              },
          ],
          if (hits.isEmpty) 'note': 'No match. Try other words, e.g. the wording a tafsir would use.',
        });

      case 'read_tafsir' when q != null:
        final refs = [
          for (final r in (input['refs'] as List? ?? const [])) r.toString(),
        ].take(3).toList();
        if (refs.isEmpty) return result("refs must list verse refs like '60:8'", error: true);
        final out = <Map<String, dynamic>>[];
        for (final raw in refs) {
          final key = q.parseRef(raw);
          if (key == null) {
            out.add({'ref': raw, 'error': 'No such verse.'});
            continue;
          }
          final v = q.verse(key)!;
          final tabariText = tafsirRead[key] ?? await tabari?.forVerse(key);
          // A verse counts as read only once its approved tafsir was read.
          if (tabariText == null) {
            out.add({
              'ref': key,
              'verse': v.uthmani,
              'tabari': 'unavailable right now — do not cite this verse',
            });
            continue;
          }
          tafsirRead[key] = tabariText;
          if (readRefs.add(key)) {
            research.add(lang == 'en'
                ? 'Read Tafsir al-Tabari on ${q.surahName(v.surah, lang: 'en')} ${v.ayah}'
                : 'قراءة تفسير الطبري: ${q.surahName(v.surah)} ${v.ayah}');
          }
          out.add({
            'ref': key,
            'surah': q.surahName(v.surah),
            'verse': v.uthmani,
            'tabari': excerpt(tabariText),
            if (lang == 'en' && v.english.isNotEmpty) 'english_meaning': v.english,
          });
        }
        return result({'verses': out});

      default:
        return result('Unknown or unavailable tool: ${use['name']}', error: true);
    }
  }


  /// Whether the submission's text is in the answer language: more Latin
  /// than Arabic letters for English, the reverse for Arabic. Very short
  /// texts pass.
  static bool inLanguage(Map<String, dynamic> input, String lang) {
    final text = [
      for (final k in const ['principle', 'culture', 'khilafAgreed', 'khilafNote', 'referReason', 'referTo', 'abstainReason'])
        '${input[k] ?? ''}',
      for (final g in (input['guidance'] as List?) ?? const []) '$g',
    ].join(' ');
    var arabic = 0;
    var latin = 0;
    for (final r in text.runes) {
      if (r >= 0x0600 && r <= 0x06FF) {
        arabic++;
      } else if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A)) {
        latin++;
      }
    }
    if (arabic + latin < 20) return true;
    return lang == 'en' ? latin >= arabic : arabic >= latin;
  }

  static void _addUsage(Map<String, int> into, Map<String, dynamic> usage) {
    for (final k in const [
      'input_tokens',
      'output_tokens',
      'cache_read_input_tokens',
      'cache_creation_input_tokens',
    ]) {
      final v = usage[k];
      if (v is int) into[k] = (into[k] ?? 0) + v;
    }
  }
}
