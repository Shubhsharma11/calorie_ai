import '../core/streak_calculator.dart';
import '../models/meal_entry.dart';

/// Streak data returned by `GET /api/v1/meals/streak`.
class MealStreakModel {
  const MealStreakModel({
    required this.currentStreak,
    required this.longestStreak,
    required this.hasLoggedToday,
    required this.isAtRisk,
    required this.loggedDates,
  });

  final int currentStreak;
  final int longestStreak;
  final bool hasLoggedToday;
  final bool isAtRisk;
  final Set<DateTime> loggedDates;

  factory MealStreakModel.fromJson(Map<String, dynamic> json) {
    final data = _unwrapData(json);
    final streak = _firstMap(data, const ['streak']) ?? data;

    final loggedDates = _readLoggedDates(streak);
    final current = _readInt(streak, const [
          'currentStreak',
          'current_streak',
          'streak',
          'days',
        ]) ??
        StreakCalculator.computeCurrentStreak(loggedDates);
    final longest = _readInt(streak, const [
          'longestStreak',
          'longest_streak',
          'bestStreak',
          'best_streak',
        ]) ??
        StreakCalculator.computeLongestStreak(loggedDates);
    final hasLoggedToday = _readBool(streak, const [
          'hasLoggedToday',
          'has_logged_today',
          'loggedToday',
          'logged_today',
        ]) ??
        StreakCalculator.hasLoggedOn(
          loggedDates,
          day: DateTime.now(),
        );
    final isAtRisk = _readBool(streak, const [
          'isAtRisk',
          'is_at_risk',
          'atRisk',
          'at_risk',
        ]) ??
        (current > 0 && !hasLoggedToday);

    return MealStreakModel(
      currentStreak: current,
      longestStreak: longest,
      hasLoggedToday: hasLoggedToday,
      isAtRisk: isAtRisk,
      loggedDates: loggedDates,
    );
  }

  StreakStats toStreakStats({
    Set<DateTime>? calendarDates,
    int storedLongest = 0,
    int calendarDays = 30,
  }) {
    final dates = calendarDates ?? loggedDates;
    final computedLongest = StreakCalculator.computeLongestStreak(dates);
    final longest = [
      longestStreak,
      computedLongest,
      storedLongest,
    ].reduce((a, b) => a > b ? a : b);

    return StreakStats(
      currentStreak: currentStreak,
      longestStreak: longest,
      hasLoggedToday: hasLoggedToday,
      isAtRisk: isAtRisk,
      recentDays: StreakCalculator.buildRecentDays(
        dates,
        dayCount: calendarDays,
        currentStreakOverride: currentStreak,
      ),
    );
  }

  static Map<String, dynamic> _unwrapData(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return json;
  }

  static Map<String, dynamic>? _firstMap(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static int? _readInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.round();
      if (value is String) return int.tryParse(value);
    }
    return null;
  }

  static bool? _readBool(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is bool) return value;
      if (value is String) {
        final normalized = value.toLowerCase();
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
      }
      if (value is num) return value != 0;
    }
    return null;
  }

  static Set<DateTime> _readLoggedDates(Map<String, dynamic> map) {
    for (final key in const [
      'loggedDates',
      'logged_dates',
      'dates',
      'mealDates',
      'meal_dates',
      'days',
      'calendar',
      'recentDays',
      'recent_days',
    ]) {
      final value = map[key];
      if (value is! List) continue;

      final dates = <DateTime>{};
      for (final item in value) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final logged = _readBool(map, const [
            'logged',
            'hasLogged',
            'has_logged',
            'isLogged',
            'is_logged',
          ]);
          if (logged == false) continue;
          final parsed = _parseDate(map);
          if (parsed != null) dates.add(parsed);
          continue;
        }
        final parsed = _parseDate(item);
        if (parsed != null) dates.add(parsed);
      }
      if (dates.isNotEmpty) return dates;
    }

    return {};
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return MealEntry.normalizeDate(parsed);
      }
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final raw = map['date'] ??
          map['day'] ??
          map['loggedAt'] ??
          map['logged_at'] ??
          map['loggedDate'] ??
          map['logged_date'];
      if (raw is String) return _parseDate(raw);
    }
    return null;
  }
}
