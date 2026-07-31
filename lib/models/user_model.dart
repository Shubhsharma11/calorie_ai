import 'dart:typed_data';

import 'activity_level.dart';
import 'goal_type.dart';
import 'health_concern.dart';
import '../core/weight_goal_calculator.dart';

/// In-memory profile. Body metrics are nullable until the API / onboarding
/// supplies them — never invent John / 70kg / age-25 placeholders.
class UserModel {
  String name = '';
  String email = '';

  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  Uint8List? profilePhotoBytes;
  GoalType? goal;

  int? age;
  String? gender;
  int? heightCm;
  int? weightKg;

  double? manualGoalWeightKg;

  /// Absolute lose/gain target from Goals / onboarding.
  /// Never updated by Weight Progress logs — only by explicit goal edits.
  double? pinnedGoalWeightKg;

  /// Goal type chosen in Goals / onboarding (survives weight-API profile mutations).
  GoalType? pinnedGoalType;

  /// Weight when the current target was set (from API `startWeight`, not disk).
  double? goalStartWeightKg;
  List<HealthConcern> healthConcerns = [];

  bool get hasHealthConcernsConfigured => healthConcerns.isNotEmpty;

  bool get hasNoHealthConcerns =>
      healthConcerns.length == 1 && healthConcerns.first.isNone;

  String get healthProblemCategory {
    if (healthConcerns.isEmpty) return '';
    if (hasNoHealthConcerns) return HealthConcern.noneCategory;
    return healthConcerns.map((concern) => concern.category).join(', ');
  }

  /// User offset applied on top of the calculated calorie goal (can be negative).
  int manualCalorieAdjustment = 0;

  /// API-recommended daily calories from the nutrition plan.
  int? nutritionPlanBaseCalories;

  /// Active daily calorie goal from the nutrition plan (may be user-adjusted).
  int? nutritionPlanDailyCalories;

  int? nutritionPlanProteinG;
  int? nutritionPlanCarbsG;
  int? nutritionPlanFatG;

  ActivityLevel? activityLevel;
  DateTime targetDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  ).add(const Duration(days: 90));

  /// True once onboarding/API has filled real body metrics.
  bool get hasProfileBasics {
    final a = age;
    final h = heightCm;
    final w = weightKg;
    final g = gender?.trim() ?? '';
    return a != null &&
        a > 0 &&
        h != null &&
        h > 0 &&
        w != null &&
        w > 0 &&
        g.isNotEmpty;
  }

  bool get isGoalWeightManual =>
      manualGoalWeightKg != null || pinnedGoalWeightKg != null;

  double get recommendedGoalWeightKg {
    if (!hasProfileBasics) return 0;
    return WeightGoalCalculator.recommendedGoalWeight(
      goal: goal,
      weightKg: weightKg!,
      heightCm: heightCm!,
      age: age!,
      gender: gender!,
    );
  }

  /// Active target for home + profile.
  ///
  /// Lose/gain always use the pinned onboarding/goal target — never a live
  /// recalculation from the latest weigh-in.
  double get goalWeightKg {
    final effectiveGoal = pinnedGoalType ?? goal;
    final current = weightKg?.toDouble() ?? 0;
    if (effectiveGoal == GoalType.maintainWeight) {
      return current;
    }
    if (pinnedGoalWeightKg != null) return pinnedGoalWeightKg!;
    if (manualGoalWeightKg != null) return manualGoalWeightKg!;
    return recommendedGoalWeightKg;
  }

  void pinGoalWeight(double kg, {GoalType? goalType}) {
    final clamped = kg.clamp(40.0, 200.0);
    pinnedGoalWeightKg = clamped;
    manualGoalWeightKg = clamped;
    if (goalType != null) {
      pinnedGoalType = goalType;
      goal = goalType;
    } else if (goal != null && goal != GoalType.maintainWeight) {
      pinnedGoalType = goal;
    }
  }

  void clearPinnedGoalWeight() {
    pinnedGoalWeightKg = null;
    manualGoalWeightKg = null;
    pinnedGoalType = null;
  }

  double get bmr {
    if (!hasProfileBasics) return 0;
    return 10 * weightKg! +
        6.25 * heightCm! -
        5 * age! +
        (gender == 'Male' ? 5 : -161);
  }

  double get _activityMultiplier => switch (activityLevel) {
    ActivityLevel.sedentary => 1.2,
    ActivityLevel.lightlyActive => 1.375,
    ActivityLevel.moderatelyActive => 1.55,
    ActivityLevel.veryActive => 1.725,
    null => 1.2,
  };

  /// Calories to maintain current weight (TDEE).
  int get maintenanceCalories {
    if (!hasProfileBasics) return 0;
    return (bmr * _activityMultiplier).round().clamp(1200, 4000);
  }

  /// Client fallback calorie goal from body metrics (before manual add/deduct).
  /// Prefer [dailyCalorieGoal] which is API-first.
  int get calculatedDailyCalorieGoal {
    if (!hasProfileBasics) return 0;
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
    final weightDiff = goalWeightKg - weightKg!;

    if (weightDiff.abs() < 0.1) return tdee;

    // ~7,700 kcal per kg; spread across days until the target date.
    final dailyAdjustment = (weightDiff / weeks * 7700 / 7).round();
    final cappedAdjustment = dailyAdjustment.clamp(-1000, 750);

    return (tdee + cappedAdjustment).clamp(1200, 4000);
  }

  /// API nutrition plan first; otherwise calculate only when profile exists.
  int get dailyCalorieGoal {
    final plan = nutritionPlanDailyCalories;
    if (plan != null && plan > 0) {
      return plan.clamp(0, 10000);
    }
    if (!hasProfileBasics) return 0;
    return (calculatedDailyCalorieGoal + manualCalorieAdjustment).clamp(
      0,
      10000,
    );
  }

  bool get hasManualCalorieAdjustment {
    if (nutritionPlanBaseCalories != null &&
        nutritionPlanDailyCalories != null) {
      return nutritionPlanDailyCalories != nutritionPlanBaseCalories;
    }
    return manualCalorieAdjustment != 0;
  }

  double get weightChangeKg => goalWeightKg - (weightKg?.toDouble() ?? 0);

  /// Onboarding API timeline: `1week` | `2week` | `1month` | `custom`.
  String get goalTimeline {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final days = target.difference(today).inDays;
    final weeks = (days / 7).round().clamp(1, 520);
    return switch (weeks) {
      1 => '1week',
      2 => '2week',
      4 => '1month',
      _ => 'custom',
    };
  }

  /// Required by the API when [goalTimeline] is `custom`.
  String? get goalTimelineCustomDate {
    if (goalTimeline != 'custom') return null;
    final year = targetDate.year.toString().padLeft(4, '0');
    final month = targetDate.month.toString().padLeft(2, '0');
    final day = targetDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Suggested daily macro targets (grams) from API plan or calorie goal.
  int get proteinGoalG =>
      nutritionPlanProteinG ?? (dailyCalorieGoal * 0.30 / 4).round();
  int get carbsGoalG =>
      nutritionPlanCarbsG ?? (dailyCalorieGoal * 0.40 / 4).round();
  int get fatGoalG =>
      nutritionPlanFatG ?? (dailyCalorieGoal * 0.30 / 9).round();

  /// Clears to an empty session — not fake defaults.
  void clear() {
    name = '';
    email = '';
    profilePhotoBytes = null;
    goal = null;
    age = null;
    gender = null;
    heightCm = null;
    weightKg = null;
    manualGoalWeightKg = null;
    pinnedGoalWeightKg = null;
    pinnedGoalType = null;
    goalStartWeightKg = null;
    healthConcerns = [];
    manualCalorieAdjustment = 0;
    nutritionPlanBaseCalories = null;
    nutritionPlanDailyCalories = null;
    nutritionPlanProteinG = null;
    nutritionPlanCarbsG = null;
    nutritionPlanFatG = null;
    activityLevel = null;
    targetDate = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ).add(const Duration(days: 90));
  }

  /// Alias kept for existing call sites.
  void resetToDefaults() => clear();
}
