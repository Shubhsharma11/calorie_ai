import 'package:calorie_ai/controllers/food_controller.dart';
import 'package:calorie_ai/models/food_item.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/models/meal_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  test('recentQuickMeals reads from apiMeals not local entries', () {
    final food = FoodController();

    const oats = FoodItem(
      name: 'Oats',
      caloriesPer100g: 389,
      protein: 16.9,
      carbs: 66.3,
      fat: 6.9,
      emoji: '🥣',
    );
    const rice = FoodItem(
      name: 'Rice',
      caloriesPer100g: 130,
      protein: 2.7,
      carbs: 28,
      fat: 0.3,
      emoji: '🍚',
    );

    final today = MealEntry.normalizeDate(DateTime.now());
    food.entries.add(
      MealEntry(
        id: 'local-only',
        food: oats,
        grams: 150,
        meal: MealType.breakfast,
        date: today,
      ),
    );
    food.apiMeals.add(
      MealEntry(
        id: 'api-1',
        food: rice,
        grams: 200,
        meal: MealType.lunch,
        date: today,
      ),
    );

    final quick = food.recentQuickMeals;

    expect(quick, hasLength(1));
    expect(quick.first.food.name, 'Rice');
  });

  test('quickMealsFor uses apiMeals history for meal slot', () {
    final food = FoodController();

    const oats = FoodItem(
      name: 'Oats',
      caloriesPer100g: 389,
      protein: 16.9,
      carbs: 66.3,
      fat: 6.9,
      emoji: '🥣',
    );

    final today = MealEntry.normalizeDate(DateTime.now());
    food.apiMeals.add(
      MealEntry(
        id: 'api-1',
        food: oats,
        grams: 150,
        meal: MealType.breakfast,
        date: today,
      ),
    );

    final quick = food.quickMealsFor(MealType.breakfast);

    expect(quick, hasLength(1));
    expect(quick.first.food.name, 'Oats');
  });
}
