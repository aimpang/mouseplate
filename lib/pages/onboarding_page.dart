import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mouseplate/controllers/app_controller.dart';
import 'package:mouseplate/nav.dart';
import 'package:mouseplate/theme.dart';
import 'package:mouseplate/widgets/app_shell.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final app = context.read<AppController>();
    await app.setOnboardingComplete(true);
    if (!mounted) return;
    context.go(app.hasTrip ? AppRoutes.appHome : AppRoutes.welcome);
  }

  void _next() {
    if (_index >= 2) return;
    _controller.nextPage(duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: AppBody(
          padding: AppSpacing.paddingLg,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Welcome', style: text.titleLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.85))),
                  ),
                  TextButton(
                    onPressed: _finish,
                    child: Text('Skip', style: text.labelLarge?.copyWith(color: cs.primary)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (value) => setState(() => _index = value),
                  children: [
                    _OnboardingPanel(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Track dining credits in seconds',
                      body:
                          'Enchanted Credits is a simple, lightweight manual tracker for Walt Disney World Quick-Service and Disney Dining Plan credits — perfect for families sharing meals and snacks.',
                      tip: 'Tip: Credits are valid through the end of your checkout day — the app shows a live countdown so you never waste a meal.',
                      accent: cs.primary,
                    ),
                    _OnboardingPanel(
                      icon: Icons.offline_bolt_rounded,
                      title: 'Offline + lightweight',
                      body:
                          'No accounts, no syncing, no clutter. Everything stays on your device so you can log a meal fast and get back to the fun.',
                      tip: 'Tip: No Wi-Fi at the park? No problem. All your data lives on-device, so you can log a snack right at the booth.',
                      accent: cs.secondary,
                    ),
                    _OnboardingPanel(
                      icon: Icons.check_circle_rounded,
                      title: 'Simple flow: set trip, then log',
                      body:
                          'Enter your party size, nights, and check-in date — the app calculates your total credits (including 2026 Kids Eat Free!). Then just log meals as you use them.',
                      tip: 'Tip: You can always edit your trip details later from the Dashboard — just tap the pencil icon in the top right.',
                      accent: cs.tertiary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Dots(index: _index),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _index == 2 ? _finish : _next,
                  icon: Icon(_index == 2 ? Icons.park_rounded : Icons.arrow_forward_rounded, color: cs.onPrimary),
                  label: Text(
                    _index == 2 ? 'Get started' : 'Next',
                    style: text.titleMedium?.copyWith(color: cs.onPrimary),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Not affiliated with Disney. Manual entry only.',
                style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelHero extends StatelessWidget {
  final IconData icon;
  final Color primary;
  final Color primaryContainer;

  const _PanelHero({required this.icon, required this.primary, required this.primaryContainer});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primary.withValues(alpha: 0.15),
                  primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryContainer, primaryContainer.withValues(alpha: 0.70)],
              ),
              boxShadow: AppShadows.cardFloat,
            ),
            child: Icon(icon, size: 32, color: primary),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String tip;
  final Color? accent;

  const _OnboardingPanel({required this.icon, required this.title, required this.body, required this.tip, this.accent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accentColor = accent ?? cs.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PanelHero(icon: icon, primary: accentColor, primaryContainer: accentColor.withValues(alpha: 0.40)),
        const SizedBox(height: AppSpacing.lg),
        Text(title, style: text.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          body,
          style: text.bodyLarge?.copyWith(height: 1.5, color: cs.onSurface.withValues(alpha: 0.90)),
        ),
        const Spacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.appCardBackground,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outline.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.85)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tip,
                  style: text.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.88), height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  final int index;
  const _Dots({required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final selected = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: selected ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected ? AppColors.gold : cs.outline.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
