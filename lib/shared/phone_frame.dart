import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'patterns.dart';

/// On wide screens (web on a computer) the app is shown inside an
/// iPhone 15 Pro: 393 × 852 pt screen, 55 pt display corners, Dynamic
/// Island, status bar, home indicator and side buttons, with iOS safe-area
/// insets (59 pt top, 34 pt bottom) so layouts behave exactly as on the
/// device. The device scales down to fit short windows. On a phone-sized
/// viewport the app is full-bleed.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  static const screen = Size(393, 852);
  static const _displayRadius = 55.0;
  static const _bezel = 12.0; // black glass border
  static const _rim = 4.0; // titanium band
  static const _inset = _bezel + _rim;
  static const _buttons = 4.0; // side buttons stick out this much

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width < 620) return child;

    final body = Size(screen.width + 2 * _inset, screen.height + 2 * _inset);
    return ColoredBox(
      color: const Color(0xFFE9E8E6),
      child: Stack(
        children: [
          const Positioned.fill(
            child: PatternBackdrop(opacity: .06, glow: Alignment(0, -1.3), fade: false),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: body.width + 2 * _buttons,
                  height: body.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Side buttons: action + volume (left), side button (right).
                      _button(left: 0, top: 150, height: 32),
                      _button(left: 0, top: 210, height: 62),
                      _button(left: 0, top: 285, height: 62),
                      _button(right: 0, top: 240, height: 100),
                      Positioned(
                        left: _buttons,
                        top: 0,
                        width: body.width,
                        height: body.height,
                        child: _device(mq),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _device(MediaQueryData outer) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_displayRadius + _inset),
        // Natural titanium rim
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB9B8B4), Color(0xFFE6E4DF), Color(0xFF9E9D99), Color(0xFFD4D2CD)],
          stops: [0, .35, .7, 1],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 60, offset: Offset(0, 30)),
          BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(_rim),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B0C),
            borderRadius: BorderRadius.circular(_displayRadius + _bezel),
          ),
          child: Padding(
            padding: const EdgeInsets.all(_bezel),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_displayRadius),
              child: SizedBox.fromSize(
                size: screen,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: MediaQuery(
                        data: outer.copyWith(
                          size: screen,
                          padding: const EdgeInsets.only(top: 59, bottom: 34),
                          viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
                          viewInsets: EdgeInsets.zero,
                        ),
                        child: child,
                      ),
                    ),
                    const Positioned(top: 0, left: 0, right: 0, height: 54, child: IgnorePointer(child: _StatusBar())),
                    // Dynamic Island
                    Positioned(
                      top: 11,
                      left: (screen.width - 126) / 2,
                      width: 126,
                      height: 37,
                      child: const IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                        ),
                      ),
                    ),
                    // Home indicator
                    Positioned(
                      bottom: 8,
                      left: (screen.width - 134) / 2,
                      width: 134,
                      height: 5,
                      child: const IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xE6000000),
                            borderRadius: BorderRadius.all(Radius.circular(3)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _button({double? left, double? right, required double top, required double height}) =>
      Positioned(
        left: left,
        right: right,
        top: top,
        width: _buttons + 3,
        height: height,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFFA5A4A0), Color(0xFFD9D7D2)]),
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
      );
}

/// iOS-style status bar: 9:41 on the left, signal / Wi-Fi / battery on the
/// right (the device chrome stays left-to-right regardless of app language).
class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF111111);
    return Material(
      type: MaterialType.transparency,
      child: Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 17, 32, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 54,
              child: Text(
                '9:41',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.w600, color: ink, height: 1.1),
              ),
            ),
            const Spacer(),
            const _SignalBars(color: ink),
            const SizedBox(width: 6),
            const Icon(Icons.wifi_rounded, size: 18, color: ink),
            const SizedBox(width: 6),
            const _Battery(color: ink),
          ],
        ),
      ),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (final h in const [4.0, 6.5, 9.0, 11.5])
        Container(
          width: 3,
          height: h,
          margin: const EdgeInsets.only(right: 1.5),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
        ),
    ],
  );
}

class _Battery extends StatelessWidget {
  const _Battery({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 25,
        height: 12,
        padding: const EdgeInsets.all(1.6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: .4), width: 1),
          borderRadius: BorderRadius.circular(3.5),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
      ),
      const SizedBox(width: 1),
      Container(
        width: 1.5,
        height: 4,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .4),
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(1)),
        ),
      ),
    ],
  );
}
