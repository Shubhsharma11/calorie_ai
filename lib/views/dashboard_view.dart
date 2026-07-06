import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/dashboard_controller.dart';
import '../controllers/food_controller.dart';
import '../controllers/nutrition_plan_controller.dart';
import '../controllers/main_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/streak_controller.dart';
import '../controllers/tracker_controller.dart';
import '../controllers/user_controller.dart';
import '../core/dashboard_actions.dart';
import '../core/macro_emojis.dart';
import '../core/responsive.dart';
import '../models/nutrition_trend_metric.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/goal_progress_banner.dart';
import '../widgets/macro_nutrition_card.dart';
import '../widgets/responsive_page.dart';
import '../widgets/streak_badge.dart';
import '../widgets/water_intake_banner.dart';
import '../widgets/weekly_progress_chart.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<DashboardController>()) {
      Get.put(DashboardController(), permanent: true);
    }
    if (!Get.isRegistered<FoodController>()) {
      Get.put(FoodController(), permanent: true);
    }

    final user = Get.find<UserController>().user;
    final food = Get.find<FoodController>();
    final r = context.responsive;

    return Obx(() {
      final _ = food.entriesRevision.value;
      if (Get.isRegistered<SettingsController>()) {
        final settings = Get.find<SettingsController>();
        settings.pushNotifications.value;
        settings.mealReminders.value;
        settings.waterReminders.value;
      }
      if (Get.isRegistered<TrackerController>()) {
        final tracker = Get.find<TrackerController>();
        tracker.waterGlasses;
        tracker.activityRevision.value;
      }
      if (Get.isRegistered<StreakController>()) {
        Get.find<StreakController>().revision.value;
      }
      if (Get.isRegistered<NutritionPlanController>()) {
        final planController = Get.find<NutritionPlanController>();
        planController.isLoading.value;
        planController.plan.value;
      }
      Get.find<UserController>().calorieGoalRevision.value;

      final left = controller.caloriesLeft;
      final goal = controller.calorieGoal;
      final eaten = controller.foodCalories;
      final burned = controller.exerciseCalories;
      final netRemaining = controller.netCaloriesRemaining;
      final progress = controller.progress.clamp(0.0, 1.0);
      final ringSize = r.scale(220, tablet: 240, desktop: 260);
      final streak = controller.loggingStreak;

      return ResponsivePage(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardHeader(
              firstName: user.firstName,
              showNotificationBadge: DashboardActions.hasNotificationBadge,
              onSearch: DashboardActions.openFoodSearch,
              onCalendar: () => DashboardActions.openCalendar(context),
              onNotifications: () =>
                  DashboardActions.openNotifications(context),
            ),
            StreakBadge(
              streakDays: streak,
              isAtRisk: controller.isStreakAtRisk,
              onTap: () => Get.toNamed(AppRoutes.streak),
            ),
            SizedBox(height: r.scale(20)),
            Column(
              children: [
                _CalorieRing(
                  caloriesLeft: left,
                  progress: progress,
                  size: ringSize,
                ),
                if (burned > 0) ...[
                  SizedBox(height: r.scale(10)),
                  Text(
                    'Net incl. activity: $netRemaining kcal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: r.scale(13),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: r.scale(20)),
            MacroNutritionCard(
              macros: [
                MacroNutritionData(
                  label: 'Carbs',
                  currentG: food.totalCarbs.round(),
                  goalG: user.carbsGoalG,
                  progress: controller.carbsProgress,
                  color: const Color(0xFF2196F3),
                  emoji: MacroEmojis.carbs,
                ),
                MacroNutritionData(
                  label: 'Fat',
                  currentG: food.totalFat.round(),
                  goalG: user.fatGoalG,
                  progress: controller.fatProgress,
                  color: const Color(0xFF9C27B0),
                  emoji: MacroEmojis.fat,
                ),
                MacroNutritionData(
                  label: 'Protein',
                  currentG: food.totalProtein.round(),
                  goalG: user.proteinGoalG,
                  progress: controller.proteinProgress,
                  color: const Color(0xFF4CAF50),
                  emoji: MacroEmojis.protein,
                ),
              ],
            ),
            SizedBox(height: r.scale(12)),
            Row(
              children: [
                _StatCard(
                  label: 'Calories Burn',
                  value: burned,
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFFF9500),
                  onTap: () => Get.toNamed(AppRoutes.caloriesBurn),
                ),
                SizedBox(width: r.scale(10)),
                _StatCard(
                  label: 'Goal',
                  value: goal,
                  icon: Icons.flag_rounded,
                  iconColor: AppColors.primary,
                ),
                SizedBox(width: r.scale(10)),
                _StatCard(
                  label: 'Food',
                  value: eaten,
                  icon: Icons.restaurant_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                ),
              ],
            ),
            SizedBox(height: r.scale(12)),
            const WaterIntakeBanner(),
            SizedBox(height: r.scale(12)),
            GoalProgressBanner(
              consumed: eaten,
              goal: goal,
              progressPercent: controller.goalProgressPercent,
              onTap: () {
                if (eaten == 0) {
                  Get.toNamed(AppRoutes.addFood);
                } else {
                  Get.toNamed(AppRoutes.dailySummary);
                }
              },
            ),
            SizedBox(height: r.scale(28)),
            _SecondarySection(
              food: food,
              controller: controller,
              goal: goal,
              weeklyMetric: controller.weeklyMetric.value,
            ),
          ],
        ),
      );
    });
  }
}

class _CalorieRing extends StatelessWidget {
  const _CalorieRing({
    required this.caloriesLeft,
    required this.progress,
    required this.size,
  });

  final int caloriesLeft;
  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: r.scale(16, tablet: 18, desktop: 20),
                backgroundColor: AppColors.surface,
                color: AppColors.primary,
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$caloriesLeft',
                  style: TextStyle(
                    fontSize: r.scale(40, tablet: 44, desktop: 48),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Calories Left',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    final card = Container(
      padding: EdgeInsets.symmetric(
        vertical: r.scale(16),
        horizontal: r.scale(10),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: r.scale(24)),
          SizedBox(height: r.scale(10)),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: r.scale(18, tablet: 19),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
              children: [
                TextSpan(text: '$value '),
                TextSpan(
                  text: 'kcal',
                  style: TextStyle(
                    fontSize: r.scale(14, tablet: 15),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.scale(6)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(12),
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    return Expanded(
      child: onTap == null
          ? card
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: card,
              ),
            ),
    );
  }
}

class _SecondarySection extends StatelessWidget {
  const _SecondarySection({
    required this.food,
    required this.controller,
    required this.goal,
    required this.weeklyMetric,
  });

  final FoodController food;
  final DashboardController controller;
  final int goal;
  final NutritionTrendMetric weeklyMetric;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final sectionTitle = TextStyle(
      fontSize: r.scale(18, tablet: 19, desktop: 20),
      fontWeight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weekly Progress', style: sectionTitle),
        SizedBox(height: r.scale(12)),
        WeeklyProgressChart(
          days: controller.weeklyNutrition,
          metric: weeklyMetric,
          calorieGoal: goal,
          onMetricChanged: controller.setWeeklyMetric,
          chartHeight: r.scale(140, tablet: 160, desktop: 180),
        ),
        SizedBox(height: r.scale(28)),
        Text('Today', style: sectionTitle),
        SizedBox(height: r.scale(12)),
        if (food.todayMeals.isEmpty)
          const _MealPreview(
            meal: 'Breakfast',
            hint: 'Tap the card above or + Add Food to log your first meal',
          )
        else
          Column(
            children: food.todayMeals
                .take(3)
                .map(
                  (e) => _MealPreview(
                    meal: e.meal,
                    hint: '${e.food.name} · ${e.calories} kcal',
                  ),
                )
                .toList(),
          ),
        SizedBox(height: r.scale(12)),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton.icon(
              onPressed: () => Get.toNamed(AppRoutes.addFood),
              icon: Icon(Icons.add, color: AppColors.primary),
              label: Text(
                'Add Food',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
            TextButton.icon(
              onPressed: () => Get.find<MainController>().changeTab(2),
              icon: Icon(Icons.camera_alt, color: AppColors.primary),
              label: Text('Scan', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ],
    );
  }
}

class _MealPreview extends StatelessWidget {
  const _MealPreview({required this.meal, required this.hint});

  final String meal;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      margin: EdgeInsets.only(bottom: r.scale(10)),
      padding: EdgeInsets.all(r.scale(16)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.free_breakfast, color: AppColors.primary),
          SizedBox(width: r.scale(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal, style: TextStyle(fontWeight: FontWeight.w600)),
                Text(hint, style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
