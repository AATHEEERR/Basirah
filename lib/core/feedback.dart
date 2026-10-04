import 'dart:convert';

import 'package:basirah_core/basirah_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'config.dart';

/// The fixed reasons a rating may carry (the server accepts no others and
/// no typed text): (id, Arabic, English).
const helpfulReasons = [
  ('clear', 'واضحة', 'Clear'),
  ('answered', 'أجابت سؤالي', 'Answered my question'),
  ('sources', 'مصادرها مطمئنة', 'Trustworthy sources'),
];
const unhelpfulReasons = [
  ('unclear', 'غير واضحة', 'Unclear'),
  ('incomplete', 'ناقصة', 'Incomplete'),
  ('evidence', 'الدليل لا يناسب السؤال', 'The evidence does not fit'),
  ('misunderstood', 'لم تفهم سؤالي', 'Misunderstood my question'),
];

/// Ratings given in this session, by answer key: one rating per answer.
final ratedProvider = StateProvider<Map<String, bool>>((ref) => const {});

/// Sends one rating. Only the answer's kind, its category, the language and
/// the chosen reasons leave the device — never the question.
Future<bool> sendFeedback({
  required BasirahAnswer answer,
  required bool helpful,
  required List<String> reasons,
  String? category,
}) async {
  if (!AppConfig.hasApi) return false;
  try {
    final res = await http
        .post(
          Uri.parse('${AppConfig.apiBase}/api/feedback'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'helpful': helpful,
            'reasons': reasons,
            'kind': answer.kind.name,
            'lang': RegExp('[؀-ۿ]').hasMatch(answer.question) ? 'ar' : 'en',
            'category': ?category,
          }),
        )
        .timeout(const Duration(seconds: 15));
    return res.statusCode == 200;
  } on Exception {
    return false;
  }
}

/// «لوحة الأثر»: the server's anonymous totals (null without a server).
final statsProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  if (!AppConfig.hasApi) return null;
  final res = await http.get(Uri.parse('${AppConfig.apiBase}/api/stats')).timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) throw Exception('stats ${res.statusCode}');
  return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
});
