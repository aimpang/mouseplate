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
    return 2;
  }

  String _locationForIndex(int index) => switch (index) {
    0 => AppRoutes.appHome,
    1 => AppRoutes.appLog,
    _ => AppRoutes.appSettings,
  };

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final idx = _indexForLocation(loc);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppGradients.pageBackgroundFor(cs)),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
              child: child,
            ),
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.10))),
        ),
        child: NavigationBar(
          height: 68,
          selectedIndex: idx,
          onDestinationSelected: (index) {
            final target = _locationForIndex(index);
            if (target == loc) return;
            context.go(target);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline_rounded),
              selectedIcon: Icon(Icons.add_circle_rounded),
              label: 'Log',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
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
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: AppGradients.pageBackgroundFor(cs)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
          child: Padding(padding: padding, child: child),
        ),
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
          // Opaque surface — semi-transparent + M3 scroll tint reads as a white veil over content.
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.outline.withValues(alpha: 0.0),
                    cs.outline.withValues(alpha: 0.10),
                    cs.outline.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
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
