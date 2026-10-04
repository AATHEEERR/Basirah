import 'dart:io';

import 'package:basirah_server/basirah_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// The web app is served from a folder next to the server's secrets
/// (server/.env): nothing outside that folder may ever be served.
void main() {
  late Directory tmp;
  late Handler handler;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('basirah_web');
    File('${tmp.path}/.env').writeAsStringSync('SECRET=1');
    Directory('${tmp.path}/web/assets').createSync(recursive: true);
    File('${tmp.path}/web/index.html').writeAsStringSync('<html>app</html>');
    File('${tmp.path}/web/main.dart.js').writeAsStringSync('main();');
    File('${tmp.path}/web/assets/FontManifest.json').writeAsStringSync('[]');
    handler = webAppHandler('${tmp.path}/web');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<Response> get(String path, {String method = 'GET'}) async => await handler(Request(method, Uri.parse('http://localhost/$path')));

  test('serves the app: / is index.html, files by path, no-cache', () async {
    final index = await get('');
    expect(index.statusCode, 200);
    expect(await index.readAsString(), '<html>app</html>');
    expect(index.headers['content-type'], startsWith('text/html'));
    expect(index.headers['cache-control'], 'no-cache');
    expect((await get('main.dart.js')).headers['content-type'], 'application/javascript');
    expect((await get('assets/FontManifest.json')).statusCode, 200);
  });

  test('missing files and other methods are 404', () async {
    expect((await get('nope.js')).statusCode, 404);
    expect((await get('index.html', method: 'POST')).statusCode, 404);
  });

  test('never leaves the folder, however the path is encoded', () async {
    for (final path in [
      '..%2F.env', // decoded into one segment «../.env»: the case that got through
      '%2E%2E%2F.env',
      '%2e%2e/.env',
      '../.env',
      '..%5C.env',
      'assets%2F..%2F..%2F.env',
      'assets/..%2F..%2F.env',
      '%2F.env',
      'C:%2FWindows%2Fwin.ini',
      'web/../.env',
    ]) {
      final r = await get(path);
      expect(r.statusCode, 404, reason: path);
      expect(await r.readAsString(), isNot(contains('SECRET')), reason: path);
    }
  });
}
