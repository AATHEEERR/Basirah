import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/lang.dart';
import 'patterns.dart';

/// Text painted with the gold gradient (used sparingly for accents).
class GoldText extends StatelessWidget {
  const GoldText(this.text, {super.key, required this.style, this.textAlign});

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  /// One solid deep gold, the interface's gold everywhere: the lighter
  /// gradient read as pale yellow on the light canvas.
  @override
  Widget build(BuildContext context) => Text(text, textAlign: textAlign, style: style.copyWith(color: BColors.goldDeep));
}

/// White rounded card — the basic surface.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.onTap,
    this.glow,
    this.glowAlignment = const Alignment(-1, 1),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Optional pastel glow in one corner.
  final Color? glow;
  final Alignment glowAlignment;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BColors.surface,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: glow == null
              ? null
              : BoxDecoration(
                  gradient: RadialGradient(
                    center: glowAlignment,
                    radius: 1.0,
                    colors: [glow!, glow!.withValues(alpha: 0)],
                  ),
                ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A category's card background: a soft two-colour wash in the category's
/// hue with a faint star lattice over the whole card. Always given a bounded
/// size: the content fills the card, so a tap or hover covers all of it.
class CategoryBackdrop extends StatelessWidget {
  const CategoryBackdrop({
    super.key,
    required this.category,
    required this.child,
    this.radius = 26,
  });

  final Category category;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [category.top, category.bottom],
        ),
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(painter: StarLatticePainter(color: category.accent, opacity: .09, cell: 56)),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Small square of a category's colours with its icon (chips, headers).
class CoverArt extends StatelessWidget {
  const CoverArt({super.key, required this.category, this.size = 40, this.radius = 12});

  final Category category;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [category.top, category.bottom],
      ),
    ),
    child: Icon(category.iconData, size: size * .58, color: category.accent),
  );
}

/// «N أسئلة» on a category card, in the category's colour.
class CountPill extends StatelessWidget {
  const CountPill({super.key, required this.category, required this.count});

  final Category category;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .75),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.format_list_bulleted_rounded, size: 14, color: category.accent),
        const SizedBox(width: 5),
        Text(
          context.tr('$count أسئلة', '$count questions'),
          style: BText.label(12, color: category.accent, weight: FontWeight.w600),
        ),
      ],
    ),
  );
}

/// Circle with a pastel fill and a tinted icon.
class IconBubble extends StatelessWidget {
  const IconBubble({super.key, required this.icon, required this.color, this.size = 44, this.fill});

  final IconData icon;
  final Color color;
  final Color? fill;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: fill ?? color.withValues(alpha: .13), shape: BoxShape.circle),
    child: Icon(icon, color: color, size: size * .5),
  );
}

class LevelChip extends StatelessWidget {
  const LevelChip(this.level, {super.key, this.compact = false});

  final ContentLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = level.color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 11, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        () {
          final lang = context.lang;
          final name = '${context.tr('مستوى', 'Level')} ${level.letterFor(lang)}';
          return compact ? name : '$name · ${level.shortLabelFor(lang)}';
        }(),
        style: BText.label(compact ? 11.5 : 12, color: c, weight: FontWeight.w600),
      ),
    );
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.icon, required this.label, this.color, this.dark = false});

  final IconData icon;
  final String label;
  final Color? color;

  /// Black badge.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final c = dark ? BColors.onInk : (color ?? BColors.textMuted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dark ? BColors.ink : BColors.surfaceMuted,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: BText.label(12, color: c), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// Grey pill with an arrow: the "see more" affordance next to titles.
class ArrowPill extends StatelessWidget {
  const ArrowPill({super.key, required this.onTap, this.tooltip});

  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? context.tr('عرض الكل', 'See all'),
    child: Material(
      color: BColors.surfaceMuted,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: const SizedBox(
          width: 88,
          height: 52,
          child: Icon(Icons.arrow_forward_rounded, color: BColors.ink, size: 22),
        ),
      ),
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.eyebrow, this.onMore, this.linkLabel, this.onLink});

  final String title;
  final String? subtitle;

  /// Small line above the title (e.g. «استكشف»).
  final String? eyebrow;

  /// Shows the grey arrow pill.
  final VoidCallback? onMore;

  /// Underlined text link (e.g. «عرض الكل ←»).
  final String? linkLabel;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 30, 20, 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) Text(eyebrow!, style: BText.label(13, weight: FontWeight.w400)),
              Text(title, style: BText.display(22)),
              if (subtitle != null) Text(subtitle!, style: BText.label(13, weight: FontWeight.w400)),
            ],
          ),
        ),
        if (onMore != null) ArrowPill(onTap: onMore!),
        if (linkLabel != null)
          InkWell(
            onTap: onLink,
            child: Row(
              children: [
                Text(
                  linkLabel!,
                  style: BText.label(14, color: BColors.ink, weight: FontWeight.w500)
                      .copyWith(decoration: TextDecoration.underline),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 18, color: BColors.ink),
              ],
            ),
          ),
      ],
    ),
  );
}

/// A numbered question row on a white card, like a track in a playlist.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.onTap,
    this.kind,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 10),
  });

  /// Space around the tile (the website's columns need no side padding).
  final EdgeInsets padding;

  final int index;
  final String title;
  final String subtitle;
  final ContentLevel level;
  final AnswerKind? kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kindTone = switch (kind) {
      AnswerKind.khilaf => Tones.khilaf,
      AnswerKind.refer => Tones.refer,
      _ => null,
    };
    return Padding(
      padding: padding,
      child: SoftCard(
        onTap: onTap,
        radius: 20,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: BColors.bg, shape: BoxShape.circle),
              child: Text(index.toString().padLeft(2, '0'), style: BText.label(13, color: BColors.ink)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: BText.title(15, weight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: level.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(subtitle, style: BText.label(12, weight: FontWeight.w400), overflow: TextOverflow.ellipsis),
                      ),
                      if (kindTone != null) ...[
                        const SizedBox(width: 8),
                        Icon(kindTone.icon, size: 14, color: kindTone.accent),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: BColors.textFaint),
          ],
        ),
      ),
    );
  }
}

/// Round amber action button.
class GoldCircleButton extends StatelessWidget {
  const GoldCircleButton({super.key, required this.icon, required this.onTap, this.size = 56, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: BColors.gold,
        boxShadow: [BoxShadow(color: BColors.gold.withValues(alpha: .35), blurRadius: 16, spreadRadius: -4, offset: const Offset(0, 6))],
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: size,
            child: Icon(icon, color: BColors.onInk, size: size * .46),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Ink-black pill — the primary action.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onTap, this.icon, this.expand = false});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BColors.ink,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: BText.title(15, color: BColors.onInk, weight: FontWeight.w500)),
              if (icon != null) ...[
                const SizedBox(width: 10),
                Icon(icon, color: BColors.onInk, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Grey pill — secondary action.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Material(
    color: BColors.surfaceMuted,
    borderRadius: BorderRadius.circular(99),
    child: InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: BColors.ink),
              const SizedBox(width: 8),
            ],
            Flexible(child: Text(label, style: BText.label(13.5, color: BColors.ink))),
          ],
        ),
      ),
    ),
  );
}

/// Fades and lifts its child in after [delay].
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.delay = Duration.zero, this.offset = 18});

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    child: widget.child,
    builder: (_, child) => Opacity(
      opacity: _a.value,
      child: Transform.translate(offset: Offset(0, (1 - _a.value) * widget.offset), child: child),
    ),
  );
}

class EmptyNote extends StatelessWidget {
  const EmptyNote({super.key, required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
    child: Column(
      children: [
        IconBubble(icon: icon, color: BColors.beigeInk, fill: BColors.beige, size: 64),
        const SizedBox(height: 14),
        Text(title, style: BText.title(16), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(body, style: BText.body(13.5, color: BColors.textMuted, height: 1.7), textAlign: TextAlign.center),
      ],
    ),
  );
}
