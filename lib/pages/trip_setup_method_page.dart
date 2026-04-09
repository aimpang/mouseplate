import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mouseplate/controllers/app_controller.dart';
import 'package:mouseplate/nav.dart';
import 'package:mouseplate/theme.dart';
import 'package:mouseplate/widgets/app_shell.dart';

enum TripSetupMethodTab { manual, ai }

class TripSetupMethodPage extends StatelessWidget {
  final TripSetupMethodTab initialTab;
  const TripSetupMethodPage({super.key, this.initialTab = TripSetupMethodTab.manual});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final controller = context.watch<AppController>();

    final manualSelected = initialTab == TripSetupMethodTab.manual;
    final aiSelected = initialTab == TripSetupMethodTab.ai;

    Future<void> openPaywall() async => context.push(AppRoutes.paywall);

    Future<void> openAiFlow() async {
      if (!controller.premiumUnlocked) {
        await openPaywall();
        return;
      }

      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: cs.surface,
        builder: (ctx) => Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.primary.withValues(alpha: 0.18))),
                    child: Icon(Icons.auto_awesome_rounded, color: cs.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('AI Concierge (coming soon)', style: text.titleLarge)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Phase 1 ships manual onboarding only. Next, Premium will let you describe your trip in plain English, then review & edit the generated summary before saving.',
                style: text.bodyMedium?.copyWith(height: 1.45, color: cs.onSurface.withValues(alpha: 0.80)),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => ctx.pop(),
                  icon: Icon(Icons.check_rounded, color: cs.onPrimary),
                  label: Text('Got it', style: text.titleMedium?.copyWith(color: cs.onPrimary)),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl))),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your trip'),
        backgroundColor: cs.surface.withValues(alpha: 0.90),
        surfaceTintColor: Colors.transparent,
        actions: [
          if (controller.hasTrip)
            TextButton(
              onPressed: () => context.go(AppRoutes.appHome),
              child: Text('Skip', style: text.labelLarge?.copyWith(color: cs.primary)),
            ),
        ],
      ),
      body: SafeArea(
        child: AppBody(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose how you want to onboard', style: text.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Manual setup is fast and works offline. AI Concierge will (soon) fill everything from a single message — then you can review & edit before saving.',
                style: text.bodyLarge?.copyWith(height: 1.45, color: cs.onSurface.withValues(alpha: 0.80)),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SetupMethodCard(
                title: 'Manual setup',
                subtitle: 'Step-by-step wizard (free)'
                    '${controller.hasTrip ? '\nEdits will replace your current trip.' : ''}',
                icon: Icons.tune_rounded,
                selected: manualSelected,
                badge: 'Free',
                onTap: () => context.go(AppRoutes.setupManual),
              ),
              const SizedBox(height: AppSpacing.md),
              _SetupMethodCard(
                title: 'AI Concierge',
                subtitle: controller.premiumUnlocked
                    ? 'Premium (coming soon)'
                    : 'Premium (locked) — describe your trip in one message',
                icon: Icons.auto_awesome_rounded,
                selected: aiSelected,
                badge: controller.premiumUnlocked ? 'Premium' : 'Locked',
                locked: !controller.premiumUnlocked,
                onTap: openAiFlow,
              ),
              const Spacer(),
              if (!controller.premiumUnlocked)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: openPaywall,
                    icon: Icon(Icons.star_rounded, color: cs.primary),
                    label: const Text('View Premium'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupMethodCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String badge;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _SetupMethodCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
    required this.selected,
    this.locked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final bg = selected ? cs.primaryContainer.withValues(alpha: 0.65) : cs.appCardBackground;
    final border = selected ? cs.primary.withValues(alpha: 0.22) : cs.outline.withValues(alpha: 0.12);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: border)),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: cs.outline.withValues(alpha: 0.12))),
              child: Icon(icon, color: locked ? cs.onSurface.withValues(alpha: 0.45) : cs.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: text.titleLarge?.copyWith(height: 1.1))),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: cs.surface.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: cs.outline.withValues(alpha: 0.10))),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(locked ? Icons.lock_rounded : Icons.check_rounded, size: 16, color: cs.onSurface.withValues(alpha: 0.70)),
                            const SizedBox(width: 6),
                            Text(badge, style: text.labelMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.80))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: text.bodyMedium?.copyWith(height: 1.35, color: cs.onSurface.withValues(alpha: 0.75))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }
}
