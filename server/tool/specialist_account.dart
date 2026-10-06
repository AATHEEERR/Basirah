// Makes a specialist's account for the panel. The team runs it; specialists
// cannot sign up themselves.
//   dart run tool/specialist_account.dart <username>          (from server/)
// It makes a strong random password and writes, to a file that stays on this
// machine (specialist_accounts.local.txt, never committed):
//   - the username and password, to give the specialist privately;
//   - the line for SPECIALIST_ACCOUNTS (a salted PBKDF2 hash, not the
//     password), to add on the server: in Render, Environment →
//     SPECIALIST_ACCOUNTS; several accounts are joined with «;».
// Nothing secret is printed.
import 'dart:io';
import 'dart:math';

import 'package:basirah_server/src/specialists.dart';

void main(List<String> args) {
  if (args.isEmpty || !RegExp(r'^[a-zA-Z0-9._-]{3,32}$').hasMatch(args.first)) {
    stderr.writeln('usage: dart run tool/specialist_account.dart <username>   (3–32 letters, digits, . _ -)');
    exit(2);
  }
  final username = args.first.toLowerCase();
  // 20 characters from a set without look-alikes (no 0/O, 1/l/I).
  const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  final password = List.generate(20, (_) => chars[random.nextInt(chars.length)]).join();
  final entry = SpecialistAccounts.entry(username, password);

  final file = File('specialist_accounts.local.txt');
  file.writeAsStringSync(
    '${file.existsSync() ? '${file.readAsStringSync()}\n' : ''}'
    '— ${DateTime.now().toIso8601String().substring(0, 16)} —\n'
    'Give to the specialist, privately:\n'
    '  username: $username\n'
    '  password: $password\n'
    'Add to SPECIALIST_ACCOUNTS on the server (join several with ;):\n'
    '  $entry\n',
  );
  stdout.writeln('Account "$username" made. The password and the SPECIALIST_ACCOUNTS line are in server/${file.path} (kept off git).');
}
