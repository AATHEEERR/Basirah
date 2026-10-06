import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../core/lang.dart';

/// Pill that shows the interface language in its own name and opens the
/// list of all of them: Arabic, and the 25 languages with an approved
/// translation of the meanings.
class LangToggle extends ConsumerWidget {
  const LangToggle({super.key, this.color = BColors.surfaceMuted, this.tooltip = true});

  final Color color;

  /// Off where there is no Overlay (the website header sits above the
  /// Navigator).
  final bool tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(langProvider);
    final name = uiLanguages.firstWhere((l) => l.$1 == ui, orElse: () => uiLanguages.first).$2;
    final message = context.tr('لغة الواجهة', 'Interface language');
    final pill = Material(
      color: color,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => _pick(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.translate_rounded, size: 18, color: BColors.ink),
              const SizedBox(width: 6),
              Text(name, style: BText.label(13.5, color: BColors.ink, weight: FontWeight.w600)),
              const Icon(Icons.expand_more_rounded, size: 18, color: BColors.ink),
            ],
          ),
        ),
      ),
    );
    return tooltip ? Tooltip(message: message, child: pill) : Semantics(label: message, button: true, child: pill);
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    // The header has no Navigator above it: the list opens in the app's.
    final host = ref.read(appRouterProvider).routerDelegate.navigatorKey.currentContext ?? context;
    final current = ref.read(langProvider);
    final chosen = await showDialog<String>(
      context: host,
      builder: (dialog) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520, maxHeight: MediaQuery.of(dialog).size.height * .8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 8, 4),
                child: Row(
                  children: [
                    Expanded(child: Text(dialog.tr('لغة الواجهة', 'Interface language'), style: BText.title(17))),
                    IconButton(
                      onPressed: () => Navigator.of(dialog).pop(),
                      tooltip: dialog.tr('إغلاق', 'Close'),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  dialog.tr(
                    'الإجابات المراجَعة بالعربية والإنجليزية؛ واسأل بأي لغة تصلك الإجابة بلغتك، ومعاني الآيات بترجمة معتمدة.',
                    'The reviewed answers are in Arabic and English; ask in any language and the answer comes in yours, with an approved translation of the verses’ meanings.',
                  ),
                  style: BText.label(12.5, weight: FontWeight.w400),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (code, native, rtl) in uiLanguages)
                        ChoiceChip(
                          selected: code == current,
                          onSelected: (_) => Navigator.of(dialog).pop(code),
                          label: Text(native, textDirection: rtl ? TextDirection.rtl : TextDirection.ltr),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null && chosen != current) await ref.read(langProvider.notifier).set(chosen);
  }
}
