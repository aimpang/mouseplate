import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mouseplate/controllers/app_controller.dart';
import 'package:mouseplate/pages/dashboard_page.dart';
import 'package:mouseplate/pages/log_page.dart';
import 'package:mouseplate/pages/onboarding_page.dart';
import 'package:mouseplate/pages/paywall_page.dart';
import 'package:mouseplate/pages/settings_page.dart';
import 'package:mouseplate/pages/tips_page.dart';
import 'package:mouseplate/pages/trip_onboarder_page.dart';
import 'package:mouseplate/pages/trip_setup_method_page.dart';
import 'package:mouseplate/pages/welcome_page.dart';
import 'package:mouseplate/widgets/app_shell.dart';

class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String setup = '/setup';
  static const String setupManual = '/setup/manual';
  static const String setupAi = '/setup/ai';

  static const String appHome = '/app/home';
  static const String appLog = '/app/log';
  static const String appTips = '/app/tips';
  static const String appSettings = '/app/settings';

  static const String paywall = '/paywall';
}

class AppRouter {
  static GoRouter router(AppController controller) => GoRouter(
    initialLocation:
        controller.onboardingComplete ? (controller.hasTrip ? AppRoutes.appHome : AppRoutes.welcome) : AppRoutes.onboarding,
    refreshListenable: controller,
    redirect: (context, state) {
      final hasTrip = controller.hasTrip;
      final onboardingDone = controller.onboardingComplete;
      final loc = state.matchedLocation;

      if (!onboardingDone && loc != AppRoutes.onboarding) return AppRoutes.onboarding;
      if (onboardingDone && loc == AppRoutes.onboarding) return hasTrip ? AppRoutes.appHome : AppRoutes.welcome;

      final isWelcome = loc == AppRoutes.welcome;
      final isSetupFlow = loc == AppRoutes.setup || loc.startsWith('${AppRoutes.setup}/');
      final isInApp = loc.startsWith('/app');

      if (!hasTrip && isInApp) return AppRoutes.welcome;
      // Allow setup flow even when a trip exists (repeat customers can edit/replace their trip).
      if (hasTrip && isWelcome) return AppRoutes.appHome;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        pageBuilder: (context, state) => const NoTransitionPage(child: OnboardingPage()),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        name: 'welcome',
        pageBuilder: (context, state) => const NoTransitionPage(child: WelcomePage()),
      ),
      GoRoute(
        path: AppRoutes.setup,
        name: 'setup',
        pageBuilder: (context, state) => const NoTransitionPage(child: TripSetupMethodPage()),
        routes: [
          GoRoute(
            path: 'manual',
            name: 'setup_manual',
            pageBuilder: (context, state) => const NoTransitionPage(child: TripOnboarderPage()),
          ),
          GoRoute(
            path: 'ai',
            name: 'setup_ai',
            pageBuilder: (context, state) => const NoTransitionPage(child: TripSetupMethodPage(initialTab: TripSetupMethodTab.ai)),
          ),
        ],
      ),

      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.appHome,
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(child: DashboardPage()),
          ),
          GoRoute(
            path: AppRoutes.appLog,
            name: 'log',
            pageBuilder: (context, state) => const NoTransitionPage(child: LogPage()),
          ),
          GoRoute(
            path: AppRoutes.appTips,
            name: 'tips',
            pageBuilder: (context, state) => const NoTransitionPage(child: TipsPage()),
          ),
          GoRoute(
            path: AppRoutes.appSettings,
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(child: SettingsPage()),
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.paywall,
        name: 'paywall',
        pageBuilder: (context, state) => MaterialPage(child: PaywallPage()),
      ),
    ],
  );
}
