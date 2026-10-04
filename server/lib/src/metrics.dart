import 'dart:convert';
import 'dart:io';

/// Anonymous usage and feedback for «لوحة الأثر» (the impact page).
///
/// An event never holds the question text, an IP address or any user or
/// device id: only what kind of answer was given and how, and for feedback
/// the rating and its fixed reasons. Times are kept to the hour, so events
/// cannot be lined up with one person's visit.
class Metrics {
  Metrics({this.file = 'cache/metrics.jsonl', DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// One JSON event per line. On a server whose disk is replaced on every
  /// deploy, point METRICS_FILE at a persistent disk.
  final String file;
  final DateTime Function() _clock;

  /// The only reasons a rating may carry (chosen from buttons, never typed).
  static const helpfulReasons = {'clear', 'answered', 'sources'};
  static const unhelpfulReasons = {'unclear', 'incomplete', 'evidence', 'misunderstood'};

  static const _kinds = {'answer', 'khilaf', 'refer', 'abstain', 'offTopic'};
  static const _vias = {'ai', 'kb', 'offline', 'scope'};

  String get _hour {
    final t = _clock().toUtc();
    return '${t.toIso8601String().substring(0, 13)}:00Z';
  }

  void _append(Map<String, Object?> event) {
    try {
      final f = File(file);
      f.parent.createSync(recursive: true);
      f.writeAsStringSync('${jsonEncode(event)}\n', mode: FileMode.append, flush: true);
    } on FileSystemException catch (e) {
      stderr.writeln('metrics: could not write ($e)');
    }
  }

  /// One answered question.
  void recordAsk({
    required String kind,
    required String via,
    required bool cached,
    required int ms,
    required int verses,
    required int hadith,
    required int guardCatches,
    required String lang,
    String? category,
  }) => _append({
    'e': 'ask',
    't': _hour,
    'kind': kind,
    'via': via,
    'cached': cached,
    'ms': ms,
    'verses': verses,
    'hadith': hadith,
    'guard': guardCatches,
    'lang': lang,
    'category': ?category,
  });

  /// A rating from the button under an answer. Returns false (and records
  /// nothing) when anything is outside the fixed choices.
  bool recordFeedback({
    required bool helpful,
    required List<String> reasons,
    required String kind,
    required String lang,
    String? category,
  }) {
    final allowed = helpful ? helpfulReasons : unhelpfulReasons;
    if (!_kinds.contains(kind) || (lang != 'ar' && lang != 'en') || reasons.length > 4 || reasons.any((r) => !allowed.contains(r))) {
      return false;
    }
    if (category != null && !RegExp(r'^[a-z][a-z0-9_-]{0,30}$').hasMatch(category)) return false;
    _append({
      'e': 'feedback',
      't': _hour,
      'helpful': helpful,
      'reasons': reasons.toSet().toList(),
      'kind': kind,
      'lang': lang,
      'category': ?category,
    });
    return true;
  }

  /// Totals for the impact page: counts and shares only, never an event.
  Map<String, Object?> summary() {
    final asks = <Map<String, dynamic>>[];
    final feedback = <Map<String, dynamic>>[];
    final f = File(file);
    if (f.existsSync()) {
      for (final line in f.readAsLinesSync()) {
        try {
          final e = jsonDecode(line) as Map<String, dynamic>;
          (e['e'] == 'ask' ? asks : feedback).add(e);
        } on FormatException {
          // A torn last line after a crash: skip it.
        }
      }
    }
    Map<String, int> count(Iterable<Object?> values) {
      final m = <String, int>{};
      for (final v in values) {
        if (v != null) m['$v'] = (m['$v'] ?? 0) + 1;
      }
      return m;
    }

    final ms = [
      for (final a in asks)
        if (a['cached'] != true) (a['ms'] as num).toInt(),
    ]..sort();
    int? pct(double q) => ms.isEmpty ? null : ms[((ms.length - 1) * q).round()];
    final reasons = count([for (final f in feedback) ...(f['reasons'] as List)]);
    return {
      'since': asks.isEmpty ? null : asks.first['t'],
      'questions': asks.length,
      'kinds': count(asks.map((a) => a['kind'])),
      'via': count(asks.map((a) => _vias.contains(a['via']) ? a['via'] : 'other')),
      'cached': asks.where((a) => a['cached'] == true).length,
      'withVerses': asks.where((a) => (a['verses'] as num? ?? 0) > 0).length,
      'withHadith': asks.where((a) => (a['hadith'] as num? ?? 0) > 0).length,
      'guardCatches': asks.where((a) => (a['guard'] as num? ?? 0) > 0).length,
      'medianMs': pct(.5),
      'p90Ms': pct(.9),
      'lang': count(asks.map((a) => a['lang'])),
      'categories': count(asks.map((a) => a['category'])),
      'feedback': {'total': feedback.length, 'helpful': feedback.where((f) => f['helpful'] == true).length, 'reasons': reasons},
    };
  }
}
