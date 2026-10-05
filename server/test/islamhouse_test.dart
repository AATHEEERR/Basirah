import 'package:basirah_server/basirah_server.dart';
import 'package:test/test.dart';

void main() {
  test('browse_library text → items, books first, one per title', () {
    const text = '5 of 5 items:\n\n'
        "[75590] L'Islam - Epître concise\n    audios · الفريق العلمي (author #61062) · Pour les non musulmans (category #15592)\n    L'Islam - Epître\n    https://islamcontent.com/fr/content/75590\n\n"
        "[15054] L'Islam - Epître concise (avec preuves)\n    books · الفريق العلمي (author #61062)\n    Cette épitre\n    https://islamcontent.com/fr/content/15054\n\n"
        "[15033] l'islam - epître concise\n    books · الفريق العلمي (author #61062)\n    https://islamcontent.com/fr/content/15033";
    final items = parseLibrary(text);
    expect([for (final i in items) i.id], ['15054', '75590']);
    expect(items.first.type, 'books');
    expect(items.first.url, 'https://islamcontent.com/fr/content/15054');
  });

  test('a language code that is not one is not sent', () async {
    expect(await IslamHouseLibrary().forLanguage('../x'), isEmpty);
  });
}
