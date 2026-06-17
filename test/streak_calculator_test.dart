import 'package:calorie_ai/core/streak_calculator.dart';
import 'package:calorie_ai/models/food_item.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:flutter_test/flutter_test.dart';

FoodItem _food() => const FoodItem(
      name: 'Rice',
      caloriesPer100g: 130,
      protein: 2.7,
      carbs: 28,
      fat: 0.3,
    );

MealEntry _entry(DateTime date) => MealEntry(
      food: _food(),
      grams: 100,
      meal: 'Lunch',
      date: date,
    );

void main() {
  final today = DateTime(2026, 6, 10);
  final yesterday = DateTime(2026, 6, 9);
  final twoDaysAgo = DateTime(2026, 6, 8);

  group('computeCurrentStreak', () {
    test('returns 0 when no entries', () {
      expect(
        StreakCalculator.computeCurrentStreak({}, asOf: today),
        0,
      );
    });

    test('counts consecutive days ending today', () {
      final dates = {
        MealEntry.normalizeDate(today),
        MealEntry.normalizeDate(yesterday),
        MealEntry.normalizeDate(twoDaysAgo),
      };
      expect(
        StreakCalculator.computeCurrentStreak(dates, asOf: today),
        3,
      );
    });

    test('preserves streak through today when yesterday was logged', () {
      final dates = {MealEntry.normalizeDate(yesterday)};
      expect(
        StreakCalculator.computeCurrentStreak(dates, asOf: today),
        1,
      );
    });

    test('breaks when gap is more than one day', () {
      final dates = {MealEntry.normalizeDate(twoDaysAgo)};
      expect(
        StreakCalculator.computeCurrentStreak(dates, asOf: today),
        0,
      );
    });
  });

  group('computeLongestStreak', () {
    test('finds longest run across history', () {
      final dates = {
        MealEntry.normalizeDate(DateTime(2026, 6, 1)),
        MealEntry.normalizeDate(DateTime(2026, 6, 2)),
        MealEntry.normalizeDate(DateTime(2026, 6, 3)),
        MealEntry.normalizeDate(DateTime(2026, 6, 10)),
        MealEntry.normalizeDate(DateTime(2026, 6, 11)),
      };
      expect(StreakCalculator.computeLongestStreak(dates), 3);
    });
  });

  group('compute', () {
    test('marks streak as at risk when yesterday logged but not today', () {
      final stats = StreakCalculator.compute(
        [_entry(yesterday)],
        asOf: today,
      );
      expect(stats.currentStreak, 1);
      expect(stats.hasLoggedToday, isFalse);
      expect(stats.isAtRisk, isTrue);
    });

    test('uses stored longest when higher than computed', () {
      final stats = StreakCalculator.compute(
        [_entry(today)],
        storedLongest: 20,
        asOf: today,
      );
      expect(stats.longestStreak, 20);
    });
  });
}
