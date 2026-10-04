import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../core/kb_provider.dart';
import '../../core/state.dart';
import '../../shared/brand.dart';
import '../../shared/patterns.dart';
import '../../shared/widgets.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    final minimum = Future<void>.delayed(const Duration(milliseconds: 2500));
    final kb = ref.read(kbProvider.future);
    final seen = await Onboarding.seen();
    await kb;
    await minimum;
    if (!mounted) return;
    context.go(seen ? '/home' : '/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PatternBackdrop(opacity: .08, glow: Alignment(1, -1), fade: false),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(size: 128, motion: LogoMotion.reveal, tile: true),
                const SizedBox(height: 26),
                Reveal(
                  delay: const Duration(milliseconds: 900),
                  child: Text(context.tr('بصيرة', 'Basirah'), style: BText.brand(context.isEn ? 46 : 54)),
                ),
                const SizedBox(height: 4),
                Reveal(
                  delay: const Duration(milliseconds: 1300),
                  child: Text('عَلَىٰ بَصِيرَةٍ', style: BText.quran(20, color: BColors.textMuted)),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Reveal(
              delay: const Duration(milliseconds: 1600),
              child: Text(
                context.tr('إجابات موثقة لأسئلة المسلم الجديد', 'Documented answers for new Muslims'),
                textAlign: TextAlign.center,
                style: BText.label(14, weight: FontWeight.w400),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
