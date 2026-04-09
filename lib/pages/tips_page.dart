import 'package:flutter/material.dart';

import 'package:mouseplate/theme.dart';
import 'package:mouseplate/widgets/app_shell.dart';

class TipsPage extends StatelessWidget {
  const TipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tips = const [
      ('Log as you go', 'Tap Log right after you order — tiny habit, big peace of mind.'),
      ('Use snack credits wisely', 'Fruit, bottled drinks, and festival booths can stretch your value.'),
      ('Prioritize high-cost items', 'When possible, use meal credits on pricier entrées to maximize value.'),
      ('Avoid the last-night rush', 'Check remaining credits midday on your last day to prevent waste.'),
      ('Keep notes for favorites', 'Add a quick note (restaurant or snack) so you can remember what to repeat.'),
    ];

    return AppPageScaffold(
      title: 'Tips',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Practical, no-stress tips', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          ...tips.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TipCard(title: t.$1, body: t.$2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Dining plans and pricing can change. Always confirm details with Disney for your dates.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70)),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String title;
  final String body;
  const _TipCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.appCardBackground,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: text.titleMedium)),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: text.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.85), height: 1.4)),
        ],
      ),
    );
  }
}
