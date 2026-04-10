enum EatingStyle {
  light,
  moderate,
  hearty;

  String get label => switch (this) {
    EatingStyle.light    => 'Little Nibbler',
    EatingStyle.moderate => 'Park Explorer',
    EatingStyle.hearty   => 'Feast Mode',
  };

  double get multiplier => switch (this) {
    EatingStyle.light    => 0.80,
    EatingStyle.moderate => 1.00,
    EatingStyle.hearty   => 1.20,
  };
}

class PartyMember {
  final String id;

  /// Display name, e.g. "Mom", "Emma", "Adult 1".
  final String name;

  /// true = adult (age 10+), false = child (age 3–9).
  final bool isAdult;

  final EatingStyle eatingStyle;

  /// Snacks per day for this person.
  final int snacksPerDay;

  /// Whether this person orders dessert at Table-Service meals.
  final bool dessertAtTableService;

  /// Whether this person typically orders alcoholic beverages (adults only).
  final bool enjoysAlcohol;

  const PartyMember({
    required this.id,
    required this.name,
    required this.isAdult,
    this.eatingStyle = EatingStyle.moderate,
    this.snacksPerDay = 1,
    this.dessertAtTableService = false,
    this.enjoysAlcohol = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isAdult': isAdult,
    'eatingStyle': eatingStyle.name,
    'snacksPerDay': snacksPerDay,
    'dessertAtTableService': dessertAtTableService,
    'enjoysAlcohol': enjoysAlcohol,
  };

  factory PartyMember.fromJson(Map<String, dynamic> json) {
    final styleName = (json['eatingStyle'] ?? EatingStyle.moderate.name).toString();
    final style = EatingStyle.values.where((s) => s.name == styleName).firstOrNull ?? EatingStyle.moderate;
    return PartyMember(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      isAdult: (json['isAdult'] as bool?) ?? true,
      eatingStyle: style,
      snacksPerDay: (json['snacksPerDay'] as num?)?.toInt() ?? 1,
      dessertAtTableService: (json['dessertAtTableService'] as bool?) ?? false,
      enjoysAlcohol: (json['enjoysAlcohol'] as bool?) ?? false,
    );
  }

  PartyMember copyWith({
    String? id,
    String? name,
    bool? isAdult,
    EatingStyle? eatingStyle,
    int? snacksPerDay,
    bool? dessertAtTableService,
    bool? enjoysAlcohol,
  }) =>
      PartyMember(
        id: id ?? this.id,
        name: name ?? this.name,
        isAdult: isAdult ?? this.isAdult,
        eatingStyle: eatingStyle ?? this.eatingStyle,
        snacksPerDay: snacksPerDay ?? this.snacksPerDay,
        dessertAtTableService: dessertAtTableService ?? this.dessertAtTableService,
        enjoysAlcohol: enjoysAlcohol ?? this.enjoysAlcohol,
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
