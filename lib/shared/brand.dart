import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/lang.dart';

/// How the logo moves.
enum LogoMotion {
  /// Still.
  none,

  /// Splash: grows in with a slight turn.
  reveal,

  /// Loading / thinking: a soft, continuous twinkle.
  twinkle,
}

/// Brand colours of the mark.
abstract final class BrandColors {
  /// The mark on light backgrounds.
  static const gold = Color(0xFFC9932C);

  /// The mark on the dark app-icon tile.
  static const goldOnInk = Color(0xFFE2B04E);

  /// The app-icon tile.
  static const ink = Color(0xFF18171C);
}

/// The Basirah logo: one large four-point sparkle with two small ones, drawn
/// flat in a single gold (no shading), from the same geometry as the app
/// icons (`tool/make_logo.ps1`).
///
/// [tile] draws it as the app icon: the gold mark on a dark rounded square.
class BrandLogo extends StatefulWidget {
  const BrandLogo({super.key, this.size = 40, this.motion = LogoMotion.none, this.tile = false});

  final double size;
  final LogoMotion motion;
  final bool tile;

  @override
  State<BrandLogo> createState() => _BrandLogoState();
}

class _BrandLogoState extends State<BrandLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: switch (widget.motion) {
      LogoMotion.reveal => const Duration(milliseconds: 1200),
      _ => const Duration(milliseconds: 1600),
    },
  );

  @override
  void initState() {
    super.initState();
    switch (widget.motion) {
      case LogoMotion.none:
        _c.value = 1;
      case LogoMotion.reveal:
        _c.forward();
      case LogoMotion.twinkle:
        _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final mark = CustomPaint(
      size: Size.square(widget.tile ? s * .70 : s),
      painter: BrandMarkPainter(color: widget.tile ? BrandColors.goldOnInk : BrandColors.gold),
    );
    final Widget logo = Semantics(
      label: context.tr('بصيرة', 'Basirah'),
      image: true,
      child: widget.tile
          ? Container(
              width: s,
              height: s,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BrandColors.ink,
                borderRadius: BorderRadius.circular(s * .23),
              ),
              child: mark,
            )
          : mark,
    );
    if (widget.motion == LogoMotion.none) return logo;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        child: logo,
        builder: (context, child) {
          final t = _c.value;
          if (widget.motion == LogoMotion.reveal) {
            final grow = Curves.easeOutBack.transform(t);
            final fade = Curves.easeOut.transform((t * 1.6).clamp(0.0, 1.0));
            return Opacity(
              opacity: fade,
              child: Transform.rotate(
                angle: (1 - grow) * -math.pi / 8,
                child: Transform.scale(scale: .6 + .4 * grow, child: child),
              ),
            );
          }
          // Twinkle: breathe gently in size and opacity.
          final e = Curves.easeInOut.transform(t);
          return Opacity(
            opacity: .7 + .3 * e,
            child: Transform.scale(scale: .9 + .1 * e, child: child),
          );
        },
      ),
    );
  }
}

/// The name «بصيرة» in the brand font ([style]). The logo draws the last
/// letter without its two dots: in this font the stroke above the letter
/// already stands for them (so it is written with ه; screen readers still
/// read «بصيرة»). In other languages it is the plain word «Basirah».
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, required this.style, this.lang});

  final TextStyle style;

  /// The language to write it in; when null, the interface's: the Arabic
  /// logo in the right-to-left interfaces (Arabic, Urdu, Persian, Pashto),
  /// and the name in the script of the others (Basirah, बसीरा, バシーラ…).
  final String? lang;

  @override
  Widget build(BuildContext context) {
    final ui = context.uiLang;
    final arabic = lang == null ? isRtlLanguage(ui) : lang == 'ar';
    if (arabic) return Semantics(label: 'بصيرة', excludeSemantics: true, child: Text('بصيره', style: style));
    return Text(lang == null ? appNameFor(ui) : 'Basirah', style: style);
  }
}

/// The sparkle mark in a square: a four-point star with concave sides
/// (x = r·sgn(cos θ)|cos θ|ⁿ, y = r·sgn(sin θ)|sin θ|ⁿ) and two small
/// companions, top-start and bottom-end, as in the original artwork.
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({required this.color});

  final Color color;

  /// (centre x, centre y, radius, exponent), as fractions of the side.
  static const stars = [
    (0.50, 0.50, 0.47, 4.6),
    (0.295, 0.265, 0.095, 3.4),
    (0.715, 0.725, 0.082, 3.4),
  ];

  static Path starPath(Offset c, double r, double n, {int steps = 360}) {
    final path = Path();
    for (var i = 0; i < steps; i++) {
      final t = 2 * math.pi * i / steps;
      final cs = math.cos(t);
      final sn = math.sin(t);
      final p = c + Offset(r * cs.sign * math.pow(cs.abs(), n), r * sn.sign * math.pow(sn.abs(), n));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    for (final (x, y, r, n) in stars) {
      canvas.drawPath(starPath(Offset(x * side, y * side), r * side, n), paint);
    }
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) => old.color != color;
}
