import 'package:calorie_ai/models/food_item.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/models/meal_type.dart';
import 'package:calorie_ai/models/saved_meal_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SavedMealItem round-trips through json', () {
    const item = SavedMealItem(
      food: FoodItem(
        name: 'Oats',
        caloriesPer100g: 389,
        protein: 16.9,
        carbs: 66.3,
        fat: 6.9,
        emoji: '🥣',
      ),
      grams: 150,
      meal: MealType.breakfast,
    );

    final restored = SavedMealItem.fromJson(item.toJson());
    expect(restored.food.name, 'Oats');
    expect(restored.grams, 150);
    expect(restored.meal, MealType.breakfast);
    expect(restored.calories, 584);
  });

  test('SavedMealItem.historyFromEntries returns unique recent meals', () {
    final entries = [
      MealEntry(
        food: const FoodItem(
          name: 'Oats',
          caloriesPer100g: 389,
          protein: 16.9,
          carbs: 66.3,
          fat: 6.9,
        ),
        grams: 150,
        meal: MealType.breakfast,
        date: DateTime(2026, 6, 22),
      ),
      MealEntry(
        food: const FoodItem(
          name: 'Oats',
          caloriesPer100g: 389,
          protein: 16.9,
          carbs: 66.3,
          fat: 6.9,
        ),
        grams: 150,
        meal: MealType.breakfast,
        date: DateTime(2026, 6, 23),
      ),
      MealEntry(
        food: const FoodItem(
          name: 'Dal',
          caloriesPer100g: 105,
          protein: 7.5,
          carbs: 14,
          fat: 2.5,
        ),
        grams: 200,
        meal: MealType.lunch,
        date: DateTime(2026, 6, 23),
      ),
    ];

    final history = SavedMealItem.historyFromEntries(entries);
    expect(history.length, 2);
    expect(history.first.food.name, 'Dal');
    expect(
      SavedMealItem.historyFromEntries(entries, meal: MealType.breakfast).length,
      1,
    );
  });
}
