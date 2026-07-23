import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/daily_log/repeat_yesterday_bottom_sheet.dart';
import '../widgets/daily_log/repeat_yesterday_card.dart';

import '../controllers/dashboard_controller.dart';
import '../controllers/food_controller.dart';
import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/dashboard_actions.dart';
import '../core/responsive.dart';
import '../models/meal_type.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/daily_log/daily_log_meal_section.dart';
import '../widgets/past_date_banner.dart';
import '../widgets/responsive_page.dart';

class DailyLogView extends GetView<FoodController> {
  const DailyLogView({super.key});

  @override
  Widget build(BuildContext context) {
    final dash = Get.find<DashboardController>();
    final r = context.responsive;

    return Obx(() {
      final _ = controller.entriesRevision.value;
      final logDate = controller.selectedLogDate.value;
      final eaten = controller.selectedDateCalories;
      final goal = dash.calorieGoal;
      final progress = goal > 0 ? (eaten / goal).clamp(0.0, 1.0) : 0.0;
      final overGoal = goal > 0 && eaten > goal;
      final nutrition = controller.nutritionForDate(logDate);
      final user = Get.find<UserController>().user;
      final dateLabel = formatLogDateLabel(logDate);
      final viewingToday = controller.isViewingToday;

      final showRepeat =
          viewingToday &&
          controller.canRepeatYesterday &&
          controller.showRepeatYesterdayCard.value;

      final mealGap = r.scale(16);

      return ResponsivePage(
        child: RefreshIndicator(
          onRefresh: () async {
            await controller.refreshMealsFromApi();
          },
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Daily Log',
                      style: TextStyle(
                        fontSize: r.scale(26, tablet: 28),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => DashboardActions.openCalendar(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: r.scale(12),
                        vertical: r.scale(6),
                      ),
                      decoration: BoxDecoration(
                        color: viewingToday
                            ? AppColors.surface
                            : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(20),
                        border: viewingToday
                            ? null
                            : Border.all(
                                color: const Color(0xFFFF9800)
                                    .withValues(alpha: 0.45),
                              ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            viewingToday
                                ? Icons.calendar_today_rounded
                                : Icons.history_rounded,
                            size: 16,
                            color: viewingToday
                                ? AppColors.primary
                                : const Color(0xFFE65100),
                          ),
                          SizedBox(width: r.scale(6)),
                          Text(
                            dateLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: viewingToday
                                  ? AppColors.primary
                                  : const Color(0xFFE65100),
                              fontSize: r.scale(13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (!viewingToday) ...[
                SizedBox(height: r.scale(12)),
                PastDateBanner(
                  dateLabel: dateLabel,
                  message: 'Showing this day\'s diary. Tap Today to go back.',
                  onBackToToday: () {
                    Get.find<DashboardController>().backToToday();
                  },
                ),
              ],
              SizedBox(height: r.scale(20)),
              _CalorieSummaryCard(
                eaten: eaten,
                goal: goal,
                progress: progress,
                overGoal: overGoal,
                proteinG: nutrition.protein.round(),
                carbsG: nutrition.carbs.round(),
                fatG: nutrition.fat.round(),
                proteinGoalG: user.proteinGoalG,
                carbsGoalG: user.carbsGoalG,
                fatGoalG: user.fatGoalG,
              ),
              if (showRepeat) ...[
                SizedBox(height: r.scale(14)),
                // _QuickActions(
                //   showRepeat: showRepeat,
                //   yesterdayCount: controller.yesterdayMealCount,
                //   onRepeat: () {
                //     final count = controller.copyYesterdayToDate();
                //     if (count == 0) {
                //       AppSnackbar.info('No meals logged yesterday.');
                //       return;
                //     }
                //     AppSnackbar.success(
                //       '$count meals copied.',
                //       title: 'Done',
                //     );
                //   },
                // ),
                controller.hasRepeatedYesterdayMeals
                    ? SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await controller.cancelRepeatedYesterdayMeals();

                            AppSnackbar.success(
                              'Repeated meals removed.',
                              title: 'Done',
                            );
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                        ),
                      )
                    : RepeatYesterdayCard(
                        mealCount: controller.lastLoggedMealCount,
                        calories: controller.lastLoggedCalories,
                        dayLabel: controller.lastLoggedDayLabel,
                        onRepeat: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) =>
                                const RepeatYesterdayBottomSheet(),
                          );
                        },
                        onDismiss: () async {
                          await controller.dismissRepeatYesterdayCard();
                        },
                      ),
              ],
              SizedBox(height: mealGap),
              for (var i = 0; i < MealType.all.length; i++) ...[
                DailyLogMealBlock(
                  meal: MealType.all[i],
                  onEditEntry: (entry) =>
                      Get.toNamed(AppRoutes.editMeal, arguments: entry),
                ),
                if (i < MealType.all.length - 1) SizedBox(height: mealGap),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _CalorieSummaryCard extends StatelessWidget {
  const _CalorieSummaryCard({
    required this.eaten,
    required this.goal,
    required this.progress,
    required this.overGoal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.proteinGoalG,
    required this.carbsGoalG,
    required this.fatGoalG,
  });

  final int eaten;
  final int goal;
  final double progress;
  final bool overGoal;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int proteinGoalG;
  final int carbsGoalG;
  final int fatGoalG;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final remaining = (goal - eaten).clamp(0, goal);
    final overBy = eaten - goal;
    final statusColor = overGoal ? AppColors.warning : AppColors.primary;
    final statusLabel = overGoal
        ? '+$overBy over'
        : goal > 0
        ? '$remaining left'
        : null;

    return Container(
      padding: EdgeInsets.all(r.scale(18)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$eaten',
                style: TextStyle(
                  fontSize: r.scale(36, tablet: 40),
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -1,
                  color: statusColor,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: r.scale(4), bottom: r.scale(6)),
                child: Text(
                  '/ $goal kcal',
                  style: TextStyle(
                    fontSize: r.scale(15),
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              if (statusLabel != null)
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: r.scale(13),
                    fontWeight: FontWeight.w600,
                    color: overGoal
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          SizedBox(height: r.scale(14)),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: overGoal ? 1.0 : progress,
              minHeight: 6,
              backgroundColor: AppColors.border,
              color: statusColor,
            ),
          ),
          if (proteinGoalG > 0 || carbsGoalG > 0 || fatGoalG > 0) ...[
            SizedBox(height: r.scale(14)),
            Row(
              children: [
                _MacroStat(
                  label: 'Protein',
                  current: proteinG,
                  goal: proteinGoalG,
                  color: const Color(0xFF5AC8FA),
                ),
                _MacroStat(
                  label: 'Carbs',
                  current: carbsG,
                  goal: carbsGoalG,
                  color: AppColors.warning,
                ),
                _MacroStat(
                  label: 'Fat',
                  current: fatG,
                  goal: fatGoalG,
                  color: const Color(0xFFFF2D55),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MacroStat extends StatelessWidget {
  const _MacroStat({
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
  });

  final String label;
  final int current;
  final int goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: r.scale(11),
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: r.scale(2)),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: r.scale(13),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              children: [
                TextSpan(
                  text: '${current}g',
                  style: TextStyle(color: color),
                ),
                TextSpan(
                  text: ' / ${goal}g',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.showRepeat,
    required this.yesterdayCount,
    required this.onRepeat,
  });

  final bool showRepeat;
  final int yesterdayCount;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    if (!showRepeat) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onRepeat,
        icon: Icon(Icons.replay_rounded, size: 18),
        label: Text('Repeat yesterday · $yesterdayCount meals'),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: r.scale(12)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
