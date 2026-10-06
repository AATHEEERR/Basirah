import 'dart:convert';
import 'dart:io';

import 'package:basirah_core/basirah_core.dart';

/// Saved live answers: a question asked again — the same words, compared
/// without diacritics or punctuation, with the same category and asker
/// context — gets the same researched answer at once, without another model
/// call (consistent answers, no quota spent, no waiting).
///
/// * Only complete answers researched by the model are kept, and only for a
///   first question (a follow-up depends on the conversation).
/// * Privacy: the question text is never written. The file name is a hash
///   of the normalised question, and the saved answer has its question
///   blanked; it is filled in from the request when served.
/// * An entry expires after [ttl], and a new knowledge-base version or
///   [version] (bumped when the prompt or the rules change) starts afresh.
class AnswerCache {
  AnswerCache({this.dir = 'cache/answers', this.ttl = const Duration(days: 14), DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// Bump when the prompt, tools or guard change what a fresh answer would be.
  static const version = 'v7-fixed-texts';

  final String dir;
  final Duration ttl;
  final DateTime Function() _clock;
  final _memory = <String, (DateTime, Map<String, dynamic>)>{};

  String keyFor({
    required String question,
    required String kbVersion,
    String? categoryId,
    String context = '',
  }) {
    final normal = normalizeArabic(question).replaceAll(' ', '');
    var material = '$version|$kbVersion|${categoryId ?? ''}|$context|$normal';
    // The normaliser keeps Arabic and Latin letters only. A question in
    // another language also keys on its language and on the letters the
    // normaliser drops (Chinese, Devanagari, Urdu's ے…), so two different
    // questions never share an answer. Arabic and English keys are unchanged.
    final lang = detectLanguage(question);
    final other = String.fromCharCodes(
      question.toLowerCase().runes.where((r) => r > 0x24F && !(r >= 0x0621 && r <= 0x064A) && _letter.hasMatch(String.fromCharCode(r))),
    );
    if ((lang != 'ar' && lang != 'en') || other.isNotEmpty) material += '|$lang|$other';
    return '${_fnv1a(material, 0xcbf29ce484222325)}${_fnv1a(material, 0x84222325cbf29ce4)}';
  }

  /// The saved answer for [key], with [question] restored, or null.
  BasirahAnswer? get(String key, String question) {
    var hit = _memory[key];
    if (hit == null) {
      final file = File('$dir/$key.json');
      if (file.existsSync()) {
        try {
          final j = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
          hit = (DateTime.parse(j['saved'] as String), (j['answer'] as Map).cast<String, dynamic>());
          _memory[key] = hit;
        } on FormatException {
          return null;
        }
      }
    }
    if (hit == null) return null;
    if (_clock().difference(hit.$1) > ttl) {
      _memory.remove(key);
      return null;
    }
    return BasirahAnswer.fromJson({...hit.$2, 'question': question});
  }

  void put(String key, BasirahAnswer answer) {
    final saved = _clock();
    final json = {...answer.toJson(), 'question': ''};
    _memory[key] = (saved, json);
    try {
      final file = File('$dir/$key.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode({'saved': saved.toIso8601String(), 'answer': json}));
    } on FileSystemException {
      // Read-only filesystem: memory only.
    }
  }

  /// 64-bit FNV-1a over the UTF-16 code units, as 16 hex digits.
  static String _fnv1a(String s, int seed) {
    var h = seed;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return h.toUnsigned(64).toRadixString(16).padLeft(16, '0');
  }
}

/// A letter in any script.
final _letter = RegExp(r'\p{L}', unicode: true);
