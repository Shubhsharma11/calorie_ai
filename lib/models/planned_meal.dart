import '../models/meal_type.dart';

enum PlannedMealStatus { next, upcoming, completed }

class PlannedMeal {
  const PlannedMeal({
    required this.id,
    required this.mealType,
    required this.name,
    required this.timeLabel,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.status,
    required this.description,
    required this.ingredients,
    required this.why,
  });

  final String id;
  final String mealType;
  final String name;
  final String timeLabel;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final PlannedMealStatus status;
  final String description;
  final List<String> ingredients;
  final String why;

  PlannedMeal copyWith({PlannedMealStatus? status}) {
    return PlannedMeal(
      id: id,
      mealType: mealType,
      name: name,
      timeLabel: timeLabel,
      calories: calories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      status: status ?? this.status,
      description: description,
      ingredients: ingredients,
      why: why,
    );
  }
}

/// Sample weekly plan used until a dedicated meal-plan API is available.
abstract final class SampleWeeklyMealPlan {
  static const _sharedIngredients = [
    'Rolled oats (40g)',
    'Banana (1 Medium)',
    'Almonds (10g)',
    'Milk (200ml)',
  ];

  static const _sharedWhy =
      'High in fibre and good carbs to give you sustained energy throughout the morning.';

  static const _sharedDescription =
      'A Perfect high-fibre breakfast to keep you full and energized';

  static List<PlannedMeal> mealsForWeekday(int weekday) {
    // Same sample structure for every day; statuses mirror the design.
    return [
      const PlannedMeal(
        id: 'breakfast',
        mealType: MealType.breakfast,
        name: 'Oats + Banana + Almonds',
        timeLabel: '9:30 AM',
        calories: 420,
        proteinG: 20,
        carbsG: 55,
        fatG: 12,
        status: PlannedMealStatus.completed,
        description: _sharedDescription,
        ingredients: _sharedIngredients,
        why: _sharedWhy,
      ),
      const PlannedMeal(
        id: 'lunch',
        mealType: MealType.lunch,
        name: 'Oats + Banana + Almonds',
        timeLabel: '9:30 AM',
        calories: 420,
        proteinG: 20,
        carbsG: 55,
        fatG: 12,
        status: PlannedMealStatus.next,
        description: _sharedDescription,
        ingredients: _sharedIngredients,
        why: _sharedWhy,
      ),
      const PlannedMeal(
        id: 'snacks',
        mealType: 'Evening Snacks',
        name: 'Oats + Banana + Almonds',
        timeLabel: '9:30 PM',
        calories: 420,
        proteinG: 20,
        carbsG: 55,
        fatG: 12,
        status: PlannedMealStatus.upcoming,
        description: _sharedDescription,
        ingredients: _sharedIngredients,
        why: _sharedWhy,
      ),
      const PlannedMeal(
        id: 'dinner',
        mealType: MealType.dinner,
        name: 'Oats + Banana + Almonds',
        timeLabel: '9:30 AM',
        calories: 420,
        proteinG: 20,
        carbsG: 55,
        fatG: 12,
        status: PlannedMealStatus.upcoming,
        description: _sharedDescription,
        ingredients: _sharedIngredients,
        why: _sharedWhy,
      ),
    ];
  }
}
