import 'package:mouseplate/models/planned_meal.dart';

enum PlanType { quickService, standard }

/// The outcome of the “worth it?” calculator.
///
/// - outOfPocket: recommended to pay cash (no dining plan)
/// - quickService: recommended to buy the Quick-Service Dining Plan
/// - standard: recommended to buy the Disney Dining Plan
enum DiningRecommendation { outOfPocket, quickService, standard }

enum BeveragePreference { waterOnly, fountainOrNonAlcoholic, includesAlcohol }

enum DiningStyle { budget, average, splurge }

extension PlanTypeX on PlanType {
  String get label => switch (this) {
    PlanType.quickService => 'Quick-Service Dining Plan',
    PlanType.standard => 'Disney Dining Plan',
  };

  String get shortLabel => switch (this) {
    PlanType.quickService => 'Quick-Service',
    PlanType.standard => 'Standard',
  };
}

class Trip {
  final String id;

  /// If false, the user is in “pay cash” mode.
  ///
  /// We still keep the trip object for dates + party + logging, but credits are
  /// disabled and logging is unlimited.
  final bool usesDiningPlan;

  /// Only meaningful when [usesDiningPlan] is true.
  final PlanType planType;
  final int adults;
  final int children;
  final int nights;
  final DateTime startDate;

  // Step 1: Discounts
  final bool annualPassholder;
  final bool dvcMember;

  // Step 2: Dining preferences
  final BeveragePreference beveragePreference;
  final int snacksPerPersonPerDay;
  final bool dessertAtTableService;
  final bool resortRefillableMugs;
  final DiningStyle diningStyle;

  // Step 4: recommendation outcome
  final DiningRecommendation recommendation;

  // Step 3: planned restaurants/meals
  final List<PlannedMeal> plannedMeals;

  /// “Worth it?” assumptions (user-tunable; used for out-of-pocket estimates).
  ///
  /// These are *average* menu prices per credit category.
  final double assumedQuickServiceValue;
  final double assumedTableServiceValue;
  final double assumedSnackValue;

  /// Plan pricing assumptions.
  ///
  /// Historically, Disney plan prices differ for adults vs children. This app
  /// defaults to the existing behavior (adult-only pricing with children at $0)
  /// but allows overriding child pricing for more accurate math.
  final double assumedChildPricePerNight;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Trip({
    required this.id,
    this.usesDiningPlan = true,
    required this.planType,
    required this.adults,
    required this.children,
    required this.nights,
    required this.startDate,

    this.annualPassholder = false,
    this.dvcMember = false,

    this.beveragePreference = BeveragePreference.fountainOrNonAlcoholic,
    this.snacksPerPersonPerDay = 0,
    this.dessertAtTableService = false,
    this.resortRefillableMugs = false,
    this.diningStyle = DiningStyle.average,
    this.recommendation = DiningRecommendation.quickService,

    this.plannedMeals = const <PlannedMeal>[],
    this.assumedQuickServiceValue = 23.00,
    this.assumedTableServiceValue = 60.00,
    this.assumedSnackValue = 9.00,
    this.assumedChildPricePerNight = 0.00,
    required this.createdAt,
    required this.updatedAt,
  });

  /// The last NIGHT of the stay (startDate + nights - 1)
  DateTime get lastNight => DateTime(startDate.year, startDate.month, startDate.day).add(Duration(days: nights - 1));

  /// Checkout day (startDate + nights). Credits expire at midnight on checkout day.
  DateTime get checkoutDay => DateTime(startDate.year, startDate.month, startDate.day).add(Duration(days: nights));

  /// Credits expire at midnight at the END of checkout day (i.e., start of day after checkout).
  DateTime get creditsExpireAt => checkoutDay.add(const Duration(days: 1));

  /// 2026 pricing (hardcoded): per adult, per night.
  double get pricePerAdultNight => switch (planType) {
    PlanType.quickService => 60.47,
    PlanType.standard => 98.59,
  };

  double get estimatedTotalCost => usesDiningPlan ? (pricePerAdultNight * adults + assumedChildPricePerNight * children) * nights : 0.0;

  double get estimatedOutOfPocketCost =>
      totalQuickServiceCredits * assumedQuickServiceValue + totalTableServiceCredits * assumedTableServiceValue + totalSnackCredits * assumedSnackValue;

  double get estimatedNetValue => estimatedOutOfPocketCost - estimatedTotalCost;

  int get totalPartySize => adults + children;

  int get totalQuickServiceCredits => !usesDiningPlan
      ? 0
      : switch (planType) {
    PlanType.quickService => totalPartySize * 2 * nights,
    PlanType.standard => totalPartySize * 1 * nights,
  };

  int get totalTableServiceCredits => !usesDiningPlan
      ? 0
      : switch (planType) {
    PlanType.quickService => 0,
    PlanType.standard => totalPartySize * 1 * nights,
  };

  /// Only Disney Dining Plan (standard) includes snacks: 2 per person per night
  /// Quick-Service Dining Plan does NOT include snacks
  int get totalSnackCredits => !usesDiningPlan
      ? 0
      : switch (planType) {
    PlanType.quickService => 0,
    PlanType.standard => totalPartySize * 2 * nights,
  };

  /// Resort refillable mug: 1 per person per PACKAGE (not per night)
  int get totalRefillableMugs => totalPartySize;

  int get totalAllCredits => totalQuickServiceCredits + totalTableServiceCredits + totalSnackCredits;

  Map<String, dynamic> toJson() => {
    'id': id,
    'usesDiningPlan': usesDiningPlan,
    'planType': planType.name,
    'adults': adults,
    'children': children,
    'nights': nights,
    'startDate': startDate.toIso8601String(),

    'annualPassholder': annualPassholder,
    'dvcMember': dvcMember,

    'beveragePreference': beveragePreference.name,
    'snacksPerPersonPerDay': snacksPerPersonPerDay,
    'dessertAtTableService': dessertAtTableService,
    'resortRefillableMugs': resortRefillableMugs,
    'diningStyle': diningStyle.name,
    'recommendation': recommendation.name,
    'plannedMeals': plannedMeals.map((m) => m.toJson()).toList(),
    'assumedQuickServiceValue': assumedQuickServiceValue,
    'assumedTableServiceValue': assumedTableServiceValue,
    'assumedSnackValue': assumedSnackValue,
    'assumedChildPricePerNight': assumedChildPricePerNight,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Trip.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String key) => DateTime.tryParse((json[key] ?? '').toString()) ?? DateTime.now();
    final planName = (json['planType'] ?? PlanType.quickService.name).toString();
    final planType = PlanType.values.where((p) => p.name == planName).firstOrNull ?? PlanType.quickService;

    BeveragePreference parseBeverage() {
      final raw = (json['beveragePreference'] ?? '').toString();
      return BeveragePreference.values.where((b) => b.name == raw).firstOrNull ?? BeveragePreference.fountainOrNonAlcoholic;
    }

    DiningStyle parseStyle() {
      final raw = (json['diningStyle'] ?? '').toString();
      return DiningStyle.values.where((s) => s.name == raw).firstOrNull ?? DiningStyle.average;
    }

    DiningRecommendation parseRec() {
      final raw = (json['recommendation'] ?? '').toString();
      return DiningRecommendation.values.where((r) => r.name == raw).firstOrNull ?? DiningRecommendation.quickService;
    }

    List<PlannedMeal> parsePlanned() {
      final raw = json['plannedMeals'];
      if (raw is! List) return <PlannedMeal>[];
      final meals = <PlannedMeal>[];
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          meals.add(PlannedMeal.fromJson(item));
        } else if (item is Map) {
          meals.add(PlannedMeal.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      return meals.where((m) => m.id.trim().isNotEmpty).toList();
    }

    return Trip(
      id: (json['id'] ?? 'trip').toString(),
      usesDiningPlan: (json['usesDiningPlan'] as bool?) ?? true,
      planType: planType,
      adults: (json['adults'] as num?)?.toInt() ?? 2,
      children: (json['children'] as num?)?.toInt() ?? 0,
      nights: (json['nights'] as num?)?.toInt() ?? 4,
      startDate: parseDate('startDate'),

      annualPassholder: (json['annualPassholder'] as bool?) ?? false,
      dvcMember: (json['dvcMember'] as bool?) ?? false,

      beveragePreference: parseBeverage(),
      snacksPerPersonPerDay: (json['snacksPerPersonPerDay'] as num?)?.toInt() ?? 0,
      dessertAtTableService: (json['dessertAtTableService'] as bool?) ?? false,
      resortRefillableMugs: (json['resortRefillableMugs'] as bool?) ?? false,
      diningStyle: parseStyle(),
      recommendation: parseRec(),
      plannedMeals: parsePlanned(),
      assumedQuickServiceValue: (json['assumedQuickServiceValue'] as num?)?.toDouble() ?? 23.00,
      assumedTableServiceValue: (json['assumedTableServiceValue'] as num?)?.toDouble() ?? 60.00,
      assumedSnackValue: (json['assumedSnackValue'] as num?)?.toDouble() ?? 9.00,
      assumedChildPricePerNight: (json['assumedChildPricePerNight'] as num?)?.toDouble() ?? 0.00,
      createdAt: parseDate('createdAt'),
      updatedAt: parseDate('updatedAt'),
    );
  }

  Trip copyWith({
    String? id,
    bool? usesDiningPlan,
    PlanType? planType,
    int? adults,
    int? children,
    int? nights,
    DateTime? startDate,

    bool? annualPassholder,
    bool? dvcMember,

    BeveragePreference? beveragePreference,
    int? snacksPerPersonPerDay,
    bool? dessertAtTableService,
    bool? resortRefillableMugs,
    DiningStyle? diningStyle,
    DiningRecommendation? recommendation,
    List<PlannedMeal>? plannedMeals,
    double? assumedQuickServiceValue,
    double? assumedTableServiceValue,
    double? assumedSnackValue,
    double? assumedChildPricePerNight,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Trip(
        id: id ?? this.id,
        usesDiningPlan: usesDiningPlan ?? this.usesDiningPlan,
        planType: planType ?? this.planType,
        adults: adults ?? this.adults,
        children: children ?? this.children,
        nights: nights ?? this.nights,
        startDate: startDate ?? this.startDate,

        annualPassholder: annualPassholder ?? this.annualPassholder,
        dvcMember: dvcMember ?? this.dvcMember,

        beveragePreference: beveragePreference ?? this.beveragePreference,
        snacksPerPersonPerDay: snacksPerPersonPerDay ?? this.snacksPerPersonPerDay,
        dessertAtTableService: dessertAtTableService ?? this.dessertAtTableService,
        resortRefillableMugs: resortRefillableMugs ?? this.resortRefillableMugs,
        diningStyle: diningStyle ?? this.diningStyle,
        recommendation: recommendation ?? this.recommendation,
        plannedMeals: plannedMeals ?? this.plannedMeals,
        assumedQuickServiceValue: assumedQuickServiceValue ?? this.assumedQuickServiceValue,
        assumedTableServiceValue: assumedTableServiceValue ?? this.assumedTableServiceValue,
        assumedSnackValue: assumedSnackValue ?? this.assumedSnackValue,
        assumedChildPricePerNight: assumedChildPricePerNight ?? this.assumedChildPricePerNight,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
