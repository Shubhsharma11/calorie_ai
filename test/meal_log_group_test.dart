import 'package:calorie_ai/core/meal_log_group.dart';
import 'package:calorie_ai/models/food_item.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/models/meal_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const oats = FoodItem(
    name: 'Oats',
    caloriesPer100g: 389,
    protein: 16.9,
    carbs: 66.3,
    fat: 6.9,
    emoji: '🥣',
  );

  test('MealLogGroup groups identical food and portion', () {
    final today = MealEntry.normalizeDate(DateTime.now());
    final groups = MealLogGroup.fromEntries([
      MealEntry(
        id: '1',
        food: oats,
        grams: 100,
        meal: MealType.breakfast,
        date: today,
      ),
      MealEntry(
        id: '2',
        food: oats,
        grams: 100,
        meal: MealType.breakfast,
        date: today,
      ),
      MealEntry(
        id: '3',
        food: oats,
        grams: 150,
        meal: MealType.breakfast,
        date: today,
      ),
    ]);

    expect(groups, hasLength(2));
    expect(groups.first.count, 2);
    expect(groups.first.totalCalories, greaterThan(0));
    expect(groups.last.count, 1);
  });
}
