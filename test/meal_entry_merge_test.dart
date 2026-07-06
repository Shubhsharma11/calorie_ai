import 'package:calorie_ai/core/meal_entry_merge.dart';
import 'package:calorie_ai/models/food_item.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/models/meal_type.dart';
import 'package:flutter_test/flutter_test.dart';

FoodItem _food(String name) => FoodItem(
      name: name,
      caloriesPer100g: 100,
      protein: 1,
      carbs: 1,
      fat: 1,
    );

void main() {
  test('mergeAll keeps local-only meals not returned by API', () {
    final local = [
      MealEntry(
        id: 'local-1',
        food: _food('Banana'),
        grams: 100,
        meal: MealType.breakfast,
      ),
    ];
    final fetched = [
      MealEntry(
        id: 'server-1',
        food: _food('Oats'),
        grams: 150,
        meal: MealType.breakfast,
      ),
    ];

    final merged = MealEntryMerge.mergeAll(current: local, fetched: fetched);

    expect(merged.length, 2);
    expect(merged.any((entry) => entry.id == 'local-1'), isTrue);
    expect(merged.any((entry) => entry.id == 'server-1'), isTrue);
  });

  test('mergeForDay keeps unsynced meals for that day', () {
    final today = MealEntry.normalizeDate(DateTime.now());
    final local = [
      MealEntry(
        id: 'local-today',
        food: _food('Apple'),
        grams: 120,
        meal: MealType.snacks,
        date: today,
      ),
      MealEntry(
        id: 'server-old',
        food: _food('Rice'),
        grams: 200,
        meal: MealType.lunch,
        date: today,
      ),
    ];
    final fetched = [
      MealEntry(
        id: 'server-old',
        food: _food('Rice'),
        grams: 180,
        meal: MealType.lunch,
        date: today,
      ),
    ];

    final merged = MealEntryMerge.mergeForDay(
      current: local,
      day: today,
      fetched: fetched,
    );

    expect(merged.length, 2);
    expect(merged.any((entry) => entry.id == 'local-today'), isTrue);
    expect(
      merged.firstWhere((entry) => entry.id == 'server-old').grams,
      180,
    );
  });
}
