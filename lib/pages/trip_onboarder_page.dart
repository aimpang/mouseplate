import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mouseplate/data/wdw_restaurant_catalog.dart';
import 'package:mouseplate/controllers/app_controller.dart';
import 'package:mouseplate/models/party_member.dart';
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

  // Step 0
  late final TextEditingController _adults;
  late final TextEditingController _children;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 4));
  bool _annualPassholder = false;
  bool _dvcMember = false;

  // Step 1: per-person party drafts
  late List<_PartyDraft> _partyDrafts;
  bool _mugs = false;

  // Step 2: park selection
  late List<WdwPark> _preferredParks;

  // Step 3: signature dining drafts
  late List<_SignatureDraft> _signatureDrafts;

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

    _mugs = existing?.resortRefillableMugs ?? false;

    _preferredParks = existing?.preferredParks.isNotEmpty == true
        ? List<WdwPark>.from(existing!.preferredParks)
        : WdwPark.values.toList();

    _recommendation = existing?.recommendation ?? DiningRecommendation.quickService;
    _selectedOption = existing?.usesDiningPlan == false ? DiningRecommendation.outOfPocket : _recommendation;

    _partyDrafts = _buildPartyDrafts(existing);
    _signatureDrafts = _buildSignatureDrafts(existing);
    _recompute();
  }

  @override
  void dispose() {
    _adults.dispose();
    _children.dispose();
    super.dispose();
  }

  List<_SignatureDraft> _buildSignatureDrafts(Trip? existing) {
    final options = WdwRestaurantCatalog.signatureDining(_preferredParks);
    final existingMeals = existing?.plannedMeals ?? const <PlannedMeal>[];
    return options.map((opt) {
      final m = existingMeals.where((m) => m.restaurant == opt.name && m.credits == 2).firstOrNull;
      return _SignatureDraft(restaurant: opt, selected: m != null, day: m?.day);
    }).toList();
  }

  List<_PartyDraft> _buildPartyDrafts(Trip? existing) {
    final adults = _intOrZero(_adults.text).clamp(0, 100);
    final children = _intOrZero(_children.text).clamp(0, 100);
    final existingMembers = existing?.partyMembers ?? const <PartyMember>[];
    final existingAdults = existingMembers.where((m) => m.isAdult).toList();
    final existingChildren = existingMembers.where((m) => !m.isAdult).toList();

    final drafts = <_PartyDraft>[];
    for (var i = 0; i < adults; i++) {
      final m = i < existingAdults.length ? existingAdults[i] : null;
      drafts.add(_PartyDraft(
        isAdult: true,
        name: m?.name ?? 'Adult ${i + 1}',
        eatingStyle: m?.eatingStyle ?? EatingStyle.moderate,
        snacksPerDay: m?.snacksPerDay ?? 1,
        dessertAtTableService: m?.dessertAtTableService ?? false,
        enjoysAlcohol: m?.enjoysAlcohol ?? false,
      ));
    }
    for (var i = 0; i < children; i++) {
      final m = i < existingChildren.length ? existingChildren[i] : null;
      drafts.add(_PartyDraft(
        isAdult: false,
        name: m?.name ?? 'Child ${i + 1}',
        eatingStyle: m?.eatingStyle ?? EatingStyle.moderate,
        snacksPerDay: m?.snacksPerDay ?? 1,
        dessertAtTableService: m?.dessertAtTableService ?? false,
        enjoysAlcohol: false,
      ));
    }
    return drafts;
  }

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


  void _recompute() {
    final adults = _intOrZero(_adults.text).clamp(0, 100);
    final children = _intOrZero(_children.text).clamp(0, 100);

    // Use the existing Trip assumptions for now (user can later tune on Dashboard).
    // These are not "official"; they're calculators inputs.
    const assumedQS = 23.00;
    const assumedTS = 60.00;

    final outOfPocket = _estimateOutOfPocket(
      adults: adults,
      children: children,
      assumedQS: assumedQS,
      assumedTS: assumedTS,
      mugs: _mugs,
      applyDiscount: _annualPassholder || _dvcMember,
    );

    final qsPlan = _estimatePlanCostWithBreakdown(PlanType.quickService, adults: adults, children: children, nights: _nights);
    final stdPlan = _estimatePlanCostWithBreakdown(PlanType.standard, adults: adults, children: children, nights: _nights);

    final rec = _minRecommendation(outOfPocket: outOfPocket.total, qsPlan: qsPlan.total, standardPlan: stdPlan.total);
    setState(() {
      _costs = _CostBreakdown(outOfPocket: outOfPocket, quickServicePlan: qsPlan, standardPlan: stdPlan);
      _recommendation = rec;
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


  _CostEstimate _estimateOutOfPocket({
    required int adults,
    required int children,
    required double assumedQS,
    required double assumedTS,
    required bool mugs,
    required bool applyDiscount,
  }) {
    const assumedChildQS = 12.00;
    const assumedChildTS = 28.00;
    const assumedSnack = 9.00;
    const alcoholPremium = 6.00;

    final party = (adults + children).clamp(0, 100);
    final items = <_LineItem>[];
    double mealTotal = 0.0;
    double snackTotal = 0.0;

    if (_partyDrafts.isEmpty) {
      // Fallback for zero-party edge case.
      for (final d in _signatureDrafts) {
        if (!d.selected) continue;
        mealTotal += d.restaurant.avgPerAdult * party;
      }
      mealTotal += 2 * _nights * assumedQS * party;
      snackTotal += _nights * assumedSnack * party;
    } else {
      // Signature Dining (TS, per person)
      for (final sig in _signatureDrafts) {
        if (!sig.selected) continue;
        for (final m in _partyDrafts) {
          final base = m.isAdult ? sig.restaurant.avgPerAdult : assumedChildTS;
          mealTotal += base * m.eatingStyle.multiplier;
          if (m.dessertAtTableService) mealTotal += 6.00;
          if (m.isAdult && m.enjoysAlcohol) mealTotal += alcoholPremium;
        }
      }

      // Regular QS meals: 2 per person per day
      for (final m in _partyDrafts) {
        final baseQS = m.isAdult ? assumedQS : assumedChildQS;
        mealTotal += 2 * _nights * (baseQS * m.eatingStyle.multiplier + (m.isAdult && m.enjoysAlcohol ? alcoholPremium : 0.0));
        snackTotal += m.snacksPerDay * _nights * assumedSnack;
      }
    }

    if (mealTotal > 0) {
      items.add(_LineItem(label: 'Meals & Beverages', amount: mealTotal));
    }
    if (snackTotal > 0) {
      items.add(_LineItem(label: 'Snacks (\$9 each)', amount: snackTotal));
    }

    final mugTotal = mugs ? party * 22.0 : 0.0;
    if (mugTotal > 0) {
      items.add(_LineItem(label: 'Refillable Mugs (\$22 per person)', amount: mugTotal));
    }

    final discountRate = applyDiscount ? 0.10 : 0.0;
    final discountAmount = mealTotal * discountRate;
    final discountedMeals = mealTotal * (1.0 - discountRate);

    if (discountAmount > 0) {
      items.add(_LineItem(label: 'AP/DVC Dining Discount (-10%)', amount: -discountAmount));
    }

    final total = discountedMeals + snackTotal + mugTotal;
    final notes = <String>[
      if (applyDiscount) 'Includes an estimated 10% dining discount (AP/DVC).',
      'Snacks assumed at \$9 each.',
      if (mugs) 'Mugs assumed at \$22 per person.',
    ];
    return _CostEstimate(total: total, items: items, notes: notes);
  }

  _CostEstimate _estimatePlanCostWithBreakdown(PlanType type, {required int adults, required int children, required int nights}) {
    final perAdultNight = switch (type) {
      PlanType.quickService => 60.47,
      PlanType.standard => 98.59,
    };
    final perChildNight = switch (type) {
      PlanType.quickService => 47.17,
      PlanType.standard => 76.89,
    };
    final adultCost = perAdultNight * adults * nights;
    final childCost = perChildNight * children * nights;
    final total = adultCost + childCost;
    final planName = switch (type) {
      PlanType.quickService => 'Quick-Service Plan',
      PlanType.standard => 'Disney Dining Plan',
    };
    final items = <_LineItem>[
      if (adultCost > 0) _LineItem(label: '$planName (\$$perAdultNight per adult/night)', amount: adultCost),
      if (childCost > 0) _LineItem(label: '$planName — children (\$$perChildNight/night)', amount: childCost),
    ];
    return _CostEstimate(total: total, items: items, notes: const <String>[]);
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

    final members = _partyDrafts.asMap().entries.map((e) {
      final i = e.key;
      final d = e.value;
      final defaultName = d.isAdult ? 'Adult ${i + 1}' : 'Child ${i + 1}';
      return PartyMember(
        id: 'member_$i',
        name: d.name.trim().isEmpty ? defaultName : d.name.trim(),
        isAdult: d.isAdult,
        eatingStyle: d.eatingStyle,
        snacksPerDay: d.snacksPerDay,
        dessertAtTableService: d.dessertAtTableService,
        enjoysAlcohol: d.enjoysAlcohol,
      );
    }).toList();

    final usesDiningPlan = _selectedOption != DiningRecommendation.outOfPocket;
    final planType = switch (_selectedOption) {
      DiningRecommendation.quickService => PlanType.quickService,
      DiningRecommendation.standard => PlanType.standard,
      DiningRecommendation.outOfPocket => PlanType.quickService,
    };

    // Signature dining costs 2 TS credits. Only add as planned meals when the
    // selected plan includes Table-Service credits; QS-plan and cash users pay
    // out of pocket and have no TS credit counter to track against.
    final mealsIncludeTS = usesDiningPlan && planType == PlanType.standard;
    final meals = <PlannedMeal>[];
    if (mealsIncludeTS) {
      for (final d in _signatureDrafts) {
        if (!d.selected) continue;
        final day = d.day ?? DateTime(_startDate.year, _startDate.month, _startDate.day);
        meals.add(
          PlannedMeal(
            id: '${day.microsecondsSinceEpoch}-${d.restaurant.name.hashCode}',
            day: day,
            slot: MealSlot.dinner,
            type: UsageType.tableService,
            restaurant: d.restaurant.name,
            estimatedValue: d.restaurant.avgPerAdult,
            credits: 2,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }

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
      beveragePreference: controller.trip?.beveragePreference ?? BeveragePreference.fountainOrNonAlcoholic,
      snacksPerPersonPerDay: controller.trip?.snacksPerPersonPerDay ?? 0,
      dessertAtTableService: controller.trip?.dessertAtTableService ?? false,
      resortRefillableMugs: _mugs,
      diningStyle: controller.trip?.diningStyle ?? DiningStyle.average,
      preferredParks: _preferredParks,
      recommendation: _recommendation,
      plannedMeals: meals,
      partyMembers: members,
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
    if (_step == 0) {
      // Party size may have changed. Rebuild drafts, preserving customizations by position.
      final currentAdults = _intOrZero(_adults.text);
      final currentChildren = _intOrZero(_children.text);
      final existingAdults = _partyDrafts.where((d) => d.isAdult).length;
      final existingChildren = _partyDrafts.where((d) => !d.isAdult).length;

      // Only rebuild if count changed. Convert current drafts to a minimal Trip-like
      // structure for _buildPartyDrafts to preserve customizations.
      if (currentAdults != existingAdults || currentChildren != existingChildren) {
        final members = _partyDrafts.asMap().entries.map((e) {
          return PartyMember(
            id: 'party-${e.key}',
            name: e.value.name,
            isAdult: e.value.isAdult,
            eatingStyle: e.value.eatingStyle,
            snacksPerDay: e.value.snacksPerDay,
            dessertAtTableService: e.value.dessertAtTableService,
            enjoysAlcohol: e.value.enjoysAlcohol,
          );
        }).toList();
        // Create a minimal Trip with just the party data for _buildPartyDrafts.
        final tempTrip = Trip(
          id: 'temp',
          planType: PlanType.quickService,
          adults: currentAdults,
          children: currentChildren,
          nights: 1,
          startDate: DateTime.now(),
          partyMembers: members,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        setState(() => _partyDrafts = _buildPartyDrafts(tempTrip));
      }
    }
    if (_step == 2) {
      // Parks confirmed — signature drafts are already filtered by park selection in the UI.
      // No need to rebuild here; they're managed via onDraftChanged callbacks.
    }
    setState(() => _step++);
    if (_step >= 4) _recompute();
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
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _step > 0 ? _back : _cancel,
          tooltip: 'Back',
        ),
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
                    1 => _Step1Party(
                        key: const ValueKey('s1p'),
                        partyDrafts: _partyDrafts,
                        mugs: _mugs,
                        onDraftChanged: (_) => _recompute(),
                        onMugsChanged: (v) {
                          setState(() => _mugs = v);
                          _recompute();
                        },
                      ),
                    2 => _Step2Parks(
                        key: const ValueKey('s2p'),
                        selected: _preferredParks,
                        onChanged: (v) => setState(() => _preferredParks = v),
                      ),
                    3 => _Step3Signatures(
                        key: const ValueKey('s3'),
                        drafts: _signatureDrafts,
                        tripDays: _tripDays(),
                        onDraftChanged: (_) => setState(() {}),
                      ),
                    4 => _Step4Recommendation(
                        key: const ValueKey('s4'),
                        costs: _costs,
                        recommendation: _recommendation,
                        selected: _selectedOption,
                        onSelectedChanged: (v) => setState(() => _selectedOption = v),
                      ),
                    _ => _Step6ReviewConfirm(
                        key: const ValueKey('s5'),
                        adults: _intOrZero(_adults.text),
                        children: _intOrZero(_children.text),
                        startDate: _startDate,
                        endDate: _endDate,
                        nights: _nights,
                        annualPassholder: _annualPassholder,
                        dvcMember: _dvcMember,
                        mugs: _mugs,
                        selected: _selectedOption,
                        costs: _costs,
                        preferredParks: _preferredParks,
                        signatureDrafts: _signatureDrafts,
                        partyDrafts: _partyDrafts,
                        onJumpToStep: (s) => setState(() => _step = s.clamp(0, 5)),
                      ),
                  },
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: MediaQuery.of(context).viewInsets.bottom > 0
                    ? const SizedBox.shrink()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _step > 0 ? _back : _cancel,
                                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl))),
                                  child: const Text('Back'),
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
      '2. Meet your party',
      '3. Parks you\'re visiting',
      '4. Signature Dining plans',
      '5. Choose your dining option',
      '6. Review & confirm',
    ];
    final subtitle = switch (step) {
      0 => 'Party, dates, and discounts.',
      1 => 'Tell us how each person dines.',
      2 => 'We\'ll show only restaurants in your parks.',
      3 => '2-credit restaurants that affect your estimate most.',
      4 => 'Pick the option that works best for your family.',
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
                Text('If you\'re an Annual Passholder or DVC Member, we\'ll apply an estimated dining discount.', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.25)),
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

class _Step1Party extends StatelessWidget {
  final List<_PartyDraft> partyDrafts;
  final bool mugs;
  final ValueChanged<_PartyDraft> onDraftChanged;
  final ValueChanged<bool> onMugsChanged;

  const _Step1Party({
    super.key,
    required this.partyDrafts,
    required this.mugs,
    required this.onDraftChanged,
    required this.onMugsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (partyDrafts.isEmpty)
            _Card(
              child: Text(
                'No party members yet — go back and enter your party size.',
                style: text.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.75)),
              ),
            ),
          ...partyDrafts.map((d) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _PartyMemberCard(draft: d, onChanged: () => onDraftChanged(d)),
          )),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Buy resort refillable mugs'),
                  value: mugs,
                  onChanged: onMugsChanged,
                ),
                Text('Estimate uses \$22 per person.', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.72))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyMemberCard extends StatefulWidget {
  final _PartyDraft draft;
  final VoidCallback onChanged;

  const _PartyMemberCard({required this.draft, required this.onChanged});

  @override
  State<_PartyMemberCard> createState() => _PartyMemberCardState();
}

class _PartyMemberCardState extends State<_PartyMemberCard> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.draft.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final d = widget.draft;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: d.isAdult ? cs.primaryContainer : cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Icon(
                  d.isAdult ? Icons.person_rounded : Icons.child_care_rounded,
                  size: 18,
                  color: d.isAdult ? cs.onPrimaryContainer : cs.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                d.isAdult ? 'Adult (10+)' : 'Child (3–9)',
                style: text.labelMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.65), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name (optional)', prefixIcon: Icon(Icons.badge_rounded)),
            onChanged: (v) {
              d.name = v;
              widget.onChanged();
            },
          ),
          const SizedBox(height: 14),
          Text('Eating style', style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: EatingStyle.values.map((style) => ChoiceChip(
              label: Text(style.label),
              selected: d.eatingStyle == style,
              onSelected: (val) {
                if (val) {
                  setState(() => d.eatingStyle = style);
                  widget.onChanged();
                }
              },
            )).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('Snacks per day', style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded),
                onPressed: d.snacksPerDay > 0
                    ? () {
                        setState(() => d.snacksPerDay--);
                        widget.onChanged();
                      }
                    : null,
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '${d.snacksPerDay}',
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: d.snacksPerDay < 10
                    ? () {
                        setState(() => d.snacksPerDay++);
                        widget.onChanged();
                      }
                    : null,
              ),
            ],
          ),
          CheckboxListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Orders dessert at Table-Service meals'),
            value: d.dessertAtTableService,
            onChanged: (v) {
              setState(() => d.dessertAtTableService = v ?? false);
              widget.onChanged();
            },
          ),
          if (d.isAdult)
            CheckboxListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enjoys alcoholic beverages'),
              value: d.enjoysAlcohol,
              onChanged: (v) {
                setState(() => d.enjoysAlcohol = v ?? false);
                widget.onChanged();
              },
            ),
        ],
      ),
    );
  }
}

class _Step2Parks extends StatelessWidget {
  final List<WdwPark> selected;
  final ValueChanged<List<WdwPark>> onChanged;
  const _Step2Parks({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Which parks are you visiting?', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('We\'ll show only Signature Dining (2-credit) restaurants in your chosen parks.', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.25)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WdwPark.values.map((park) {
                final isSelected = selected.contains(park);
                return FilterChip(
                  label: Text(park.label),
                  selected: isSelected,
                  onSelected: (val) {
                    final next = List<WdwPark>.from(selected);
                    if (val) {
                      if (!next.contains(park)) next.add(park);
                    } else {
                      if (next.length > 1) next.remove(park);
                    }
                    onChanged(next);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Text('At least one park must be selected.', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.55))),
          ],
        ),
      ),
    );
  }
}

class _Step3Signatures extends StatelessWidget {
  final List<_SignatureDraft> drafts;
  final List<DateTime> tripDays;
  final ValueChanged<_SignatureDraft> onDraftChanged;
  const _Step3Signatures({super.key, required this.drafts, required this.tripDays, required this.onDraftChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (drafts.isEmpty) {
      return SingleChildScrollView(
        child: _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No Signature Dining in selected parks', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('None of the 2-credit Signature Dining restaurants are in your selected parks. Go back to add more parks, or continue to skip this step.', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.25)),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Signature Dining plans', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('2-credit restaurants — these cost more and affect your worth-it estimate most. Select the ones you plan to visit.', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), height: 1.25)),
                const SizedBox(height: 14),
                ...drafts.map((d) => _SignatureRow(draft: d, tripDays: tripDays, onChanged: () => onDraftChanged(d))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignatureRow extends StatelessWidget {
  final _SignatureDraft draft;
  final List<DateTime> tripDays;
  final VoidCallback onChanged;
  const _SignatureRow({required this.draft, required this.tripDays, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final d = draft;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: d.selected ? cs.primaryContainer.withValues(alpha: 0.40) : cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: d.selected ? cs.primary.withValues(alpha: 0.22) : cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.restaurant.name, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(99)),
                          child: Text(d.restaurant.park!.label, style: text.labelSmall?.copyWith(color: cs.onSecondaryContainer, fontWeight: FontWeight.w600)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(99)),
                          child: Text('2 credits', style: text.labelSmall?.copyWith(color: cs.onTertiaryContainer, fontWeight: FontWeight.w600)),
                        ),
                        Text('~\$${d.restaurant.avgPerAdult.toStringAsFixed(0)}/adult', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.65))),
                      ],
                    ),
                  ],
                ),
              ),
              Checkbox.adaptive(
                value: d.selected,
                onChanged: (val) {
                  d.selected = val ?? false;
                  onChanged();
                },
              ),
            ],
          ),
          if (d.selected && tripDays.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 15, color: cs.onSurface.withValues(alpha: 0.65)),
                const SizedBox(width: 6),
                Text('Which day?', style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.75))),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<DateTime?>(
                    value: tripDays.where((td) => d.day != null && td.year == d.day!.year && td.month == d.day!.month && td.day == d.day!.day).firstOrNull,
                    isExpanded: true,
                    hint: Text('Not sure', style: text.bodySmall),
                    items: [
                      DropdownMenuItem<DateTime?>(value: null, child: Text('Not sure', style: text.bodySmall)),
                      ...tripDays.map((td) => DropdownMenuItem<DateTime?>(
                        value: td,
                        child: Text(_shortDate(td), style: text.bodySmall),
                      )),
                    ],
                    onChanged: (val) {
                      d.day = val;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _shortDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
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
          if (costs.outOfPocket.notes.isNotEmpty)
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assumptions used', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ...costs.outOfPocket.notes.map((n) => Padding(
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

class _Step6ReviewConfirm extends StatelessWidget {
  final int adults;
  final int children;
  final DateTime startDate;
  final DateTime endDate;
  final int nights;
  final bool annualPassholder;
  final bool dvcMember;
  final bool mugs;
  final DiningRecommendation selected;
  final _CostBreakdown costs;
  final List<WdwPark> preferredParks;
  final List<_SignatureDraft> signatureDrafts;
  final List<_PartyDraft> partyDrafts;
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
    required this.mugs,
    required this.selected,
    required this.costs,
    required this.preferredParks,
    required this.signatureDrafts,
    required this.partyDrafts,
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
                Text('Your party', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (partyDrafts.isEmpty)
                  _SummaryTile(
                    title: 'Party members',
                    subtitle: 'No profiles set',
                    icon: Icons.people_rounded,
                    trailingLabel: 'Edit',
                    onTap: () => onJumpToStep(1),
                  )
                else
                  _SummaryTile(
                    title: 'Party members',
                    subtitle: partyDrafts.map((d) => '${d.name.trim().isEmpty ? (d.isAdult ? 'Adult' : 'Child') : d.name} (${d.eatingStyle.label})').join('\n'),
                    icon: Icons.people_rounded,
                    trailingLabel: 'Edit',
                    onTap: () => onJumpToStep(1),
                  ),
                if (mugs) ...[
                  const SizedBox(height: 10),
                  _SummaryTile(
                    title: 'Resort refillable mugs',
                    subtitle: 'Included in estimate (\$22/person)',
                    icon: Icons.local_cafe_rounded,
                    trailingLabel: 'Edit',
                    onTap: () => onJumpToStep(1),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Parks & Signature Dining', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _SummaryTile(
                  title: 'Parks visiting',
                  subtitle: preferredParks.map((p) => p.label).join(' • '),
                  icon: Icons.castle_rounded,
                  trailingLabel: 'Edit',
                  onTap: () => onJumpToStep(2),
                ),
                if (signatureDrafts.any((d) => d.selected)) ...[
                  const SizedBox(height: 10),
                  _SummaryTile(
                    title: 'Signature Dining',
                    subtitle: signatureDrafts.where((d) => d.selected).map((d) => d.restaurant.name).join('\n'),
                    icon: Icons.star_rounded,
                    trailingLabel: 'Edit',
                    onTap: () => onJumpToStep(3),
                  ),
                ],
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
                          'Nothing is "official" — these are calculator assumptions until you provide your own prices.',
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

  static String _optionTitle(DiningRecommendation v) => switch (v) {
    DiningRecommendation.outOfPocket => 'Pay cash (no plan)',
    DiningRecommendation.quickService => 'Quick-Service Dining Plan',
    DiningRecommendation.standard => 'Disney Dining Plan',
  };

  static double _optionCost(DiningRecommendation v, _CostBreakdown costs) => switch (v) {
    DiningRecommendation.outOfPocket => costs.outOfPocket.total,
    DiningRecommendation.quickService => costs.quickServicePlan.total,
    DiningRecommendation.standard => costs.standardPlan.total,
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

  _CostEstimate _estimateForOption(DiningRecommendation opt) => switch (opt) {
    DiningRecommendation.outOfPocket => costs.outOfPocket,
    DiningRecommendation.quickService => costs.quickServicePlan,
    DiningRecommendation.standard => costs.standardPlan,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final selectedEstimate = _estimateForOption(selected);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose what you want to do', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _OptionRow(
            title: 'Pay cash (no plan)',
            subtitle: _money(costs.outOfPocket.total),
            value: DiningRecommendation.outOfPocket,
            group: selected,
            recommended: recommendation == DiningRecommendation.outOfPocket,
            onChanged: onChanged,
            icon: Icons.payments_rounded,
          ),
          const SizedBox(height: 10),
          _OptionRow(
            title: 'Quick-Service Dining Plan',
            subtitle: _money(costs.quickServicePlan.total),
            value: DiningRecommendation.quickService,
            group: selected,
            recommended: recommendation == DiningRecommendation.quickService,
            onChanged: onChanged,
            icon: Icons.fastfood_rounded,
          ),
          const SizedBox(height: 10),
          _OptionRow(
            title: 'Disney Dining Plan',
            subtitle: _money(costs.standardPlan.total),
            value: DiningRecommendation.standard,
            group: selected,
            recommended: recommendation == DiningRecommendation.standard,
            onChanged: onChanged,
            icon: Icons.restaurant_rounded,
          ),
          if (selectedEstimate.items.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: cs.outline.withValues(alpha: 0.12), height: 1),
            const SizedBox(height: 12),
            Text('Receipt', style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface.withValues(alpha: 0.80))),
            const SizedBox(height: 8),
            ...selectedEstimate.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(item.label, style: text.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.85)))),
                  const SizedBox(width: 12),
                  Text(_money(item.amount), style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: item.amount < 0 ? cs.error : cs.onSurface.withValues(alpha: 0.85))),
                ],
              ),
            )),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.15)))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: text.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Text(_money(selectedEstimate.total), style: text.labelMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
            ),
          ],
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

class _PartyDraft {
  final bool isAdult;
  String name;
  EatingStyle eatingStyle;
  int snacksPerDay;
  bool dessertAtTableService;
  bool enjoysAlcohol;

  _PartyDraft({
    required this.isAdult,
    required this.name,
    this.eatingStyle = EatingStyle.moderate,
    this.snacksPerDay = 1,
    this.dessertAtTableService = false,
    this.enjoysAlcohol = false,
  });
}

class _SignatureDraft {
  final WdwRestaurantOption restaurant;
  bool selected;
  DateTime? day;

  _SignatureDraft({required this.restaurant, this.selected = false, this.day});
}

class _LineItem {
  final String label;
  final double amount;
  const _LineItem({required this.label, required this.amount});
}

class _CostEstimate {
  final double total;
  final List<_LineItem> items;
  final List<String> notes;
  const _CostEstimate({required this.total, required this.items, required this.notes});

  const _CostEstimate.zero() : total = 0, items = const <_LineItem>[], notes = const <String>[];
}

class _CostBreakdown {
  final _CostEstimate outOfPocket;
  final _CostEstimate quickServicePlan;
  final _CostEstimate standardPlan;

  const _CostBreakdown({
    required this.outOfPocket,
    required this.quickServicePlan,
    required this.standardPlan,
  });

  const _CostBreakdown.zero()
    : outOfPocket = const _CostEstimate.zero(),
      quickServicePlan = const _CostEstimate.zero(),
      standardPlan = const _CostEstimate.zero();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

