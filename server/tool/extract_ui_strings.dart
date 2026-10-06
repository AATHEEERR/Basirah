// Collects every English string of the app's interface, with its Arabic
// twin, for translation into the other interface languages:
//   dart run tool/extract_ui_strings.dart        (from server/)
// Writes ../assets/i18n/source.json.
//
// The code is parsed (package:analyzer), not searched as text. A string is
// taken when it is the English side of an Arabic/English pair:
// - consecutive arguments or fields, Arabic then English («context.tr(ar,
//   en)», «('id', 'عربي', 'English')», named «title: …, titleEn: …»);
// - a choice on the language («lang == 'en' ? 'English' : 'عربي'»);
// - a list whose name ends in «En» (its twin ending in «Ar» gives the Arabic).
// A value inside a string («${n} questions») becomes a slot: «{0} questions».
// The categories' names and descriptions come from assets/kb/en.json.
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

final _arabic = RegExp(r'[؀-ۿ]');
final _latin = RegExp(r'[A-Za-z]');

int _count(RegExp re, String s) => re.allMatches(s).length;
bool _isArabic(String s) => _count(_arabic, s) > _count(_latin, s);
bool _isEnglish(String s) => _count(_latin, s) > 0 && _count(_latin, s) >= _count(_arabic, s);

/// The string with each interpolated value as a numbered slot, or null when
/// [e] is not a string literal.
String? template(Expression e) {
  var slot = 0;
  String? walk(Expression e) {
    if (e is SimpleStringLiteral) return e.value;
    if (e is AdjacentStrings) {
      final parts = [for (final s in e.strings) walk(s)];
      return parts.contains(null) ? null : parts.join();
    }
    if (e is StringInterpolation) {
      final b = StringBuffer();
      for (final el in e.elements) {
        if (el is InterpolationString) {
          b.write(el.value);
        } else {
          b.write('{${slot++}}');
        }
      }
      return b.toString();
    }
    if (e is ParenthesizedExpression) return walk(e.expression);
    // An English string already routed through the translation: UiStrings.fromEnglish('…').
    if (e is MethodInvocation && e.methodName.name == 'fromEnglish' && e.argumentList.arguments.length == 1) {
      return walk(e.argumentList.arguments.single.argumentExpression);
    }
    return null;
  }

  return walk(e);
}

class _Collector extends RecursiveAstVisitor<void> {
  final found = <String, String?>{};
  final _lists = <String, List<String?>>{};

  void _add(String en, String? ar) {
    if (en.replaceAll(RegExp(r'\{\d+\}'), '').trim().isEmpty) return;
    found[en] = found[en] ?? ar;
  }

  void _pairs(Iterable<Expression> items) {
    final list = items.toList();
    for (var i = 0; i + 1 < list.length; i++) {
      final a = template(list[i]);
      final b = template(list[i + 1]);
      if (a != null && b != null && _isArabic(a) && _isEnglish(b)) _add(b, a);
    }
  }

  @override
  void visitArgumentList(ArgumentList node) {
    _pairs(node.arguments.map((a) => a.argumentExpression));
    super.visitArgumentList(node);
  }

  /// «context.tr(ar, en)»: the English side, even when the Arabic one has no
  /// Arabic letters («{0} ✓»).
  @override
  void visitMethodInvocation(MethodInvocation node) {
    final args = node.argumentList.arguments;
    if (node.methodName.name == 'tr' && args.length == 2) {
      final en = template(args[1].argumentExpression);
      if (en != null && _isEnglish(en)) _add(en, template(args[0].argumentExpression));
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitRecordLiteral(RecordLiteral node) {
    _pairs(node.fields.map((f) => f.fieldExpression));
    super.visitRecordLiteral(node);
  }

  @override
  void visitListLiteral(ListLiteral node) {
    _pairs(node.elements.whereType<Expression>());
    super.visitListLiteral(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    final cond = node.condition.toSource();
    if (cond.contains("'en'") || cond.contains('isEn') || cond.contains("'ar'")) {
      final a = template(node.thenExpression);
      final b = template(node.elseExpression);
      if (a != null && b != null) {
        if (_isEnglish(a) && _isArabic(b)) _add(a, b);
        if (_isArabic(a) && _isEnglish(b)) _add(b, a);
      }
    }
    super.visitConditionalExpression(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final init = node.initializer;
    if (init is ListLiteral) {
      _lists[node.name.lexeme] = [for (final e in init.elements) e is Expression ? template(e) : null];
    }
    super.visitVariableDeclaration(node);
  }

  /// The lists named «…En», each item with the same place in «…Ar».
  void finishLists() {
    for (final MapEntry(:key, :value) in _lists.entries) {
      if (!key.endsWith('En')) continue;
      final ar = _lists['${key.substring(0, key.length - 2)}Ar'];
      for (final (i, en) in value.indexed) {
        if (en != null && _isEnglish(en)) _add(en, ar != null && i < ar.length ? ar[i] : null);
      }
    }
  }
}

void main() {
  final collector = _Collector();
  final files = Directory('../lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final unit = parseFile(path: f.absolute.path, featureSet: FeatureSet.latestLanguageVersion()).unit;
    unit.accept(collector);
  }
  collector.finishLists();
  final fromCode = collector.found.length;

  // The categories, from the English overlay of the knowledge base.
  final en = jsonDecode(File('../assets/kb/en.json').readAsStringSync()) as Map<String, dynamic>;
  for (final c in (en['categories'] as Map<String, dynamic>).values) {
    for (final text in (c as Map<String, dynamic>).values) {
      if (text is String && _isEnglish(text)) collector._add(text, null);
    }
  }

  final strings = collector.found.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final out = File('../assets/i18n/source.json')..createSync(recursive: true);
  out.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
      'strings': [
        for (final MapEntry(:key, :value) in strings) {'en': key, if (value != null) 'ar': value},
      ],
    })}\n',
  );
  stdout.writeln('${files.length} files → $fromCode strings from the code, ${strings.length} with the categories → ${out.path}');
}
