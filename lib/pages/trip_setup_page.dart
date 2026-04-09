import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mouseplate/controllers/app_controller.dart';
import 'package:mouseplate/models/trip.dart';
import 'package:mouseplate/nav.dart';
import 'package:mouseplate/theme.dart';
import 'package:mouseplate/widgets/app_shell.dart';

class TripSetupPage extends StatefulWidget {
  const TripSetupPage({super.key});

  @override
  State<TripSetupPage> createState() => _TripSetupPageState();
}

class _TripSetupPageState extends State<TripSetupPage> {
  final _formKey = GlobalKey<FormState>();

  PlanType _planType = PlanType.quickService;
  late final TextEditingController _adults;
  late final TextEditingController _children;
  late final TextEditingController _nights;
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    final existing = context.read<AppController>().trip;
    _planType = existing?.planType ?? PlanType.quickService;
    _adults = TextEditingController(text: (existing?.adults ?? 2).toString());
    _children = TextEditingController(text: (existing?.children ?? 0).toString());
    _nights = TextEditingController(text: (existing?.nights ?? 4).toString());
    _startDate = existing?.startDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _adults.dispose();
    _children.dispose();
    _nights.dispose();
    super.dispose();
  }

  int? _intOrNull(String raw) => int.tryParse(raw.trim());

  String? _validateAdults(String? v) {
    final n = _intOrNull(v ?? '');
    if (n == null) return 'Enter a number';
    if (n < 1) return 'At least 1 adult';
    if (n > 20) return 'Max 20 for now';
    return null;
  }

  String? _validateChildren(String? v) {
    final n = _intOrNull(v ?? '');
    if (n == null) return 'Enter a number';
    if (n < 0) return 'Can’t be negative';
    if (n > 20) return 'Max 20 for now';
    return null;
  }

  String? _validateNights(String? v) {
    final n = _intOrNull(v ?? '');
    if (n == null) return 'Enter a number';
    if (n < 1) return 'At least 1 night';
    if (n > 21) return 'Max 21 nights';
    return null;
  }

  Trip _buildPreviewTrip() {
    final now = DateTime.now();
    final existing = context.read<AppController>().trip;
    return Trip(
      id: existing?.id ?? 'trip',
      planType: _planType,
      adults: _intOrNull(_adults.text) ?? 0,
      children: _intOrNull(_children.text) ?? 0,
      nights: _intOrNull(_nights.text) ?? 0,
      startDate: _startDate,
      assumedQuickServiceValue: existing?.assumedQuickServiceValue ?? 23.00,
      assumedTableServiceValue: existing?.assumedTableServiceValue ?? 60.00,
      assumedSnackValue: existing?.assumedSnackValue ?? 9.00,
      assumedChildPricePerNight: existing?.assumedChildPricePerNight ?? 0.00,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: 'Select check-in date',
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final controller = context.read<AppController>();
    final now = DateTime.now();
    final previous = controller.trip;

    final trip = Trip(
      id: previous?.id ?? 'trip',
      planType: _planType,
      adults: int.parse(_adults.text.trim()),
      children: int.parse(_children.text.trim()),
      nights: int.parse(_nights.text.trim()),
      startDate: _startDate,
      assumedQuickServiceValue: previous?.assumedQuickServiceValue ?? 23.00,
      assumedTableServiceValue: previous?.assumedTableServiceValue ?? 60.00,
      assumedSnackValue: previous?.assumedSnackValue ?? 9.00,
      assumedChildPricePerNight: previous?.assumedChildPricePerNight ?? 0.00,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );

    await controller.saveTrip(trip);
    if (mounted) context.go(AppRoutes.appHome);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final preview = _buildPreviewTrip();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Setup'),
        backgroundColor: cs.surface.withValues(alpha: 0.90),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: AppBody(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pick your plan', style: text.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                _PlanPicker(value: _planType, onChanged: (v) => setState(() => _planType = v)),
                const SizedBox(height: AppSpacing.lg),
                Text('Check-in date', style: text.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                _DatePickerTile(date: _startDate, onTap: _pickStartDate),
                const SizedBox(height: AppSpacing.lg),
                Text('Party & nights', style: text.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _adults,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Adults (10+)', prefixIcon: Icon(Icons.person_rounded)),
                              validator: _validateAdults,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: TextFormField(
                              controller: _children,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Children (3–9)', prefixIcon: Icon(Icons.child_care_rounded)),
                              validator: _validateChildren,
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _nights,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Nights', prefixIcon: Icon(Icons.nights_stay_rounded)),
                        validator: _validateNights,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _TotalsCard(trip: preview),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: Icon(Icons.check_rounded, color: cs.onPrimary),
                    label: Text('Save & Continue', style: text.titleMedium?.copyWith(color: cs.onPrimary)),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Plan price uses 2026 adult pricing. Child price defaults to \$0 but you can adjust it in the “Worth it?” card on the Dashboard.',
                  style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.70), height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanPicker extends StatelessWidget {
  final PlanType value;
  final ValueChanged<PlanType> onChanged;
  const _PlanPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget tile({required PlanType type, required IconData icon, required String subtitle}) {
      final selected = value == type;
      return InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => onChanged(type),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : cs.appCardBackground,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: selected ? cs.primary.withValues(alpha: 0.35) : cs.outline.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? cs.primary.withValues(alpha: 0.12) : cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
                ),
                child: Icon(icon, color: cs.onSurface),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label, style: text.titleMedium?.copyWith(color: cs.onSurface)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.25)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? cs.primary : cs.outline.withValues(alpha: 0.60)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        tile(type: PlanType.quickService, icon: Icons.fastfood_rounded, subtitle: '2 Quick-Service meals per person, per night. No snacks.'),
        const SizedBox(height: 10),
        tile(type: PlanType.standard, icon: Icons.restaurant_rounded, subtitle: '1 Table-Service + 1 Quick-Service + 2 Snacks per person, per night.'),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final Trip trip;
  const _TotalsCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final currency = trip.estimatedTotalCost.isFinite ? trip.estimatedTotalCost : 0.0;

    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: cs.onSurface.withValues(alpha: 0.75)),
                const SizedBox(width: 10),
                Text('Estimated totals', style: text.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            _RowStat(label: 'Quick-Service meals', value: trip.totalQuickServiceCredits.toString()),
            _RowStat(label: 'Table-Service meals', value: trip.totalTableServiceCredits.toString()),
            _RowStat(label: 'Snacks / drinks', value: trip.totalSnackCredits.toString()),
            const SizedBox(height: 6),
            _RowStat(label: 'Checkout day', value: _formatDate(trip.checkoutDay)),
            _RowStat(label: 'Credits expire', value: 'Midnight, ${_formatDate(trip.checkoutDay)}'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Row(
                children: [
                  Expanded(child: Text('Estimated cost', style: text.bodyMedium?.copyWith(color: cs.onPrimaryContainer))),
                  Text(_formatMoney(currency), style: text.titleMedium?.copyWith(color: cs.onPrimaryContainer)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMoney(double v) => '\$${v.toStringAsFixed(2)}';
  String _formatDate(DateTime d) => '${_month(d.month)} ${d.day}, ${d.year}';
  String _month(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
}

class _RowStat extends StatelessWidget {
  final String label;
  final String value;
  const _RowStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.80)))),
          Text(value, style: text.titleMedium?.copyWith(color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DatePickerTile({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final formatted = '${_weekday(date.weekday)}, ${_month(date.month)} ${date.day}, ${date.year}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.appCardBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outline.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
              ),
              child: Icon(Icons.calendar_today_rounded, color: cs.onSurface),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Check-in', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.70))),
                  const SizedBox(height: 2),
                  Text(formatted, style: text.titleMedium?.copyWith(color: cs.onSurface)),
                ],
              ),
            ),
            Icon(Icons.edit_rounded, color: cs.onSurface.withValues(alpha: 0.55)),
          ],
        ),
      ),
    );
  }

  String _weekday(int w) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
  String _month(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
}
