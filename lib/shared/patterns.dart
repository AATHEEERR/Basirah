import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'web_frame.dart';

/// Star polygon {n/m} centred at [c]. When gcd(n, m) > 1 it is drawn as a
/// compound of rotated sub-polygons (e.g. {8/2} = two squares).
Path starPolygon(Offset c, double r, int n, int m, {double rotation = -math.pi / 2}) {
  final path = Path();
  final g = _gcd(n, m);
  final per = n ~/ g;
  for (var k = 0; k < g; k++) {
    for (var i = 0; i <= per; i++) {
      final idx = (k + i * m) % n;
      final a = rotation + idx * 2 * math.pi / n;
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
  }
  return path;
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

/// Repeating eight-pointed-star lattice (خاتم) used as a background texture.
class StarLatticePainter extends CustomPainter {
  const StarLatticePainter({
    this.color = BColors.goldDeep,
    this.opacity = .08,
    this.cell = 64,
    this.strokeWidth = .8,
  });

  final Color color;
  final double opacity;
  final double cell;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withValues(alpha: opacity);
    final r = cell * .34;
    final d = r * math.cos(math.pi / 4);
    for (var y = 0.0; y <= size.height + cell; y += cell) {
      for (var x = 0.0; x <= size.width + cell; x += cell) {
        final p = Offset(x, y);
        canvas.drawPath(starPolygon(p, r, 8, 3, rotation: 0), paint);
        canvas.drawCircle(p, r * .34, paint);
        // Diagonal tips of the four surrounding stars meet at the cell centre.
        final centre = p + Offset(cell / 2, cell / 2);
        for (final tip in [
          Offset(d, d),
          Offset(cell - d, d),
          Offset(d, cell - d),
          Offset(cell - d, cell - d),
        ]) {
          canvas.drawLine(p + tip, centre, paint);
        }
        canvas.drawLine(p + Offset(r, 0), p + Offset(cell - r, 0), paint);
        canvas.drawLine(p + Offset(0, r), p + Offset(0, cell - r), paint);
        canvas.drawPath(starPolygon(centre, cell * .12, 4, 1, rotation: math.pi / 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(StarLatticePainter old) =>
      old.color != color || old.opacity != opacity || old.cell != cell;
}

/// Header wash: a warm sand glow in the top corner with a faint
/// star lattice, fading into the grey canvas.
class PatternBackdrop extends StatelessWidget {
  const PatternBackdrop({
    super.key,
    this.height,
    this.opacity = .07,
    this.glow = const Alignment(1, -1),
    this.fade = true,
  });

  final double? height;
  final double opacity;
  final Alignment glow;
  final bool fade;

  @override
  Widget build(BuildContext context) {
    // The website keeps a plain ground: in its centred column the pattern
    // would read as a box.
    if (isWebsite(context)) return const SizedBox.shrink();
    Widget child = Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: glow,
              radius: 1.25,
              colors: [BColors.sand, BColors.sandSoft.withValues(alpha: .7), BColors.bg.withValues(alpha: 0)],
              stops: const [0, .45, 1],
            ),
          ),
        ),
        RepaintBoundary(child: CustomPaint(painter: StarLatticePainter(opacity: opacity))),
      ],
    );
    if (fade) {
      child = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0, .4, 1],
        ).createShader(r),
        child: child,
      );
    }
    return IgnorePointer(child: SizedBox(height: height, child: child));
  }
}

/// Nav glyphs: outline when idle, amber fill when active.
enum Glyph { hexagon, star, book }

class NavGlyph extends StatelessWidget {
  const NavGlyph(this.glyph, {super.key, required this.active, this.size = 26});

  final Glyph glyph;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (glyph == Glyph.book) {
      return Icon(
        active ? Icons.bookmarks_rounded : Icons.bookmarks_outlined,
        size: size,
        color: active ? BColors.gold : BColors.ink,
      );
    }
    return CustomPaint(size: Size.square(size), painter: _GlyphPainter(glyph, active));
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.active);

  final Glyph glyph;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * .46;
    final path = switch (glyph) {
      Glyph.hexagon => _hexagon(c, r),
      Glyph.star => _eightPoint(c, r),
      Glyph.book => Path(),
    };
    if (active) {
      canvas.drawPath(path, Paint()..color = BColors.gold);
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..color = BColors.ink,
      );
    }
  }

  static Path _hexagon(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      final q = c + Offset(math.cos(a), math.sin(a)) * r * .92;
      i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    return p..close();
  }

  /// Rub el Hizb-like outline: two overlapping squares, traced as one star.
  static Path _eightPoint(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 16; i++) {
      final a = -math.pi / 2 + i * math.pi / 8;
      final rr = i.isEven ? r : r * .74;
      final q = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
    }
    return p..close();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.active != active || old.glyph != glyph;
}
