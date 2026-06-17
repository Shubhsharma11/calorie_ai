import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/meal_entry.dart';

/// Persists meal logs and streak metadata locally.
class LocalStorageService {
  LocalStorageService([this._prefs]);

  SharedPreferences? _prefs;

  static const _mealEntriesKey = 'meal_entries_v1';
  static const _longestStreakKey = 'longest_streak';
  static const _celebratedMilestonesKey = 'celebrated_streak_milestones';
  static const _calorieAdjustmentKey = 'manual_calorie_adjustment';

  Future<SharedPreferences> get _storage async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<List<MealEntry>> loadMealEntries() async {
    final prefs = await _storage;
    final raw = prefs.getString(_mealEntriesKey);
    if (raw == null || raw.isEmpty) return [];

    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => MealEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveMealEntries(List<MealEntry> entries) async {
    final prefs = await _storage;
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_mealEntriesKey, encoded);
  }

  Future<int> loadLongestStreak() async {
    final prefs = await _storage;
    return prefs.getInt(_longestStreakKey) ?? 0;
  }

  Future<void> saveLongestStreak(int value) async {
    final prefs = await _storage;
    await prefs.setInt(_longestStreakKey, value);
  }

  Future<Set<int>> loadCelebratedMilestones() async {
    final prefs = await _storage;
    final raw = prefs.getStringList(_celebratedMilestonesKey);
    if (raw == null) return {};
    return raw.map(int.parse).toSet();
  }

  Future<void> saveCelebratedMilestones(Set<int> milestones) async {
    final prefs = await _storage;
    final sorted = milestones.toList()..sort();
    await prefs.setStringList(
      _celebratedMilestonesKey,
      sorted.map((m) => m.toString()).toList(),
    );
  }

  Future<int> loadCalorieAdjustment() async {
    final prefs = await _storage;
    return prefs.getInt(_calorieAdjustmentKey) ?? 0;
  }

  Future<void> saveCalorieAdjustment(int value) async {
    final prefs = await _storage;
    await prefs.setInt(_calorieAdjustmentKey, value);
  }
}
