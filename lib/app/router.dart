import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/answer/answer_screen.dart';
import '../features/ask/ask_screen.dart';
import '../features/category/category_screen.dart';
import '../features/explore/explore_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/about_screen.dart';
import '../features/library/glossary_screen.dart';
import '../features/guide/guide_screen.dart';
import '../features/library/baseline_screen.dart';
import '../features/library/impact_screen.dart';
import '../features/specialist/specialist.dart';
import '../features/library/library_screen.dart';
import '../features/library/sources_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/welcome/context_screen.dart';
import '../features/welcome/welcome_screen.dart';
import '../core/lang.dart';
import 'shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(
        path: '/context',
        builder: (_, s) => ContextScreen(firstRun: s.uri.queryParameters['first'] == '1'),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/explore', builder: (_, _) => const ExploreScreen())]),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ask',
                // `/ask?q=…` opens the tab and asks immediately (shareable links, demos).
                builder: (_, s) => AskScreen(initialQuestion: s.uri.queryParameters['q']),
              ),
            ],
          ),
          StatefulShellBranch(routes: [GoRoute(path: '/library', builder: (_, _) => const LibraryScreen())]),
        ],
      ),
      GoRoute(
        path: '/category/:id',
        builder: (_, s) => CategoryScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/faq/:id',
        builder: (_, s) => FaqScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/answer',
        redirect: (_, s) => s.extra is BasirahAnswer ? null : '/ask',
        builder: (_, s) => AskedAnswerScreen(answer: s.extra! as BasirahAnswer),
      ),
      GoRoute(path: '/glossary', builder: (_, _) => const GlossaryScreen()),
      GoRoute(path: '/sources', builder: (_, _) => const SourcesScreen()),
      GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
      GoRoute(path: '/impact', builder: (_, _) => const ImpactScreen()),
      GoRoute(path: '/baseline', builder: (_, _) => const BaselineScreen()),
      GoRoute(path: '/referrals', builder: (_, _) => const MyReferralsScreen()),
      GoRoute(path: '/guide/:id', builder: (_, s) => GuideScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/specialist', builder: (_, _) => const SpecialistPanelScreen()),
    ],
    errorBuilder: (context, _) => Scaffold(body: Center(child: Text(context.tr('الصفحة غير موجودة', 'Page not found')))),
  );
});
