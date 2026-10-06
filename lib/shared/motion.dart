import 'dart:async';

import 'package:flutter/material.dart';

/// Builds [builder] with `false` until the widget scrolls into view, then
/// with `true` (once): the numbers and marks move when the reader reaches
/// them, not while they are off screen.
class RevealOnView extends StatefulWidget {
  const RevealOnView({super.key, required this.builder});

  final Widget Function(BuildContext context, bool shown) builder;

  @override
  State<RevealOnView> createState() => _RevealOnViewState();
}

class _RevealOnViewState extends State<RevealOnView> {
  bool _shown = false;
  ScrollPosition? _position;

  /// Looks again a few times a second, whatever scrolls the page (the
  /// nearest list, an outer one, a resize), until the widget is in view.
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(milliseconds: 300), (_) => _check());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position?.removeListener(_check);
    _position = Scrollable.maybeOf(context)?.position;
    _position?.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_shown || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    // In the screen's own pixels: the website may be drawn zoomed.
    final top = box.localToGlobal(Offset.zero).dy;
    final screen = View.of(context);
    final height = screen.physicalSize.height / screen.devicePixelRatio;
    if (top < height * .92) {
      _stop();
      setState(() => _shown = true);
    }
  }

  void _stop() {
    _poll?.cancel();
    _position?.removeListener(_check);
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _shown);
}

/// A number that counts up from zero when it comes into view.
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, required this.format, this.style, this.textAlign});

  final num value;

  /// The text for a value on the way (e.g. `(v) => '${v.round()}%'`).
  final String Function(double value) format;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => RevealOnView(
    builder: (context, shown) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: shown ? value.toDouble() : 0),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v), style: style, textAlign: textAlign),
    ),
  );
}

/// [child] appears (grows and fades in) when it comes into view, the [index]th
/// a little after the one before it.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final delay = 90 * index.clamp(0, 30);
    final total = 420 + delay;
    return RevealOnView(
      builder: (context, shown) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: shown ? 1 : 0),
        duration: Duration(milliseconds: total),
        curve: Interval(delay / total, 1, curve: Curves.easeOutBack),
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.scale(scale: .4 + .6 * t, child: child),
        ),
        child: child,
      ),
    );
  }
}
