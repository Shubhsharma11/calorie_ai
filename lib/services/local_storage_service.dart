import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/exercise_entry.dart';

/// Device-only prefs. Meals, weight, water, profile, and nutrition are API-only.
///
/// Kept on disk:
/// - auth session (required to stay signed in)
/// - welcome intro + coach marks (one-time device UX)
/// - pedometer baselines / step opt-in (Health Connect is device-local)
class LocalStorageService {
  LocalStorageService([this._prefs, this.userId]);

  final String? userId;

  SharedPreferences? _prefs;

  static const _authSessionKey = 'auth_session_v1';
  static const _coachMarksSeenKey = 'coach_marks_seen_v1';
  static const _welcomeIntroSeenKey = 'welcome_intro_seen_v1';
  static const _activityLogKey = 'activity_log_v1';
  static const _stepTrackingEnabledKey = 'step_tracking_enabled_v1';
  static const _legacyKeysWipedKey = 'legacy_api_cache_wiped_v3';

  Future<SharedPreferences> get _storage async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// One-shot wipe of old meal/profile/onboarding caches from earlier builds.
  Future<void> wipeLegacyApiCachesIfNeeded() async {
    final prefs = await _storage;
    if (prefs.getBool(_legacyKeysWipedKey) ?? false) return;

    const legacy = <String>[
      'longest_streak',
      'celebrated_streak_milestones',
      'manual_calorie_adjustment',
      'nutrition_targets_v1',
      'health_problem_v2',
      'health_problem_v1',
      'onboarding_completed_v1',
      'onboarding_step_v1',
      'onboarding_draft_v1',
      'weight_entries_v1',
      'home_tutorial_seen_v1',
      'home_tutorial_pending_v1',
      'favorite_meals_v1',
      'custom_meals_v1',
      'custom_foods_v1',
      'goal_start_weight_kg_v1',
    ];
    for (final key in legacy) {
      await prefs.remove(key);
    }
    // Guest / per-user meal dumps from old builds.
    for (final key in prefs.getKeys()) {
      if (key.startsWith('meal_entries_v1_') ||
          key.startsWith('goal_start_weight_kg_v1')) {
        await prefs.remove(key);
      }
    }
    await prefs.setBool(_legacyKeysWipedKey, true);
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
    bool setupComplete = false,
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
      'setupComplete': setupComplete,
      'loggedInAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_authSessionKey, encoded);
  }

  Future<void> clearAuthSession() async {
    final prefs = await _storage;
    await prefs.remove(_authSessionKey);
  }

  /// True after the user finishes (or skips) the welcome intro slides.
  Future<bool> isWelcomeIntroSeen() async {
    final prefs = await _storage;
    return prefs.getBool(_welcomeIntroSeenKey) ?? false;
  }

  Future<void> saveWelcomeIntroSeen({required bool seen}) async {
    final prefs = await _storage;
    await prefs.setBool(_welcomeIntroSeenKey, seen);
  }

  Future<bool> isCoachMarksSeen() async {
    final prefs = await _storage;
    return prefs.getBool(_coachMarksKeyForUser) ?? false;
  }

  Future<void> saveCoachMarksSeen({required bool seen}) async {
    final prefs = await _storage;
    await prefs.setBool(_coachMarksKeyForUser, seen);
  }

  String get _coachMarksKeyForUser {
    final id = userId?.trim();
    if (id != null && id.isNotEmpty) {
      return '${_coachMarksSeenKey}_$id';
    }
    return _coachMarksSeenKey;
  }

  /// Clears session-adjacent leftovers on logout. Auth is cleared separately.
  Future<void> clearUserProfileCache() async {
    // Profile / meals / onboarding are API-owned — nothing to clear on disk.
    // Keep welcome intro + coach marks (device UX).
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

  Future<bool> loadStepTrackingEnabled() async {
    final prefs = await _storage;
    return prefs.getBool(_stepTrackingEnabledKey) ?? true;
  }

  Future<void> saveStepTrackingEnabled(bool enabled) async {
    final prefs = await _storage;
    await prefs.setBool(_stepTrackingEnabledKey, enabled);
  }
}
