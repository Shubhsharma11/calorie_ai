import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/dashboard_controller.dart';
import '../controllers/food_controller.dart';
// import '../controllers/streak_controller.dart';
import '../controllers/tracker_controller.dart';
import '../controllers/user_controller.dart';
import '../core/app_coach_marks.dart';
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
import '../widgets/past_date_banner.dart';
import '../widgets/responsive_page.dart';
// import '../widgets/streak_badge.dart';
import '../widgets/water_intake_banner.dart';
import '../widgets/weight_tracker_banner.dart';
import '../widgets/meal_type_icon.dart';
import '../widgets/weekly_progress_chart.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final food = Get.find<FoodController>();
    final r = context.responsive;

    return RefreshIndicator(
      onRefresh: food.refreshMealsFromApi,
      color: AppColors.primary,
      child: ResponsivePage(
        scrollable: true,
        scrollController: controller.homeScrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(() {
              final hasBadge = DashboardActions.hasNotificationBadge;
              return GetBuilder<UserController>(
                builder: (userCtrl) {
                  final name = userCtrl.user.name.trim();
                  final homeTitle = Platform.isIOS && name.isEmpty
                      ? 'MyCaloriePal'
                      : userCtrl.user.firstName;
                  return DashboardHeader(
                    firstName: homeTitle,
                    showNotificationBadge: hasBadge,
                    onSearch: DashboardActions.openFoodSearch,
                    onCalendar: () => DashboardActions.openCalendar(context),
                    onNotifications: () =>
                        DashboardActions.openNotifications(context),
                    searchShowcaseKey: AppCoachMarks.searchKey,
                  );
                },
              );
            }),
            Obx(() {
              food.selectedLogDate.value;
              if (controller.isViewingToday) {
                return SizedBox(height: r.scale(10));
              }
              return Column(
                children: [    
                  SizedBox(height: r.scale(12)),
                  PastDateBanner(
                    dateLabel: formatLogDateLabel(controller.viewingDate),
                    onBackToToday: controller.backToToday,
                  ),
                  SizedBox(height: r.scale(10)),
                ],
              );
            }),
            // Streak badge temporarily disabled on home.
            // const _StreakSection(),
            // SizedBox(height: r.scale(20)),
            const _CalorieSection(),
            SizedBox(height: r.scale(12)),
            WaterIntakeBanner(coachKey: AppCoachMarks.waterKey),
            SizedBox(height: r.scale(12)),
            WeightTrackerBanner(coachKey: AppCoachMarks.weightKey),
            SizedBox(height: r.scale(28)),
            const _SecondarySection(),
          ],
        ),
      ),
    );
  }
}

// class _StreakSection extends GetView<DashboardController> {
//   const _StreakSection();
//
//   @override
//   Widget build(BuildContext context) {
//     return Obx(() {
//       if (Get.isRegistered<StreakController>()) {
//         Get.find<StreakController>().revision.value;
//       }
//       return StreakBadge(
//         streakDays: controller.loggingStreak,
//         isAtRisk: controller.isStreakAtRisk,
//         onTap: () => Get.toNamed(AppRoutes.streak),
//       );
//     });
//   }
// }

class _CalorieSection extends GetView<DashboardController> {
  const _CalorieSection();

  @override
  Widget build(BuildContext context) {
    final food = Get.find<FoodController>();
    final user = Get.find<UserController>().user;

    return Obx(() {
      food.entriesRevision.value;
      food.selectedLogDate.value;
      if (Get.isRegistered<TrackerController>()) {
        Get.find<TrackerController>().activityRevision.value;
      }
      Get.find<UserController>().calorieGoalRevision.value;
      final nutrition = controller.viewingNutrition;

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
        showcaseKey: AppCoachMarks.calorieKey,
        addFoodShowcaseKey: AppCoachMarks.addFoodKey,
        macros: [
          MacroNutritionData(
            label: 'Carbs',
            currentG: nutrition.carbs.round(),
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
            currentG: nutrition.fat.round(),
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
            currentG: nutrition.protein.round(),
            goalG: user.proteinGoalG,
            progress: controller.proteinProgress,
            color: const Color(0xFF4CAF50),
            emoji: MacroEmojis.protein,
            lottieAsset: 'assets/image/protein.json',
            lottieScale: 0.95,
          ),
        ],
        onAddFood: () => Get.toNamed(AppRoutes.addFood),
        onViewSummary: () => Get.toNamed(AppRoutes.dailySummary),
        onCaloriesBurn: () => Get.toNamed(AppRoutes.caloriesBurn),
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
      food.selectedLogDate.value;
      Get.find<UserController>().calorieGoalRevision.value;
      if (Get.isRegistered<TrackerController>()) {
        Get.find<TrackerController>().activityRevision.value;
      }
      final user = Get.find<UserController>().user;
      final goal = controller.calorieGoal;
      final weeklyMetric = controller.weeklyMetric.value;

      return _SecondaryContent(
        food: food,
        goal: goal,
        proteinGoal: user.proteinGoalG,
        carbsGoal: user.carbsGoalG,
        fatGoal: user.fatGoalG,
        weeklyMetric: weeklyMetric,
        weeklyNutrition: controller.weeklyNutrition,
        onMetricChanged: controller.setWeeklyMetric,
        dateLabel: formatLogDateLabel(controller.viewingDate),
        viewingToday: controller.isViewingToday,
      );
    });
  }
}

class _SecondaryContent extends StatelessWidget {
  const _SecondaryContent({
    required this.food,
    required this.goal,
    required this.proteinGoal,
    required this.carbsGoal,
    required this.fatGoal,
    required this.weeklyMetric,
    required this.weeklyNutrition,
    required this.onMetricChanged,
    required this.dateLabel,
    required this.viewingToday,
  });

  final FoodController food;
  final int goal;
  final int proteinGoal;
  final int carbsGoal;
  final int fatGoal;
  final NutritionTrendMetric weeklyMetric;
  final List<DailyNutrition> weeklyNutrition;
  final ValueChanged<NutritionTrendMetric> onMetricChanged;
  final String dateLabel;
  final bool viewingToday;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final meals = food.selectedDateMeals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.35),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              r.scale(18),
              r.scale(14),
              r.scale(18),
              r.scale(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: r.scale(45),
                      height: r.scale(45),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(r.scale(5)),
                        child: SvgPicture.asset(
                          'assets/image/bar.svg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(width: r.scale(12)),
                    Expanded(
                      child: Text(
                        'Weekly Progress',
                        style: TextStyle(
                          fontSize: r.scale(17),
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.scale(14)),
                WeeklyProgressChart(
                  days: weeklyNutrition,
                  metric: weeklyMetric,
                  calorieGoal: goal,
                  proteinGoal: proteinGoal,
                  carbsGoal: carbsGoal,
                  fatGoal: fatGoal,
                  onMetricChanged: onMetricChanged,
                  chartHeight: r.scale(140, tablet: 160, desktop: 180),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: r.scale(28)),
        Text(
          viewingToday ? 'Today' : dateLabel,
          style: TextStyle(
            fontSize: r.scale(18, tablet: 19, desktop: 20),
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: r.scale(12)),
        if (meals.isEmpty)
          _TodayEmptyState(
            viewingToday: viewingToday,
            onAddFood: () => Get.toNamed(AppRoutes.addFood),
          )
        else
          Column(
            children: meals
                .take(3)
                .map(
                  (e) => _MealPreview(
                    meal: e.meal,
                    hint: '${e.food.name} · ${e.calories} kcal',
                  ),
                )
                .toList(),
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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          MealTypeIcon(meal: meal, size: r.scale(36)),
          SizedBox(width: r.scale(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  hint,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayEmptyState extends StatelessWidget {
  const _TodayEmptyState({
    required this.viewingToday,
    required this.onAddFood,
  });

  final bool viewingToday;
  final VoidCallback onAddFood;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.scale(18)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: r.scale(42),
                height: r.scale(42),
                decoration: BoxDecoration(
                  color: AppColors.selectionFill,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  color: AppColors.primary,
                  size: r.scale(22),
                ),
              ),
              SizedBox(width: r.scale(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meals',
                      style: TextStyle(
                        fontSize: r.scale(18),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: r.scale(2)),
                    Text(
                      viewingToday
                          ? 'Tap Add Food to log your first meal today.'
                          : 'Nothing was logged on this day.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: r.scale(13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (viewingToday) ...[
            SizedBox(height: r.scale(16)),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAddFood,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    vertical: r.scale(12),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: Icon(Icons.add_rounded, size: r.scale(18)),
                label: Text(
                  'Add Food',
                  style: TextStyle(
                    fontSize: r.scale(15),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

