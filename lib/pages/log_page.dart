import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mouseplate/controllers/app_controller.dart';
import 'package:mouseplate/models/planned_meal.dart';
import 'package:mouseplate/models/trip.dart';
import 'package:mouseplate/models/usage_entry.dart';
import 'package:mouseplate/theme.dart';
import 'package:mouseplate/widgets/app_shell.dart';
import 'package:mouseplate/widgets/wdw_restaurant_picker.dart';

double? _parseMoneyOrNull(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final normalized = s.replaceAll(RegExp(r'[^0-9.\-]'), '');
  final v = double.tryParse(normalized);
  if (v == null || !v.isFinite || v <= 0) return null;
  return v;
}

class LogPage extends StatelessWidget {
  const LogPage({super.key});

  Future<void> _openLogSheet(BuildContext context, UsageType type) async {
    final controller = context.read<AppController>();
    final trip = controller.trip;
    final cs = Theme.of(context).colorScheme;

    final bool cashMode = trip?.usesDiningPlan == false;

    final remaining = cashMode ? 0 : controller.remainingFor(type);
    final total = cashMode ? 0 : controller.totalFor(type);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => _QuickLogSheet(
        type: type,
        cashMode: cashMode,
        remaining: remaining,
        total: total,
        appController: controller,
        snackBarContext: context,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final trip = controller.trip;

    if (trip == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return AppPageScaffold(
      title: 'Log',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trip.usesDiningPlan && trip.plannedMeals.isNotEmpty) ...[
            _PlannedMealsCard(meals: trip.plannedMeals),
            const SizedBox(height: AppSpacing.lg),
          ],
          _QuickButtons(trip: trip, onTap: (t) => _openLogSheet(context, t)),
          const SizedBox(height: AppSpacing.lg),
          Text('History', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          _HistoryList(entries: controller.usage),
        ],
      ),
    );
  }
}

class _QuickLogSheet extends StatefulWidget {
  final UsageType type;
  final bool cashMode;
  final int remaining;
  final int total;
  final AppController appController;
  final BuildContext snackBarContext;

  const _QuickLogSheet({
    required this.type,
    required this.cashMode,
    required this.remaining,
    required this.total,
    required this.appController,
    required this.snackBarContext,
  });

  @override
  State<_QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<_QuickLogSheet> {
  late final TextEditingController _noteController;
  late final TextEditingController _valueController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _valueController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  bool get _isMealLog => widget.type == UsageType.quickService || widget.type == UsageType.tableService;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final needsOverdraftConfirm = !widget.cashMode && widget.remaining <= 0;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: bottomInset + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(16)),
                  child: Icon(_iconFor(widget.type), color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Log: ${widget.type.label}', style: text.titleLarge)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (!widget.cashMode)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: needsOverdraftConfirm ? cs.tertiaryContainer.withValues(alpha: 0.70) : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Icon(needsOverdraftConfirm ? Icons.info_outline_rounded : Icons.confirmation_number_rounded, size: 18, color: needsOverdraftConfirm ? cs.onTertiaryContainer : cs.onSurface),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        needsOverdraftConfirm
                            ? 'You’re out of ${widget.type.shortLabel} credits (used ${widget.total - widget.remaining} of ${widget.total}). You can still log for accuracy.'
                            : '${widget.remaining} ${widget.type.shortLabel} credits remaining',
                        style: text.bodyMedium?.copyWith(color: needsOverdraftConfirm ? cs.onTertiaryContainer : cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            if (!widget.cashMode) const SizedBox(height: AppSpacing.md),
            const SizedBox(height: AppSpacing.sm),
            if (_isMealLog) ...[
              WdwRestaurantPicker(
                type: widget.type,
                controller: _noteController,
                showFooterHint: false,
                onChanged: () => setState(() {}),
                onCatalogSelected: (o) {
                  _valueController.text = o.avgPerAdult.toStringAsFixed(2);
                },
              ),
            ] else ...[
              TextField(
                controller: _noteController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Optional note',
                  hintText: 'e.g., Mickey bar',
                  prefixIcon: Icon(Icons.icecream_rounded),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _valueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Optional value (what you would have paid)',
                hintText: 'e.g., 27.99',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final value = _parseMoneyOrNull(_valueController.text);
                  final outcome = await widget.appController.logUsage(
                    type: widget.type,
                    note: _noteController.text,
                    value: value,
                    allowOverdraft: needsOverdraftConfirm,
                  );
                  if (!context.mounted) return;
                  if (outcome == LogUsageOutcome.success) {
                    Navigator.of(context).pop();
                    return;
                  }

                  final msg = switch (outcome) {
                    LogUsageOutcome.noTrip => 'Please set up your trip first.',
                    LogUsageOutcome.expired => 'This trip has expired — logging is disabled.',
                    LogUsageOutcome.notInPlan => 'That credit type isn’t included in your plan.',
                    LogUsageOutcome.noRemaining => 'No remaining credits. (You can still log by confirming.)',
                    LogUsageOutcome.storageError => 'Couldn’t save your log. Try again.',
                    LogUsageOutcome.success => '',
                  };
                  if (!widget.snackBarContext.mounted) return;
                  ScaffoldMessenger.of(widget.snackBarContext).showSnackBar(SnackBar(content: Text(msg)));
                },
                icon: Icon(Icons.check_rounded, color: cs.onPrimary),
                label: Text(
                  needsOverdraftConfirm ? 'Log anyway' : 'Add to history',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(color: cs.onPrimary),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _PlannedMealsCard extends StatelessWidget {
  final List<PlannedMeal> meals;
  const _PlannedMealsCard({required this.meals});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final grouped = <String, List<PlannedMeal>>{};
    for (final m in meals) {
      final d = DateTime(m.day.year, m.day.month, m.day.day);
      final key = d.toIso8601String();
      grouped.putIfAbsent(key, () => <PlannedMeal>[]).add(m);
    }
    final days = grouped.values.toList()..sort((a, b) => a.first.day.compareTo(b.first.day));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.appCardBackgroundStrong,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: cs.outline.withValues(alpha: 0.10))),
                child: Icon(Icons.playlist_add_check_rounded, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Planned meals', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 12),
          Text('Tap “Eat” to move a planned meal into your history.', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.2)),
          const SizedBox(height: 12),
          for (final dayMeals in days) ...[
            _PlannedDay(day: dayMeals.first.day, meals: dayMeals),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PlannedDay extends StatelessWidget {
  final DateTime day;
  final List<PlannedMeal> meals;
  const _PlannedDay({required this.day, required this.meals});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final formatted = '${_month(day.month)} ${day.day}';
    final sorted = meals.toList()..sort((a, b) => a.slot.index.compareTo(b.slot.index));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.appCardBackgroundSubtle, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: cs.outline.withValues(alpha: 0.10))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatted, style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface.withValues(alpha: 0.85))),
          const SizedBox(height: 10),
          for (final m in sorted) ...[
            _PlannedMealRow(meal: m),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  String _month(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
}

class _PlannedMealRow extends StatelessWidget {
  final PlannedMeal meal;
  const _PlannedMealRow({required this.meal});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<AppController>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outline.withValues(alpha: 0.10))),
          child: Icon(_iconFor(meal.type), color: cs.onSurface.withValues(alpha: 0.85)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${meal.slot.label} • ${meal.type.shortLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                meal.restaurant,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: () async {
            final ok = await controller.consumePlannedMeal(meal.id);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Logged!' : 'Could not log.')));
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: Text('Eat', style: text.labelLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _QuickButtons extends StatelessWidget {
  final Trip trip;
  final ValueChanged<UsageType> onTap;

  const _QuickButtons({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add a quick log', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        if (controller.creditsExpired)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: cs.error.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_rounded, size: 18, color: cs.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(child: Text('Credits for this trip have expired. Logging is disabled.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onErrorContainer))),
              ],
            ),
          ),
        if (controller.creditsExpired) const SizedBox(height: AppSpacing.sm),
        _ActionTile(
          icon: Icons.fastfood_rounded,
          title: 'Quick Service',
          subtitle: '1 meal',
          badgeText: _badgeText(controller, UsageType.quickService),
          enabled: !controller.creditsExpired,
          onPressed: () => onTap(UsageType.quickService),
        ),
        const SizedBox(height: AppSpacing.md),
        _ActionTile(
          icon: Icons.icecream_rounded,
          title: 'Snack',
          subtitle: '1 snack',
          badgeText: _badgeText(controller, UsageType.snack),
          enabled: !controller.creditsExpired,
          onPressed: () => onTap(UsageType.snack),
        ),
        if (trip.totalTableServiceCredits > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _ActionTile(
            icon: Icons.restaurant_rounded,
            title: 'Table Service',
            subtitle: '1 meal',
            badgeText: _badgeText(controller, UsageType.tableService),
            enabled: !controller.creditsExpired,
            onPressed: () => onTap(UsageType.tableService),
          ),
        ],
      ],
    );
  }

  String _badgeText(AppController controller, UsageType type) {
    if (!trip.usesDiningPlan) return 'cash';
    final remaining = controller.remainingFor(type);
    if (remaining <= 0) return '0 left';
    return '$remaining left';
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badgeText;
  final bool enabled;
  final VoidCallback onPressed;

  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onPressed, this.badgeText, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final bg = enabled ? cs.appCardBackgroundStrong : cs.appCardBackgroundStrong.withValues(alpha: 0.55);
    final fg = enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.55);

    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: cs.outline.withValues(alpha: 0.10))),
              child: Icon(icon, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: fg.withValues(alpha: 0.75)),
                  ),
                ],
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.10)),
                ),
                child: Text(badgeText!, style: text.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
              ),
            ],
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: fg.withValues(alpha: 0.55)),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<UsageEntry> entries;
  const _HistoryList({required this.entries});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final controller = context.read<AppController>();

    if (entries.isEmpty) {
      return Container(
        width: double.infinity,
          padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: cs.appCardBackgroundStrong,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
        ),
        child: Text('Nothing logged yet. Add your first meal or snack above.', style: text.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.80))),
      );
    }

    return Column(
      children: entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Dismissible(
                key: ValueKey(e.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  padding: const EdgeInsets.only(right: 18),
                  alignment: Alignment.centerRight,
                  decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(AppRadius.xl)),
                  child: Icon(Icons.delete_rounded, color: cs.onErrorContainer),
                ),
                onDismissed: (_) => controller.deleteUsage(e.id),
                child: Container(
                  padding: const EdgeInsets.all(14),
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
                        decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: cs.outline.withValues(alpha: 0.10))),
                        child: Icon(_iconFor(e.type), color: cs.onSurface.withValues(alpha: 0.85)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.type.label, style: text.titleSmall),
                            const SizedBox(height: 2),
                            Text(_formatTime(e.usedAt), style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75))),
                            if (e.value != null) ...[
                              const SizedBox(height: 4),
                              Text('Value: ${_formatMoney(e.value!)}', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75))),
                            ],
                            if (e.note != null) ...[
                              const SizedBox(height: 4),
                              Text(e.note!, style: text.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.90))),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${_month(dt.month)} ${dt.day} • $h:$m $ampm';
  }

  String _month(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

  String _formatMoney(double v) => '\$${v.toStringAsFixed(2)}';
}

IconData _iconFor(UsageType t) => switch (t) {
  UsageType.quickService => Icons.fastfood_rounded,
  UsageType.tableService => Icons.restaurant_rounded,
  UsageType.snack => Icons.icecream_rounded,
};
