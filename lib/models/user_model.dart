import 'dart:typed_data';

import 'activity_level.dart';
import 'goal_type.dart';
import '../core/weight_goal_calculator.dart';

class UserModel {
  String name = 'John';
  String email = '';
  Uint8List? profilePhotoBytes;
  GoalType? goal;
  int age = 25;
  String gender = 'Male';
  int heightCm = 170;
  int weightKg = 70;
  double? manualGoalWeightKg;

  /// User offset applied on top of the calculated calorie goal (can be negative).
  int manualCalorieAdjustment = 0;

  ActivityLevel activityLevel = ActivityLevel.moderatelyActive;
  DateTime targetDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  ).add(const Duration(days: 90));

  bool get isGoalWeightManual => manualGoalWeightKg != null;

  double get recommendedGoalWeightKg => WeightGoalCalculator.recommendedGoalWeight(
        goal: goal,
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        gender: gender,
      );

  /// Active target — manual override or suggested recommendation.
  double get goalWeightKg => manualGoalWeightKg ?? recommendedGoalWeightKg;

  double get bmr =>
      10 * weightKg + 6.25 * heightCm - 5 * age + (gender == 'Male' ? 5 : -161);

  double get _activityMultiplier => switch (activityLevel) {
        ActivityLevel.sedentary => 1.2,
        ActivityLevel.lightlyActive => 1.375,
        ActivityLevel.moderatelyActive => 1.55,
        ActivityLevel.veryActive => 1.725,
      };

  /// Calories to maintain current weight (TDEE).
  int get maintenanceCalories =>
      (bmr * _activityMultiplier).round().clamp(1200, 4000);

  /// Calorie goal from profile (before manual add/deduct).
  int get calculatedDailyCalorieGoal {
    final tdee = maintenanceCalories;

    if (goal == null || goal == GoalType.maintainWeight) {
      return tdee;
    }

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final daysUntilTarget = targetDate.difference(today).inDays.clamp(1, 730);
    final weeks = daysUntilTarget / 7.0;
    final weightDiff = goalWeightKg - weightKg;

    if (weightDiff.abs() < 0.1) return tdee;

    // ~7,700 kcal per kg; spread across days until the target date.
    final dailyAdjustment = (weightDiff / weeks * 7700 / 7).round();
    final cappedAdjustment = dailyAdjustment.clamp(-1000, 750);

    return (tdee + cappedAdjustment).clamp(1200, 4000);
  }

  /// Final daily calorie goal including [manualCalorieAdjustment].
  int get dailyCalorieGoal =>
      (calculatedDailyCalorieGoal + manualCalorieAdjustment).clamp(1200, 4000);

  bool get hasManualCalorieAdjustment => manualCalorieAdjustment != 0;

  double get weightChangeKg => goalWeightKg - weightKg;

  /// Suggested daily macro targets (grams) from calorie goal.
  int get proteinGoalG => (dailyCalorieGoal * 0.30 / 4).round();
  int get carbsGoalG => (dailyCalorieGoal * 0.40 / 4).round();
  int get fatGoalG => (dailyCalorieGoal * 0.30 / 9).round();
}
