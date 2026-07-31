import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/daily_nutrition.dart';
import '../models/meal_entry.dart';
import '../models/nutrition_trend_metric.dart';
import 'food_controller.dart';
import 'streak_controller.dart';
import 'tracker_controller.dart';
import 'user_controller.dart';

class DashboardController extends GetxController {
  final Rx<NutritionTrendMetric> weeklyMetric =
      NutritionTrendMetric.calories.obs;

  final ScrollController homeScrollController = ScrollController();

  int get calorieGoal => Get.find<UserController>().user.dailyCalorieGoal;

  FoodController get _food => Get.find<FoodController>();

  DateTime get viewingDate =>
      MealEntry.normalizeDate(_food.selectedLogDate.value);

  bool get isViewingToday => _food.isViewingToday;

  DailyNutrition get viewingNutrition => _food.nutritionForDate(viewingDate);

  int get exerciseCalories {
    if (!Get.isRegistered<TrackerController>()) return 0;
    final tracker = Get.find<TrackerController>();
    if (isViewingToday) return tracker.todayCaloriesBurned;
    return tracker.caloriesBurnedForDate(viewingDate);
  }

  List<DailyNutrition> get weeklyNutrition => _food.last7Days;

  int get foodCalories => viewingNutrition.calories;

  int get caloriesLeft => (calorieGoal - foodCalories).clamp(0, 99999);

  bool get isOverCalorieGoal => calorieGoal > 0 && foodCalories > calorieGoal;

  int get caloriesOver => isOverCalorieGoal ? foodCalories - calorieGoal : 0;

  /// Food remaining after subtracting burned calories (eat-back model).
  int get netCaloriesRemaining =>
      (calorieGoal - foodCalories + exerciseCalories).clamp(0, 99999);

  int get netCalorieBalance => calorieGoal - foodCalories + exerciseCalories;

  bool get isNetOverCalorieGoal => netCalorieBalance < 0;

  int get netCaloriesOver => isNetOverCalorieGoal ? -netCalorieBalance : 0;

  double get progress => calorieGoal > 0 ? foodCalories / calorieGoal : 0;

  int get goalProgressPercent => (progress * 100).round().clamp(0, 100);

  double get proteinProgress {
    final goal = Get.find<UserController>().user.proteinGoalG;
    return goal > 0
        ? (viewingNutrition.protein / goal).clamp(0.0, 1.0)
        : 0;
  }

  double get carbsProgress {
    final goal = Get.find<UserController>().user.carbsGoalG;
    return goal > 0 ? (viewingNutrition.carbs / goal).clamp(0.0, 1.0) : 0;
  }

  double get fatProgress {
    final goal = Get.find<UserController>().user.fatGoalG;
    return goal > 0 ? (viewingNutrition.fat / goal).clamp(0.0, 1.0) : 0;
  }

  int get weeklyAverageCalories {
    final days = weeklyNutrition;
    if (days.isEmpty) return 0;
    final total = days.fold(0, (sum, d) => sum + d.calories);
    return total ~/ days.length;
  }

  int get daysOnGoal {
    final goal = calorieGoal;
    return weeklyNutrition
        .where((d) => d.hasData && (d.calories - goal).abs() <= 150)
        .length;
  }

  int get loggingStreak => Get.isRegistered<StreakController>()
      ? Get.find<StreakController>().currentStreak
      : 0;

  bool get isStreakAtRisk => Get.isRegistered<StreakController>()
      ? Get.find<StreakController>().isAtRisk
      : false;

  int get totalConsumed => foodCalories;

  void setWeeklyMetric(NutritionTrendMetric metric) =>
      weeklyMetric.value = metric;

  void backToToday() {
    _food.setSelectedLogDate(DateTime.now());
  }

  void scrollHomeToTop({bool animate = true}) {
    if (!homeScrollController.hasClients) return;
    if (animate) {
      homeScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      homeScrollController.jumpTo(0);
    }
  }

  @override
  void onClose() {
    homeScrollController.dispose();
    super.onClose();
  }
}
