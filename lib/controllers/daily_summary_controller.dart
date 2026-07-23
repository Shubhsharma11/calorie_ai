import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/dashboard_actions.dart';
import '../models/daily_nutrition.dart';
import '../models/meal_type.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'dashboard_controller.dart';
import 'food_controller.dart';
import 'tracker_controller.dart';
import 'user_controller.dart';

class DailyAchievement {
  const DailyAchievement({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.route,
    this.openFoodTab = false,
  });

  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? route;
  final bool openFoodTab;
}

class SmartInsight {
  const SmartInsight({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.bold,
    required this.suffix,
    this.route,
    this.openFoodTab = false,
    this.openAnalyticsTab = false,
  });

  final String id;
  final IconData icon;
  final Color iconColor;
  final String text;
  final String bold;
  final String suffix;
  final String? route;
  final bool openFoodTab;
  final bool openAnalyticsTab;
}

class DailySummaryController extends GetxController {
  DashboardController get _dash => Get.find<DashboardController>();
  FoodController get _food => Get.find<FoodController>();
  UserController get _user => Get.find<UserController>();
  TrackerController get _tracker => Get.find<TrackerController>();

  DateTime get viewingDate => _dash.viewingDate;
  bool get isViewingToday => _dash.isViewingToday;
  String get dateLabel => formatLogDateLabel(viewingDate);
  String get dayWord => isViewingToday ? 'today' : 'this day';
  String get dayPossessive =>
      isViewingToday ? "Today's" : "$dateLabel's";

  DailyNutrition get _nutrition => _dash.viewingNutrition;

  int get calorieGoal => _dash.calorieGoal;
  int get consumed => _dash.foodCalories;
  int get remaining => _dash.caloriesLeft;
  int get progressPercent => _dash.goalProgressPercent;

  int get proteinGoal => _user.user.proteinGoalG;
  int get proteinEaten => _nutrition.protein.round();
  int get proteinGap => (proteinGoal - proteinEaten).clamp(0, proteinGoal);
  int get proteinOver =>
      proteinEaten > proteinGoal ? proteinEaten - proteinGoal : 0;

  int get carbsGoal => _user.user.carbsGoalG;
  int get carbsEaten => _nutrition.carbs.round();
  int get carbsGap => (carbsGoal - carbsEaten).clamp(0, carbsGoal);
  int get carbsOver => carbsEaten > carbsGoal ? carbsEaten - carbsGoal : 0;

  int get fatGoal => _user.user.fatGoalG;
  int get fatEaten => _nutrition.fat.round();
  int get fatGap => (fatGoal - fatEaten).clamp(0, fatGoal);
  int get fatOver => fatEaten > fatGoal ? fatEaten - fatGoal : 0;

  int get waterMl => _tracker.waterForDate(viewingDate);
  int get waterGlasses =>
      (waterMl / TrackerController.mlPerGlass).round();
  int get waterGoalMl => TrackerController.waterGoalMl;
  int get waterMlRemaining => (waterGoalMl - waterMl).clamp(0, waterGoalMl);

  bool get waterGoalCompleted => waterMl >= waterGoalMl;
  int get waterMlOverGoal => (waterMl - waterGoalMl).clamp(0, 1000000);
  bool get allMealsLogged => MealType.all.every(
        (meal) => _food.mealsForDate(viewingDate, meal).isNotEmpty,
      );

  List<String> get missingMeals => MealType.all
      .where((meal) => _food.mealsForDate(viewingDate, meal).isEmpty)
      .toList();

  int get daySteps => _tracker.stepsForDate(viewingDate);
  int get stepsRemaining =>
      (TrackerController.stepsGoal - daySteps)
          .clamp(0, TrackerController.stepsGoal);
  bool get stepsGoalComplete => daySteps >= TrackerController.stepsGoal;
  int get stepsCalories => (daySteps * 0.04).round();

  int get caloriesOver => _dash.caloriesOver;

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

  String get motivationTitle => isViewingToday
      ? "You're doing great!"
      : 'Summary for $dateLabel';

  String get motivationSubtitle => isViewingToday
      ? 'Keep moving toward your goal.'
      : consumed > 0
          ? 'Here’s how that day went — viewing only.'
          : 'Nothing was logged on this day.';

  /// Unlocked achievements for the selected day.
  List<DailyAchievement> get unlockedAchievements {
    const blue = Color(0xFF007AFF);
    const purple = Color(0xFF8B5CF6);

    final items = <DailyAchievement>[];

    if (waterGoalCompleted) {
      items.add(
        DailyAchievement(
          id: 'water_goal',
          icon: Icons.water_drop_rounded,
          color: blue,
          title: 'Water Goal Completed',
          subtitle: waterMlOverGoal > 0
              ? '+$waterMlOverGoal ml over goal'
              : 'Great job!',
          route: AppRoutes.waterTracker,
        ),
      );
    }

    if (allMealsLogged) {
      items.add(
        DailyAchievement(
          id: 'all_meals',
          icon: Icons.restaurant_rounded,
          color: AppColors.primary,
          title: isViewingToday
              ? 'Logged All Meals Today'
              : 'Logged All Meals',
          subtitle: 'Awesome!',
          openFoodTab: true,
        ),
      );
    }

    if (progressPercent >= 100) {
      items.add(
        DailyAchievement(
          id: 'calorie_goal',
          icon: Icons.flag_rounded,
          color: AppColors.primary,
          title: 'Calorie Goal Hit',
          subtitle: isViewingToday ? '100% today' : '100% that day',
        ),
      );
    } else if (progressPercent >= 80) {
      items.add(
        DailyAchievement(
          id: 'calorie_80',
          icon: Icons.flag_rounded,
          color: purple,
          title: 'Almost There',
          subtitle: '$progressPercent% of calorie goal',
        ),
      );
    }

    return items;
  }

  int get totalAchievements => unlockedAchievements.length;

  int get weeklyCalorieChangePercent {
    final days = _food.last7Days;
    if (days.length < 7) return 0;
    final thisHalf = days.sublist(4).fold(0, (s, d) => s + d.calories);
    final lastHalf = days.sublist(0, 4).fold(0, (s, d) => s + d.calories);
    if (lastHalf == 0) return 0;
    return (((thisHalf - lastHalf) / lastHalf) * 100).round();
  }

  /// Prioritized smart tips for the selected day.
  List<SmartInsight> get smartInsights {
    const blue = Color(0xFF007AFF);
    const orange = Color(0xFFFF9500);
    const purple = Color(0xFF8B5CF6);
    final insights = <SmartInsight>[];
    final day = dayWord;

    if (caloriesOver > 0) {
      insights.add(
        SmartInsight(
          id: 'cal_over',
          icon: Icons.warning_amber_rounded,
          iconColor: orange,
          text: 'You were ',
          bold: '$caloriesOver kcal over',
          suffix: isViewingToday
              ? ' your daily goal. Consider a lighter next meal.'
              : ' your goal on $dateLabel.',
          openFoodTab: true,
        ),
      );
    } else if (remaining > 0 && consumed > 0) {
      insights.add(
        SmartInsight(
          id: 'cal_left',
          icon: Icons.local_fire_department_rounded,
          iconColor: AppColors.primary,
          text: isViewingToday ? 'You still have ' : 'There were ',
          bold: '$remaining kcal',
          suffix: isViewingToday
              ? ' left today — room for a balanced meal or snack.'
              : ' remaining on $dateLabel.',
          openFoodTab: true,
        ),
      );
    } else if (consumed == 0) {
      insights.add(
        SmartInsight(
          id: 'cal_empty',
          icon: Icons.restaurant_rounded,
          iconColor: AppColors.primary,
          text: isViewingToday
              ? 'No meals logged yet. '
              : 'No meals were logged. ',
          bold: isViewingToday ? 'Log your first meal' : 'Add food for this day',
          suffix: ' to track $day’s nutrition.',
          openFoodTab: true,
        ),
      );
    }

    final missing = missingMeals;
    if (missing.isNotEmpty && consumed > 0) {
      final label = missing.length == 1
          ? missing.first
          : '${missing.take(missing.length - 1).join(', ')} and ${missing.last}';
      insights.add(
        SmartInsight(
          id: 'missing_meals',
          icon: Icons.schedule_rounded,
          iconColor: orange,
          text: isViewingToday ? 'You haven’t logged ' : 'Missing ',
          bold: label,
          suffix: isViewingToday
              ? ' yet. Logging keeps your summary accurate.'
              : ' on $dateLabel.',
          openFoodTab: true,
        ),
      );
    }

    if (proteinGoal > 0 && proteinGap > 0) {
      insights.add(
        SmartInsight(
          id: 'protein_low',
          icon: Icons.bar_chart_rounded,
          iconColor: purple,
          text: 'Protein intake is ',
          bold: '${proteinGap}g below',
          suffix: ' target. Try eggs, dal, chicken, or Greek yogurt.',
          route: AppRoutes.addFood,
        ),
      );
    } else if (proteinOver >= 20) {
      insights.add(
        SmartInsight(
          id: 'protein_high',
          icon: Icons.bar_chart_rounded,
          iconColor: purple,
          text: 'Protein is ',
          bold: '${proteinOver}g above',
          suffix: ' target — great if you’re building muscle.',
          openAnalyticsTab: true,
        ),
      );
    }

    if (carbsGoal > 0 && carbsGap > 0 && carbsEaten > 0) {
      insights.add(
        SmartInsight(
          id: 'carbs_low',
          icon: Icons.grain_rounded,
          iconColor: orange,
          text: 'Carbs are ',
          bold: '${carbsGap}g below',
          suffix: ' target. Whole grains or fruit can help fuel your day.',
          route: AppRoutes.addFood,
        ),
      );
    } else if (carbsOver >= 30) {
      insights.add(
        SmartInsight(
          id: 'carbs_high',
          icon: Icons.grain_rounded,
          iconColor: orange,
          text: 'Carbs are ',
          bold: '${carbsOver}g above',
          suffix: ' target. Balance with protein and fiber next meal.',
          openFoodTab: true,
        ),
      );
    }

    if (fatGoal > 0 && fatGap > 0 && fatEaten > 0) {
      insights.add(
        SmartInsight(
          id: 'fat_low',
          icon: Icons.opacity_rounded,
          iconColor: const Color(0xFFE6A23C),
          text: 'Fat intake is ',
          bold: '${fatGap}g below',
          suffix: ' target. Nuts, avocado, or olive oil can help.',
          route: AppRoutes.addFood,
        ),
      );
    } else if (fatOver >= 15) {
      insights.add(
        SmartInsight(
          id: 'fat_high',
          icon: Icons.opacity_rounded,
          iconColor: const Color(0xFFE6A23C),
          text: 'Fat is ',
          bold: '${fatOver}g above',
          suffix: ' target. Prefer grilled or lighter cooking next time.',
          openFoodTab: true,
        ),
      );
    }

    if (waterMlRemaining > 0) {
      final glassesLeft =
          (waterMlRemaining / TrackerController.mlPerGlass).ceil().clamp(1, 20);
      insights.add(
        SmartInsight(
          id: 'water_left',
          icon: Icons.water_drop_rounded,
          iconColor: blue,
          text: isViewingToday ? 'Drink ' : 'Hydration was short by ',
          bold: glassesLeft == 1 ? '1 more glass' : '$glassesLeft more glasses',
          suffix: isViewingToday
              ? ' to finish today’s hydration goal.'
              : ' on $dateLabel.',
          route: AppRoutes.waterTracker,
        ),
      );
    } else if (waterGoalCompleted) {
      insights.add(
        SmartInsight(
          id: 'water_done',
          icon: Icons.water_drop_rounded,
          iconColor: blue,
          text: 'Hydration goal ',
          bold: 'completed',
          suffix: waterMlOverGoal > 0
              ? ' — nice work staying ahead!'
              : ' — keep it up!',
          route: AppRoutes.waterTracker,
        ),
      );
    }

    if (!stepsGoalComplete && daySteps > 0) {
      insights.add(
        SmartInsight(
          id: 'steps_left',
          icon: Icons.directions_walk_rounded,
          iconColor: blue,
          text: 'About ',
          bold: '$stepsRemaining steps',
          suffix:
              ' left to hit your ${TrackerController.stepsGoal} step goal (~$stepsCalories kcal burned so far).',
          route: AppRoutes.caloriesBurn,
        ),
      );
    } else if (stepsGoalComplete) {
      insights.add(
        SmartInsight(
          id: 'steps_done',
          icon: Icons.directions_walk_rounded,
          iconColor: AppColors.primary,
          text: 'Step goal ',
          bold: 'achieved',
          suffix: ' — about $stepsCalories kcal from walking.',
          route: AppRoutes.caloriesBurn,
        ),
      );
    } else if (daySteps == 0) {
      insights.add(
        SmartInsight(
          id: 'steps_empty',
          icon: Icons.directions_walk_rounded,
          iconColor: blue,
          text: isViewingToday
              ? 'No steps tracked yet. '
              : 'No steps were tracked. ',
          bold: 'A short walk',
          suffix: isViewingToday
              ? ' can boost today’s calorie burn.'
              : ' would have boosted burn on $dateLabel.',
          route: AppRoutes.caloriesBurn,
        ),
      );
    }

    if (weeklyCalorieChangePercent.abs() >= 8) {
      final up = weeklyCalorieChangePercent > 0;
      insights.add(
        SmartInsight(
          id: 'weekly_trend',
          icon: up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          iconColor: up ? orange : AppColors.primary,
          text: 'This week’s calories are ',
          bold:
              '${up ? '+' : ''}$weeklyCalorieChangePercent% ${up ? 'higher' : 'lower'}',
          suffix: ' than earlier in the week.',
          openAnalyticsTab: true,
        ),
      );
    }

    if (healthScore >= 70 && insights.length < 6) {
      insights.add(
        SmartInsight(
          id: 'on_track',
          icon: Icons.favorite_rounded,
          iconColor: AppColors.primary,
          text: 'You’re on track ',
          bold: '($healthScore/100)',
          suffix:
              ' with calories, protein, and water $day. Keep going!',
        ),
      );
    }

    return insights.take(6).toList();
  }

  void backToToday() => _dash.backToToday();
}
