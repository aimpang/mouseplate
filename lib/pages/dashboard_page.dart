import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mouseplate/controllers/app_controller.dart';
import 'package:mouseplate/models/trip.dart';
import 'package:mouseplate/models/usage_entry.dart';
import 'package:mouseplate/nav.dart';
import 'package:mouseplate/theme.dart';
import 'package:mouseplate/widgets/app_shell.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static const int _maxClamp = 1000000000;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final trip = controller.trip;
    if (trip == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final usedQS = controller.usedQuickService;
    final usedTS = controller.usedTableService;
    final usedSnack = controller.usedSnacks;

    final remainingQS = (trip.totalQuickServiceCredits - usedQS).clamp(0, _maxClamp);
    final remainingTS = (trip.totalTableServiceCredits - usedTS).clamp(0, _maxClamp);
    final remainingSnack = (trip.totalSnackCredits - usedSnack).clamp(0, _maxClamp);

    final totalUsed = usedQS + usedTS + usedSnack;
    final totalRemaining = remainingQS + remainingTS + remainingSnack;

    return AppPageScaffold(
      title: 'Dashboard',
      actions: [
        IconButton(
          tooltip: 'Edit trip',
          onPressed: () => context.push(AppRoutes.setup),
          icon: const Icon(Icons.edit_rounded),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TripHeader(trip: trip),
          const SizedBox(height: AppSpacing.md),
          _DashboardModeToggle(mode: controller.dashboardMode, onChanged: controller.setDashboardMode),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _BigStatCard(title: 'Total', primary: trip.totalAllCredits.toString(), secondary: '$totalUsed used')),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _BigStatCard(title: 'Remaining', primary: totalRemaining.toString(), secondary: 'keep the magic going')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _WorthItCard(trip: trip, usage: controller.usage, totalRemainingCredits: totalRemaining, onUpdateTrip: controller.saveTrip),
          const SizedBox(height: AppSpacing.md),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: controller.dashboardMode == DashboardMode.totals
                ? _CountersCard(
                    key: const ValueKey('totals'),
                    trip: trip,
                    usedQS: usedQS,
                    usedTS: usedTS,
                    usedSnack: usedSnack,
                    remainingQS: remainingQS,
                    remainingTS: remainingTS,
                    remainingSnack: remainingSnack,
                  )
                : _DayByDayCard(
                    key: const ValueKey('dayByDay'),
                    trip: trip,
                    usage: controller.usage,
                    remainingQS: remainingQS,
                    remainingTS: remainingTS,
                    remainingSnack: remainingSnack,
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.go(AppRoutes.appLog),
              icon: Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.onPrimary),
              label: Text('Log a Meal / Snack', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ExpiryCountdown(trip: trip),
          const SizedBox(height: AppSpacing.md),
          _LowCreditsReminder(
            remainingQS: remainingQS,
            remainingTS: remainingTS,
            remainingSnack: remainingSnack,
            trip: trip,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Recent history', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          _RecentHistory(usage: controller.usage.take(5).toList()),
        ],
      ),
    );
  }
}

class _WorthItCard extends StatelessWidget {
  final Trip trip;
  final List<UsageEntry> usage;
  final int totalRemainingCredits;
  final Future<void> Function(Trip trip) onUpdateTrip;

  const _WorthItCard({required this.trip, required this.usage, required this.totalRemainingCredits, required this.onUpdateTrip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final planCost = trip.estimatedTotalCost;
    final oopEstimate = trip.estimatedOutOfPocketCost;
    final delta = oopEstimate - planCost;

    final loggedValue = usage.fold<double>(0.0, (sum, e) => sum + (e.value ?? 0.0));
    final remainingToBreakEven = (planCost - loggedValue).clamp(0.0, double.infinity);
    final perCreditNeeded = totalRemainingCredits <= 0 ? 0.0 : (remainingToBreakEven / totalRemainingCredits);

    final bool hasLoggedValues = usage.any((e) => (e.value ?? 0) > 0);
    final Color accent = delta >= 0 ? cs.primary : cs.tertiary;
    final Color bg = cs.appCardBackgroundStrong;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
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
                child: Icon(Icons.calculate_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Worth it?', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Estimate plan vs cash — then track if you’re actually using it.',
                      style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.2),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _openAssumptionsSheet(context),
                icon: Icon(Icons.tune_rounded, color: cs.primary),
                label: Text('Edit', style: text.labelLarge?.copyWith(color: cs.primary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WorthItRow(label: 'Plan cost (est.)', value: _money(planCost), valueStyle: text.titleMedium?.copyWith(color: cs.onSurface)),
          _WorthItRow(label: 'Cash if you buy the same items', value: _money(oopEstimate), valueStyle: text.titleMedium?.copyWith(color: cs.onSurface)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: (delta >= 0 ? cs.primaryContainer : cs.tertiaryContainer).withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: accent.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    delta >= 0 ? 'Estimated savings' : 'Estimated extra cost',
                    style: text.bodyMedium?.copyWith(color: delta >= 0 ? cs.onPrimaryContainer : cs.onTertiaryContainer),
                  ),
                ),
                Text(
                  (delta >= 0 ? '' : '-') + _money(delta.abs()),
                  style: text.titleMedium?.copyWith(color: delta >= 0 ? cs.onPrimaryContainer : cs.onTertiaryContainer, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (hasLoggedValues) ...[
            const SizedBox(height: 12),
            Text('Based on what you’ve logged', style: text.labelLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.80))),
            const SizedBox(height: 8),
            _WorthItRow(label: 'Value logged so far', value: _money(loggedValue), valueStyle: text.titleMedium?.copyWith(color: cs.onSurface)),
            _WorthItRow(label: 'Still needed to break even', value: _money(remainingToBreakEven), valueStyle: text.titleMedium?.copyWith(color: cs.onSurface)),
            if (totalRemainingCredits > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Simple target: average ${_money(perCreditNeeded)} per remaining credit.',
                  style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.2),
                ),
              ),
          ]
        ],
      ),
    );
  }

  Future<void> _openAssumptionsSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final qs = TextEditingController(text: trip.assumedQuickServiceValue.toStringAsFixed(2));
    final ts = TextEditingController(text: trip.assumedTableServiceValue.toStringAsFixed(2));
    final snack = TextEditingController(text: trip.assumedSnackValue.toStringAsFixed(2));
    final childPrice = TextEditingController(text: trip.assumedChildPricePerNight.toStringAsFixed(2));

    double? parseMoney(String raw) {
      final s = raw.trim();
      if (s.isEmpty) return null;
      final normalized = s.replaceAll(RegExp(r'[^0-9.\-]'), '');
      final v = double.tryParse(normalized);
      if (v == null || !v.isFinite) return null;
      return v;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.md, bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Worth-it assumptions', style: text.titleLarge),
              const SizedBox(height: 6),
              Text('Set your typical prices. The app uses these to estimate cash vs plan.', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.25)),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: qs,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Avg Quick-Service value', prefixIcon: Icon(Icons.fastfood_rounded), hintText: 'e.g., 23.00'),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (trip.totalTableServiceCredits > 0) ...[
                TextField(
                  controller: ts,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Avg Table-Service value', prefixIcon: Icon(Icons.restaurant_rounded), hintText: 'e.g., 60.00'),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (trip.totalSnackCredits > 0) ...[
                TextField(
                  controller: snack,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Avg Snack value', prefixIcon: Icon(Icons.icecream_rounded), hintText: 'e.g., 9.00'),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              TextField(
                controller: childPrice,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Child plan price per night (optional)', prefixIcon: Icon(Icons.child_care_rounded), hintText: '0.00'),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final next = trip.copyWith(
                      assumedQuickServiceValue: (parseMoney(qs.text) ?? trip.assumedQuickServiceValue).clamp(0.0, 1000.0),
                      assumedTableServiceValue: (parseMoney(ts.text) ?? trip.assumedTableServiceValue).clamp(0.0, 1000.0),
                      assumedSnackValue: (parseMoney(snack.text) ?? trip.assumedSnackValue).clamp(0.0, 1000.0),
                      assumedChildPricePerNight: (parseMoney(childPrice.text) ?? trip.assumedChildPricePerNight).clamp(0.0, 1000.0),
                      updatedAt: DateTime.now(),
                    );
                    await onUpdateTrip(next);
                    if (ctx.mounted) ctx.pop();
                  },
                  icon: Icon(Icons.check_rounded, color: cs.onPrimary),
                  label: Text('Save', style: text.titleMedium?.copyWith(color: cs.onPrimary)),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  static String _money(double v) => '\$${(v.isFinite ? v : 0.0).toStringAsFixed(2)}';
}

class _WorthItRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _WorthItRow({required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.80)))),
          Text(value, style: valueStyle ?? text.titleMedium?.copyWith(color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _TripHeader extends StatelessWidget {
  final Trip trip;
  const _TripHeader({required this.trip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
            ),
            child: Icon(Icons.castle_rounded, color: cs.onSurface),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trip.planType.label, style: text.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
                const SizedBox(height: 4),
                Text('${trip.adults} adult${trip.adults != 1 ? 's' : ''} • ${trip.children} kid${trip.children != 1 ? 's' : ''} • ${trip.nights} night${trip.nights != 1 ? 's' : ''}', style: text.bodyMedium?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardModeToggle extends StatelessWidget {
  final DashboardMode mode;
  final Future<void> Function(DashboardMode mode) onChanged;
  const _DashboardModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: SegmentedButton<DashboardMode>(
        segments: const [
          ButtonSegment(value: DashboardMode.totals, label: Text('Totals'), icon: Icon(Icons.pie_chart_outline_rounded)),
          ButtonSegment(value: DashboardMode.dayByDay, label: Text('Day by day'), icon: Icon(Icons.calendar_view_day_rounded)),
        ],
        selected: <DashboardMode>{mode},
        showSelectedIcon: false,
        style: ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
        ),
        onSelectionChanged: (selection) {
          final next = selection.isEmpty ? null : selection.first;
          if (next == null || next == mode) return;
          onChanged(next);
        },
      ),
    );
  }
}

class _BigStatCard extends StatelessWidget {
  final String title;
  final String primary;
  final String secondary;
  const _BigStatCard({required this.title, required this.primary, required this.secondary});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.labelLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.75))),
            const SizedBox(height: 8),
            Text(primary, style: text.headlineLarge?.copyWith(color: cs.onSurface)),
            const SizedBox(height: 6),
            Text(secondary, style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.70), height: 1.2)),
          ],
        ),
      ),
    );
  }
}

class _CountersCard extends StatelessWidget {
  final Trip trip;
  final int usedQS;
  final int usedTS;
  final int usedSnack;
  final int remainingQS;
  final int remainingTS;
  final int remainingSnack;

  const _CountersCard({
    super.key,
    required this.trip,
    required this.usedQS,
    required this.usedTS,
    required this.usedSnack,
    required this.remainingQS,
    required this.remainingTS,
    required this.remainingSnack,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Counters', style: text.titleMedium),
            const SizedBox(height: 12),
            _CounterRow(label: 'Quick-Service', total: trip.totalQuickServiceCredits, used: usedQS, remaining: remainingQS),
            const SizedBox(height: 10),
            if (trip.totalTableServiceCredits > 0) ...[
              _CounterRow(label: 'Table-Service', total: trip.totalTableServiceCredits, used: usedTS, remaining: remainingTS),
              const SizedBox(height: 10),
            ],
            _CounterRow(label: 'Snacks / drinks', total: trip.totalSnackCredits, used: usedSnack, remaining: remainingSnack),
          ],
        ),
      ),
    );
  }
}

class _DayByDayCard extends StatelessWidget {
  final Trip trip;
  final List<UsageEntry> usage;
  final int remainingQS;
  final int remainingTS;
  final int remainingSnack;

  const _DayByDayCard({super.key, required this.trip, required this.usage, required this.remainingQS, required this.remainingTS, required this.remainingSnack});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final today = _dateOnly(DateTime.now());
    final tripStart = _dateOnly(trip.startDate);
    final checkout = _dateOnly(trip.checkoutDay);

    // If the trip hasn't started yet, pace should begin from the trip start date
    // (not from today's date), otherwise it can suggest an unrealistically low pace.
    final paceStart = today.isBefore(tripStart) ? tripStart : today;
    final remainingDays = paceStart.isAfter(checkout) ? 0 : checkout.difference(paceStart).inDays + 1;
    final qsPerDay = remainingDays == 0 ? 0.0 : (remainingQS / remainingDays);
    final tsPerDay = remainingDays == 0 ? 0.0 : (remainingTS / remainingDays);
    final snackPerDay = remainingDays == 0 ? 0.0 : (remainingSnack / remainingDays);

    final days = <DateTime>[];
    for (var i = 0; i <= trip.nights; i++) {
      days.add(_dateOnly(trip.startDate).add(Duration(days: i)));
    }

    final usageByDay = <DateTime, List<UsageEntry>>{};
    for (final e in usage) {
      final d = _dateOnly(e.usedAt);
      (usageByDay[d] ??= <UsageEntry>[]).add(e);
    }

    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Day-by-day', style: text.titleMedium)),
                Icon(Icons.auto_graph_rounded, color: cs.primary),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              remainingDays == 0
                  ? 'Your trip is over — this view is read-only.'
                  : 'Suggested pace to finish by checkout: '
                      '${_fmt1(qsPerDay)} QS/day'
                      '${trip.totalTableServiceCredits > 0 ? ' • ${_fmt1(tsPerDay)} TS/day' : ''}'
                      '${trip.totalSnackCredits > 0 ? ' • ${_fmt1(snackPerDay)} snack/day' : ''}'
                      '${paceStart != today ? ' (starting ${_formatMonthDay(paceStart)})' : ''}',
              style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.25),
            ),
            const SizedBox(height: 12),
            ...days.map((day) {
              final entries = usageByDay[day] ?? const <UsageEntry>[];
              final usedQS = entries.where((e) => e.type == UsageType.quickService).length;
              final usedTS = entries.where((e) => e.type == UsageType.tableService).length;
              final usedSnack = entries.where((e) => e.type == UsageType.snack).length;
              final isToday = today == day;
              final isPast = day.isBefore(today);
              final isFuture = day.isAfter(today);
              final usedAny = usedQS + usedTS + usedSnack;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isFuture ? cs.appCardBackground : cs.appCardBackgroundStrong,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: cs.outline.withValues(alpha: isToday ? 0.25 : 0.12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(_formatMonthDay(day), style: text.titleSmall?.copyWith(color: cs.onSurface)),
                                const SizedBox(width: 8),
                                if (isToday)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: cs.primaryContainer,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: cs.primary.withValues(alpha: 0.20)),
                                    ),
                                    child: Text('Today', style: text.labelSmall?.copyWith(color: cs.onPrimaryContainer)),
                                  )
                                else if (isPast)
                                  Text('Past', style: text.labelSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.55))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              usedAny == 0 ? 'No credits logged' : '$usedAny credit${usedAny == 1 ? '' : 's'} logged',
                              style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.70), height: 1.2),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                _MiniPill(icon: Icons.fastfood_rounded, label: 'QS', value: usedQS),
                                if (trip.totalTableServiceCredits > 0) _MiniPill(icon: Icons.restaurant_rounded, label: 'TS', value: usedTS),
                                if (trip.totalSnackCredits > 0) _MiniPill(icon: Icons.icecream_rounded, label: 'Snack', value: usedSnack),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: isFuture ? 0.25 : 0.45)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  const _MiniPill({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 6),
          Text(label, style: text.labelLarge?.copyWith(color: cs.onSurface)),
          const SizedBox(width: 8),
          Text(value.toString(), style: text.titleSmall?.copyWith(color: cs.onSurface)),
        ],
      ),
    );
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _formatMonthDay(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final m = (d.month >= 1 && d.month <= 12) ? months[d.month - 1] : d.month.toString();
  return '$m ${d.day}';
}

String _fmt1(double v) => v.isNaN || v.isInfinite ? '0.0' : v.toStringAsFixed(1);

class _CounterRow extends StatelessWidget {
  final String label;
  final int total;
  final int used;
  final int remaining;

  const _CounterRow({required this.label, required this.total, required this.used, required this.remaining});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final pct = total == 0 ? 0.0 : (used / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.appCardBackgroundStrong,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: text.titleSmall?.copyWith(color: cs.onSurface))),
              Text('$remaining', style: text.titleLarge?.copyWith(color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: cs.surface,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text('$used used of $total', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.70))),
        ],
      ),
    );
  }
}

class _ExpiryCountdown extends StatelessWidget {
  final Trip trip;
  const _ExpiryCountdown({required this.trip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final checkout = trip.checkoutDay;
    final diff = checkout.difference(now);

    final checkoutPretty = '${_month(checkout.month)} ${checkout.day}';

    // Determine countdown state
    final bool expired = diff.isNegative;
    final bool lastDay = !expired && diff.inDays == 0;
    final bool soonExpiring = !expired && diff.inDays <= 1;

    String countdownText;
    Color bgColor;
    Color fgColor;
    IconData icon;

    if (expired) {
      countdownText = 'Credits have expired';
      bgColor = cs.errorContainer;
      fgColor = cs.onErrorContainer;
      icon = Icons.warning_rounded;
    } else if (lastDay) {
      final hours = diff.inHours;
      countdownText = 'Last day! $hours hours left until midnight';
      bgColor = cs.errorContainer;
      fgColor = cs.onErrorContainer;
      icon = Icons.schedule_rounded;
    } else if (soonExpiring) {
      final hours = diff.inHours;
      countdownText = '${diff.inDays}d ${hours % 24}h left — checkout $checkoutPretty';
      bgColor = cs.tertiaryContainer;
      fgColor = cs.onTertiaryContainer;
      icon = Icons.hourglass_bottom_rounded;
    } else {
      countdownText = '${diff.inDays} days left — checkout $checkoutPretty';
      bgColor = cs.primaryContainer.withValues(alpha: 0.50);
      fgColor = cs.onPrimaryContainer;
      icon = Icons.event_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: fgColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              countdownText,
              style: text.bodyMedium?.copyWith(color: fgColor, fontWeight: soonExpiring || expired ? FontWeight.w600 : FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }

  String _month(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
}

class _LowCreditsReminder extends StatelessWidget {
  final int remainingQS;
  final int remainingTS;
  final int remainingSnack;
  final Trip trip;

  const _LowCreditsReminder({
    required this.remainingQS,
    required this.remainingTS,
    required this.remainingSnack,
    required this.trip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final checkout = trip.checkoutDay;
    final daysLeft = checkout.difference(now).inDays;

    // Gather hints
    final List<String> hints = [];

    // Check for unused credits relative to days remaining
    if (daysLeft > 0 && daysLeft <= 2) {
      final totalRemaining = remainingQS + remainingTS + remainingSnack;
      if (totalRemaining > 0) {
        hints.add('Don\'t forget — $totalRemaining credit${totalRemaining == 1 ? '' : 's'} left to use!');
      }
    }

    // Check for snacks piling up
    if (remainingSnack >= 4 && daysLeft <= 3) {
      hints.add('$remainingSnack snack credits left — time for some treats!');
    }

    // Check for quick-service credits piling up
    if (remainingQS >= trip.totalPartySize * 2 && daysLeft <= 2) {
      hints.add('Plenty of QS meals left — consider a big family meal.');
    }

    if (hints.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, size: 20, color: cs.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hints.first,
              style: text.bodyMedium?.copyWith(color: cs.onTertiaryContainer, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentHistory extends StatelessWidget {
  final List<UsageEntry> usage;
  const _RecentHistory({required this.usage});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (usage.isEmpty) {
      return Container(
        width: double.infinity,
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: cs.appCardBackgroundStrong,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
        ),
        child: Text('No logs yet — tap “Log a Meal / Snack” to start.', style: text.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.80))),
      );
    }

    return Column(
      children: usage
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.appCardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: cs.outline.withValues(alpha: 0.12))),
                      child: Icon(_iconFor(e.type), color: cs.onSurface.withValues(alpha: 0.85)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.type.label, style: text.titleSmall),
                          const SizedBox(height: 2),
                          Text(_formatTime(e.usedAt) + (e.note == null ? '' : ' • ${e.note}'), style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  IconData _iconFor(UsageType t) => switch (t) {
    UsageType.quickService => Icons.fastfood_rounded,
    UsageType.tableService => Icons.restaurant_rounded,
    UsageType.snack => Icons.icecream_rounded,
  };

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${_month(dt.month)} ${dt.day} • $h:$m $ampm';
  }

  String _month(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
}
