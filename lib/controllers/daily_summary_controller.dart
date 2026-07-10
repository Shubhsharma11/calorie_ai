import 'package:get/get.dart';

import '../models/meal_type.dart';
import 'dashboard_controller.dart';
import 'food_controller.dart';
import 'streak_controller.dart';
import 'tracker_controller.dart';
import 'user_controller.dart';

class DailySummaryController extends GetxController {
  DashboardController get _dash => Get.find<DashboardController>();
  FoodController get _food => Get.find<FoodController>();
  UserController get _user => Get.find<UserController>();
  TrackerController get _tracker => Get.find<TrackerController>();

  int get calorieGoal => _dash.calorieGoal;
  int get consumed => _dash.foodCalories;
  int get remaining => _dash.caloriesLeft;
  int get progressPercent => _dash.goalProgressPercent;

  int get proteinGoal => _user.user.proteinGoalG;
  int get proteinEaten => _food.totalProtein.round();
  int get proteinGap => (proteinGoal - proteinEaten).clamp(0, proteinGoal);

  int get waterMl => _tracker.waterMl;
  int get waterGlasses => _tracker.waterGlasses;
  int get waterGoalMl => TrackerController.waterGoalMl;
  int get waterMlRemaining => _tracker.waterMlRemaining;

  bool get waterGoalCompleted => _tracker.isWaterGoalComplete;
  int get waterMlOverGoal => _tracker.waterMlOverGoal;
  bool get allMealsLogged =>
      MealType.all.every((meal) => _food.mealsForToday(meal).isNotEmpty);

  int get loggingStreak => _dash.loggingStreak;

  int get longestStreak => Get.isRegistered<StreakController>()
      ? Get.find<StreakController>().longestStreak
      : loggingStreak;

  bool get isStreakAtRisk => _dash.isStreakAtRisk;

  String get streakSubtitle {
    if (loggingStreak == 0) return 'Log today to begin';
    if (isStreakAtRisk) return 'Log today to keep it';
    return 'Best: $longestStreak days';
  }

  int get healthScore {
    final caloriePart = (progressPercent * 0.5).round();
    final waterPart = waterGoalCompleted
        ? 25
        : waterGoalMl > 0
            ? ((waterMl / waterGoalMl) * 25).round().clamp(0, 25)
            : 0;
    final proteinPart = proteinGoal > 0
        ? ((proteinEaten / proteinGoal) * 25).round().clamp(0, 25)
        : 0;
    return (caloriePart + waterPart + proteinPart).clamp(0, 100);
  }

  int get totalAchievements {
    var count = 0;
    if (waterGoalCompleted) count++;
    if (allMealsLogged) count++;
    if (progressPercent >= 80) count++;
    if (loggingStreak >= 3) count++;
    return count + 8;
  }

  int get weeklyCalorieChangePercent {
    final days = _food.last7Days;
    if (days.length < 7) return 0;
    final thisHalf = days.sublist(4).fold(0, (s, d) => s + d.calories);
    final lastHalf = days.sublist(0, 4).fold(0, (s, d) => s + d.calories);
    if (lastHalf == 0) return 0;
    return (((thisHalf - lastHalf) / lastHalf) * 100).round();
  }

  String get nextGoalTitle {
    if (progressPercent >= 80) {
      return 'Hit 100% of your calorie goal today';
    }
    if (progressPercent >= 50) {
      return 'Reach 80% of your calorie goal today';
    }
    return 'Log your next meal to build momentum';
  }

  List<({String day, int percent, bool hasData})> get weeklyBars {
    final days = _food.last7Days;
    final goal = calorieGoal;
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return List.generate(7, (index) {
      final day = days[index];
      final percent = goal > 0 && day.hasData
          ? ((day.calories / goal) * 100).round().clamp(0, 100)
          : 0;
      return (day: labels[index], percent: percent, hasData: day.hasData);
    });
  }
}
