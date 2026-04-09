import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mouseplate/controllers/app_controller.dart';
import 'package:mouseplate/models/planned_meal.dart';
import 'package:mouseplate/models/trip.dart';
import 'package:mouseplate/models/usage_entry.dart';
import 'package:mouseplate/nav.dart';
import 'package:mouseplate/theme.dart';
import 'package:mouseplate/widgets/app_shell.dart';

class TripOnboarderPage extends StatefulWidget {
  const TripOnboarderPage({super.key});

  @override
  State<TripOnboarderPage> createState() => _TripOnboarderPageState();
}

class _TripOnboarderPageState extends State<TripOnboarderPage> {
  int _step = 0;

  // Step 1
  late final TextEditingController _adults;
  late final TextEditingController _children;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 4));
  bool _annualPassholder = false;
  bool _dvcMember = false;

  // Step 2
  BeveragePreference _beverage = BeveragePreference.fountainOrNonAlcoholic;
  int _snacksPerPersonPerDay = 0;
  bool _dessertAtTS = false;
  bool _mugs = false;
  DiningStyle _style = DiningStyle.average;

  // Step 3 drafts
  late List<_MealDraft> _mealDrafts;

  // Step 4/5
  DiningRecommendation _recommendation = DiningRecommendation.quickService;
  DiningRecommendation _selectedOption = DiningRecommendation.quickService;
  _CostBreakdown _costs = const _CostBreakdown.zero();

  @override
  void initState() {
    super.initState();
    final existing = context.read<AppController>().trip;

    _adults = TextEditingController(text: (existing?.adults ?? 2).toString());
    _children = TextEditingController(text: (existing?.children ?? 0).toString());
    _startDate = existing?.startDate ?? DateTime.now();
    final existingNights = existing?.nights ?? 4;
    _endDate = _startDate.add(Duration(days: existingNights));
    _annualPassholder = existing?.annualPassholder ?? false;
    _dvcMember = existing?.dvcMember ?? false;

    _beverage = existing?.beveragePreference ?? BeveragePreference.fountainOrNonAlcoholic;
    _snacksPerPersonPerDay = existing?.snacksPerPersonPerDay ?? 0;
    _dessertAtTS = existing?.dessertAtTableService ?? false;
    _mugs = existing?.resortRefillableMugs ?? false;
    _style = existing?.diningStyle ?? DiningStyle.average;

    _recommendation = existing?.recommendation ?? DiningRecommendation.quickService;
    _selectedOption = existing?.usesDiningPlan == false ? DiningRecommendation.outOfPocket : _recommendation;

    _mealDrafts = _buildMealDrafts(existing);
    _recompute();
  }

  @override
  void dispose() {
    _adults.dispose();
    _children.dispose();
    for (final d in _mealDrafts) {
      d.restaurant.dispose();
    }
    super.dispose();
  }

  List<_MealDraft> _buildMealDrafts(Trip? existing) {
    final existingMeals = existing?.plannedMeals ?? const <PlannedMeal>[];
    final byKey = <String, PlannedMeal>{
      for (final m in existingMeals) _draftKey(m.day, m.slot): m,
    };

    final days = _tripDays();
    final drafts = <_MealDraft>[];
    for (final day in days) {
      for (final slot in MealSlot.values) {
        final k = _draftKey(day, slot);
        final m = byKey[k];
        drafts.add(
          _MealDraft(
            day: day,
            slot: slot,
            type: m?.type ?? _defaultUsageTypeFor(slot),
            restaurant: TextEditingController(text: m?.restaurant ?? ''),
          ),
        );
      }
    }
    return drafts;
  }

  static UsageType _defaultUsageTypeFor(MealSlot slot) => switch (slot) {
    MealSlot.breakfast => UsageType.quickService,
    MealSlot.lunch => UsageType.quickService,
    MealSlot.dinner => UsageType.tableService,
  };

  static String _draftKey(DateTime day, MealSlot slot) => '${day.year}-${day.month}-${day.day}-${slot.name}';

  List<DateTime> _tripDays() {
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
    final nights = end.difference(start).inDays;
    final capped = nights < 1 ? 1 : nights;
    return List<DateTime>.generate(capped, (i) => start.add(Duration(days: i)));
  }

  int _intOrZero(String raw) => int.tryParse(raw.trim()) ?? 0;

  int get _nights {
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
    final nights = end.difference(start).inDays;
    return nights < 1 ? 1 : nights;
  }

  int get _partySize {
    final a = _intOrZero(_adults.text);
    final c = _intOrZero(_children.text);
    return (a + c).clamp(0, 100);
  }

  void _recompute() {
    final adults = _intOrZero(_adults.text).clamp(0, 100);
    final children = _intOrZero(_children.text).clamp(0, 100);

    // Use the existing Trip assumptions for now (user can later tune on Dashboard).
    // These are not “official”; they’re calculators inputs.
    const assumedQS = 23.00;
    const assumedTS = 60.00;

    final outOfPocket = _estimateOutOfPocket(
      adults: adults,
      children: children,
      assumedQS: assumedQS,
      assumedTS: assumedTS,
      beverage: _beverage,
      dessertAtTS: _dessertAtTS,
      snacksPerPersonPerDay: _snacksPerPersonPerDay,
      mugs: _mugs,
      style: _style,
      applyDiscount: _annualPassholder || _dvcMember,
    );

    final qsPlan = _estimatePlanCost(PlanType.quickService, adults: adults, children: children, nights: _nights);
    final stdPlan = _estimatePlanCost(PlanType.standard, adults: adults, children: children, nights: _nights);

    final rec = _minRecommendation(outOfPocket: outOfPocket.total, qsPlan: qsPlan, standardPlan: stdPlan);
    setState(() {
      _costs = _CostBreakdown(outOfPocket: outOfPocket.total, quickServicePlan: qsPlan, standardPlan: stdPlan, notes: outOfPocket.notes);
      _recommendation = rec;
      if (_step >= 3) {
        // If the user hasn’t manually changed it, keep it synced.
        if (_selectedOption == DiningRecommendation.quickService || _selectedOption == DiningRecommendation.standard || _selectedOption == DiningRecommendation.outOfPocket) {
          // Only auto-sync when the selected option equals the old recommendation.
          // This avoids hijacking a manual selection.
        }
      }
      if (_step == 3 || _step == 4) {
        // If user never interacted with selection yet, keep it at recommendation.
        if (_selectedOption == DiningRecommendation.quickService && rec != DiningRecommendation.quickService && _selectedOption == _recommendation) {
          _selectedOption = rec;
        }
      }
    });
  }

  DiningRecommendation _minRecommendation({required double outOfPocket, required double qsPlan, required double standardPlan}) {
    final entries = <DiningRecommendation, double>{
      DiningRecommendation.outOfPocket: outOfPocket,
      DiningRecommendation.quickService: qsPlan,
      DiningRecommendation.standard: standardPlan,
    };
    DiningRecommendation best = DiningRecommendation.outOfPocket;
    double bestV = entries[best]!;
    for (final e in entries.entries) {
      if (e.value < bestV) {
        best = e.key;
        bestV = e.value;
      }
    }
    return best;
  }

  double _estimatePlanCost(PlanType type, {required int adults, required int children, required int nights}) {
    // Child pricing isn’t implemented here yet. (The existing app allows a child override
    // in the Dashboard assumptions.)
    final perAdultNight = switch (type) {
      PlanType.quickService => 60.47,
      PlanType.standard => 98.59,
    };
    return perAdultNight * adults * nights;
  }

  _OopEstimate _estimateOutOfPocket({
    required int adults,
    required int children,
    required double assumedQS,
    required double assumedTS,
    required BeveragePreference beverage,
    required bool dessertAtTS,
    required int snacksPerPersonPerDay,
    required bool mugs,
    required DiningStyle style,
    required bool applyDiscount,
  }) {
    final party = (adults + children).clamp(0, 100);
    final styleMultiplier = switch (style) {
      DiningStyle.budget => 0.88,
      DiningStyle.average => 1.0,
      DiningStyle.splurge => 1.18,
    };

    double mealTotal = 0.0;
    int qsCount = 0;
    int tsCount = 0;
    for (final d in _mealDrafts) {
      final name = d.restaurant.text.trim();
      if (name.isEmpty) continue;
      final base = (d.type == UsageType.tableService ? assumedTS : assumedQS) * styleMultiplier;
      mealTotal += base;
      if (d.type == UsageType.tableService) {
        tsCount++;
        if (dessertAtTS) mealTotal += 6.00; // avg dessert assumption
      } else {
        qsCount++;
      }

      mealTotal += _beverageCost(d.type, beverage);
    }

    // If user didn’t pick restaurants, still estimate based on “typical meals” per person per day.
    if (qsCount == 0 && tsCount == 0) {
      final qsMealsPerPersonPerDay = 2;
      final estMeals = qsMealsPerPersonPerDay * party * _nights;
      mealTotal += estMeals * assumedQS * styleMultiplier;
      mealTotal += estMeals * _beverageCost(UsageType.quickService, beverage);
    }

    final snacks = snacksPerPersonPerDay.clamp(0, 10) * party * _nights;
    final snackTotal = snacks * 7.0; // per your spec

    final mugTotal = mugs ? party * 22.0 : 0.0;

    final discountRate = applyDiscount ? 0.10 : 0.0;
    final discountedMeals = mealTotal * (1.0 - discountRate);

    final total = discountedMeals + snackTotal + mugTotal;
    final notes = <String>[
      if (applyDiscount) 'Includes an estimated 10% dining discount (AP/DVC).',
      'Snacks assumed at \$7 each.',
      if (mugs) 'Mugs assumed at \$22 per person.',
    ];
    return _OopEstimate(total: total, notes: notes);
  }

  double _beverageCost(UsageType mealType, BeveragePreference pref) {
    return switch (pref) {
      BeveragePreference.waterOnly => 0.0,
      BeveragePreference.fountainOrNonAlcoholic => 3.99,
      BeveragePreference.includesAlcohol => mealType == UsageType.tableService ? 12.0 : 10.0,
    };
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: 'Check-in date',
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (!_endDate.isAfter(_startDate)) _endDate = _startDate.add(const Duration(days: 1));
      _mealDrafts = _buildMealDrafts(context.read<AppController>().trip);
    });
    _recompute();
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: 'Check-out date',
    );
    if (picked == null) return;
    setState(() {
      _endDate = picked;
      _mealDrafts = _buildMealDrafts(context.read<AppController>().trip);
    });
    _recompute();
  }

  Future<void> _cancel() async {
    if (!mounted) return;
    final hasTrip = context.read<AppController>().hasTrip;
    if (hasTrip) {
      context.pop();
    } else {
      context.go(AppRoutes.welcome);
    }
  }

  Future<void> _save() async {
    final controller = context.read<AppController>();

    if (controller.usage.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace this trip?'),
          content: const Text('Saving a new trip will clear your existing log history for this device.'),
          actions: [
            TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => ctx.pop(true), child: const Text('Save')),
          ],
        ),
      );
      if (ok != true) return;
    }

    final now = DateTime.now();
    final adults = _intOrZero(_adults.text).clamp(0, 100);
    final children = _intOrZero(_children.text).clamp(0, 100);

    final meals = <PlannedMeal>[];
    for (final d in _mealDrafts) {
      final name = d.restaurant.text.trim();
      if (name.isEmpty) continue;
      meals.add(
        PlannedMeal(
          id: '${d.day.microsecondsSinceEpoch}-${d.slot.name}',
          day: d.day,
          slot: d.slot,
          type: d.type,
          restaurant: name,
          estimatedValue: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final usesDiningPlan = _selectedOption != DiningRecommendation.outOfPocket;
    final planType = switch (_selectedOption) {
      DiningRecommendation.quickService => PlanType.quickService,
      DiningRecommendation.standard => PlanType.standard,
      DiningRecommendation.outOfPocket => PlanType.quickService,
    };

    final trip = Trip(
      id: controller.trip?.id ?? 'trip',
      usesDiningPlan: usesDiningPlan,
      planType: planType,
      adults: adults,
      children: children,
      nights: _nights,
      startDate: DateTime(_startDate.year, _startDate.month, _startDate.day),
      annualPassholder: _annualPassholder,
      dvcMember: _dvcMember,
      beveragePreference: _beverage,
      snacksPerPersonPerDay: _snacksPerPersonPerDay,
      dessertAtTableService: _dessertAtTS,
      resortRefillableMugs: _mugs,
      diningStyle: _style,
      recommendation: _recommendation,
      plannedMeals: usesDiningPlan ? meals : const <PlannedMeal>[],
      // Keep existing assumptions if present.
      assumedQuickServiceValue: controller.trip?.assumedQuickServiceValue ?? 23.00,
      assumedTableServiceValue: controller.trip?.assumedTableServiceValue ?? 60.00,
      assumedSnackValue: controller.trip?.assumedSnackValue ?? 9.00,
      assumedChildPricePerNight: controller.trip?.assumedChildPricePerNight ?? 0.00,
      createdAt: controller.trip?.createdAt ?? now,
      updatedAt: now,
    );

    await controller.replaceTripAndClearUsage(trip);
    if (!mounted) return;
    context.go(AppRoutes.appHome);
  }

  void _next() {
    if (_step == 2) {
      // Rebuild drafts if dates changed.
      setState(() => _mealDrafts = _buildMealDrafts(context.read<AppController>().trip));
    }
    if (_step >= 5) return;
    setState(() => _step++);
    if (_step >= 3) _recompute();
  }

  void _back() {
    if (_step <= 0) return;
    setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Onboarding'),
        backgroundColor: cs.surface.withValues(alpha: 0.90),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: _cancel),
        actions: [
          if (_step > 0)
            TextButton(
              onPressed: _back,
              child: Text('Back', style: text.labelLarge?.copyWith(color: cs.primary)),
            ),
        ],
      ),
      body: SafeArea(
        child: AppBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepHeader(step: _step, cs: cs),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: switch (_step) {
                    0 => _Step1VacationPlans(
                        key: const ValueKey('s1'),
                        adults: _adults,
                        children: _children,
                        startDate: _startDate,
                        endDate: _endDate,
                        nights: _nights,
                        annualPassholder: _annualPassholder,
                        dvcMember: _dvcMember,
                        onPickStart: _pickStart,
                        onPickEnd: _pickEnd,
                        onAnnualPassholderChanged: (v) => setState(() {
                          _annualPassholder = v;
                          _recompute();
                        }),
                        onDvcChanged: (v) => setState(() {
                          _dvcMember = v;
                          _recompute();
                        }),
                        onChanged: () {
                          setState(() {});
                          _recompute();
                        },
                      ),
                    1 => _Step2Customize(
                        key: const ValueKey('s2'),
                        beverage: _beverage,
                        snacksPerPersonPerDay: _snacksPerPersonPerDay,
                        dessertAtTS: _dessertAtTS,
                        mugs: _mugs,
                        style: _style,
                        onBeverageChanged: (v) => setState(() {
                          _beverage = v;
                          _recompute();
                        }),
                        onSnacksChanged: (v) => setState(() {
                          _snacksPerPersonPerDay = v;
                          _recompute();
                        }),
                        onDessertChanged: (v) => setState(() {
                          _dessertAtTS = v;
                          _recompute();
                        }),
                        onMugsChanged: (v) => setState(() {
                          _mugs = v;
                          _recompute();
                        }),
                        onStyleChanged: (v) => setState(() {
                          _style = v;
                          _recompute();
                        }),
                      ),
                    2 => _Step3Restaurants(key: const ValueKey('s3'), drafts: _mealDrafts, onChanged: _recompute),
                    3 => _Step4Recommendation(
                        key: const ValueKey('s4'),
                        costs: _costs,
                        recommendation: _recommendation,
                        selected: _selectedOption,
                        onSelectedChanged: (v) => setState(() => _selectedOption = v),
                      ),
                    4 => _Step5OtherOptions(
                        key: const ValueKey('s5'),
                        costs: _costs,
                        recommendation: _recommendation,
                        selected: _selectedOption,
                        onSelectedChanged: (v) => setState(() => _selectedOption = v),
                      ),
                    _ => _Step6ReviewConfirm(
                        key: const ValueKey('s6'),
                        adults: _intOrZero(_adults.text),
                        children: _intOrZero(_children.text),
                        startDate: _startDate,
                        endDate: _endDate,
                        nights: _nights,
                        annualPassholder: _annualPassholder,
                        dvcMember: _dvcMember,
                        beverage: _beverage,
                        snacksPerPersonPerDay: _snacksPerPersonPerDay,
                        dessertAtTS: _dessertAtTS,
                        mugs: _mugs,
                        style: _style,
                        selected: _selectedOption,
                        costs: _costs,
                        plannedMealsCount: _mealDrafts.where((d) => d.restaurant.text.trim().isNotEmpty).length,
                        onJumpToStep: (s) => setState(() => _step = s.clamp(0, 5)),
                      ),
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancel,
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl))),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _step == 5 ? _save : _next,
                      icon: Icon(_step == 5 ? Icons.check_rounded : Icons.arrow_forward_rounded, color: cs.onPrimary),
                      label: Text(_step == 5 ? 'Save trip' : 'Continue', style: text.titleMedium?.copyWith(color: cs.onPrimary)),
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int step;
  final ColorScheme cs;
  const _StepHeader({required this.step, required this.cs});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final titles = const [
      '1. Describe your vacation plans',
      '2. Customize your dining experience',
      '3. Select your restaurants',
      '4. Get your recommendation',
      '5. Explore other options',
      '6. Review & confirm',
    ];
    final subtitle = switch (step) {
      0 => 'Party, dates, and discounts.',
      1 => 'Match the calculator to your habits.',
      2 => 'Add a restaurant for each meal (optional).',
      3 => 'Most cost-effective option based on your inputs.',
      4 => 'Compare the two options you didn’t pick.',
      _ => 'Quick check before we save your trip.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titles[step.clamp(0, titles.length - 1)], style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, style: text.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.72), height: 1.25)),
        const SizedBox(height: 10),
        _Dots(count: 6, index: step),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 6),
          height: 8,
          width: i == index ? 22 : 8,
          decoration: BoxDecoration(
            color: i == index ? cs.primary : cs.outline.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class _Step1VacationPlans extends StatelessWidget {
  final TextEditingController adults;
  final TextEditingController children;
  final DateTime startDate;
  final DateTime endDate;
  final int nights;
  final bool annualPassholder;
  final bool dvcMember;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final ValueChanged<bool> onAnnualPassholderChanged;
  final ValueChanged<bool> onDvcChanged;
  final VoidCallback onChanged;

  const _Step1VacationPlans({
    super.key,
    required this.adults,
    required this.children,
    required this.startDate,
    required this.endDate,
    required this.nights,
    required this.annualPassholder,
    required this.dvcMember,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onAnnualPassholderChanged,
    required this.onDvcChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Travel party', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: adults,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Adults (10+)', prefixIcon: Icon(Icons.person_rounded)),
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextField(
                        controller: children,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Children (3–9)', prefixIcon: Icon(Icons.child_care_rounded)),
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dates', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _DateTile(label: 'Check-in', date: startDate, onTap: onPickStart),
                const SizedBox(height: 10),
                _DateTile(label: 'Check-out', date: endDate, onTap: onPickEnd),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: cs.outline.withValues(alpha: 0.12))),
                  child: Row(
                    children: [
                      Icon(Icons.nights_stay_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.75)),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Nights', style: text.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.75)))),
                      Text(nights.toString(), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Discounts', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('If you’re an Annual Passholder or DVC Member, we’ll apply an estimated dining discount.', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.25)),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Annual Passholder'),
                  value: annualPassholder,
                  onChanged: onAnnualPassholderChanged,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('DVC Member'),
                  value: dvcMember,
                  onChanged: onDvcChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step2Customize extends StatelessWidget {
  final BeveragePreference beverage;
  final int snacksPerPersonPerDay;
  final bool dessertAtTS;
  final bool mugs;
  final DiningStyle style;
  final ValueChanged<BeveragePreference> onBeverageChanged;
  final ValueChanged<int> onSnacksChanged;
  final ValueChanged<bool> onDessertChanged;
  final ValueChanged<bool> onMugsChanged;
  final ValueChanged<DiningStyle> onStyleChanged;

  const _Step2Customize({
    super.key,
    required this.beverage,
    required this.snacksPerPersonPerDay,
    required this.dessertAtTS,
    required this.mugs,
    required this.style,
    required this.onBeverageChanged,
    required this.onSnacksChanged,
    required this.onDessertChanged,
    required this.onMugsChanged,
    required this.onStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Beverages', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Choose your preferred drinks. For estimates, we’ll use the higher-priced option.', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.25)),
                const SizedBox(height: 10),
                _RadioTile(
                  title: 'Water only',
                  subtitle: 'No beverage cost added',
                  value: BeveragePreference.waterOnly,
                  group: beverage,
                  onChanged: onBeverageChanged,
                  icon: Icons.water_drop_rounded,
                ),
                _RadioTile(
                  title: 'Fountain / specialty (non-alcoholic)',
                  subtitle: 'Uses a fountain/specialty drink price',
                  value: BeveragePreference.fountainOrNonAlcoholic,
                  group: beverage,
                  onChanged: onBeverageChanged,
                  icon: Icons.local_drink_rounded,
                ),
                _RadioTile(
                  title: 'Includes alcohol',
                  subtitle: 'Uses the higher-priced alcoholic option',
                  value: BeveragePreference.includesAlcohol,
                  group: beverage,
                  onChanged: onBeverageChanged,
                  icon: Icons.wine_bar_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Snacks per day', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Estimate snacks per person per day. We assume \$7 per snack.', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.25)),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: snacksPerPersonPerDay,
                  items: List.generate(8, (i) => DropdownMenuItem(value: i, child: Text(i.toString()))),
                  onChanged: (v) => onSnacksChanged(v ?? 0),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.icecream_rounded), labelText: 'Snacks per person / day'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dessert at Table Service', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Usually order dessert at Table-Service meals'),
                  value: dessertAtTS,
                  onChanged: onDessertChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resort refillable mugs', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Buy refillable mugs (one per person)'),
                  value: mugs,
                  onChanged: onMugsChanged,
                ),
                Text('Estimate uses \$22 per person.', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.72))),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dining style', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _RadioTile(
                  title: 'Budget-friendly',
                  subtitle: 'Chicken/pasta style picks',
                  value: DiningStyle.budget,
                  group: style,
                  onChanged: onStyleChanged,
                  icon: Icons.savings_rounded,
                ),
                _RadioTile(
                  title: 'Average',
                  subtitle: 'A little of everything',
                  value: DiningStyle.average,
                  group: style,
                  onChanged: onStyleChanged,
                  icon: Icons.balance_rounded,
                ),
                _RadioTile(
                  title: 'Splurge',
                  subtitle: 'Steak/seafood and upgrades',
                  value: DiningStyle.splurge,
                  group: style,
                  onChanged: onStyleChanged,
                  icon: Icons.auto_awesome_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step3Restaurants extends StatelessWidget {
  final List<_MealDraft> drafts;
  final VoidCallback onChanged;
  const _Step3Restaurants({super.key, required this.drafts, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final byDay = <String, List<_MealDraft>>{};
    for (final d in drafts) {
      final k = '${d.day.year}-${d.day.month}-${d.day.day}';
      byDay.putIfAbsent(k, () => <_MealDraft>[]).add(d);
    }

    final days = byDay.values.toList();
    days.sort((a, b) => a.first.day.compareTo(b.first.day));

    return ListView.builder(
      itemCount: days.length,
      itemBuilder: (context, index) {
        final items = days[index];
        final day = items.first.day;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _DayMealCard(day: day, drafts: items, onChanged: onChanged),
        );
      },
    );
  }
}

class _Step4Recommendation extends StatelessWidget {
  final _CostBreakdown costs;
  final DiningRecommendation recommendation;
  final DiningRecommendation selected;
  final ValueChanged<DiningRecommendation> onSelectedChanged;

  const _Step4Recommendation({super.key, required this.costs, required this.recommendation, required this.selected, required this.onSelectedChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final headline = switch (recommendation) {
      DiningRecommendation.outOfPocket => 'Pay out of pocket',
      DiningRecommendation.quickService => 'Get the Quick-Service Dining Plan',
      DiningRecommendation.standard => 'Get the Disney Dining Plan',
    };

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(16)),
                      child: Icon(Icons.verified_rounded, color: cs.onPrimaryContainer),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Recommendation', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                  ],
                ),
                const SizedBox(height: 10),
                Text(headline, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('Based on your inputs, this is the lowest estimated total cost.', style: text.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.25)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _OptionPicker(costs: costs, selected: selected, recommendation: recommendation, onChanged: onSelectedChanged),
          const SizedBox(height: AppSpacing.md),
          if (costs.notes.isNotEmpty)
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assumptions used', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ...costs.notes.map((n) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: cs.onSurface.withValues(alpha: 0.60)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(n, style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.80), height: 1.25))),
                          ],
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Step5OtherOptions extends StatelessWidget {
  final _CostBreakdown costs;
  final DiningRecommendation recommendation;
  final DiningRecommendation selected;
  final ValueChanged<DiningRecommendation> onSelectedChanged;

  const _Step5OtherOptions({super.key, required this.costs, required this.recommendation, required this.selected, required this.onSelectedChanged});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Compare all options', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _OptionPicker(costs: costs, selected: selected, recommendation: recommendation, onChanged: onSelectedChanged),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next: you can still edit anything', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Use Back to tweak your inputs, or Save to start tracking/logging for this trip.', style: text.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.25)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step6ReviewConfirm extends StatelessWidget {
  final int adults;
  final int children;
  final DateTime startDate;
  final DateTime endDate;
  final int nights;
  final bool annualPassholder;
  final bool dvcMember;
  final BeveragePreference beverage;
  final int snacksPerPersonPerDay;
  final bool dessertAtTS;
  final bool mugs;
  final DiningStyle style;
  final DiningRecommendation selected;
  final _CostBreakdown costs;
  final int plannedMealsCount;
  final ValueChanged<int> onJumpToStep;

  const _Step6ReviewConfirm({
    super.key,
    required this.adults,
    required this.children,
    required this.startDate,
    required this.endDate,
    required this.nights,
    required this.annualPassholder,
    required this.dvcMember,
    required this.beverage,
    required this.snacksPerPersonPerDay,
    required this.dessertAtTS,
    required this.mugs,
    required this.style,
    required this.selected,
    required this.costs,
    required this.plannedMealsCount,
    required this.onJumpToStep,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review & confirm', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trip snapshot', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _SummaryTile(
                  title: 'Vacation plans',
                  subtitle: '${adults.clamp(0, 100)} adults • ${children.clamp(0, 100)} children\n${_shortDate(startDate)} → ${_shortDate(endDate)} (${nights.clamp(1, 365)} nights)',
                  icon: Icons.calendar_month_rounded,
                  trailingLabel: 'Edit',
                  onTap: () => onJumpToStep(0),
                ),
                const SizedBox(height: 10),
                _SummaryTile(
                  title: 'Discounts',
                  subtitle: _discountText(annualPassholder: annualPassholder, dvcMember: dvcMember),
                  icon: Icons.local_offer_rounded,
                  trailingLabel: 'Edit',
                  onTap: () => onJumpToStep(0),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dining preferences', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _SummaryTile(
                  title: 'Beverages & extras',
                  subtitle: '${_beverageText(beverage)}\nSnacks: ${snacksPerPersonPerDay.clamp(0, 10)}/person/day • Dessert at TS: ${dessertAtTS ? 'Yes' : 'No'} • Mugs: ${mugs ? 'Yes' : 'No'}',
                  icon: Icons.local_cafe_rounded,
                  trailingLabel: 'Edit',
                  onTap: () => onJumpToStep(1),
                ),
                const SizedBox(height: 10),
                _SummaryTile(
                  title: 'Dining style',
                  subtitle: _styleText(style),
                  icon: Icons.auto_graph_rounded,
                  trailingLabel: 'Edit',
                  onTap: () => onJumpToStep(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Planned restaurants', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _SummaryTile(
                  title: 'Meals added',
                  subtitle: plannedMealsCount == 0 ? 'None yet (optional)' : '$plannedMealsCount meal(s) added',
                  icon: Icons.restaurant_menu_rounded,
                  trailingLabel: 'Edit',
                  onTap: () => onJumpToStep(2),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your choice', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _SummaryTile(
                  title: _optionTitle(selected),
                  subtitle: 'Estimated cost: ${_money(_optionCost(selected, costs))}\nTap to change your selection.',
                  icon: Icons.check_circle_outline_rounded,
                  trailingLabel: 'Change',
                  onTap: () => onJumpToStep(4),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.50), borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: cs.primary.withValues(alpha: 0.16))),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: cs.onPrimaryContainer.withValues(alpha: 0.85)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nothing is “official” — these are calculator assumptions until you provide your own prices.',
                          style: text.bodySmall?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.90), height: 1.25),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _shortDate(DateTime d) => '${d.month}/${d.day}/${d.year}';

  static String _money(double v) => '\$${v.toStringAsFixed(2)}';

  static String _discountText({required bool annualPassholder, required bool dvcMember}) {
    if (!annualPassholder && !dvcMember) return 'None selected';
    final bits = <String>[];
    if (annualPassholder) bits.add('Annual Passholder');
    if (dvcMember) bits.add('DVC Member');
    return bits.join(' • ');
  }

  static String _beverageText(BeveragePreference pref) => switch (pref) {
    BeveragePreference.waterOnly => 'Water only',
    BeveragePreference.fountainOrNonAlcoholic => 'Fountain/non-alcoholic drinks',
    BeveragePreference.includesAlcohol => 'Includes alcohol (where allowed)',
  };

  static String _styleText(DiningStyle style) => switch (style) {
    DiningStyle.budget => 'Budget (value-focused)',
    DiningStyle.average => 'Average',
    DiningStyle.splurge => 'Splurge (higher spend)',
  };

  static String _optionTitle(DiningRecommendation v) => switch (v) {
    DiningRecommendation.outOfPocket => 'Pay cash (no plan)',
    DiningRecommendation.quickService => 'Quick-Service Dining Plan',
    DiningRecommendation.standard => 'Disney Dining Plan',
  };

  static double _optionCost(DiningRecommendation v, _CostBreakdown costs) => switch (v) {
    DiningRecommendation.outOfPocket => costs.outOfPocket,
    DiningRecommendation.quickService => costs.quickServicePlan,
    DiningRecommendation.standard => costs.standardPlan,
  };
}

class _SummaryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String trailingLabel;
  final VoidCallback onTap;

  const _SummaryTile({required this.title, required this.subtitle, required this.icon, required this.trailingLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: cs.surface.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: cs.outline.withValues(alpha: 0.10))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: cs.appCardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: cs.outline.withValues(alpha: 0.12))),
              child: Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.80)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.80), height: 1.30)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(99), border: Border.all(color: cs.primary.withValues(alpha: 0.16))),
              child: Text(trailingLabel, style: text.labelMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionPicker extends StatelessWidget {
  final _CostBreakdown costs;
  final DiningRecommendation selected;
  final DiningRecommendation recommendation;
  final ValueChanged<DiningRecommendation> onChanged;

  const _OptionPicker({required this.costs, required this.selected, required this.recommendation, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose what you want to do', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _OptionRow(
            title: 'Pay cash (no plan)',
            subtitle: _money(costs.outOfPocket),
            value: DiningRecommendation.outOfPocket,
            group: selected,
            recommended: recommendation == DiningRecommendation.outOfPocket,
            onChanged: onChanged,
            icon: Icons.payments_rounded,
          ),
          const SizedBox(height: 10),
          _OptionRow(
            title: 'Quick-Service Dining Plan',
            subtitle: _money(costs.quickServicePlan),
            value: DiningRecommendation.quickService,
            group: selected,
            recommended: recommendation == DiningRecommendation.quickService,
            onChanged: onChanged,
            icon: Icons.fastfood_rounded,
          ),
          const SizedBox(height: 10),
          _OptionRow(
            title: 'Disney Dining Plan',
            subtitle: _money(costs.standardPlan),
            value: DiningRecommendation.standard,
            group: selected,
            recommended: recommendation == DiningRecommendation.standard,
            onChanged: onChanged,
            icon: Icons.restaurant_rounded,
          ),
        ],
      ),
    );
  }

  String _money(double v) => '\$${v.toStringAsFixed(2)}';
}

class _OptionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final DiningRecommendation value;
  final DiningRecommendation group;
  final bool recommended;
  final ValueChanged<DiningRecommendation> onChanged;
  final IconData icon;

  const _OptionRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.group,
    required this.recommended,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final selected = group == value;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer.withValues(alpha: 0.65) : cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: selected ? cs.primary.withValues(alpha: 0.22) : cs.outline.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outline.withValues(alpha: 0.10))),
              child: Icon(icon, color: cs.onSurface.withValues(alpha: 0.85)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                      if (recommended)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(999)),
                          child: Text('Recommended', style: text.labelSmall?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? cs.primary : cs.outline.withValues(alpha: 0.60)),
          ],
        ),
      ),
    );
  }
}

class _DayMealCard extends StatelessWidget {
  final DateTime day;
  final List<_MealDraft> drafts;
  final VoidCallback onChanged;
  const _DayMealCard({required this.day, required this.drafts, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final formatted = '${_month(day.month)} ${day.day}, ${day.year}';
    final sorted = drafts.toList()..sort((a, b) => a.slot.index.compareTo(b.slot.index));
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.75)),
              const SizedBox(width: 10),
              Text(formatted, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          for (final d in sorted) ...[
            _MealRow(draft: d, onChanged: onChanged),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  String _month(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
}

class _MealRow extends StatelessWidget {
  final _MealDraft draft;
  final VoidCallback onChanged;
  const _MealRow({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(draft.slot.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.80)))),
            const SizedBox(width: 10),
            DropdownButton<UsageType>(
              value: draft.type,
              items: const [
                DropdownMenuItem(value: UsageType.quickService, child: Text('QS')),
                DropdownMenuItem(value: UsageType.tableService, child: Text('TS')),
              ],
              onChanged: (v) {
                if (v == null) return;
                draft.type = v;
                onChanged();
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: draft.restaurant,
          decoration: const InputDecoration(hintText: 'Restaurant (optional)', prefixIcon: Icon(Icons.storefront_rounded)),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateTile({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final formatted = '${_weekday(date.weekday)}, ${_month(date.month)} ${date.day}, ${date.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: cs.outline.withValues(alpha: 0.12))),
        child: Row(
          children: [
            Icon(Icons.edit_calendar_rounded, color: cs.onSurface.withValues(alpha: 0.75)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: text.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.75)))),
            Text(formatted, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  String _weekday(int w) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
  String _month(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
}

class _RadioTile<T> extends StatelessWidget {
  final String title;
  final String subtitle;
  final T value;
  final T group;
  final ValueChanged<T> onChanged;
  final IconData icon;

  const _RadioTile({required this.title, required this.subtitle, required this.value, required this.group, required this.onChanged, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final selected = value == group;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer.withValues(alpha: 0.55) : cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: selected ? cs.primary.withValues(alpha: 0.22) : cs.outline.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outline.withValues(alpha: 0.10))),
              child: Icon(icon, color: cs.onSurface.withValues(alpha: 0.85)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.2)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? cs.primary : cs.outline.withValues(alpha: 0.60)),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.appCardBackgroundStrong, borderRadius: BorderRadius.circular(AppRadius.xl), border: Border.all(color: cs.outline.withValues(alpha: 0.12))),
      child: child,
    );
  }
}

class _MealDraft {
  final DateTime day;
  final MealSlot slot;
  final TextEditingController restaurant;
  UsageType type;

  _MealDraft({required this.day, required this.slot, required this.type, required this.restaurant});
}

class _CostBreakdown {
  final double outOfPocket;
  final double quickServicePlan;
  final double standardPlan;
  final List<String> notes;

  const _CostBreakdown({required this.outOfPocket, required this.quickServicePlan, required this.standardPlan, required this.notes});
  const _CostBreakdown.zero() : outOfPocket = 0, quickServicePlan = 0, standardPlan = 0, notes = const <String>[];
}

class _OopEstimate {
  final double total;
  final List<String> notes;
  const _OopEstimate({required this.total, required this.notes});
}
