import 'dart:convert';

import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../shared/brand.dart';
import 'lang.dart';
import 'ui_strings.dart';

/// The curated knowledge base's files, bundled with the app (same files as
/// the API): the Arabic master text plus the English overlay.
final _kbFilesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  Future<Map<String, dynamic>> load(String name) async =>
      jsonDecode(await rootBundle.loadString('assets/kb/$name')) as Map<String, dynamic>;
  return Future.wait([
    load('categories.json'),
    load('faqs.json'),
    load('evidence.json'),
    load('reference.json'),
    load('en.json'),
  ]);
});

KnowledgeBase _fromFiles(List<Map<String, dynamic>> files, Map<String, dynamic> english) => KnowledgeBase.fromJsonFiles(
  categories: files[0],
  faqs: files[1],
  evidence: files[2],
  reference: files[3],
  english: english,
);

/// The curated knowledge base.
final baseKbProvider = FutureProvider<KnowledgeBase>((ref) async {
  final files = await ref.watch(_kbFilesProvider.future);
  return _fromFiles(files, files[4]);
});

/// The knowledge base in the interface language (what screens display). In
/// the other interface languages the reviewed answers stay in English, and
/// the categories' names are translated with the interface.
final kbProvider = FutureProvider<KnowledgeBase>((ref) async {
  final ui = ref.watch(langProvider);
  if (ui == 'ar' || ui == 'en') return (await ref.watch(baseKbProvider.future)).localized(ui);
  final files = await ref.watch(_kbFilesProvider.future);
  final english = Map<String, dynamic>.of(files[4]);
  english['categories'] = {
    for (final MapEntry(:key, :value) in (files[4]['categories'] as Map<String, dynamic>).entries)
      key: {
        for (final MapEntry(key: field, value: text) in (value as Map<String, dynamic>).entries)
          field: text is String ? UiStrings.fromEnglish(text) : text,
      },
  };
  return _fromFiles(files, english).localized('en');
});

/// On-device routers for each answer language (retrieval + safety rules).
final routersProvider = Provider<Map<String, OfflineRouter>?>((ref) {
  final base = ref.watch(baseKbProvider).valueOrNull;
  if (base == null) return null;
  return {'ar': OfflineRouter(base), 'en': OfflineRouter(base.localized('en'))};
});

/// The router for the interface language (search on the Explore tab).
final routerProvider = Provider<OfflineRouter?>((ref) {
  final routers = ref.watch(routersProvider);
  return routers?[contentLang(ref.watch(langProvider))];
});

/// Renders [builder] once the knowledge base is loaded.
class KbBuilder extends ConsumerWidget {
  const KbBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, KnowledgeBase kb) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(kbProvider).when(
      skipLoadingOnReload: true,
      data: (kb) => builder(context, kb),
      loading: () => const Center(child: BrandLogo(size: 56, motion: LogoMotion.twinkle)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${context.tr('تعذّر تحميل قاعدة المعرفة', 'Could not load the knowledge base')}\n$e',
            style: BText.body(14),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
