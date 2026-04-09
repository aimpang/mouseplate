import 'package:flutter/foundation.dart';

import 'package:mouseplate/models/trip.dart';
import 'package:mouseplate/models/usage_entry.dart';
import 'package:mouseplate/services/local_storage_service.dart';

enum LogUsageOutcome {
  success,
  noTrip,
  expired,
  notInPlan,
  noRemaining,
  storageError,
}

enum DashboardMode { totals, dayByDay }

class AppController extends ChangeNotifier {
  final LocalStorageService _storage;

  // Web safety: avoid bit-shift bounds like `-1 << 30` which can end up as an
  // unsigned 32-bit value in dart2js, causing `clamp(lower, upper)` to throw
  // because lower > upper.
  static const int _minClamp = -1000000000;
  static const int _maxClamp = 1000000000;

  Trip? _trip;
  List<UsageEntry> _usage = <UsageEntry>[];
  bool _premium = false;
  bool _onboardingComplete = false;
  DashboardMode _dashboardMode = DashboardMode.totals;

  AppController({LocalStorageService? storage}) : _storage = storage ?? LocalStorageService();

  Trip? get trip => _trip;
  List<UsageEntry> get usage => List.unmodifiable(_usage);
  bool get hasTrip => _trip != null;
  bool get premiumUnlocked => _premium;
  bool get onboardingComplete => _onboardingComplete;
  DashboardMode get dashboardMode => _dashboardMode;

  int usedCount(UsageType type) => _usage.where((e) => e.type == type).length;

  int get usedQuickService => usedCount(UsageType.quickService);
  int get usedTableService => usedCount(UsageType.tableService);
  int get usedSnacks => usedCount(UsageType.snack);

  int totalFor(UsageType type) {
    final t = _trip;
    if (t == null) return 0;
    if (!t.usesDiningPlan) return 0;
    return switch (type) {
      UsageType.quickService => t.totalQuickServiceCredits,
      UsageType.tableService => t.totalTableServiceCredits,
      UsageType.snack => t.totalSnackCredits,
    };
  }

  int remainingFor(UsageType type) {
    final total = totalFor(type);
    final used = usedCount(type);
    final remaining = total - used;
    final clamped = remaining.clamp(_minClamp, _maxClamp);
    return clamped is int ? clamped : clamped.toInt();
  }

  bool typeAvailableInPlan(UsageType type) {
    final t = _trip;
    if (t == null) return false;
    if (!t.usesDiningPlan) return true;
    final total = totalFor(type);
    // For Table-Service: total==0 means the plan simply doesn't include it.
    if (type == UsageType.tableService) return total > 0;
    // QS + Snack always exist for both plans.
    return true;
  }

  bool get creditsExpired {
    final t = _trip;
    if (t == null) return false;
    if (!t.usesDiningPlan) return false;
    final now = DateTime.now();
    return !now.isBefore(t.creditsExpireAt);
  }

  Future<void> load() async {
    try {
      _trip = await _storage.loadTrip();
      _usage = await _storage.loadUsage();
      _premium = await _storage.loadPremium();
      _onboardingComplete = await _storage.loadOnboardingComplete();
      final rawMode = await _storage.loadDashboardMode();
      _dashboardMode = DashboardMode.values.where((m) => m.name == rawMode).firstOrNull ?? DashboardMode.totals;
    } catch (e) {
      debugPrint('AppController.load failed: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> setDashboardMode(DashboardMode mode) async {
    _dashboardMode = mode;
    await _storage.saveDashboardMode(mode.name);
    notifyListeners();
  }

  Future<void> setOnboardingComplete(bool complete) async {
    _onboardingComplete = complete;
    await _storage.saveOnboardingComplete(complete);
    notifyListeners();
  }

  Future<void> saveTrip(Trip trip) async {
    _trip = trip;
    await _storage.saveTrip(trip);
    notifyListeners();
  }

  Future<LogUsageOutcome> logUsage({required UsageType type, String? note, double? value, bool allowOverdraft = false}) async {
    if (_trip == null) return LogUsageOutcome.noTrip;

    // Cash mode: unlimited logging, no expiry/credit gating.
    if (_trip?.usesDiningPlan == false) {
      try {
        final now = DateTime.now();
        final entry = UsageEntry(
          id: now.microsecondsSinceEpoch.toString(),
          type: type,
          usedAt: now,
          note: (note == null || note.trim().isEmpty) ? null : note.trim(),
          value: value,
          createdAt: now,
          updatedAt: now,
        );
        _usage = <UsageEntry>[entry, ..._usage];
        await _storage.saveUsage(_usage);
        notifyListeners();
        return LogUsageOutcome.success;
      } catch (e) {
        debugPrint('AppController.logUsage (cash mode) failed: $e');
        return LogUsageOutcome.storageError;
      }
    }

    if (creditsExpired) return LogUsageOutcome.expired;
    if (!typeAvailableInPlan(type)) return LogUsageOutcome.notInPlan;

    final remaining = remainingFor(type);
    if (remaining <= 0 && !allowOverdraft) return LogUsageOutcome.noRemaining;

    try {
      final now = DateTime.now();
      final entry = UsageEntry(
        id: now.microsecondsSinceEpoch.toString(),
        type: type,
        usedAt: now,
        note: (note == null || note.trim().isEmpty) ? null : note.trim(),
        value: value,
        createdAt: now,
        updatedAt: now,
      );
      _usage = <UsageEntry>[entry, ..._usage];
      await _storage.saveUsage(_usage);
      notifyListeners();
      return LogUsageOutcome.success;
    } catch (e) {
      debugPrint('AppController.logUsage failed: $e');
      return LogUsageOutcome.storageError;
    }
  }

  Future<void> deleteUsage(String id) async {
    _usage = _usage.where((e) => e.id != id).toList();
    await _storage.saveUsage(_usage);
    notifyListeners();
  }

  Future<void> clearTripAndUsage() async {
    _trip = null;
    _usage = <UsageEntry>[];
    await _storage.clearAll();
    notifyListeners();
  }

  /// Used by onboarding: replace the trip and reset usage in one consistent save.
  Future<void> replaceTripAndClearUsage(Trip trip) async {
    _trip = trip;
    _usage = <UsageEntry>[];
    try {
      await _storage.saveTrip(trip);
      await _storage.saveUsage(_usage);
    } catch (e) {
      debugPrint('AppController.replaceTripAndClearUsage failed: $e');
    }
    notifyListeners();
  }

  Future<bool> consumePlannedMeal(String plannedMealId) async {
    final t = _trip;
    if (t == null) return false;
    final idx = t.plannedMeals.indexWhere((m) => m.id == plannedMealId);
    if (idx < 0) return false;

    final planned = t.plannedMeals[idx];
    final now = DateTime.now();
    final entry = UsageEntry(
      id: now.microsecondsSinceEpoch.toString(),
      type: planned.type,
      usedAt: now,
      note: planned.restaurant.trim().isEmpty ? null : planned.restaurant.trim(),
      value: planned.estimatedValue,
      createdAt: now,
      updatedAt: now,
    );

    _usage = <UsageEntry>[entry, ..._usage];
    final updatedMeals = t.plannedMeals.where((m) => m.id != plannedMealId).toList();
    _trip = t.copyWith(plannedMeals: updatedMeals, updatedAt: now);

    try {
      await _storage.saveUsage(_usage);
      await _storage.saveTrip(_trip!);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AppController.consumePlannedMeal failed: $e');
      return false;
    }
  }

  Future<void> setPremiumUnlocked(bool unlocked) async {
    _premium = unlocked;
    await _storage.savePremium(unlocked);
    notifyListeners();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
