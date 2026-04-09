import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mouseplate/nav.dart';
import 'package:mouseplate/theme.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _indexForLocation(String location) {
    if (location.startsWith(AppRoutes.appHome)) return 0;
    if (location.startsWith(AppRoutes.appLog)) return 1;
    if (location.startsWith(AppRoutes.appTips)) return 2;
    return 3;
  }

  String _locationForIndex(int index) => switch (index) {
    0 => AppRoutes.appHome,
    1 => AppRoutes.appLog,
    2 => AppRoutes.appTips,
    _ => AppRoutes.appSettings,
  };

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final idx = _indexForLocation(loc);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: idx,
        onDestinationSelected: (index) {
          final target = _locationForIndex(index);
          if (target == loc) return;
          context.go(target);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline_rounded), label: 'Log'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_rounded), label: 'Tips'),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

/// Standard page padding + max-width constraint wrapper.
///
/// Use this for standalone pages (Welcome/Setup/Paywall) that are not inside the
/// sliver-based [AppPageScaffold].
class AppBody extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const AppBody({super.key, required this.child, this.padding = AppLayout.pagePadding});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class AppPageScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;

  const AppPageScaffold({super.key, required this.title, required this.child, this.actions});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(title),
          actions: actions,
          backgroundColor: cs.surface.withValues(alpha: 0.90),
          surfaceTintColor: Colors.transparent,
        ),
        SliverPadding(
          padding: AppLayout.pagePadding,
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
