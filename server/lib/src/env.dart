import 'dart:io';

/// Reads `KEY=VALUE` lines from a local `.env` file (gitignored), then
/// overlays the real process environment, which always wins.
Map<String, String> loadEnv({String path = '.env'}) {
  final merged = <String, String>{};
  final file = File(path);
  if (file.existsSync()) {
    for (final raw in file.readAsLinesSync()) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final i = line.indexOf('=');
      if (i <= 0) continue;
      var value = line.substring(i + 1).trim();
      final quoted = value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")));
      if (quoted) value = value.substring(1, value.length - 1);
      merged[line.substring(0, i).trim()] = value;
    }
  }
  for (final e in Platform.environment.entries) {
    if (e.value.isNotEmpty) merged[e.key] = e.value;
  }
  return merged;
}
