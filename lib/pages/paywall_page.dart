import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mouseplate/controllers/app_controller.dart';
import 'package:mouseplate/services/iap_service.dart';
import 'package:mouseplate/theme.dart';
import 'package:mouseplate/widgets/app_shell.dart';

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  late final IapService _iap;

  @override
  void initState() {
    super.initState();
    _iap = IapService();
    _iap.onPremiumUnlocked = () {
      if (!mounted) return;
      context.read<AppController>().setPremiumUnlocked(true);
    };
    _iap.init();
    _iap.addListener(_onIapChanged);
  }

  void _onIapChanged() {
    if (!mounted) return;
    setState(() {});
    final msg = _iap.errorMessage;
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  void dispose() {
    _iap.removeListener(_onIapChanged);
    _iap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final controller = context.watch<AppController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium'),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: AppBody(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: cs.outline.withValues(alpha: 0.12))),
                      child: Icon(Icons.star_rounded, color: cs.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('One-time unlock', style: text.titleLarge?.copyWith(color: cs.onPrimaryContainer)),
                          const SizedBox(height: 4),
                          Text('Keep it simple: pay once, enjoy forever.', style: text.bodyMedium?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.85))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text('What you get', style: text.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              const _BenefitRow(icon: Icons.groups_rounded, title: 'Family / party sharing', subtitle: 'Share one trip across devices (coming soon).'),
              const _BenefitRow(icon: Icons.picture_as_pdf_rounded, title: 'PDF trip summary', subtitle: 'Export a neat recap for your memories.'),
              const _BenefitRow(icon: Icons.block_rounded, title: 'Ad-free', subtitle: 'This app ships with no ads anyway — Premium keeps it that way.'),
              const Spacer(),

              if (controller.premiumUnlocked)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: cs.appCardBackgroundStrong, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: cs.outline.withValues(alpha: 0.12))),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Premium is already unlocked on this device.', style: text.bodyMedium)),
                    ],
                  ),
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _iap.loading || !_iap.available ? null : _iap.buyPremium,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                    ),
                    child: _iap.loading
                        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary))
                        : Text('Unlock for \$4.99', style: text.titleMedium?.copyWith(color: cs.onPrimary)),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: _iap.loading ? null : _iap.restorePurchases,
                    child: Text('Restore purchase', style: text.bodyMedium?.copyWith(color: cs.primary)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitRow({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: cs.appCardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outline.withValues(alpha: 0.12))),
            child: Icon(icon, color: cs.onSurface.withValues(alpha: 0.85)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
