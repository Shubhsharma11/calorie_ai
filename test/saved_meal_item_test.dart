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

  test('historyFromEntries skips excluded food names and fills the limit', () {
    final entries = [
      MealEntry(
        food: const FoodItem(
          name: 'Protein Shake',
          caloriesPer100g: 120,
          protein: 20,
          carbs: 4,
          fat: 2,
        ),
        grams: 100,
        meal: MealType.breakfast,
        date: DateTime(2026, 6, 23),
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
        date: DateTime(2026, 6, 22),
      ),
    ];

    final history = SavedMealItem.historyFromEntries(
      entries,
      limit: 5,
      excludeFoodNames: {'protein shake'},
    );
    expect(history, hasLength(1));
    expect(history.first.food.name, 'Oats');
  });

  test('toMealEntry keeps gram quantity instead of rewriting to 100 g', () {
    const item = SavedMealItem(
      food: FoodItem(
        name: 'Oats',
        caloriesPer100g: 389,
        protein: 16.9,
        carbs: 66.3,
        fat: 6.9,
      ),
      grams: 100,
      meal: MealType.breakfast,
      servingQuantity: 150,
      servingUnit: 'g',
      nutritionBasisQuantity: 100,
      basisCarbs: 66.3,
      basisProtein: 16.9,
      basisFat: 6.9,
    );

    final entry = item.toMealEntry(date: DateTime(2026, 6, 23));
    expect(entry.grams, 150);
    expect(entry.quantityLabel, '150 g');
    expect(entry.calories, 584);
  });

  test('toMealEntry keeps bowl serving on the diary label', () {
    const item = SavedMealItem(
      food: FoodItem(
        name: 'Dal',
        caloriesPer100g: 210,
        protein: 12,
        carbs: 28,
        fat: 5,
      ),
      grams: 100,
      meal: MealType.lunch,
      servingQuantity: 1,
      servingUnit: 'bowl',
      nutritionBasisQuantity: 1,
      basisCarbs: 28,
      basisProtein: 12,
      basisFat: 5,
    );

    final entry = item.toMealEntry(date: DateTime(2026, 6, 23));
    expect(entry.food.servingUnit, 'bowl');
    expect(entry.quantityLabel, '1 Bowl (100 g)');
    expect(entry.calories, 210);
  });

  test('toMealEntry keeps user-entered glass calories', () {
    const item = SavedMealItem(
      food: FoodItem(
        name: 'Aam Panna',
        caloriesPer100g: 110,
        protein: 1,
        carbs: 26,
        fat: 0,
      ),
      grams: 100,
      meal: MealType.breakfast,
      servingQuantity: 1,
      servingUnit: 'glass',
      nutritionBasisQuantity: 1,
      basisCarbs: 26,
      basisProtein: 1,
      basisFat: 0,
    );

    final entry = item.toMealEntry(date: DateTime(2026, 6, 23));
    expect(entry.calories, 110);
    expect(entry.food.servingUnit, 'glass');
  });

  test('toMealEntry keeps milliliter quantity', () {
    const item = SavedMealItem(
      food: FoodItem(
        name: 'Buttermilk',
        caloriesPer100g: 32,
        protein: 1.6,
        carbs: 4,
        fat: 0.8,
      ),
      grams: 100,
      meal: MealType.breakfast,
      servingQuantity: 250,
      servingUnit: 'ml',
      nutritionBasisQuantity: 100,
      basisCarbs: 4,
      basisProtein: 1.6,
      basisFat: 0.8,
    );

    final entry = item.toMealEntry(date: DateTime(2026, 6, 23));
    expect(entry.grams, 250);
    expect(entry.food.servingUnit, 'ml');
    expect(entry.quantityLabel, '250 ml');
  });

  test('FoodItem.isSameFavoriteFood matches by name, not portion', () {
    const bowl = FoodItem(
      name: 'Achari Aloo',
      caloriesPer100g: 102,
      protein: 2,
      carbs: 18,
      fat: 3,
      catalogId: 'food-1',
    );
    const otherPortion = FoodItem(
      name: 'Achari Aloo',
      caloriesPer100g: 102,
      protein: 2,
      carbs: 18,
      fat: 3,
    );
    const otherFood = FoodItem(
      name: 'Dal Tadka',
      caloriesPer100g: 110,
      protein: 6,
      carbs: 12,
      fat: 4,
    );

    expect(bowl.isSameFavoriteFood(otherPortion), isTrue);
    expect(bowl.isSameFavoriteFood(otherFood), isFalse);
  });
}
