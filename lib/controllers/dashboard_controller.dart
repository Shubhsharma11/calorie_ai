import 'package:get/get.dart';

import '../models/daily_nutrition.dart';
import '../models/nutrition_trend_metric.dart';
import 'food_controller.dart';
import 'streak_controller.dart';
import 'user_controller.dart';

class DashboardController extends GetxController {
  final RxInt exerciseCalories = 0.obs;
  final Rx<NutritionTrendMetric> weeklyMetric =
      NutritionTrendMetric.calories.obs;

  int get calorieGoal => Get.find<UserController>().user.dailyCalorieGoal;

  FoodController get _food => Get.find<FoodController>();

  List<DailyNutrition> get weeklyNutrition => _food.last7Days;

  int get foodCalories => _food.totalCaloriesEaten;

  int get caloriesLeft =>
      (calorieGoal - foodCalories + exerciseCalories.value).clamp(0, 99999);

  double get progress =>
      calorieGoal > 0 ? foodCalories / calorieGoal : 0;

  int get goalProgressPercent => (progress * 100).round().clamp(0, 100);

  double get proteinProgress {
    final goal = Get.find<UserController>().user.proteinGoalG;
    return goal > 0 ? (_food.totalProtein / goal).clamp(0.0, 1.0) : 0;
  }

  double get carbsProgress {
    final goal = Get.find<UserController>().user.carbsGoalG;
    return goal > 0 ? (_food.totalCarbs / goal).clamp(0.0, 1.0) : 0;
  }

  double get fatProgress {
    final goal = Get.find<UserController>().user.fatGoalG;
    return goal > 0 ? (_food.totalFat / goal).clamp(0.0, 1.0) : 0;
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

  int get totalConsumed => foodCalories + exerciseCalories.value;

  void setWeeklyMetric(NutritionTrendMetric metric) =>
      weeklyMetric.value = metric;
}
