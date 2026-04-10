import 'package:mouseplate/data/wdw_restaurant_catalog.dart';
import 'package:mouseplate/models/party_member.dart';
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

  // Step 1: per-person party profiles
  final List<PartyMember> partyMembers;

  // Step 2: preferred parks (used to filter Signature Dining list)
  final List<WdwPark> preferredParks;

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

  /// Per-child cash value for a Quick-Service or Table-Service meal.
  /// Children (3–9) order from the kids menu, which is significantly cheaper.
  final double assumedChildQuickServiceValue;
  final double assumedChildTableServiceValue;

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
    this.partyMembers = const <PartyMember>[],
    this.preferredParks = const [WdwPark.magicKingdom, WdwPark.epcot, WdwPark.hollywoodStudios, WdwPark.animalKingdom, WdwPark.disneySprings],
    this.recommendation = DiningRecommendation.quickService,

    this.plannedMeals = const <PlannedMeal>[],
    this.assumedQuickServiceValue = 23.00,
    this.assumedTableServiceValue = 60.00,
    this.assumedSnackValue = 9.00,
    this.assumedChildQuickServiceValue = 12.00,
    this.assumedChildTableServiceValue = 28.00,
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

  /// 2026 Disney Dining Plan pricing for children (ages 3–9), per night.
  double get pricePerChildNight => switch (planType) {
    PlanType.quickService => 47.17,
    PlanType.standard => 76.89,
  };

  double get estimatedTotalCost => usesDiningPlan
      ? (pricePerAdultNight * adults + (assumedChildPricePerNight > 0 ? assumedChildPricePerNight : pricePerChildNight) * children) * nights
      : 0.0;

  /// True when the user chose to pay out of pocket (no dining plan).
  bool get isCashMode => !usesDiningPlan;

  /// Estimated cash value of dining for the trip based on party preferences.
  ///
  /// Calculated regardless of [usesDiningPlan] so cash-mode trips can still
  /// show an estimated budget on the dashboard.
  ///
  /// When [partyMembers] is populated, uses per-member eating style and
  /// adult/child pricing. Falls back to flat per-credit averages for old trips.
  double get estimatedOutOfPocketCost {
    if (partyMembers.isNotEmpty) {
      double total = 0.0;
      // In cash mode, assume 2 QS meals per person per day (no TS plan credits).
      final qsPerPerson = isCashMode ? 2 : switch (planType) {
        PlanType.quickService => 2,
        PlanType.standard => 1,
      };
      final tsPerPerson = isCashMode ? 0 : switch (planType) {
        PlanType.quickService => 0,
        PlanType.standard => 1,
      };

      for (final m in partyMembers) {
        final baseQS = m.isAdult ? assumedQuickServiceValue : assumedChildQuickServiceValue;
        final baseTS = m.isAdult ? assumedTableServiceValue : assumedChildTableServiceValue;
        final mult = m.eatingStyle.multiplier;
        // Alcohol premium: adults who drink pay ~$6 more per meal on average.
        final alcPremium = (m.isAdult && m.enjoysAlcohol) ? 6.00 : 0.0;

        total += qsPerPerson * nights * (baseQS * mult + alcPremium);
        if (tsPerPerson > 0) {
          total += tsPerPerson * nights * (baseTS * mult + alcPremium);
          if (m.dessertAtTableService) total += tsPerPerson * nights * 6.00;
        }
        total += m.snacksPerDay * nights * assumedSnackValue;
      }
      return total;
    }

    // Legacy fallback: flat per-credit pricing (plan mode) or flat party × price (cash mode).
    if (isCashMode) {
      final party = totalPartySize;
      return 2 * nights * assumedQuickServiceValue * party +
          nights * assumedSnackValue * party;
    }
    return totalQuickServiceCredits * assumedQuickServiceValue +
        totalTableServiceCredits * assumedTableServiceValue +
        totalSnackCredits * assumedSnackValue;
  }

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

  /// Both plans: 1 snack per person per night
  int get totalSnackCredits => !usesDiningPlan
      ? 0
      : totalPartySize * 1 * nights;

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
    'partyMembers': partyMembers.map((m) => m.toJson()).toList(),
    'preferredParks': preferredParks.map((p) => p.name).toList(),
    'recommendation': recommendation.name,
    'plannedMeals': plannedMeals.map((m) => m.toJson()).toList(),
    'assumedQuickServiceValue': assumedQuickServiceValue,
    'assumedTableServiceValue': assumedTableServiceValue,
    'assumedSnackValue': assumedSnackValue,
    'assumedChildQuickServiceValue': assumedChildQuickServiceValue,
    'assumedChildTableServiceValue': assumedChildTableServiceValue,
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

    List<PartyMember> parseMembers() {
      final raw = json['partyMembers'];
      if (raw is! List) return <PartyMember>[];
      final members = <PartyMember>[];
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          members.add(PartyMember.fromJson(item));
        } else if (item is Map) {
          members.add(PartyMember.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      return members;
    }

    List<WdwPark> parseParks() {
      final raw = json['preferredParks'];
      if (raw is! List) return WdwPark.values;
      final parks = <WdwPark>[];
      for (final item in raw) {
        final name = item?.toString() ?? '';
        final park = WdwPark.values.where((p) => p.name == name).firstOrNull;
        if (park != null) parks.add(park);
      }
      return parks.isEmpty ? WdwPark.values : parks;
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
      partyMembers: parseMembers(),
      preferredParks: parseParks(),
      recommendation: parseRec(),
      plannedMeals: parsePlanned(),
      assumedQuickServiceValue: (json['assumedQuickServiceValue'] as num?)?.toDouble() ?? 23.00,
      assumedTableServiceValue: (json['assumedTableServiceValue'] as num?)?.toDouble() ?? 60.00,
      assumedSnackValue: (json['assumedSnackValue'] as num?)?.toDouble() ?? 9.00,
      assumedChildQuickServiceValue: (json['assumedChildQuickServiceValue'] as num?)?.toDouble() ?? 12.00,
      assumedChildTableServiceValue: (json['assumedChildTableServiceValue'] as num?)?.toDouble() ?? 28.00,
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
    List<PartyMember>? partyMembers,
    List<WdwPark>? preferredParks,
    DiningRecommendation? recommendation,
    List<PlannedMeal>? plannedMeals,
    double? assumedQuickServiceValue,
    double? assumedTableServiceValue,
    double? assumedSnackValue,
    double? assumedChildQuickServiceValue,
    double? assumedChildTableServiceValue,
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
        partyMembers: partyMembers ?? this.partyMembers,
        preferredParks: preferredParks ?? this.preferredParks,
        recommendation: recommendation ?? this.recommendation,
        plannedMeals: plannedMeals ?? this.plannedMeals,
        assumedQuickServiceValue: assumedQuickServiceValue ?? this.assumedQuickServiceValue,
        assumedTableServiceValue: assumedTableServiceValue ?? this.assumedTableServiceValue,
        assumedSnackValue: assumedSnackValue ?? this.assumedSnackValue,
        assumedChildQuickServiceValue: assumedChildQuickServiceValue ?? this.assumedChildQuickServiceValue,
        assumedChildTableServiceValue: assumedChildTableServiceValue ?? this.assumedChildTableServiceValue,
        assumedChildPricePerNight: assumedChildPricePerNight ?? this.assumedChildPricePerNight,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
