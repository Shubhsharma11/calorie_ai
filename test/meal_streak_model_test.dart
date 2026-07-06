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

  test('MealStreakModel.toStreakStats builds calendar days', () {
    final model = MealStreakModel(
      currentStreak: 3,
      longestStreak: 8,
      hasLoggedToday: true,
      isAtRisk: false,
      loggedDates: {
        DateTime(2026, 6, 8),
        DateTime(2026, 6, 9),
        DateTime(2026, 6, 10),
      },
    );

    final stats = model.toStreakStats(storedLongest: 5);
    expect(stats.currentStreak, 3);
    expect(stats.longestStreak, 8);
    expect(stats.recentDays.length, 30);
  });
}
