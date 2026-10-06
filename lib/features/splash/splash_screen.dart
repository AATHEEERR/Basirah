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
                  child: Wordmark(style: BText.brand(context.isEn ? 46 : 54)),
                ),
                const SizedBox(height: 4),
                Reveal(
                  delay: const Duration(milliseconds: 1300),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Text(
                          '﴿$splashVerse﴾',
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: BText.quran(20, color: BColors.textMuted),
                        ),
                        Text('[يوسف: 108]', textDirection: TextDirection.rtl, style: BText.label(12, color: BColors.textFaint, weight: FontWeight.w400)),
                      ],
                    ),
                  ),
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

/// Yusuf 12:108 up to «عَلَىٰ بَصِيرَةٍ», the KFGQPC text of the Mushaf
/// (the beginning of q_12_108 in assets/kb/evidence.json; a test keeps it so).
const splashVerse = 'قُلۡ هَٰذِهِۦ سَبِيلِيٓ أَدۡعُوٓاْ إِلَى ٱللَّهِۚ عَلَىٰ بَصِيرَةٍ';
