import 'dart:convert';
import 'dart:io';

import 'package:basirah_core/basirah_core.dart';

/// Loads the same `assets/kb/*.json` files the app bundles (Arabic master
/// text + the English overlay `en.json`, when present).
KnowledgeBase loadKnowledgeBase(String dir) {
  Map<String, dynamic> read(String name) =>
      jsonDecode(File('$dir/$name').readAsStringSync()) as Map<String, dynamic>;
  final en = File('$dir/en.json');
  return KnowledgeBase.fromJsonFiles(
    categories: read('categories.json'),
    faqs: read('faqs.json'),
    evidence: read('evidence.json'),
    reference: read('reference.json'),
    english: en.existsSync() ? read('en.json') : null,
  );
}
