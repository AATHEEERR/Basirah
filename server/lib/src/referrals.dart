import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// «تحدّث مع مختص شرعي»: requests from askers to a Sharia specialist, by
/// written message or a booked voice or video call, answered from the
/// specialists' panel.
///
/// Privacy: a request holds only what the asker saw and approved before
/// sending (the question, a short form of the conversation, «سياقي»). It is
/// deleted [keepFor] after it was made. The asker reads it back with a
/// secret token kept on their device; nothing identifies them.
class Referrals {
  Referrals({required this.file, this.keepFor = const Duration(days: 30), Random? random})
    : _random = random ?? Random.secure() {
    _load();
  }

  final String file;
  final Duration keepFor;
  final Random _random;
  final _items = <String, Map<String, dynamic>>{};

  static const modes = {'message', 'audio', 'video'};
  static const statuses = {'new', 'answered', 'booked', 'closed'};
  static const maxQuestion = 1200;
  static const maxConversation = 6000;
  static const maxMessage = 2000;

  /// A new request. Returns null when it is not valid.
  Map<String, dynamic>? create({
    required String question,
    required String conversation,
    required String context,
    required String lang,
    required String mode,
    DateTime? slot,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now().toUtc();
    question = question.trim();
    if (question.isEmpty || question.length > maxQuestion) return null;
    if (conversation.length > maxConversation || context.length > 300) return null;
    if (!modes.contains(mode)) return null;
    if (!RegExp(r'^[a-z]{2,3}$').hasMatch(lang)) return null;
    if (mode != 'message') {
      // A call needs a time within the next two weeks.
      if (slot == null || slot.isBefore(at) || slot.isAfter(at.add(const Duration(days: 14)))) return null;
    }
    _purge(at);
    final id = _code(6);
    final r = <String, dynamic>{
      'id': id,
      'token': _code(24),
      'created': at.toIso8601String(),
      'lang': lang,
      'mode': mode,
      'slot': mode == 'message' ? null : slot!.toUtc().toIso8601String(),
      // A private room per request, opened in the browser at the booked time.
      'meetUrl': mode == 'message' ? null : 'https://meet.jit.si/Basirah-$id-${_code(10)}',
      'status': 'new',
      'question': question,
      'conversation': conversation.trim(),
      'context': context.trim(),
      'messages': <Map<String, dynamic>>[],
    };
    _items[id] = r;
    _save();
    return r;
  }

  /// The asker's view of a request (with its token), or null.
  Map<String, dynamic>? forAsker(String id, String token) {
    final r = _items[id];
    if (r == null || !_same(r['token'] as String, token)) return null;
    return _public(r);
  }

  /// A follow-up from the asker. False when the token or text is wrong.
  bool askerMessage(String id, String token, String text, {DateTime? now}) {
    final r = _items[id];
    text = text.trim();
    if (r == null || !_same(r['token'] as String, token) || text.isEmpty || text.length > maxMessage) return false;
    if (r['status'] == 'closed') return false;
    (r['messages'] as List).add({'from': 'asker', 'text': text, 'at': (now ?? DateTime.now().toUtc()).toIso8601String()});
    if (r['status'] == 'answered') r['status'] = 'new';
    _save();
    return true;
  }

  /// All requests for the specialists' panel, the newest first.
  List<Map<String, dynamic>> all({DateTime? now}) {
    _purge(now ?? DateTime.now().toUtc());
    final list = [for (final r in _items.values) _public(r)];
    list.sort((a, b) => (b['created'] as String).compareTo(a['created'] as String));
    return list;
  }

  /// A specialist's reply, and optionally a new status (e.g. «booked»).
  bool reply(String id, {String text = '', String? status, DateTime? now}) {
    final r = _items[id];
    text = text.trim();
    if (r == null || text.length > maxMessage) return false;
    if (status != null && !statuses.contains(status)) return false;
    if (text.isEmpty && status == null) return false;
    if (text.isNotEmpty) {
      (r['messages'] as List).add({'from': 'specialist', 'text': text, 'at': (now ?? DateTime.now().toUtc()).toIso8601String()});
    }
    r['status'] = status ?? 'answered';
    _save();
    return true;
  }

  int get length => _items.length;

  Map<String, dynamic> _public(Map<String, dynamic> r) => {
    for (final e in r.entries)
      if (e.key != 'token') e.key: e.value,
  };

  void _purge(DateTime now) {
    final before = _items.length;
    _items.removeWhere((_, r) => now.difference(DateTime.parse(r['created'] as String)) > keepFor);
    if (_items.length != before) _save();
  }

  String _code(int n) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return String.fromCharCodes([for (var i = 0; i < n; i++) alphabet.codeUnitAt(_random.nextInt(alphabet.length))]);
  }

  /// Compares tokens in constant time.
  static bool _same(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  void _load() {
    try {
      final f = File(file);
      if (!f.existsSync()) return;
      for (final r in (jsonDecode(f.readAsStringSync()) as List).cast<Map<String, dynamic>>()) {
        _items[r['id'] as String] = r;
      }
    } on Object catch (e) {
      stderr.writeln('referrals: could not read $file ($e)');
    }
  }

  void _save() {
    try {
      final f = File(file)..parent.createSync(recursive: true);
      final tmp = File('$file.tmp')..writeAsStringSync(jsonEncode(_items.values.toList()));
      tmp.renameSync(f.path);
    } on Object catch (e) {
      stderr.writeln('referrals: could not write $file ($e)');
    }
  }
}
