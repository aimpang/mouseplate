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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              _SparkleBadge(text: text, cs: cs),
              const SizedBox(height: AppSpacing.lg),
              Text('Enchanted Credits', style: text.headlineLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'A tiny dining-plan companion for Walt Disney World trips.\nTrack credits fast — stay in vacation mode.',
                style: text.bodyLarge?.copyWith(height: 1.45, color: cs.onSurface.withValues(alpha: 0.80)),
              ),
              const SizedBox(height: AppSpacing.xl),
              _FeatureChipRow(cs: cs),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.setup),
                  icon: Icon(Icons.park_rounded, color: cs.onPrimary),
                  label: Text('Start New Trip', style: text.titleMedium?.copyWith(color: cs.onPrimary)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Not affiliated with Disney. Offline & manual entry only.',
                style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.60)),
              ),
            ],
          ),
        ),
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
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 18, color: cs.onPrimaryContainer),
          const SizedBox(width: 8),
          Text('Lightweight • Offline', style: text.labelLarge?.copyWith(color: cs.onPrimaryContainer)),
        ],
      ),
    );
  }
}

class _FeatureChipRow extends StatelessWidget {
  final ColorScheme cs;
  const _FeatureChipRow({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MiniChip(icon: Icons.restaurant_rounded, label: 'Credits in/out', cs: cs),
        _MiniChip(icon: Icons.history_rounded, label: 'Simple history', cs: cs),
        _MiniChip(icon: Icons.dark_mode_rounded, label: 'Light & dark', cs: cs),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;

  const _MiniChip({required this.icon, required this.label, required this.cs});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.appCardBackground,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.75)),
          const SizedBox(width: 8),
          Text(label, style: text.labelLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}
