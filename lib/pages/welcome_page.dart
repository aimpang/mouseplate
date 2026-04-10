import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mouseplate/nav.dart';
import 'package:mouseplate/theme.dart';
import 'package:mouseplate/widgets/app_shell.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: AppBody(
          padding: AppSpacing.paddingLg,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero section
                Container(
                  width: double.infinity,
                  padding: AppSpacing.paddingLg,
                  decoration: BoxDecoration(
                    gradient: AppGradients.heroCard(cs.primary),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: cs.primary.withValues(alpha: 0.10)),
                    boxShadow: AppShadows.cardFloat,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SparkleBadge(text: text, cs: cs),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Enchanted Credits", style: text.headlineLarge),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  "Your Disney dining plan, beautifully tracked.",
                                  style: text.bodyLarge?.copyWith(height: 1.45, color: cs.onSurface.withValues(alpha: 0.85)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          _MagicMedallion(cs: cs),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Feature list
                Container(
                  decoration: BoxDecoration(
                    color: cs.appCardBackground,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.10)),
                  ),
                  child: _FeatureList(cs: cs, text: text),
                ),
                const SizedBox(height: AppSpacing.lg),
                // CTA section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => context.go(AppRoutes.setup),
                        icon: Icon(Icons.park_rounded, color: cs.onPrimary),
                        label: Text("Start New Trip", style: text.titleMedium?.copyWith(color: cs.onPrimary)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Assurance row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_rounded, size: 16, color: cs.onSurface.withValues(alpha: 0.60)),
                        const SizedBox(width: 6),
                        Text("No account", style: text.labelSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.70))),
                        const SizedBox(width: 20),
                        Icon(Icons.wifi_off_rounded, size: 16, color: cs.onSurface.withValues(alpha: 0.60)),
                        const SizedBox(width: 6),
                        Text("Works offline", style: text.labelSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.70))),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Disclaimer
                    Text(
                      "Not affiliated with Disney. Manual entry only.",
                      style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.60)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MagicMedallion extends StatelessWidget {
  final ColorScheme cs;

  const _MagicMedallion({required this.cs});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [cs.primary.withValues(alpha: 0.18), cs.primary.withValues(alpha: 0.0)],
              ),
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.gold.withValues(alpha: 0.35), AppColors.gold.withValues(alpha: 0.12)],
              ),
              boxShadow: AppShadows.cardFloat,
            ),
            child: Icon(Icons.park_rounded, size: 28, color: AppColors.goldOnSurface),
          ),
        ],
      ),
    );
  }
}

class _SparkleBadge extends StatelessWidget {
  final TextTheme text;
  final ColorScheme cs;

  const _SparkleBadge({required this.text, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: AppGradients.goldShimmer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.goldOnSurface),
          const SizedBox(width: 8),
          Text("Disney Dining Companion", style: text.labelLarge?.copyWith(color: AppColors.goldOnSurface)),
        ],
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme text;

  const _FeatureList({required this.cs, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FeatureRow(
          icon: Icons.restaurant_rounded,
          title: "Track credits instantly",
          description: "Log quick-service meals, table-service, and snacks in one tap.",
          cs: cs,
          text: text,
        ),
        Divider(color: cs.outline.withValues(alpha: 0.08), height: 1),
        _FeatureRow(
          icon: Icons.offline_bolt_rounded,
          title: "Offline & private",
          description: "No account, no sync. Everything stays on your device.",
          cs: cs,
          text: text,
        ),
        Divider(color: cs.outline.withValues(alpha: 0.08), height: 1),
        _FeatureRow(
          icon: Icons.notifications_active_rounded,
          title: "Credit countdown",
          description: "Know exactly how many credits you have left before checkout.",
          cs: cs,
          text: text,
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final ColorScheme cs;
  final TextTheme text;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.cs,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primaryContainer.withValues(alpha: 0.40),
            ),
            child: Icon(icon, size: 20, color: cs.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
