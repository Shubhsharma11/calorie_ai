import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/exercise_entry.dart';
import '../models/health_concern.dart';
import '../models/meal_entry.dart';
import '../models/saved_meal_item.dart';

/// Persists meal logs and streak metadata locally.
class LocalStorageService {
LocalStorageService([this._prefs, this.userId]);

final String? userId;

  SharedPreferences? _prefs;
 String _mealKey() {
  return 'meal_entries_v1_${userId ?? "guest"}';
}
  static const _favoriteMealsKey = 'favorite_meals_v1';
  static const _dismissedBreakfastSuggestionKey =
      'dismissed_breakfast_suggestion_v1';
  static const _longestStreakKey = 'longest_streak';
  static const _celebratedMilestonesKey = 'celebrated_streak_milestones';
  static const _calorieAdjustmentKey = 'manual_calorie_adjustment';
  static const _nutritionTargetsKey = 'nutrition_targets_v1';
  static const _healthProblemKey = 'health_problem_v2';
  static const _healthProblemLegacyKey = 'health_problem_v1';
  static const _activityLogKey = 'activity_log_v1';
  static const _authSessionKey = 'auth_session_v1';
  static const _onboardingCompletedKey = 'onboarding_completed_v1';

  Future<SharedPreferences> get _storage async =>
      _prefs ??= await SharedPreferences.getInstance();

 Future<List<MealEntry>> loadMealEntries()async {
  
  final prefs = await _storage;
  
  
  final raw = prefs.getString(_mealKey());

  if (raw == null || raw.isEmpty) return [];

  final list = jsonDecode(raw) as List<dynamic>;
  return list
      .map((item) => MealEntry.fromJson(item as Map<String, dynamic>))
      .toList();
}

Future<void> saveMealEntries(List<MealEntry> entries) async {
  final prefs = await _storage;
  final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());

await prefs.setString(_mealKey(), encoded);
}

  Future<List<SavedMealItem>> loadFavoriteMeals() async {
    final prefs = await _storage;
    final raw = prefs.getString(_favoriteMealsKey);
    if (raw == null || raw.isEmpty) return [];

    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => SavedMealItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveFavoriteMeals(List<SavedMealItem> items) async {
    final prefs = await _storage;
    final encoded = jsonEncode(items.map((item) => item.toJson()).toList());
    await prefs.setString(_favoriteMealsKey, encoded);
  }

  Future<String?> loadDismissedBreakfastSuggestionDate() async {
    final prefs = await _storage;
    return prefs.getString(_dismissedBreakfastSuggestionKey);
  }

  Future<void> saveDismissedBreakfastSuggestionDate(String dateKey) async {
    final prefs = await _storage;
    await prefs.setString(_dismissedBreakfastSuggestionKey, dateKey);
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

  Future<void> saveNutritionTargets({
    int? baseCalories,
    int? dailyCalories,
    int? proteinG,
    int? carbsG,
    int? fatG,
  }) async {
    final prefs = await _storage;
    final encoded = jsonEncode({
      'baseCalories': baseCalories,
      'dailyCalories': dailyCalories,
      'proteinG': proteinG,
      'carbsG': carbsG,
      'fatG': fatG,
    });
    await prefs.setString(_nutritionTargetsKey, encoded);
  }

  Future<Map<String, int?>> loadNutritionTargets() async {
    final prefs = await _storage;
    final raw = prefs.getString(_nutritionTargetsKey);
    if (raw == null || raw.isEmpty) return {};

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    int? readInt(String key) {
      final value = decoded[key];
      if (value is int) return value;
      if (value is num) return value.round();
      return null;
    }

    return {
      'baseCalories': readInt('baseCalories'),
      'dailyCalories': readInt('dailyCalories'),
      'proteinG': readInt('proteinG'),
      'carbsG': readInt('carbsG'),
      'fatG': readInt('fatG'),
    };
  }

  Future<List<HealthConcern>> loadHealthConcerns() async {
    final prefs = await _storage;
    final raw =
        prefs.getString(_healthProblemKey) ??
        prefs.getString(_healthProblemLegacyKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return [];

    final concernsRaw = decoded['concerns'];
    if (concernsRaw is List) {
      return concernsRaw
          .whereType<Map<String, dynamic>>()
          .map(HealthConcern.fromJson)
          .where((concern) => concern.category.isNotEmpty)
          .toList();
    }

    return _migrateLegacyHealthProblem(decoded);
  }

  List<HealthConcern> _migrateLegacyHealthProblem(Map<String, dynamic> decoded) {
    final category = (decoded['category'] as String? ?? '').trim();
    if (category.isEmpty) return [];
    if (category == HealthConcern.noneCategory) {
      return [HealthConcern.none()];
    }

    final description = decoded['description'] as String? ?? '';
    final duration = decoded['duration'] as String?;
    final severity = decoded['severity'] as String?;
    final medication = decoded['medication'] as String?;

    final categories = category
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    return categories
        .map(
          (value) => HealthConcern(
            category: value,
            description: description,
            duration: duration,
            severity: severity,
            medication: medication,
          ),
        )
        .toList();
  }

  Future<void> saveHealthConcerns(List<HealthConcern> concerns) async {
    final prefs = await _storage;
    final encoded = jsonEncode({
      'concerns': concerns.map((concern) => concern.toJson()).toList(),
    });
    await prefs.setString(_healthProblemKey, encoded);
  }

  @Deprecated('Use loadHealthConcerns')
  Future<Map<String, String?>> loadHealthProblem() async {
    final concerns = await loadHealthConcerns();
    if (concerns.isEmpty) return {};
    if (concerns.length == 1 && concerns.first.isNone) {
      return {'category': HealthConcern.noneCategory};
    }
    final first = concerns.first;
    return {
      'category': concerns.map((concern) => concern.category).join(', '),
      'description': first.description,
      'duration': first.duration,
      'severity': first.severity,
      'medication': first.medication,
    };
  }

  @Deprecated('Use saveHealthConcerns')
  Future<void> saveHealthProblem({
    required String category,
    required String description,
    String? duration,
    String? severity,
    String? medication,
  }) async {
    final prefs = await _storage;
    final encoded = jsonEncode({
      'category': category,
      'description': description,
      'duration': duration,
      'severity': severity,
      'medication': medication,
    });
    await prefs.setString(_healthProblemKey, encoded);
  }

  Future<Map<String, dynamic>> loadAuthSession() async {
    final prefs = await _storage;
    final raw = prefs.getString(_authSessionKey);
    if (raw == null || raw.isEmpty) return {};

    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveAuthSession({
    required String userId,
    required String provider,
    required String email,
    required String name,
    required String accessToken,
    String? refreshToken,
    required Map<String, dynamic> backendResponse,
  }) async {
    final prefs = await _storage;
    final encoded = jsonEncode({
      'userId': userId,
      'provider': provider,
      'email': email,
      'name': name,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'backendResponse': backendResponse,
      'loggedInAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_authSessionKey, encoded);
  }

  Future<void> clearAuthSession() async {
    final prefs = await _storage;
    await prefs.remove(_authSessionKey);
  }

  Future<bool> isOnboardingCompleted() async {
    final prefs = await _storage;
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> saveOnboardingCompleted({required bool completed}) async {
    final prefs = await _storage;
    await prefs.setBool(_onboardingCompletedKey, completed);
  }

  Future<void> clearUserProfileCache() async {
    final prefs = await _storage;
    await prefs.remove(_healthProblemKey);
    await prefs.remove(_healthProblemLegacyKey);
    await prefs.remove(_calorieAdjustmentKey);
    await prefs.remove(_nutritionTargetsKey);
    await prefs.remove(_onboardingCompletedKey);
  }

  /// Removes legacy on-device weight logs. Weight history is API-only now.
  Future<void> clearWeightEntryLogs() async {
    final prefs = await _storage;
    await prefs.remove('weight_entries_v1');
  }

  Future<Map<String, int>> loadStepsByDate() async {
    final prefs = await _storage;
    final raw = prefs.getString(_activityLogKey);
    if (raw == null || raw.isEmpty) return {};

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final stepsRaw = decoded['stepsByDate'];
    if (stepsRaw is! Map) return {};

    return stepsRaw.map((key, value) {
      final steps = value is num ? value.round() : 0;
      return MapEntry(key.toString(), steps);
    });
  }

  Future<Map<String, int>> loadStepsBaselinesByDate() async {
    final prefs = await _storage;
    final raw = prefs.getString(_activityLogKey);
    if (raw == null || raw.isEmpty) return {};

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final baselineRaw = decoded['stepsBaselineByDate'];
    if (baselineRaw is! Map) return {};

    return baselineRaw.map((key, value) {
      final baseline = value is num ? value.round() : 0;
      return MapEntry(key.toString(), baseline);
    });
  }

  Future<List<ExerciseEntry>> loadExerciseEntries() async {
    final prefs = await _storage;
    final raw = prefs.getString(_activityLogKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = decoded['exercises'];
    if (list is! List) return [];

    return list
        .map((item) => ExerciseEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveActivityLog({
    required Map<String, int> stepsByDate,
    required Map<String, int> stepsBaselineByDate,
    required List<ExerciseEntry> exercises,
  }) async {
    final prefs = await _storage;
    final encoded = jsonEncode({
      'stepsByDate': stepsByDate,
      'stepsBaselineByDate': stepsBaselineByDate,
      'exercises': exercises.map((entry) => entry.toJson()).toList(),
    });
    await prefs.setString(_activityLogKey, encoded);
  }
}
