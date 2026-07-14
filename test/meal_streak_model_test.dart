import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/models/meal_streak_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MealStreakModel.fromJson maps streak fields from data wrapper', () {
    final model = MealStreakModel.fromJson({
      'data': {
        'currentStreak': 5,
        'longestStreak': 12,
        'hasLoggedToday': true,
        'isAtRisk': false,
        'loggedDates': ['2026-06-08', '2026-06-09', '2026-06-10'],
      },
    });

    expect(model.currentStreak, 5);
    expect(model.longestStreak, 12);
    expect(model.hasLoggedToday, isTrue);
    expect(model.isAtRisk, isFalse);
    expect(model.loggedDates.length, 3);
  });

  test('MealStreakModel.fromJson reads snake_case fields', () {
    final model = MealStreakModel.fromJson({
      'current_streak': 2,
      'longest_streak': 4,
      'has_logged_today': false,
      'is_at_risk': true,
      'logged_dates': ['2026-06-09', '2026-06-10'],
    });

    expect(model.currentStreak, 2);
    expect(model.longestStreak, 4);
    expect(model.hasLoggedToday, isFalse);
    expect(model.isAtRisk, isTrue);
    expect(model.loggedDates.length, 2);
  });

  test('MealStreakModel.toStreakStats uses only real calendar dates', () {
    final model = MealStreakModel(
      currentStreak: 3,
      longestStreak: 8,
      hasLoggedToday: true,
      isAtRisk: false,
      loggedDates: const {},
    );

    final today = MealEntry.normalizeDate(DateTime.now());
    final dates = {
      today,
      today.subtract(const Duration(days: 1)),
      today.subtract(const Duration(days: 2)),
    };

    final stats = model.toStreakStats(calendarDates: dates);
    expect(stats.currentStreak, 3);
    expect(stats.recentDays.where((day) => day.logged).length, 3);
  });

  test('MealStreakModel.toStreakStats does not infer dates when calendar empty', () {
    final model = MealStreakModel(
      currentStreak: 3,
      longestStreak: 8,
      hasLoggedToday: true,
      isAtRisk: false,
      loggedDates: const {},
    );

    final stats = model.toStreakStats();
    expect(stats.recentDays.where((day) => day.logged), isEmpty);
  });
}
