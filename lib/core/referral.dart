import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// A request to a Sharia specialist made from this device. The token is the
/// only key to read it back; it never leaves the device except to read it.
class MyReferral {
  const MyReferral({
    required this.id,
    required this.token,
    required this.created,
    required this.question,
    required this.mode,
    this.slot,
    this.meetUrl,
    this.lastSeen,
  });

  factory MyReferral.fromJson(Map<String, dynamic> j) => MyReferral(
    id: j['id'] as String,
    token: j['token'] as String,
    created: DateTime.parse(j['created'] as String),
    question: j['question'] as String,
    mode: j['mode'] as String,
    slot: j['slot'] == null ? null : DateTime.parse(j['slot'] as String),
    meetUrl: j['meetUrl'] as String?,
    lastSeen: (j['lastSeen'] as Map?)?.cast<String, dynamic>(),
  );

  final String id;
  final String token;
  final DateTime created;
  final String question;

  /// «message» or «call» («audio» and «video» from before).
  final String mode;
  final DateTime? slot;
  final String? meetUrl;

  /// The request as last read from the server (status, the specialist's
  /// replies), kept so it can be read again with no connection.
  final Map<String, dynamic>? lastSeen;

  MyReferral withLastSeen(Map<String, dynamic> live) => MyReferral(
    id: id,
    token: token,
    created: created,
    question: question,
    mode: mode,
    slot: slot,
    meetUrl: meetUrl,
    lastSeen: live,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'token': token,
    'created': created.toIso8601String(),
    'question': question,
    'mode': mode,
    'slot': slot?.toUtc().toIso8601String(),
    'meetUrl': meetUrl,
    if (lastSeen != null) 'lastSeen': lastSeen,
  };
}

/// The requests made from this device, the newest first.
class MyReferralsNotifier extends Notifier<List<MyReferral>> {
  static const _key = 'basirah.referrals.v1';

  @override
  List<MyReferral> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return;
      state = [for (final j in (jsonDecode(raw) as List).cast<Map<String, dynamic>>()) MyReferral.fromJson(j)];
    } on Exception {
      // Storage unavailable: nothing kept.
    }
  }

  Future<void> add(MyReferral r) async {
    state = [r, ...state];
    await _save();
  }

  /// Keeps what the server last said about request [id].
  Future<void> remember(String id, Map<String, dynamic> live) async {
    state = [for (final r in state) r.id == id ? r.withLastSeen(live) : r];
    await _save();
  }

  Future<void> _save() async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, jsonEncode([for (final m in state) m.toJson()]));
    } on Exception {
      // Kept for this session only.
    }
  }
}

final myReferralsProvider = NotifierProvider<MyReferralsNotifier, List<MyReferral>>(MyReferralsNotifier.new);

/// Talks to the server's `/api/referral` and `/api/specialist` endpoints.
abstract final class ReferralApi {
  static Uri _u(String path, [Map<String, String>? q]) => Uri.parse('${AppConfig.apiBase}$path').replace(queryParameters: q);

  static const _json = {'content-type': 'application/json'};

  /// Sends a request the asker approved. Returns null on failure.
  static Future<MyReferral?> send({
    required String question,
    required String conversation,
    required String context,
    required String lang,
    required String mode,
    DateTime? slot,
  }) async {
    if (!AppConfig.hasApi) return null;
    try {
      final res = await http
          .post(
            _u('/api/referral'),
            headers: _json,
            body: jsonEncode({
              'consent': true,
              'question': question,
              'conversation': conversation,
              'context': context,
              'lang': lang,
              'mode': mode,
              'slot': slot?.toUtc().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return MyReferral(
        id: j['id'] as String,
        token: j['token'] as String,
        created: DateTime.now(),
        question: question,
        mode: mode,
        slot: slot,
        meetUrl: j['meetUrl'] as String?,
      );
    } on Exception {
      return null;
    }
  }

  /// The request as the server has it now (status, messages), or null.
  static Future<Map<String, dynamic>?> read(MyReferral r) async {
    try {
      final res = await http.get(_u('/api/referral/${r.id}', {'token': r.token})).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } on Exception {
      return null;
    }
  }

  static Future<bool> followUp(MyReferral r, String text) async {
    try {
      final res = await http
          .post(_u('/api/referral/${r.id}/message'), headers: _json, body: jsonEncode({'token': r.token, 'text': text}))
          .timeout(const Duration(seconds: 20));
      return res.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  /// The specialists' panel: every request, or null when the key is wrong.
  /// Every request, for the specialists' panel. [unreachable] when the
  /// server did not answer at all (not a wrong key).
  static Future<({List<Map<String, dynamic>>? items, bool unreachable})> all(String key) async {
    try {
      final res = await http.get(_u('/api/specialist/referrals'), headers: {'x-specialist-key': key}).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return (items: null, unreachable: false);
      return (
        items: ((jsonDecode(utf8.decode(res.bodyBytes)) as Map)['referrals'] as List).cast<Map<String, dynamic>>(),
        unreachable: false,
      );
    } on Exception {
      return (items: null, unreachable: true);
    }
  }

  static Future<bool> reply(String key, String id, {String text = '', String? status}) async {
    try {
      final res = await http
          .post(
            _u('/api/specialist/referrals/$id'),
            headers: {..._json, 'x-specialist-key': key},
            body: jsonEncode({'text': text, 'status': ?status}),
          )
          .timeout(const Duration(seconds: 20));
      return res.statusCode == 200;
    } on Exception {
      return false;
    }
  }
}
