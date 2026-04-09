class AppUser {
  final String id;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({required this.id, required this.displayName, required this.createdAt, required this.updatedAt});

  factory AppUser.local() {
    final now = DateTime.now();
    return AppUser(id: 'local', displayName: 'Guest', createdAt: now, updatedAt: now);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String key) => DateTime.tryParse((json[key] ?? '').toString()) ?? DateTime.now();
    return AppUser(
      id: (json['id'] ?? 'local').toString(),
      displayName: (json['displayName'] ?? 'Guest').toString(),
      createdAt: parseDate('createdAt'),
      updatedAt: parseDate('updatedAt'),
    );
  }

  AppUser copyWith({String? id, String? displayName, DateTime? createdAt, DateTime? updatedAt}) =>
      AppUser(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
