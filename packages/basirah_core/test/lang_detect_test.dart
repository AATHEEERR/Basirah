import 'package:basirah_core/basirah_core.dart';
import 'package:test/test.dart';

void main() {
  test('detects the language of a question', () {
    const cases = {
      'لماذا يعبد المسلمون الكعبة؟': 'ar',
      'هل يجب أن أغيّر اسمي بعد الإسلام؟': 'ar',
      'What does Sharia mean?': 'en',
      'Can I visit my non-Muslim family?': 'en',
      'Pourquoi les musulmans prient-ils vers la Kaaba ?': 'fr',
      'Est-ce que je dois changer mon nom après ma conversion ?': 'fr',
      '¿Por qué los musulmanes rezan hacia la Kaaba?': 'es',
      'Por que os muçulmanos rezam voltados para a Caaba?': 'pt',
      'Warum beten Muslime in Richtung der Kaaba?': 'de',
      'Müslümanlar neden Kabe’ye doğru namaz kılar?': 'tr',
      'Mengapa umat Islam salat menghadap Ka’bah?': 'id',
      'Bakit nagdarasal ang mga Muslim paharap sa Kaaba?': 'tl',
      'Kwa nini Waislamu wanaswali kuelekea Kaaba?': 'sw',
      'Zašto muslimani klanjaju prema Kabi?': 'bs',
      'Pse myslimanët falen drejt Qabes?': 'sq',
      'Tại sao người Hồi giáo cầu nguyện hướng về Kaaba?': 'vi',
      'مسلمان کعبہ کی طرف منہ کرکے نماز کیوں پڑھتے ہیں؟': 'ur',
      'چرا مسلمانان به سوی کعبه نماز می‌خوانند؟': 'fa',
      'ولې مسلمانان کعبې ته مخ کوي؟': 'ps',
      '为什么穆斯林朝着克尔白礼拜？': 'zh',
      'なぜイスラム教徒はカアバに向かって礼拝するのですか？': 'ja',
      'मुसलमान काबा की ओर नमाज़ क्यों पढ़ते हैं?': 'hi',
      'முஸ்லிம்கள் ஏன் கஅபாவை நோக்கி தொழுகிறார்கள்?': 'ta',
      'Maxay muslimiintu u caabudaan Kacbada?': 'so',
      "Me yasa musulmai suke bauta wa Ka'aba?": 'ha',
      'Müsəlmanlar niyə Kəbəyə ibadət edirlər?': 'az',
      'Waarom aanbidden moslims de Kaaba?': 'nl',
      'মুছলমানসকলে কিয় কাবাক উপাসনা কৰে?': 'as',
      'මුස්ලිම්වරු කාබාව නමදින්නේ ඇයි?': 'si',
      // A Latin-script language without a word list: answered in its own language.
      'Miksi muslimit palvovat Kaabaa?': 'und',
    };
    for (final MapEntry(key: q, value: lang) in cases.entries) {
      expect(detectLanguage(q), lang, reason: q);
    }
  });
}
