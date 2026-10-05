import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/lang.dart';
import 'shared/web_frame.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The fonts ship with the app (assets/google_fonts); loading them before
  // the first frame means Arabic is never drawn as empty boxes while they
  // arrive. The logo in web/index.html stays up meanwhile.
  for (final w in [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700]) {
    GoogleFonts.ibmPlexSansArabic(fontWeight: w);
  }
  GoogleFonts.reemKufi(fontWeight: FontWeight.w700);
  try {
    await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 8));
  } catch (_) {
    // Start anyway: a late font only swaps in when it arrives.
  }
  runApp(const ProviderScope(child: BasirahApp()));
}

class BasirahApp extends ConsumerWidget {
  const BasirahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: ref.watch(langProvider) == 'en' ? 'Basirah · بصيرة' : 'بصيرة · Basirah',
      debugShowCheckedModeBanner: false,
      theme: BasirahTheme.light(),
      themeMode: ThemeMode.light,
      locale: Locale(ref.watch(langProvider)),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => AdaptiveFrame(child: child ?? const SizedBox.shrink()),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
