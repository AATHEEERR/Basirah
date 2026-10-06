import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

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
  GoogleFonts.reemKufi(fontWeight: FontWeight.w500);
  GoogleFonts.notoKufiArabic(fontWeight: FontWeight.w700);
  try {
    await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 8));
  } catch (_) {
    // Start anyway: a late font only swaps in when it arrives.
  }
  // Month and day names in every interface language (bundled data).
  await initializeDateFormatting();
  runApp(const ProviderScope(child: BasirahApp()));
}

class BasirahApp extends ConsumerWidget {
  const BasirahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(langProvider);
    // Flutter's own texts (buttons, dates) in the interface language where
    // Flutter has it, in English otherwise.
    final material = GlobalMaterialLocalizations.delegate.isSupported(Locale(ui)) ? ui : 'en';
    return MaterialApp.router(
      // The browser tab: the name in the interface's script, then the other form.
      title: ui == 'ar' ? 'بصيرة · Basirah' : (appNameFor(ui) == 'Basirah' ? 'Basirah · بصيرة' : '${appNameFor(ui)} · Basirah'),
      debugShowCheckedModeBanner: false,
      theme: BasirahTheme.light(),
      themeMode: ThemeMode.light,
      locale: Locale(material),
      supportedLocales: [
        for (final (code, _, _) in uiLanguages)
          if (GlobalMaterialLocalizations.delegate.isSupported(Locale(code))) Locale(code),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => UiLangScope(
        lang: ui,
        child: Directionality(
          textDirection: isRtlLanguage(ui) ? TextDirection.rtl : TextDirection.ltr,
          child: AdaptiveFrame(child: child ?? const SizedBox.shrink()),
        ),
      ),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
