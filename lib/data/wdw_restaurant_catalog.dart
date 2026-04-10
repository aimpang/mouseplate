import 'package:mouseplate/models/usage_entry.dart';

part 'wdw_restaurant_catalog_entries.dart';

enum WdwPark {
  magicKingdom,
  epcot,
  hollywoodStudios,
  animalKingdom,
  disneySprings;

  String get label => switch (this) {
    WdwPark.magicKingdom => 'Magic Kingdom',
    WdwPark.epcot => 'EPCOT',
    WdwPark.hollywoodStudios => 'Hollywood Studios',
    WdwPark.animalKingdom => 'Animal Kingdom',
    WdwPark.disneySprings => 'Disney Springs',
  };
}

/// Walt Disney World dining options with **approximate** per-adult meal costs (entrée +
/// typical non-alcoholic drink, USD). Used for trip planning estimates only.
///
/// Official menus and prices change often — confirm at
/// [AllEars dining menus](https://allears.net/dining/menu/) or Disney before budgeting.
class WdwRestaurantOption {
  final String name;
  final UsageType type;

  /// Typical cash cost per adult for one meal (planning ballpark).
  final double avgPerAdult;

  /// Which park this restaurant is in. Null for resorts, water parks, and off-property.
  final WdwPark? park;

  /// Dining plan credit cost (1 or 2). Signature Dining restaurants cost 2 credits.
  final int credits;

  const WdwRestaurantOption({
    required this.name,
    required this.type,
    required this.avgPerAdult,
    this.park,
    this.credits = 1,
  });
}

abstract final class WdwRestaurantCatalog {
  static const List<WdwRestaurantOption> all = _catalogEntries;

  static const String customKey = '__custom__';

  /// Compact dropdown: popular picks (each string must match an entry in [all]).
  static const List<String> _quickPickNamesQs = [
    "Cosmic Ray's Starlight Café",
    "Satu'li Canteen",
    "Docking Bay 7 Food and Cargo",
    "Flame Tree Barbecue",
    "Regal Eagle Smokehouse",
    "Casey's Corner",
  ];

  static const List<String> _quickPickNamesTs = [
    "Be Our Guest Restaurant (dinner)",
    "Cinderella's Royal Table",
    "Hollywood Brown Derby",
    "Le Cellier Steakhouse",
    "'Ohana (Polynesian)",
    "Chef Mickey's",
  ];

  /// Current text matches a quick-pick name (for dropdown sync). [type] must be QS or TS.
  static String quickPickDropdownValueForText(String raw, UsageType t) {
    if (t == UsageType.snack) return '';
    final name = raw.trim();
    if (name.isEmpty) return '';
    for (final p in quickPicksForType(t)) {
      if (p.name.toLowerCase() == name.toLowerCase()) return p.name;
    }
    return '';
  }

  static List<WdwRestaurantOption> quickPicksForType(UsageType t) {
    if (t == UsageType.snack) return const [];
    final names = t == UsageType.quickService ? _quickPickNamesQs : _quickPickNamesTs;
    final out = <WdwRestaurantOption>[];
    for (final n in names) {
      final m = matchName(n, t);
      if (m != null) out.add(m);
    }
    return out;
  }

  /// Type-ahead matches (substring). Empty or short query returns [] so the overlay stays small.
  static List<WdwRestaurantOption> search(
    UsageType t,
    String query, {
    int limit = 8,
    int minChars = 1,
  }) {
    if (t == UsageType.snack) return const [];
    final q = query.trim().toLowerCase();
    if (q.length < minChars) return const [];
    final buf = <WdwRestaurantOption>[];
    for (final e in all) {
      if (e.type != t) continue;
      if (e.name.toLowerCase().contains(q)) buf.add(e);
    }
    buf.sort((a, b) {
      final an = a.name.toLowerCase();
      final bn = b.name.toLowerCase();
      final as = an.startsWith(q) ? 0 : 1;
      final bs = bn.startsWith(q) ? 0 : 1;
      if (as != bs) return as - bs;
      return a.name.compareTo(b.name);
    });
    if (buf.length <= limit) return buf;
    return buf.sublist(0, limit);
  }

  /// Signature Dining (2-credit) restaurants filtered by the given parks.
  static List<WdwRestaurantOption> signatureDining(List<WdwPark> parks) {
    final list = all
        .where((r) => r.credits == 2 && r.park != null && parks.contains(r.park))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  static List<WdwRestaurantOption> forType(UsageType t) {
    final list = all.where((e) => e.type == t).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Exact name match (case-insensitive) for the given meal type.
  static WdwRestaurantOption? matchName(String raw, UsageType t) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final e in all) {
      if (e.type != t) continue;
      if (e.name.toLowerCase() == q) return e;
    }
    return null;
  }
}
