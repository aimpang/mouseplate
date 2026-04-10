import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mouseplate/controllers/app_controller.dart';
import 'package:mouseplate/pages/dashboard_page.dart';
import 'package:mouseplate/pages/log_page.dart';
import 'package:mouseplate/pages/onboarding_page.dart';
import 'package:mouseplate/pages/paywall_page.dart';
import 'package:mouseplate/pages/settings_page.dart';
import 'package:mouseplate/pages/trip_onboarder_page.dart';
import 'package:mouseplate/pages/trip_setup_method_page.dart';
import 'package:mouseplate/pages/welcome_page.dart';
import 'package:mouseplate/widgets/app_shell.dart';

// Smooth fade+slide page transition helper
Page<void> _fadeSlidePage(Widget child) => CustomTransitionPage(
  child: child,
  transitionDuration: const Duration(milliseconds: 260),
  reverseTransitionDuration: const Duration(milliseconds: 200),
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        ),
      ),
);

class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String setup = '/setup';
  static const String setupManual = '/setup/manual';
  static const String setupAi = '/setup/ai';

  static const String appHome = '/app/home';
  static const String appLog = '/app/log';
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
        pageBuilder: (context, state) => _fadeSlidePage(OnboardingPage()),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        name: 'welcome',
        pageBuilder: (context, state) => _fadeSlidePage(WelcomePage()),
      ),
      GoRoute(
        path: AppRoutes.setup,
        name: 'setup',
        pageBuilder: (context, state) => _fadeSlidePage(TripSetupMethodPage()),
        routes: [
          GoRoute(
            path: 'manual',
            name: 'setup_manual',
            pageBuilder: (context, state) => _fadeSlidePage(TripOnboarderPage()),
          ),
          GoRoute(
            path: 'ai',
            name: 'setup_ai',
            pageBuilder: (context, state) => _fadeSlidePage(TripSetupMethodPage(initialTab: TripSetupMethodTab.ai)),
          ),
        ],
      ),

      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.appHome,
            name: 'home',
            pageBuilder: (context, state) => _fadeSlidePage(DashboardPage()),
          ),
          GoRoute(
            path: AppRoutes.appLog,
            name: 'log',
            pageBuilder: (context, state) => _fadeSlidePage(LogPage()),
          ),
          GoRoute(
            path: AppRoutes.appSettings,
            name: 'settings',
            pageBuilder: (context, state) => _fadeSlidePage(SettingsPage()),
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
