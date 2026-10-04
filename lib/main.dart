import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/lang.dart';
import 'shared/phone_frame.dart';

void main() {
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
      builder: (context, child) => PhoneFrame(child: child ?? const SizedBox.shrink()),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
