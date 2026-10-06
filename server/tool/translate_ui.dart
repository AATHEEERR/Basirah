// Translates the interface strings (assets/i18n/source.json, from
// tool/extract_ui_strings.dart) into every other interface language with
// Claude, and checks each translation before keeping it:
//   dart run tool/translate_ui.dart [code …]      (from server/; all by default)
// Writes ../assets/i18n/<code>.json: {language, model, strings: {English: translation}}.
// It resumes: strings already translated are kept, only missing ones are sent.
// A translation that loses or adds a value slot ({0}) is dropped, so the app
// shows that string in English.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:basirah_server/basirah_server.dart';

const _model = 'claude-sonnet-5-5';
const _chunk = 70;
const _workers = 8;

String _system(String language) => '''
You translate the user interface of Basirah (بصيرة), an app that answers new Muslims' questions about Islam from approved sources (the Quran, the authentic Sunnah and recognised scholarly references), into $language.

Rules:
- Translate each English string faithfully and naturally for a $language-speaking Muslim, in the calm, respectful register of a careful app. When the Arabic original is given, it is the authoritative wording: use it to get the meaning exactly right.
- Keep every value slot such as {0} or {1} exactly as written, each once, placed where it belongs in $language word order.
- Keep these unchanged: the name "Basirah"; the names QuranEnc, HadeethEnc, Dorar, IslamHouse, Claude, Gemini, Anthropic, Google, GitHub, Facebook, Jitsi, MCP, JSON, IP, Sonnet, Haiku; file paths, commands and code (such as eval/EVALUATION.md or dart run bin/compare.dart); numbers; the honorific ﷺ; and any Arabic text inside the string.
- Use the terms $language-speaking Muslims commonly use for Islamic concepts (Quran, hadith, Sunnah, tafsir, fatwa, Mushaf, Sharia, sahih, hasan…).
- Keep the string's punctuation and its role: a button stays short, a sentence stays a sentence. Quotation marks may follow $language usage.
- Do not add notes or explanations.

Answer with only a JSON object that maps each item's "id" to its translation.''';

final _slot = RegExp(r'\{\d+\}');
List<String> _slots(String s) => [for (final m in _slot.allMatches(s)) m[0]!]..sort();

bool _valid(String en, String? tr) {
  if (tr == null || tr.trim().isEmpty) return false;
  final a = _slots(en);
  final b = _slots(tr);
  return a.length == b.length && List.generate(a.length, (i) => a[i] == b[i]).every((x) => x);
}

/// The translation with the English string's own leading and trailing
/// spaces (« · text» is appended to another string).
String _edges(String en, String tr) {
  final lead = RegExp(r'^\s*').firstMatch(en)![0]!;
  final trail = RegExp(r'\s*$').firstMatch(en)![0]!;
  return '$lead${tr.trim()}$trail';
}

Future<void> main(List<String> args) async {
  final env = loadEnv();
  final key = env['ANTHROPIC_API_KEY'];
  if (key == null || key.isEmpty) {
    stderr.writeln('needs ANTHROPIC_API_KEY in server/.env');
    exit(2);
  }
  final source = ((jsonDecode(File('../assets/i18n/source.json').readAsStringSync()) as Map)['strings'] as List)
      .cast<Map<String, dynamic>>();
  final targets = [
    for (final l in meaningLanguages)
      if (l.iso != 'en' && (args.isEmpty || args.contains(l.iso))) l,
  ];
  final client = ClaudeClient(apiKey: key, model: _model, effort: 'low', useFallbacks: false, timeout: const Duration(minutes: 9));
  var inTokens = 0;
  var outTokens = 0;

  // Per language: what is done, its file, and what was dropped.
  final done = <String, Map<String, String>>{};
  final dropped = <String, int>{};
  final queue = <(MeaningLanguage, List<Map<String, dynamic>>)>[];
  for (final l in targets) {
    final file = File('../assets/i18n/${l.iso}.json');
    // Kept: the translations of strings the code still has.
    final wanted = {for (final s in source) s['en'] as String};
    done[l.iso] = file.existsSync()
        ? (((jsonDecode(file.readAsStringSync()) as Map)['strings'] as Map).cast<String, String>()
            ..removeWhere((en, _) => !wanted.contains(en)))
        : <String, String>{};
    dropped[l.iso] = 0;
    final todo = [for (final s in source) if (!done[l.iso]!.containsKey(s['en'])) s];
    for (var i = 0; i < todo.length; i += _chunk) {
      queue.add((l, todo.sublist(i, (i + _chunk).clamp(0, todo.length))));
    }
  }
  stdout.writeln('${targets.length} languages, ${queue.length} batches');

  void save(MeaningLanguage l) => File('../assets/i18n/${l.iso}.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'language': l.iso, 'model': _model, 'strings': done[l.iso]})}\n',
  );
  // The pruned files, even where nothing is left to translate.
  targets.forEach(save);

  Future<void> run(MeaningLanguage l, List<Map<String, dynamic>> part) async {
    final language = '${l.native} (${_englishName(l.iso)})';
    // The Arabic only when it has the same slots: otherwise the model may
    // follow its slots and lose the English ones.
    final items = [
      for (final (j, s) in part.indexed)
        {'id': '$j', 'en': s['en'], if (s['ar'] != null && _valid(s['en'] as String, s['ar'] as String)) 'ar': s['ar']},
    ];
    Map<String, dynamic>? answer;
    for (var attempt = 1; attempt <= 4 && answer == null; attempt++) {
      try {
        final turn = await client.send(
          system: _system(language),
          messages: [
            {'role': 'user', 'content': jsonEncode(items)},
          ],
          maxTokens: 20000,
        );
        inTokens += (turn.usage['input_tokens'] as int? ?? 0) + (turn.usage['cache_read_input_tokens'] as int? ?? 0);
        outTokens += turn.usage['output_tokens'] as int? ?? 0;
        final text = turn.text;
        final start = text.indexOf('{');
        final end = text.lastIndexOf('}');
        if (start < 0 || end <= start) throw const FormatException('no JSON object');
        answer = (jsonDecode(text.substring(start, end + 1)) as Map).cast<String, dynamic>();
      } on Object catch (e) {
        stderr.writeln('${l.iso}, attempt $attempt: $e');
        await Future<void>.delayed(Duration(seconds: 15 * attempt));
      }
    }
    if (answer == null) {
      dropped[l.iso] = dropped[l.iso]! + part.length;
      return;
    }
    for (final (j, s) in part.indexed) {
      final en = s['en'] as String;
      final tr = answer['$j'];
      if (tr is String && _valid(en, tr)) {
        done[l.iso]![en] = _edges(en, tr);
      } else {
        dropped[l.iso] = dropped[l.iso]! + 1;
      }
    }
    save(l);
  }

  await Future.wait([
    for (var w = 0; w < _workers; w++)
      () async {
        while (queue.isNotEmpty) {
          final (l, part) = queue.removeAt(0);
          await run(l, part);
        }
      }(),
  ]);
  client.close();
  for (final l in targets) {
    stdout.writeln('${l.iso}: ${done[l.iso]!.length}/${source.length}${dropped[l.iso] == 0 ? '' : ', ${dropped[l.iso]} dropped'}');
  }
  stdout.writeln('tokens: $inTokens in, $outTokens out');
}

String _englishName(String iso) => const {
  'tl': 'Filipino (Tagalog)',
  'fr': 'French',
  'zh': 'Chinese (Simplified)',
  'vi': 'Vietnamese',
  'si': 'Sinhala',
  'ta': 'Tamil',
  'so': 'Somali',
  'fa': 'Persian',
  'pt': 'Portuguese',
  'nl': 'Dutch',
  'az': 'Azerbaijani',
  'as': 'Assamese',
  'ur': 'Urdu',
  'id': 'Indonesian',
  'tr': 'Turkish',
  'es': 'Spanish',
  'de': 'German',
  'hi': 'Hindi',
  'sw': 'Swahili',
  'ha': 'Hausa',
  'bs': 'Bosnian',
  'sq': 'Albanian',
  'ps': 'Pashto',
  'ja': 'Japanese',
}[iso] ?? iso;
