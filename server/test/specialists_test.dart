import 'package:basirah_server/src/specialists.dart';
import 'package:test/test.dart';

void main() {
  // Few rounds: the same code, fast enough for a test.
  const rounds = 50;

  test('PBKDF2-HMAC-SHA256 matches the RFC 7914 test vector', () {
    final out = SpecialistAccounts.pbkdf2('passwd'.codeUnits, 'salt'.codeUnits, 1, 64);
    final hex = out.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    expect(
      hex,
      '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
      '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
    );
  });

  test('only an account the team made can sign in', () {
    final accounts = SpecialistAccounts(SpecialistAccounts.entry('Sheikh', 'correct horse', iterations: rounds), iterations: rounds);
    final ok = accounts.signIn('sheikh', 'correct horse', from: 'a');
    expect(ok.error, isNull);
    expect(accounts.user(ok.token), 'sheikh');
    expect(accounts.signIn('sheikh', 'wrong', from: 'b').error, 'invalid');
    expect(accounts.signIn('someone', 'correct horse', from: 'c').error, 'invalid');
    expect(accounts.user('made-up-token'), isNull);
  });

  test('a pasted entry with line breaks and spaces still works', () {
    final entry = SpecialistAccounts.entry('mufti', 'right', iterations: rounds);
    final broken = ' ${entry.substring(0, 30)}\n${entry.substring(30)} \r\n';
    final accounts = SpecialistAccounts(broken, iterations: rounds);
    expect(accounts.signIn('mufti', 'right', from: 'a').error, isNull);
  });

  test('no accounts: the panel is closed', () {
    final accounts = SpecialistAccounts('', iterations: rounds);
    expect(accounts.open, isFalse);
    expect(accounts.signIn('x', 'y', from: 'a').error, 'closed');
  });

  test('after five failures an address is refused, even with the right password', () {
    final accounts = SpecialistAccounts(SpecialistAccounts.entry('mufti', 'right', iterations: rounds), iterations: rounds);
    for (var i = 0; i < SpecialistAccounts.maxFailures; i++) {
      expect(accounts.signIn('mufti', 'guess$i', from: 'ip1').error, 'invalid');
    }
    expect(accounts.signIn('mufti', 'right', from: 'ip1').error, 'too_many');
    // Another address is not affected.
    expect(accounts.signIn('mufti', 'right', from: 'ip2').error, isNull);
  });

  test('a session ends after its life, and on sign-out', () {
    var now = DateTime.utc(2026, 10, 6, 12);
    final accounts = SpecialistAccounts(SpecialistAccounts.entry('mufti', 'right', iterations: rounds), clock: () => now, iterations: rounds);
    final a = accounts.signIn('mufti', 'right', from: 'x').token;
    final b = accounts.signIn('mufti', 'right', from: 'x').token;
    expect(accounts.user(a), 'mufti');
    accounts.signOut(b);
    expect(accounts.user(b), isNull);
    now = now.add(SpecialistAccounts.sessionLife);
    expect(accounts.user(a), isNull);
  });
}
