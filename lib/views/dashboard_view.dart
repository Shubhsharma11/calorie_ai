import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/dashboard_controller.dart';
import '../controllers/food_controller.dart';
import '../controllers/main_controller.dart';
import '../controllers/streak_controller.dart';
import '../controllers/tracker_controller.dart';
import '../controllers/user_controller.dart';
import '../core/dashboard_actions.dart';
import '../core/macro_emojis.dart';
import '../core/responsive.dart';
import '../models/daily_nutrition.dart';
import '../models/nutrition_trend_metric.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/calorie_overview_card.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/macro_nutrition_card.dart';
import '../widgets/responsive_page.dart';
import '../widgets/streak_badge.dart';
import '../widgets/water_intake_banner.dart';
import '../widgets/meal_type_icon.dart';
import '../widgets/weekly_progress_chart.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) 
  {

    final user = Get.find<UserController>().user;
    final food = Get.find<FoodController>();
    final r = context.responsive;

    return RefreshIndicator(


      onRefresh: food.refreshMealsFromApi,
      
      color: AppColors.primary,
      child: ResponsivePage(
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
            SizedBox(height: r.scale(10)),
            const _StreakSection(),
            SizedBox(height: r.scale(20)),
            const _CalorieSection(),
            SizedBox(height: r.scale(20)),
            const _MacroSection(),
            SizedBox(height: r.scale(12)),
            const WaterIntakeBanner(),
            SizedBox(height: r.scale(28)),
            const _SecondarySection(),
          ],
        ),
      ),
    );
  }
}

class _StreakSection extends GetView<DashboardController> {
  const _StreakSection();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (Get.isRegistered<StreakController>()) {
        Get.find<StreakController>().revision.value;
      }
      return StreakBadge(
        streakDays: controller.loggingStreak,
        isAtRisk: controller.isStreakAtRisk,
        onTap: () => Get.toNamed(AppRoutes.streak),
      );
    });
  }
}

class _CalorieSection extends GetView<DashboardController> {
  const _CalorieSection();

  @override
  Widget build(BuildContext context) {
    final food = Get.find<FoodController>();

    return Obx(() {
      food.entriesRevision.value;
      if (Get.isRegistered<TrackerController>()) {
        Get.find<TrackerController>().activityRevision.value;
      }
      Get.find<UserController>().calorieGoalRevision.value;

      return CalorieOverviewCard(
        eaten: controller.foodCalories,
        goal: controller.calorieGoal,
        burned: controller.exerciseCalories,
        progress: controller.progress.clamp(0.0, 1.0),
        isOverGoal: controller.isOverCalorieGoal,
        caloriesOver: controller.caloriesOver,
        progressPercent: controller.goalProgressPercent,
        netOver: controller.isNetOverCalorieGoal,
        netRemaining: controller.netCaloriesRemaining,
        netCaloriesOver: controller.netCaloriesOver,
        onAddFood: () => Get.toNamed(AppRoutes.addFood),
        onViewSummary: () => Get.toNamed(AppRoutes.dailySummary),
        onCaloriesBurn: () => Get.toNamed(AppRoutes.caloriesBurn),
      );
    });
  }
}

class _MacroSection extends GetView<DashboardController> {
  const _MacroSection();

  @override
  Widget build(BuildContext context) {
    final food = Get.find<FoodController>();
    final user = Get.find<UserController>().user;

    return Obx(() {
      food.entriesRevision.value;
      Get.find<UserController>().calorieGoalRevision.value;

      return MacroNutritionCard(
        macros: [
          MacroNutritionData(
            label: 'Carbs',
            currentG: food.totalCarbs.round(),
            goalG: user.carbsGoalG,
            progress: controller.carbsProgress,
            color: const Color(0xFF2196F3),
            emoji: MacroEmojis.carbs,
            lottieAsset: 'assets/image/ricebowl.json',
            lottieScale: 1.0,
            lottieFit: BoxFit.cover,
          ),
          MacroNutritionData(
            label: 'Fat',
            currentG: food.totalFat.round(),
            goalG: user.fatGoalG,
            progress: controller.fatProgress,
            color: const Color(0xFF9C27B0),
            emoji: MacroEmojis.fat,
            lottieAsset: 'assets/image/walking_avocado.json',
            lottieScale: 1.5,
            lottieFit: BoxFit.contain,
            lottieAlignment: const Alignment(0, 0.2),
          ),
          MacroNutritionData(
            label: 'Protein',
            currentG: food.totalProtein.round(),
            goalG: user.proteinGoalG,
            progress: controller.proteinProgress,
            color: const Color(0xFF4CAF50),
            emoji: MacroEmojis.protein,
            lottieAsset: 'assets/image/protein.json',
            lottieScale: 0.95,
          ),
        ],
      );
    });
  }
}

class _SecondarySection extends GetView<DashboardController> {
  const _SecondarySection();

  @override
  Widget build(BuildContext context) {
    final food = Get.find<FoodController>();

    return Obx(() {
      food.entriesRevision.value;
      final goal = controller.calorieGoal;
      final weeklyMetric = controller.weeklyMetric.value;

      return _SecondaryContent(
        food: food,
        goal: goal,
        weeklyMetric: weeklyMetric,
        weeklyNutrition: controller.weeklyNutrition,
        onMetricChanged: controller.setWeeklyMetric,
      );
    });
  }
}

class _SecondaryContent extends StatelessWidget {
  const _SecondaryContent({
    required this.food,
    required this.goal,
    required this.weeklyMetric,
    required this.weeklyNutrition,
    required this.onMetricChanged,
  });

  final FoodController food;
  final int goal;
  final NutritionTrendMetric weeklyMetric;
  final List<DailyNutrition> weeklyNutrition;
  final ValueChanged<NutritionTrendMetric> onMetricChanged;

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
          days: weeklyNutrition,
          metric: weeklyMetric,
          calorieGoal: goal,
          onMetricChanged: onMetricChanged,
          chartHeight: r.scale(140, tablet: 160, desktop: 180),
        ),
        SizedBox(height: r.scale(28)),
        Text('Today', style: sectionTitle),
        SizedBox(height: r.scale(12)),
        if (food.todayMeals.isEmpty)
          const _MealPreview(
            meal: 'Breakfast',
            hint: 'Tap "Add your first meal" above or use + Add Food',
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
          MealTypeIcon(meal: meal, size: r.scale(36)),
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
