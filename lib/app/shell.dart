import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/state.dart';
import '../shared/patterns.dart';
import '../shared/web_frame.dart';
import 'theme.dart';
import '../core/lang.dart';

/// Tab shell in the Nusuk idiom: a white rounded bar with glyph tabs that
/// fill with amber when active, and an assistant pill («بصيرة AI •••»).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  // (branch index, glyph, Arabic label, English label). Branch 2 is the Ask
  // tab, reached via the pill.
  static const _tabs = [
    (0, Glyph.hexagon, 'الرئيسية', 'Home'),
    (1, Glyph.star, 'استكشف', 'Explore'),
    (3, Glyph.book, 'مكتبتي', 'Library'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = shell.currentIndex;
    void askTab() {
      ref.read(askDraftProvider.notifier).state = null;
      shell.goBranch(2);
    }

    // Website layout (a computer): the website header above the app holds
    // the navigation, so no bar here.
    if (isWebsite(context)) return Scaffold(body: shell);

    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: BColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
            child: Row(
              children: [
                for (final (branch, glyph, ar, en) in _tabs)
                  Expanded(
                    child: _NavItem(
                      glyph: glyph,
                      label: context.tr(ar, en),
                      selected: current == branch,
                      onTap: () => shell.goBranch(branch, initialLocation: branch == current),
                    ),
                  ),
                const SizedBox(width: 6),
                _AiPill(active: current == 2, onTap: askTab),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.glyph, required this.label, required this.selected, required this.onTap});

  final Glyph glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NavGlyph(glyph, active: selected),
            const SizedBox(height: 4),
            Text(
              label,
              style: BText.label(12, color: BColors.ink, weight: selected ? FontWeight.w600 : FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiPill extends StatelessWidget {
  const _AiPill({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? BColors.ink : BColors.bg,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('بصيرة AI', 'Basirah AI'), style: BText.label(13.5, color: active ? BColors.onInk : BColors.ink)),
              const SizedBox(width: 8),
              _Dots(color: active ? BColors.goldOnInk : BColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final s in const [4.0, 5.0, 6.5])
        Container(
          width: s,
          height: s,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
    ],
  );
}
