import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// The specialists' accounts. The team makes each one (there is no sign-up):
/// SPECIALIST_ACCOUNTS holds one `username:salt:hash` per account, separated
/// by `;`, the salt and hash in base64url and the hash PBKDF2-HMAC-SHA256 of
/// the password ([iterations] rounds). `tool/specialist_account.dart` makes
/// an entry. A sign-in opens a session for [sessionLife]; the panel sends
/// its token in `x-specialist-session`. After [maxFailures] failed sign-ins
/// from one address within [failureWindow], that address is refused until
/// the window passes, even with the right password.
class SpecialistAccounts {
  SpecialistAccounts(String? spec, {DateTime Function()? clock, this.iterations = defaultIterations})
    : _clock = clock ?? DateTime.now,
      _accounts = _parse(spec);

  static const defaultIterations = 60000;
  static const sessionLife = Duration(hours: 12);
  static const maxFailures = 5;
  static const failureWindow = Duration(minutes: 15);

  final int iterations;
  final DateTime Function() _clock;
  final Map<String, ({Uint8List salt, Uint8List hash})> _accounts;
  final _sessions = <String, ({String user, DateTime expires})>{};
  final _failures = <String, List<DateTime>>{};
  final _random = Random.secure();

  /// Whether any account exists (the panel is closed without one).
  bool get open => _accounts.isNotEmpty;

  /// How many accounts parsed (for /health: a count, never a name).
  int get count => _accounts.length;

  /// The entries of a pasted value: a `KEY=` prefix, quotes, spaces and line
  /// breaks dropped (an entry never has any), split on «;».
  static List<String> entries(String? spec) {
    var text = (spec ?? '').trim();
    if (text.startsWith('SPECIALIST_ACCOUNTS=')) text = text.substring('SPECIALIST_ACCOUNTS='.length);
    text = text.replaceAll(RegExp('[\\s"\'«»]'), '');
    return [for (final e in text.split(';')) if (e.isNotEmpty) e];
  }

  /// The shape of a value, for /health: per entry, the length of each
  /// «:»-separated part (a valid entry is three: name, 24, 44). Lengths only.
  static List<List<int>> shape(String? spec) => [
    for (final e in entries(spec)) [for (final p in e.split(':')) p.length],
  ];

  static Map<String, ({Uint8List salt, Uint8List hash})> _parse(String? spec) {
    final out = <String, ({Uint8List salt, Uint8List hash})>{};
    for (final entry in entries(spec)) {
      final parts = entry.split(':');
      if (parts.length != 3 || parts[0].isEmpty) continue;
      try {
        out[parts[0].toLowerCase()] = (
          salt: base64Url.decode(base64Url.normalize(parts[1])),
          hash: base64Url.decode(base64Url.normalize(parts[2])),
        );
      } on FormatException {
        continue;
      }
    }
    return out;
  }

  /// A new account entry for SPECIALIST_ACCOUNTS (the tool's job).
  static String entry(String username, String password, {int iterations = defaultIterations}) {
    final random = Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
    final hash = pbkdf2(utf8.encode(password), salt, iterations, 32);
    return '${username.toLowerCase()}:${base64Url.encode(salt)}:${base64Url.encode(hash)}';
  }

  /// PBKDF2 with HMAC-SHA256 (RFC 8018).
  static Uint8List pbkdf2(List<int> password, List<int> salt, int iterations, int length) {
    final hmac = Hmac(sha256, password);
    final out = BytesBuilder();
    for (var block = 1; out.length < length; block++) {
      var u = hmac.convert([...salt, block >> 24 & 0xff, block >> 16 & 0xff, block >> 8 & 0xff, block & 0xff]).bytes;
      final t = List<int>.of(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.add(t);
    }
    return out.toBytes().sublist(0, length);
  }

  /// Signs in: a session token, or why not ('closed', 'too_many', 'invalid').
  ({String? token, String? error}) signIn(String username, String password, {required String from}) {
    if (!open) return (token: null, error: 'closed');
    final now = _clock();
    final recent = (_failures[from] ?? const <DateTime>[]).where((t) => now.difference(t) < failureWindow).toList();
    if (recent.length >= maxFailures) return (token: null, error: 'too_many');
    final account = _accounts[username.trim().toLowerCase()];
    // An unknown name costs the same time as a known one.
    final salt = account?.salt ?? Uint8List(16);
    final hash = pbkdf2(utf8.encode(password), salt, iterations, 32);
    if (account == null || !_same(hash, account.hash)) {
      _failures[from] = [...recent, now];
      return (token: null, error: 'invalid');
    }
    _failures.remove(from);
    _sessions.removeWhere((_, s) => !s.expires.isAfter(now));
    final token = base64Url.encode(List.generate(32, (_) => _random.nextInt(256))).replaceAll('=', '');
    _sessions[token] = (user: username.trim().toLowerCase(), expires: now.add(sessionLife));
    return (token: token, error: null);
  }

  /// The signed-in specialist for [token], or null.
  String? user(String? token) {
    if (token == null || token.isEmpty) return null;
    final s = _sessions[token];
    if (s == null) return null;
    if (!s.expires.isAfter(_clock())) {
      _sessions.remove(token);
      return null;
    }
    return s.user;
  }

  void signOut(String? token) => _sessions.remove(token);

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
