import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The interface in the languages beyond Arabic and English: each English
/// string of the interface has its translation in `assets/i18n/<code>.json`,
/// made once by `server/tool/translate_ui.dart` (Claude) from the strings
/// that `server/tool/extract_ui_strings.dart` finds in the code, and checked
/// there (every value slot kept). A string with values in it («{0}
/// questions») is matched as a pattern. Anything without a translation stays
/// in English.
abstract final class UiStrings {
  /// The interface language now shown (set with the language, before the
  /// rebuild).
  static String current = 'ar';

  static final _tables = <String, _Table>{};

  /// Loads [code]'s translations once. Arabic and English need none.
  static Future<void> ensure(String code) async {
    if (code == 'ar' || code == 'en' || _tables.containsKey(code)) return;
    try {
      final raw = jsonDecode(await rootBundle.loadString('assets/i18n/$code.json')) as Map<String, dynamic>;
      _tables[code] = _Table((raw['strings'] as Map).cast<String, String>());
    } on Object {
      // No file for this language: the interface stays in English.
    }
  }

  /// Sets [code]'s translations directly (tests).
  @visibleForTesting
  static void debugSet(String code, Map<String, String> strings) => _tables[code] = _Table(strings);

  /// [en] in the interface language, with the app's name in that
  /// language's script ([name], set with the language).
  static String fromEnglish(String en) {
    if (current == 'ar' || current == 'en') return en;
    final out = _tables[current]?.lookup(en) ?? en;
    return name == 'Basirah' ? out : out.replaceAll('Basirah', name);
  }

  /// The app's name in the interface language's script.
  static String name = 'Basirah';
}

class _Table {
  _Table(Map<String, String> strings) {
    for (final MapEntry(:key, :value) in strings.entries) {
      if (!_slot.hasMatch(key)) {
        _exact[key] = value;
      } else if (_letters(key) >= 2) {
        // A pattern needs words of its own: «{0}: {1}» would match anything.
        _patterns.add((_compile(key), value, _letters(key)));
      }
    }
    // The most specific pattern (the most words of its own) first.
    _patterns.sort((a, b) => b.$3.compareTo(a.$3));
  }

  static final _slot = RegExp(r'\{(\d+)\}');
  static final _notLetter = RegExp(r'[^\p{L}]', unicode: true);
  static int _letters(String template) => template.replaceAll(_slot, '').replaceAll(_notLetter, '').length;
  final _exact = <String, String>{};
  final _patterns = <(RegExp, String, int)>[];
  final _cache = <String, String>{};

  /// «{0} questions» → ^(.*?) questions$ (the slots are numbered in order).
  static RegExp _compile(String template) {
    final b = StringBuffer('^');
    var last = 0;
    for (final m in _slot.allMatches(template)) {
      b
        ..write(RegExp.escape(template.substring(last, m.start)))
        ..write('(.*?)');
      last = m.end;
    }
    b
      ..write(RegExp.escape(template.substring(last)))
      ..write(r'$');
    return RegExp(b.toString(), dotAll: true);
  }

  String? lookup(String en) {
    final hit = _exact[en] ?? _cache[en];
    if (hit != null) return hit;
    for (final (re, translated, _) in _patterns) {
      final m = re.firstMatch(en);
      if (m == null) continue;
      final out = translated.replaceAllMapped(_slot, (s) {
        final i = int.parse(s[1]!);
        return i < m.groupCount ? (m.group(i + 1) ?? '') : s[0]!;
      });
      return _cache[en] = out;
    }
    return null;
  }
}
