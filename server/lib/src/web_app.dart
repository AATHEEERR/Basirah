import 'dart:io';

import 'package:shelf/shelf.dart';

/// Static files of the web app in [dir]; `/` is `index.html`. Every reply
/// says `no-cache`, so a visitor who opened the link before an update gets
/// the new version on reload (Flutter's file names carry no content hash).
Handler webAppHandler(String dir) {
  const types = {
    'html': 'text/html; charset=utf-8',
    'js': 'application/javascript',
    'mjs': 'application/javascript',
    'json': 'application/json',
    'wasm': 'application/wasm',
    'css': 'text/css',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'svg': 'image/svg+xml',
    'ico': 'image/x-icon',
    'otf': 'font/otf',
    'ttf': 'font/ttf',
    'woff2': 'font/woff2',
    'txt': 'text/plain; charset=utf-8',
  };
  final root = Directory(dir).absolute.uri.normalizePath();
  return (Request req) {
    if (req.method != 'GET' && req.method != 'HEAD') return Response.notFound('');
    // Segments are decoded, so «..%2F.env» arrives as one segment «../.env»:
    // refuse any segment that could leave the folder, then check the
    // resolved path is still inside it.
    final segments = req.url.pathSegments;
    if (segments.any((s) => s.isEmpty || s == '.' || s.contains('..') || s.contains('/') || s.contains('\\') || s.contains(':'))) {
      return Response.notFound('');
    }
    final path = segments.isEmpty ? 'index.html' : segments.join('/');
    final target = root.resolve(path).normalizePath();
    if (!target.path.startsWith(root.path)) return Response.notFound('');
    final file = File.fromUri(target);
    if (!file.existsSync()) return Response.notFound('');
    final ext = path.split('.').last.toLowerCase();
    return Response.ok(
      req.method == 'HEAD' ? null : file.openRead(),
      headers: {
        'content-type': types[ext] ?? 'application/octet-stream',
        'content-length': '${file.lengthSync()}',
        'cache-control': 'no-cache',
      },
    );
  };
}
