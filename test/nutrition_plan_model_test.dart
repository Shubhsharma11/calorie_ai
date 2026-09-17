import 'package:calorie_ai/models/nutrition_plan_model.dart';
import 'package:calorie_ai/models/planned_meal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses homePreview for AI meal plan card', () {
    final plan = NutritionPlanModel.fromJson({
      'success': true,
      'data': {
        'nutritionPlan': {
          'calories': 2500,
          'proteinG': 180,
          'carbsG': 250,
          'fatG': 70,
          'goalLabel': 'Muscle Gain',
        },
        'homePreview': {
          'mealTypeLabel': 'Lunch',
          'name': 'Oats + Banana + Almonds',
          'timeLabel': '9:30 AM',
          'calories': 420,
          'proteinG': 20,
        },
      },
    });

    expect(plan.calories, 2500);
    expect(plan.goalLabel, 'Muscle Gain');
    expect(plan.previewMeal?.title, 'Lunch');
    expect(plan.previewMeal?.displayName, 'Oats + Banana + Almonds');
    expect(plan.previewMeal?.calories, 420);
    expect(plan.previewMeal?.proteinG, 20);
    expect(plan.previewMeal?.timeLabel, '9:30 AM');
  });

  test('parses meals list when homePreview missing', () {
    final plan = NutritionPlanModel.fromJson({
      'data': {
        'calories': 2000,
        'proteinG': 140,
        'meals': [
          {
            'title': 'Breakfast',
            'items': ['Oats', 'Banana', 'Milk'],
            'calories': 380,
            'protein': 18,
            'time': '8:00 AM',
          },
        ],
      },
    });

    expect(plan.previewMeal?.title, 'Breakfast');
    expect(plan.previewMeal?.displayName, 'Oats + Banana + Milk');
    expect(plan.previewMeal?.calories, 380);
    expect(plan.previewMeal?.proteinG, 18);
    expect(plan.previewMeal?.timeLabel, '8:00 AM');
  });

  test('parses weeklyMealPlan days for weekday lookup', () {
    final plan = NutritionPlanModel.fromJson({
      'data': {
        'nutritionPlan': {
          'calories': 2500,
          'proteinG': 180,
          'goalLabel': 'Muscle Gain',
        },
        'weeklyMealPlan': {
          'weekStart': '2026-09-15',
          'dailyCalorieTarget': 2500,
          'goalLabel': 'Muscle Gain',
          'days': [
            {
              'date': '2026-09-15',
              'weekday': 'Tue',
              'meals': [
                {
                  'id': 'meal_tue_1',
                  'mealType': 'breakfast',
                  'mealTypeLabel': 'Breakfast',
                  'name': 'Poha Bowl',
                  'timeLabel': '8:00 AM',
                  'calories': 350,
                  'proteinG': 12,
                  'carbsG': 55,
                  'fatG': 8,
                  'status': 'completed',
                  'description': 'Light breakfast',
                  'ingredients': ['Poha (50g)', 'Peanuts (10g)'],
                  'why': 'Easy carbs to start the day.',
                },
              ],
            },
            {
              'date': '2026-09-16',
              'weekday': 'Wed',
              'meals': [
                {
                  'id': 'meal_abc123',
                  'mealType': 'lunch',
                  'mealTypeLabel': 'Lunch',
                  'name': 'Oats + Banana + Almonds',
                  'scheduledTime': '09:30',
                  'timeLabel': '9:30 AM',
                  'calories': 420,
                  'proteinG': 20,
                  'carbsG': 55,
                  'fatG': 12,
                  'status': 'next',
                  'description': 'High-fibre meal to keep you full.',
                  'ingredients': [
                    'Rolled oats (40g)',
                    'Banana (1 Medium)',
                    'Almonds (10g)',
                    'Milk (200ml)',
                  ],
                  'why': 'Good carbs for sustained energy.',
                },
                {
                  'id': 'meal_abc124',
                  'mealType': 'dinner',
                  'mealTypeLabel': 'Dinner',
                  'name': 'Veg Khichdi',
                  'timeLabel': '8:00 PM',
                  'calories': 480,
                  'proteinG': 18,
                  'status': 'upcoming',
                },
              ],
            },
          ],
        },
        'homePreview': {
          'mealId': 'meal_abc123',
          'mealTypeLabel': 'Lunch',
          'name': 'Oats + Banana + Almonds',
          'timeLabel': '9:30 AM',
          'calories': 420,
          'proteinG': 20,
        },
      },
    });

    expect(plan.weeklyPlan, isNotNull);
    expect(plan.weeklyPlan!.dailyCalorieTarget, 2500);
    expect(plan.goalLabel, 'Muscle Gain');

    final wednesday = plan.weeklyPlan!.mealsForWeekday(DateTime.wednesday);
    expect(wednesday.length, 2);
    expect(wednesday.first.name, 'Oats + Banana + Almonds');
    expect(wednesday.first.status, PlannedMealStatus.next);
    expect(wednesday.first.ingredients.length, 4);
    expect(wednesday.last.status, PlannedMealStatus.upcoming);

    final tuesday = plan.weeklyPlan!.mealsForWeekday(DateTime.tuesday);
    expect(tuesday.single.name, 'Poha Bowl');
    expect(tuesday.single.status, PlannedMealStatus.completed);

    expect(plan.previewMeal?.displayName, 'Oats + Banana + Almonds');
  });

  test('parses weeklyMealPlan next meal when homePreview missing', () {
    final plan = NutritionPlanModel.fromJson({
      'data': {
        'nutritionPlan': {
          'calories': 2200,
          'proteinG': 150,
        },
        'weeklyMealPlan': {
          'days': [
            {
              'date': '2099-01-01',
              'weekday': 'Fri',
              'meals': [
                {
                  'mealTypeLabel': 'Breakfast',
                  'name': 'Egg Bowl',
                  'status': 'completed',
                  'calories': 300,
                  'proteinG': 22,
                },
                {
                  'mealTypeLabel': 'Lunch',
                  'name': 'Paneer Wrap',
                  'status': 'next',
                  'calories': 450,
                  'proteinG': 28,
                  'timeLabel': '1:00 PM',
                },
              ],
            },
          ],
        },
      },
    });

    expect(plan.previewMeal?.title, 'Lunch');
    expect(plan.previewMeal?.displayName, 'Paneer Wrap');
    expect(plan.previewMeal?.calories, 450);
    expect(plan.previewMeal?.timeLabel, '1:00 PM');
  });

  test('parses weeklyMealPlan when sent as a bare days list', () {
    final plan = NutritionPlanModel.fromJson({
      'data': {
        'calories': 2100,
        'weeklyMealPlan': [
          {
            'weekday': 'Thu',
            'meals': [
              {
                'mealTypeLabel': 'Dinner',
                'name': 'Dal Rice',
                'calories': 500,
                'status': 'next',
              },
            ],
          },
        ],
      },
    });

    expect(plan.weeklyPlan, isNotNull);
    final thursday = plan.weeklyPlan!.mealsForWeekday(DateTime.thursday);
    expect(thursday.single.name, 'Dal Rice');
  });
}
