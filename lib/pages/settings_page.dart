import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mouseplate/controllers/app_controller.dart';
import 'package:mouseplate/models/trip.dart';
import 'package:mouseplate/nav.dart';
import 'package:mouseplate/theme.dart';
import 'package:mouseplate/widgets/app_shell.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final trip = controller.trip;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return AppPageScaffold(
      title: 'Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trip != null) ...[
            _SectionTitle('Trip'),
            _SettingsTile(
              icon: Icons.edit_rounded,
              title: 'Edit trip details',
              subtitle: '${trip.planType.shortLabel} • ${trip.adults} adults • ${trip.children} kids • ${trip.nights} nights',
              onTap: () => context.push(AppRoutes.setup),
            ),
            _SettingsTile(
              icon: Icons.delete_forever_rounded,
              title: 'Reset trip & history',
              subtitle: 'Starts over, keeps Premium unlock',
              danger: true,
              onTap: () => _confirmReset(context),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          _SectionTitle('Premium (one-time unlock)'),
          _PremiumCard(unlocked: controller.premiumUnlocked),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: Icons.workspace_premium_rounded,
            title: controller.premiumUnlocked ? 'Premium unlocked' : 'Unlock Premium',
            subtitle: controller.premiumUnlocked ? 'Thank you! Sharing + export are ready.' : 'Family sharing, PDF export, and ad-free (no ads anyway).',
            onTap: controller.premiumUnlocked ? null : () => context.push(AppRoutes.paywall),
          ),
          _SettingsTile(
            icon: Icons.picture_as_pdf_rounded,
            title: 'Export trip summary (PDF)',
            subtitle: controller.premiumUnlocked ? 'Coming soon in this prototype' : 'Premium only',
            onTap: controller.premiumUnlocked ? () => _showComingSoon(context) : () => context.push(AppRoutes.paywall),
            trailing: controller.premiumUnlocked
                ? Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.55))
                : Icon(Icons.lock_rounded, color: cs.onSurface.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: AppSpacing.lg),

          _SectionTitle('About'),
          Container(
            width: double.infinity,
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: cs.appCardBackground,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
            ),
            child: Text(
              'Enchanted Credits is an unofficial, manual tracker for Walt Disney World guests.\n\nNot affiliated with or endorsed by The Walt Disney Company.',
              style: text.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.85), height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final controller = context.read<AppController>();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (ctx) => Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reset trip?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('This clears your trip details and history. Premium stays unlocked.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.error,
                    ),
                    child: Text('Reset', style: TextStyle(color: cs.onError)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await controller.clearTripAndUsage();
      if (context.mounted) context.go(AppRoutes.welcome);
    }
  }

  void _showComingSoon(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('PDF export is a Premium feature — coming soon.'),
        backgroundColor: cs.surfaceContainerHighest,
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  final bool unlocked;
  const _PremiumCard({required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: unlocked ? cs.primaryContainer.withValues(alpha: 0.65) : cs.appCardBackground,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: cs.outline.withValues(alpha: 0.12))),
            child: Icon(unlocked ? Icons.check_rounded : Icons.star_rounded, color: unlocked ? cs.primary : cs.onSurface),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(unlocked ? 'Premium unlocked' : 'Upgrade to Premium', style: text.titleMedium),
                const SizedBox(height: 4),
                Text('Sharing • PDF export • “Ad-free”', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75))),
              ],
            ),
          ),
          Text('\$4.99', style: text.titleMedium?.copyWith(color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75))),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            color: cs.appCardBackgroundSubtle,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: danger ? cs.errorContainer : cs.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.10)),
                ),
                child: Icon(icon, color: danger ? cs.onErrorContainer : cs.onSurface),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.25)),
                  ],
                ),
              ),
              trailing ?? Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.55)),
            ],
          ),
        ),
      ),
    );
  }
}
