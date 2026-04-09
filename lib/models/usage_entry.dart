enum UsageType { quickService, tableService, snack }

extension UsageTypeX on UsageType {
  String get label => switch (this) {
    UsageType.quickService => 'Quick-Service Meal',
    UsageType.tableService => 'Table-Service Meal',
    UsageType.snack => 'Snack / Drink',
  };

  String get shortLabel => switch (this) {
    UsageType.quickService => 'QS',
    UsageType.tableService => 'TS',
    UsageType.snack => 'Snack',
  };
}

class UsageEntry {
  final String id;
  final UsageType type;
  final DateTime usedAt;
  final String? note;

  /// Optional: the estimated cash value of what was redeemed with this credit.
  ///
  /// If provided, we can compute “value realized” vs plan cost.
  final double? value;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UsageEntry({
    required this.id,
    required this.type,
    required this.usedAt,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.value,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'usedAt': usedAt.toIso8601String(),
    'note': note,
    'value': value,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory UsageEntry.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String key) => DateTime.tryParse((json[key] ?? '').toString()) ?? DateTime.now();
    final typeName = (json['type'] ?? UsageType.quickService.name).toString();
    final type = UsageType.values.where((t) => t.name == typeName).firstOrNull ?? UsageType.quickService;
    return UsageEntry(
      id: (json['id'] ?? '').toString(),
      type: type,
      usedAt: parseDate('usedAt'),
      note: _parseNote(json['note']),
      value: _parseValue(json['value']),
      createdAt: parseDate('createdAt'),
      updatedAt: parseDate('updatedAt'),
    );
  }

  static String? _parseNote(Object? raw) {
    final s = raw?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  static double? _parseValue(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final normalized = s.replaceAll(RegExp(r'[^0-9.\-]'), '');
    final v = double.tryParse(normalized);
    if (v == null) return null;
    if (!v.isFinite) return null;
    if (v <= 0) return null;
    return v;
  }

  UsageEntry copyWith({
    String? id,
    UsageType? type,
    DateTime? usedAt,
    String? note,
    double? value,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      UsageEntry(
        id: id ?? this.id,
        type: type ?? this.type,
        usedAt: usedAt ?? this.usedAt,
        note: note ?? this.note,
        value: value ?? this.value,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
