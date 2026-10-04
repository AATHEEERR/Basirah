import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../core/lang.dart';

/// Pill that switches the interface between Arabic and English. It shows the
/// language you would switch *to*, written in that language.
class LangToggle extends ConsumerWidget {
  const LangToggle({super.key, this.color = BColors.surfaceMuted, this.tooltip = true});

  final Color color;

  /// Off where there is no Overlay (the website header sits above the
  /// Navigator).
  final bool tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final en = ref.watch(langProvider) == 'en';
    final message = en ? 'التبديل إلى العربية' : 'Switch to English';
    final pill = Material(
      color: color,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => ref.read(langProvider.notifier).toggle(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.translate_rounded, size: 18, color: BColors.ink),
              const SizedBox(width: 6),
              Text(en ? 'العربية' : 'English', style: BText.label(13.5, color: BColors.ink, weight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
    return tooltip ? Tooltip(message: message, child: pill) : Semantics(label: message, child: pill);
  }
}
