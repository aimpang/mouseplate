import 'package:mouseplate/models/usage_entry.dart';

enum MealSlot { breakfast, lunch, dinner }

extension MealSlotX on MealSlot {
  String get label => switch (this) {
    MealSlot.breakfast => 'Breakfast',
    MealSlot.lunch => 'Lunch',
    MealSlot.dinner => 'Dinner',
  };
}

/// A “future” meal the user intends to eat.
///
/// This is used to pre-populate the Log page after onboarding, without counting
/// anything as “used” until the user marks it as consumed.
class PlannedMeal {
  final String id;
  final DateTime day;
  final MealSlot slot;
  final UsageType type;
  final String restaurant;
  final double? estimatedValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlannedMeal({
    required this.id,
    required this.day,
    required this.slot,
    required this.type,
    required this.restaurant,
    required this.createdAt,
    required this.updatedAt,
    this.estimatedValue,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'day': DateTime(day.year, day.month, day.day).toIso8601String(),
    'slot': slot.name,
    'type': type.name,
    'restaurant': restaurant,
    'estimatedValue': estimatedValue,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory PlannedMeal.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String key) => DateTime.tryParse((json[key] ?? '').toString()) ?? DateTime.now();
    final slotName = (json['slot'] ?? MealSlot.lunch.name).toString();
    final slot = MealSlot.values.where((s) => s.name == slotName).firstOrNull ?? MealSlot.lunch;
    final typeName = (json['type'] ?? UsageType.quickService.name).toString();
    final type = UsageType.values.where((t) => t.name == typeName).firstOrNull ?? UsageType.quickService;
    return PlannedMeal(
      id: (json['id'] ?? '').toString(),
      day: parseDate('day'),
      slot: slot,
      type: type,
      restaurant: (json['restaurant'] ?? '').toString(),
      estimatedValue: (json['estimatedValue'] as num?)?.toDouble(),
      createdAt: parseDate('createdAt'),
      updatedAt: parseDate('updatedAt'),
    );
  }

  PlannedMeal copyWith({
    String? id,
    DateTime? day,
    MealSlot? slot,
    UsageType? type,
    String? restaurant,
    double? estimatedValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      PlannedMeal(
        id: id ?? this.id,
        day: day ?? this.day,
        slot: slot ?? this.slot,
        type: type ?? this.type,
        restaurant: restaurant ?? this.restaurant,
        estimatedValue: estimatedValue ?? this.estimatedValue,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
