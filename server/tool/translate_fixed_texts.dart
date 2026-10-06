// Translates the guard's fixed texts (RouterTexts.en: the default abstention,
// referral, hadith and off-topic texts) into every other language
// detectLanguage can name, with Claude, and checks each one before keeping it:
//   dart run tool/translate_fixed_texts.dart      (from server/)
// Writes lib/src/fixed_texts_i18n.dart. A language whose translation fails a
// check is left out, and its answers keep the English texts.
import 'dart:convert';
import 'dart:io';

import 'package:basirah_core/basirah_core.dart';
import 'package:basirah_server/basirah_server.dart';

const _model = 'claude-sonnet-5-5';

/// Every language detectLanguage returns, except Arabic and English (which
/// have RouterTexts of their own).
const _languages = [
  'fr', 'es', 'pt', 'de', 'nl', 'tr', 'az', 'id', 'tl', 'sw', 'so', 'ha', 'bs', 'sq', 'vi', //
  'fa', 'ur', 'ps', 'zh', 'ja', 'ko', 'hi', 'bn', 'as', 'ta', 'si', 'th', 'ru', 'am',
];

/// The app's name as the interface writes it in each script (lib/core/lang.dart).
const _appName = {
  'ur': 'بصیرہ',
  'fa': 'بصیره',
  'ps': 'بصیره',
  'hi': 'बसीरा',
  'si': 'බසීරා',
  'ta': 'பஸீரா',
  'as': 'বাছিৰা',
  'zh': '巴希拉',
  'ja': 'バシーラ',
};

Map<String, Object> _fields(RouterTexts t) => {
  'referReason': t.referReason,
  'referTo': t.referTo,
  'referGuidance': t.referGuidance,
  'abstainReason': t.abstainReason,
  'abstainGuidance': t.abstainGuidance,
  'hadithReason': t.hadithReason,
  'hadithGuidance': t.hadithGuidance,
  'personalNote': t.personalNote,
  'offTopicReason': t.offTopicReason,
  'offTopicGuidance': t.offTopicGuidance,
  'khilafFallback': t.khilafFallback,
};

String _system(String language) => '''
You translate the fixed messages of Basirah (بصيرة), an app that answers new Muslims' questions about Islam from approved sources, into $language. These messages are shown when Basirah declines to answer, refers the asker to a qualified scholar, or says it is out of scope.

Rules:
- Translate faithfully and naturally for a $language-speaking Muslim, in a calm, respectful register. The Arabic original is the authoritative wording: use it to get the meaning exactly right. Do not add, soften or strengthen anything.
- Keep these unchanged: the name "Basirah", the address dorar.net/hadith, the name Dorar.net, the honorific ﷺ, and the "…" inside the last example.
- The example questions in offTopicGuidance become natural questions in $language, in $language quotation marks.
- Use the terms $language-speaking Muslims commonly use (mufti, fatwa, hadith, Sharia, Sunnah…).
- Every list keeps exactly its items, in the same order.

Answer with only a JSON object with exactly the same keys as the input, each translated.''';

Future<void> main() async {
  final env = loadEnv();
  final key = env['ANTHROPIC_API_KEY'];
  if (key == null || key.isEmpty) {
    stderr.writeln('needs ANTHROPIC_API_KEY in server/.env');
    exit(2);
  }
  final en = _fields(RouterTexts.en);
  final ar = _fields(RouterTexts.ar);
  final client = ClaudeClient(apiKey: key, model: _model, effort: 'low', useFallbacks: false, timeout: const Duration(minutes: 5));
  final done = <String, Map<String, Object>>{};
  final failed = <String, String>{};

  Future<void> run(String iso) async {
    final language = languageName(iso);
    String? problem;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final turn = await client.send(
          system: _system(language),
          messages: [
            {
              'role': 'user',
              'content': '${problem == null ? '' : 'Your previous translation was rejected: $problem\n\n'}'
                  'English:\n${jsonEncode(en)}\n\nArabic original:\n${jsonEncode(ar)}',
            },
          ],
          maxTokens: 8000,
        );
        final text = turn.text;
        final start = text.indexOf('{');
        final end = text.lastIndexOf('}');
        if (start < 0 || end <= start) throw const FormatException('no JSON object');
        final out = (jsonDecode(text.substring(start, end + 1)) as Map).cast<String, Object?>();
        problem = _check(iso, en, out);
        if (problem == null) {
          final name = _appName[iso];
          String named(String s) => name == null ? s : s.replaceAll('Basirah', name);
          done[iso] = {
            for (final k in en.keys)
              k: out[k] is List ? [for (final s in out[k]! as List) named((s as String).trim())] : named((out[k]! as String).trim()),
          };
          return;
        }
        stderr.writeln('$iso, attempt $attempt: $problem');
      } on Object catch (e) {
        problem = '$e';
        stderr.writeln('$iso, attempt $attempt: $e');
        await Future<void>.delayed(Duration(seconds: 10 * attempt));
      }
    }
    failed[iso] = problem ?? 'unknown';
  }

  // A few at a time.
  final queue = [..._languages];
  await Future.wait([
    for (var w = 0; w < 6; w++)
      () async {
        while (queue.isNotEmpty) {
          await run(queue.removeAt(0));
        }
      }(),
  ]);
  client.close();

  final b = StringBuffer()
    ..writeln('// Generated by tool/translate_fixed_texts.dart: do not edit by hand.')
    ..writeln('//')
    ..writeln("// The guard's fixed texts (RouterTexts.en) in the other languages the server")
    ..writeln('// answers in, machine-translated with $_model from the English and')
    ..writeln('// Arabic originals and checked by the tool (every key and item present, the')
    ..writeln('// language detected, names and the address kept). Not reviewed by a person.')
    ..writeln('library;')
    ..writeln()
    ..writeln('const fixedTexts = <String, Map<String, Object>>{');
  for (final iso in _languages) {
    final t = done[iso];
    if (t == null) continue;
    b.writeln("  '$iso': {");
    for (final MapEntry(:key, :value) in t.entries) {
      b.writeln(value is List ? "    '$key': [${value.cast<String>().map(_lit).join(', ')}]," : "    '$key': ${_lit(value as String)},");
    }
    b.writeln('  },');
  }
  b.writeln('};');
  File('lib/src/fixed_texts_i18n.dart').writeAsStringSync(b.toString());
  stdout.writeln('${done.length}/${_languages.length} languages${failed.isEmpty ? '' : '; left out: $failed'}');
}

/// Why [out] is not a usable translation of [en] into [iso], or null.
String? _check(String iso, Map<String, Object> en, Map<String, Object?> out) {
  for (final MapEntry(:key, :value) in en.entries) {
    final t = out[key];
    if (value is List) {
      if (t is! List || t.length != value.length || t.any((s) => s is! String || s.trim().isEmpty)) {
        return '"$key" must be a list of ${value.length} non-empty strings';
      }
    } else if (t is! String || t.trim().isEmpty) {
      return '"$key" must be a non-empty string';
    }
  }
  if (out.keys.toSet().difference(en.keys.toSet()).isNotEmpty) return 'use exactly the input keys';
  String one(String k) => out[k]! as String;
  List<String> many(String k) => (out[k]! as List).cast<String>();
  if (!many('hadithGuidance').first.contains('dorar.net/hadith')) return 'keep dorar.net/hadith in the first hadithGuidance item';
  if (!one('hadithReason').contains('ﷺ')) return 'keep ﷺ in hadithReason';
  for (final k in ['referReason', 'offTopicReason']) {
    if (!one(k).contains('Basirah')) return 'keep the name "Basirah" in $k';
  }
  // In the language: each reason on its own (what an answer shows as its
  // text), and everything together (the detector misreads a few words).
  String detect(String s) => detectLanguage(s.replaceAll('Basirah', '').replaceAll('dorar.net/hadith', '').replaceAll('Dorar.net', ''));
  for (final k in ['referReason', 'abstainReason', 'hadithReason', 'offTopicReason']) {
    final found = detect(one(k));
    if (found != iso) return '"$k" reads as $found, not ${languageName(iso)}';
  }
  final all = detect([for (final k in en.keys) out[k] is List ? many(k).join(' ') : one(k)].join(' '));
  if (all != iso) return 'the texts read as $all, not ${languageName(iso)}';
  return null;
}

/// [s] as a Dart string literal.
String _lit(String s) {
  final j = jsonEncode(s);
  return j.replaceAll(r'$', r'\$');
}
