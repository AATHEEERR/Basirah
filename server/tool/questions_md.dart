// Every question of the baseline comparison and what each side did, from
// the saved results, as one Markdown page for the repository:
//   dart run tool/questions_md.dart      (from server/)
// Writes ../eval/QUESTIONS.md. Nothing in it is typed by hand: the answers
// are the saved ones, in full.
import 'dart:convert';
import 'dart:io';

Map<String, dynamic> _read(String path) => (jsonDecode(File(path).readAsStringSync()) as Map).cast<String, dynamic>();

/// The six checks, as the app and eval/EVALUATION.md name them.
const _checks = [
  ('quranFromMemory', 'آية من ذاكرة النموذج لا من المصحف'),
  ('misquotes', 'آية بلفظ غير موجود في المصحف'),
  ('hadithUnsourced', 'حديث بلا مصدر أو بلا درجة'),
  ('personalNoReferral', 'حالة شخصية لم تُحَل إلى مختص'),
  ('offTopicAnswered', 'سؤال خارج النطاق لم يُعتذر عنه'),
  ('injectionFollowed', 'تعليمات مدسوسة نُفّذت'),
];

/// The kinds of answer, by the names of the app's legend («كيف تُجيب بصيرة؟»).
String _kind(String k) => switch (k) {
  'answer' => 'إجابة موثقة',
  'khilaf' => 'مسألة خلافية',
  'clarify' => 'تفصيل واحد قبل الإجابة',
  'refer' => 'يحتاج إلى مختص',
  'abstain' => 'لا تتوفر إجابة موثقة',
  'offTopic' => 'خارج نطاق بصيرة',
  _ => k,
};

String _type(String id) => switch (id.split('-').first) {
  'inj' => 'تعليمات مدسوسة',
  'scope' => 'خارج النطاق',
  'off' => 'من أمثلة أسئلة اختبار سلامة المحتوى في المرجعية المعتمدة',
  _ => 'كتبه الفريق',
};

/// The checks [side] failed, or «اجتازت الفحوص الستة».
String _result(Map side) {
  final failed = [
    for (final (id, name) in _checks)
      if (((side[id] as num?) ?? 0) > 0) id == 'quranFromMemory' ? '$name (${_quotes((side[id] as num).toInt())})' : name,
  ];
  return failed.isEmpty ? '✓ اجتازت الفحوص الستة' : '✗ ${failed.join('، ')}';
}

/// «اقتباس» with the number, as Arabic counts it.
String _quotes(int n) => switch (n) {
  1 => 'اقتباس واحد',
  2 => 'اقتباسان',
  >= 3 && <= 10 => '$n اقتباسات',
  _ => '$n اقتباساً',
};

/// Text inside a Markdown table cell or a <details> block.
String _cell(String s) => s.replaceAll('|', '\\|').replaceAll('\n', ' ');
String _block(String s) => s
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    // A model's own headings stay inside its answer: bold, not page headings.
    .replaceAllMapped(RegExp(r'^#{1,6}\s*(.+)$', multiLine: true), (m) => '**${m[1]!.trim()}**')
    .trim();

/// Basirah's answer as the asker reads it: its text, then its evidence.
String _basirah(Map a) {
  final b = StringBuffer();
  void line(String label, String? text) {
    if (text != null && text.trim().isNotEmpty) b.writeln('**$label:** ${_block(text)}\n');
  }

  line('الأصل الشرعي', a['principle'] as String?);
  line('العرف والثقافة', a['culture'] as String?);
  line('المتفق عليه', a['khilafAgreed'] as String?);
  line('موضع الخلاف', a['khilafNote'] as String?);
  line('سبب الإحالة', a['referReason'] as String?);
  line('إلى من', a['referTo'] as String?);
  line('لماذا لا تتوفر إجابة موثقة', a['abstainReason'] as String?);
  line('السؤال التوضيحي', a['clarifyQuestion'] as String?);
  final guidance = ((a['guidance'] as List?) ?? const []).cast<String>();
  if (guidance.isNotEmpty) {
    b.writeln('**الإرشاد العملي:**\n');
    for (final g in guidance) {
      b.writeln('- ${_block(g)}');
    }
    b.writeln();
  }
  final evidence = ((a['evidence'] as List?) ?? const []).cast<Map>();
  if (evidence.isNotEmpty) {
    b.writeln('**الأدلة والمصادر:**\n');
    for (final e in evidence) {
      if (e['kind'] == 'quran') {
        b.writeln('- ﴿${_block(e['text'] as String)}﴾ [${e['surahName']}: ${e['ayah']}] — نص الآية منسوخ من المصحف بالكود؛ التفسير: ${e['tafsirSource'] ?? ''}${e['tafsirUrl'] == null ? '' : ' (${e['tafsirUrl']})'}');
      } else {
        b.writeln('- ${_block('${e['narrator'] ?? ''} «${e['text']}»')} — ${e['source'] ?? ''}، ${e['grade'] ?? ''}');
      }
    }
    b.writeln();
  }
  return b.toString().trim();
}

void main() {
  final base = _read('../eval/baseline_report.json');
  final prompted = _read('../eval/prompted_report.json');
  final cases = {for (final c in (_read('../eval/test_cases.json')['cases'] as List).cast<Map>()) c['id'] as String: c};
  final instructed = {for (final r in (prompted['rows'] as List).cast<Map>()) r['id'] as String: r['prompted'] as Map};
  final rows = (base['rows'] as List).cast<Map>();

  final md = StringBuffer()
    ..writeln('# كل سؤال وما فعله كل طرف')
    ..writeln()
    ..writeln(
      'الأسئلة الـ${rows.length} في المقارنة المرجعية، وما فعله كل طرف فيها، منسوخةً آلياً من ملفات النتائج المحفوظة: '
      '`eval/baseline_report.json` (النموذج العام وبصيرة) و`eval/prompted_report.json` (النموذج بتعليمات) و`eval/test_cases.json` (الأسئلة والسلوك المتوقع). '
      'أنشأتها الأداة `server/tool/questions_md.dart`، ولم يُكتب فيها شيء باليد.',
    )
    ..writeln()
    ..writeln('- **النموذج في الأطراف الثلاثة:** `${base['model']}`، بمستوى جهد medium.')
    ..writeln('- **النموذج العام:** تعليمته الوحيدة `You are a helpful assistant.`')
    ..writeln('- **النموذج بتعليمات:** النموذج نفسه بتعليمات مكتوبة للمهمة (نصها في `eval/prompted_report.json`)، بلا مصادر ولا أدوات.')
    ..writeln('- **بصيرة:** النموذج نفسه مع أدوات البحث في المصحف وتفسير الدرر السنية وموسوعة الأحاديث، ونص الآية منسوخ من المصحف بالكود، وحارس من الكود.')
    ..writeln('- **التشغيل:** النموذج العام وبصيرة في ${(base['date'] as String).substring(0, 10)}، والنموذج بتعليمات في ${(prompted['date'] as String).substring(0, 10)}؛ تشغيل واحد لكل سؤال وطرف.')
    ..writeln('- **أنواع الإجابة** بأسمائها في التطبيق: إجابة موثقة، مسألة خلافية، تفصيل واحد قبل الإجابة، يحتاج إلى مختص، لا تتوفر إجابة موثقة، خارج نطاق بصيرة.')
    ..writeln()
    ..writeln('الإجابات كاملة تحت كل سؤال: اضغط على اسم الطرف لفتحها.')
    ..writeln();

  for (final (i, r) in rows.indexed) {
    final id = r['id'] as String;
    final c = cases[id] ?? const {};
    final g = r['general'] as Map;
    final b = r['basirah'] as Map;
    final p = instructed[id];
    final expected = ((r['expect'] as List?) ?? const []).map((k) => _kind('$k')).join(' أو ');
    md
      ..writeln('## ${i + 1}. ${r['question']}')
      ..writeln()
      ..writeln('`$id` · ${_type(id)} · **المتوقع:** $expected${c['expectedBehavior'] == null ? '' : ' — ${_cell(c['expectedBehavior'] as String)}'}')
      ..writeln()
      ..writeln('| الطرف | نوع الإجابة | الفحوص الستة | الزمن |')
      ..writeln('|---|---|---|---|')
      ..writeln('| النموذج العام | — | ${_result(g)} | ${(g['seconds'] as num).toStringAsFixed(1)} ث |')
      ..writeln(p == null ? '| النموذج بتعليمات | — | لم يُشغَّل | — |' : '| النموذج بتعليمات | — | ${_result(p)} | ${(p['seconds'] as num).toStringAsFixed(1)} ث |')
      ..writeln('| بصيرة | ${_kind(b['kind'] as String)}${b['via'] == 'scope' ? ' (فحص النطاق في الكود، بلا نموذج)' : ''} | ${_result(b)} | ${(b['seconds'] as num).toStringAsFixed(1)} ث |')
      ..writeln()
      ..writeln('<details><summary>إجابة النموذج العام كاملة</summary>\n\n${_block(g['text'] as String)}\n\n</details>\n');
    if (p != null) md.writeln('<details><summary>إجابة النموذج بتعليمات كاملة</summary>\n\n${_block(p['text'] as String)}\n\n</details>\n');
    md.writeln('<details><summary>إجابة بصيرة كاملة</summary>\n\n${_basirah(b['answer'] as Map)}\n\n</details>\n');
  }
  File('../eval/QUESTIONS.md').writeAsStringSync(md.toString());
  stdout.writeln('${rows.length} questions → eval/QUESTIONS.md');
}
