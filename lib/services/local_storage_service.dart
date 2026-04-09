import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mouseplate/models/trip.dart';
import 'package:mouseplate/models/usage_entry.dart';

class LocalStorageService {
  static const _tripKey = 'enchanted.trip.v1';
  static const _usageKey = 'enchanted.usage.v1';
  static const _premiumKey = 'enchanted.premium.v1';
  static const _onboardingKey = 'enchanted.onboardingComplete.v1';
  static const _dashboardModeKey = 'enchanted.dashboardMode.v1';

  Future<Trip?> loadTrip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tripKey);
      if (raw == null || raw.trim().isEmpty) return null;
      final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
      return Trip.fromJson(jsonMap);
    } catch (e) {
      debugPrint('LocalStorageService.loadTrip failed: $e');
      return null;
    }
  }

  Future<void> saveTrip(Trip trip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tripKey, jsonEncode(trip.toJson()));
    } catch (e) {
      debugPrint('LocalStorageService.saveTrip failed: $e');
    }
  }

  Future<List<UsageEntry>> loadUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_usageKey);
      if (raw == null || raw.trim().isEmpty) return <UsageEntry>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <UsageEntry>[];

      final entries = <UsageEntry>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          entries.add(UsageEntry.fromJson(item));
        } else if (item is Map) {
          entries.add(UsageEntry.fromJson(Map<String, dynamic>.from(item)));
        }
      }

      // Sanitize: remove corrupted items (empty id), then write back.
      final sanitized = entries.where((e) => e.id.trim().isNotEmpty).toList();
      if (sanitized.length != entries.length) {
        await saveUsage(sanitized);
      }
      return sanitized;
    } catch (e) {
      debugPrint('LocalStorageService.loadUsage failed: $e');
      return <UsageEntry>[];
    }
  }

  Future<void> saveUsage(List<UsageEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_usageKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('LocalStorageService.saveUsage failed: $e');
    }
  }

  Future<bool> loadPremium() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_premiumKey) ?? false;
    } catch (e) {
      debugPrint('LocalStorageService.loadPremium failed: $e');
      return false;
    }
  }

  Future<void> savePremium(bool premium) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_premiumKey, premium);
    } catch (e) {
      debugPrint('LocalStorageService.savePremium failed: $e');
    }
  }

  Future<bool> loadOnboardingComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onboardingKey) ?? false;
    } catch (e) {
      debugPrint('LocalStorageService.loadOnboardingComplete failed: $e');
      return false;
    }
  }

  Future<void> saveOnboardingComplete(bool complete) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingKey, complete);
    } catch (e) {
      debugPrint('LocalStorageService.saveOnboardingComplete failed: $e');
    }
  }

  Future<String?> loadDashboardMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_dashboardModeKey);
      if (raw == null || raw.trim().isEmpty) return null;
      return raw;
    } catch (e) {
      debugPrint('LocalStorageService.loadDashboardMode failed: $e');
      return null;
    }
  }

  Future<void> saveDashboardMode(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dashboardModeKey, mode);
    } catch (e) {
      debugPrint('LocalStorageService.saveDashboardMode failed: $e');
    }
  }

  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tripKey);
      await prefs.remove(_usageKey);
      // Intentionally keep premium.
      // Intentionally keep onboarding flag.
      // Intentionally keep dashboard mode.
    } catch (e) {
      debugPrint('LocalStorageService.clearAll failed: $e');
    }
  }
}
