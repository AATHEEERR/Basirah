import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../shared/patterns.dart';
import '../../shared/web_frame.dart';
import '../answer/answer_screen.dart';

/// Shared layout for the reading pages (glossary, references, about).
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const PatternBackdrop(height: 300),
          ReadingWidth(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  toolbarHeight: 64,
                  automaticallyImplyLeading: false,
                  backgroundColor: BColors.bg.withValues(alpha: .92),
                  titleSpacing: 12,
                  title: Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: context.tr('رجوع', 'Back'),
                        onTap: () => context.canPop()
                            ? context.pop()
                            : context.go('/library'),
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 56),
                  sliver: SliverList.list(
                    children: [
                      Text(title, style: pageTitleStyle(context, phone: 32)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: BText.label(13.5, weight: FontWeight.w400),
                        ),
                      ],
                      const SizedBox(height: 20),
                      child,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
