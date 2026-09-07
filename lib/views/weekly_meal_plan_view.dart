import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/nutrition_plan_controller.dart';
import '../controllers/user_controller.dart';
import '../core/responsive.dart';
import '../models/goal_type.dart';
import '../models/planned_meal.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/log_meal_plan_dialog.dart';
import '../widgets/meal_type_icon.dart';
import '../widgets/responsive_page.dart';

class WeeklyMealPlanView extends StatefulWidget {
  const WeeklyMealPlanView({super.key});

  @override
  State<WeeklyMealPlanView> createState() => _WeeklyMealPlanViewState();
}

class _WeeklyMealPlanViewState extends State<WeeklyMealPlanView> {
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  late int _selectedWeekday;

  @override
  void initState() {
    super.initState();
    // DateTime.weekday: Mon=1 … Sun=7
    _selectedWeekday = DateTime.now().weekday;
  }

  String _goalLabel(GoalType? goal) {
    return switch (goal) {
      GoalType.loseWeight => 'Fat Loss',
      GoalType.gainWeight => 'Muscle Gain',
      GoalType.maintainWeight => 'Maintenance',
      null => 'Fitness',
    };
  }

  String _formatKcal(int value) {
    return NumberFormat('#,###').format(value);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final planController = Get.isRegistered<NutritionPlanController>()
        ? Get.find<NutritionPlanController>()
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar(title: 'Your Weekly Meal Plan'),
      body: ResponsivePage(
        scrollable: true,
        child: Builder(
          builder: (context) {
            if (!Get.isRegistered<UserController>()) {
              return const SizedBox.shrink();
            }
            final userController = Get.find<UserController>();
            return Obx(() {
              planController?.revision.value;
              userController.calorieGoalRevision.value;
              final user = userController.user;
              final plan = planController?.plan.value;
              final calories = plan?.calories ?? user.dailyCalorieGoal;
              final goal = user.pinnedGoalType ?? user.goal;
              final meals =
                  SampleWeeklyMealPlan.mealsForWeekday(_selectedWeekday);
              final nextMeals = meals
                  .where((m) => m.status == PlannedMealStatus.next)
                  .toList();
              final upcoming = meals
                  .where((m) => m.status == PlannedMealStatus.upcoming)
                  .toList();
              final completed = meals
                  .where((m) => m.status == PlannedMealStatus.completed)
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: r.scale(4)),
                  _TargetBanner(
                    caloriesLabel:
                        '${_formatKcal(calories)} kcal / day target',
                    goalLabel: _goalLabel(goal),
                  ),
                  SizedBox(height: r.scale(14)),
                  _WhitePanel(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.scale(12),
                      vertical: r.scale(12),
                    ),
                    child: _DaySelector(
                      selectedWeekday: _selectedWeekday,
                      labels: _dayLabels,
                      onSelected: (weekday) {
                        setState(() => _selectedWeekday = weekday);
                      },
                    ),
                  ),
                  SizedBox(height: r.scale(12)),
                  _WhitePanel(
                    padding: EdgeInsets.fromLTRB(
                      r.scale(14),
                      r.scale(18),
                      r.scale(14),
                      r.scale(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (nextMeals.isNotEmpty) ...[
                          const _SectionTitle(title: 'Next meal'),
                          SizedBox(height: r.scale(10)),
                          for (final meal in nextMeals) ...[
                            _NextMealCard(
                              meal: meal,
                              onTap: () => showLogMealPlanDialog(
                                context,
                                meal: meal,
                              ),
                            ),
                            SizedBox(height: r.scale(14)),
                          ],
                        ],
                        if (upcoming.isNotEmpty) ...[
                          const _SectionTitle(title: 'Upcoming meal'),
                          SizedBox(height: r.scale(10)),
                          for (final meal in upcoming) ...[
                            _UpcomingMealCard(
                              meal: meal,
                              onTap: () => showLogMealPlanDialog(
                                context,
                                meal: meal,
                              ),
                            ),
                            SizedBox(height: r.scale(10)),
                          ],
                          SizedBox(height: r.scale(6)),
                        ],
                        if (completed.isNotEmpty) ...[
                          const _SectionTitle(title: 'Completed'),
                          SizedBox(height: r.scale(10)),
                          for (final meal in completed) ...[
                            _CompletedMealCard(
                              meal: meal,
                              onTap: () => showLogMealPlanDialog(
                                context,
                                meal: meal,
                              ),
                            ),
                            SizedBox(height: r.scale(10)),
                          ],
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.viewPaddingOf(context).bottom +
                        r.scale(24),
                  ),
                ],
              );
            });
          },
        ),
      ),
    );
  }
}
class _WhitePanel extends StatelessWidget {
  const _WhitePanel({
    required this.child,
    required this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(r.scale(24)),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TargetBanner extends StatelessWidget {
  const _TargetBanner({
    required this.caloriesLabel,
    required this.goalLabel,
  });

  final String caloriesLabel;
  final String goalLabel;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(14),
        vertical: r.scale(14),
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/image/Vector.png',
            width: r.scale(40),
            height: r.scale(40),
            fit: BoxFit.contain,
          ),
          SizedBox(width: r.scale(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caloriesLabel,
                  style: TextStyle(
                    fontSize: r.scale(15),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: r.scale(2)),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: r.scale(12),
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                    children: [
                      const TextSpan(text: 'Designed around your '),
                      TextSpan(
                        text: goalLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const TextSpan(text: ' goal'),
                    ],
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

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.selectedWeekday,
    required this.labels,
    required this.onSelected,
  });

  final int selectedWeekday;
  final List<String> labels;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final chipWidth = r.scale(56);
    final chipHeight = r.scale(40);

    return SizedBox(
      height: chipHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => SizedBox(width: r.scale(8)),
        itemBuilder: (context, i) {
          return SizedBox(
            width: chipWidth,
            height: chipHeight,
            child: _DayChip(
              label: labels[i],
              selected: selectedWeekday == i + 1,
              onTap: () => onSelected(i + 1),
            ),
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final radius = BorderRadius.circular(r.scale(12));

    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.card,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: r.scale(13),
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primaryDark : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Text(
      title,
      style: TextStyle(
        fontSize: r.scale(16),
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _NextMealCard extends StatelessWidget {
  const _NextMealCard({required this.meal, required this.onTap});

  final PlannedMeal meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final radius = BorderRadius.circular(r.scale(16));

    return Material(
      color: AppColors.card,
      borderRadius: radius,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.all(r.scale(14)),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: radius,
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MealHeaderRow(meal: meal),
              SizedBox(height: r.scale(10)),
              Text(
                meal.name,
                style: TextStyle(
                  fontSize: r.scale(17),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: r.scale(12)),
              Row(
                children: [
                  Expanded(
                    child: _StatBlock(
                      value: '${meal.calories}',
                      unit: 'kcal',
                      label: 'Calories',
                    ),
                  ),
                  SizedBox(width: r.scale(8)),
                  Expanded(
                    child: _StatBlock(
                      value: '${meal.proteinG}',
                      unit: 'g',
                      label: 'Protein',
                    ),
                  ),
                  SizedBox(width: r.scale(8)),
                  Expanded(
                    child: _StatBlock(
                      value: '${meal.carbsG}',
                      unit: 'g',
                      label: 'Carbs',
                    ),
                  ),
                  SizedBox(width: r.scale(8)),
                  Expanded(
                    child: _StatBlock(
                      value: '${meal.fatG}',
                      unit: 'g',
                      label: 'Fat',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingMealCard extends StatelessWidget {
  const _UpcomingMealCard({required this.meal, required this.onTap});

  final PlannedMeal meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final radius = BorderRadius.circular(r.scale(16));

    return Material(
      color: AppColors.card,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.all(r.scale(12)),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: radius,
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MealHeaderRow(meal: meal),
              SizedBox(height: r.scale(8)),
              Text(
                meal.name,
                style: TextStyle(
                  fontSize: r.scale(16),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedMealCard extends StatelessWidget {
  const _CompletedMealCard({required this.meal, required this.onTap});

  final PlannedMeal meal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final radius = BorderRadius.circular(r.scale(16));

    return Material(
      color: AppColors.primary.withValues(alpha: 0.1),
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.all(r.scale(12)),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MealHeaderRow(meal: meal),
              SizedBox(height: r.scale(8)),
              Text(
                meal.name,
                style: TextStyle(
                  fontSize: r.scale(16),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealHeaderRow extends StatelessWidget {
  const _MealHeaderRow({required this.meal});

  final PlannedMeal meal;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Row(
      children: [
        MealTypeIcon(meal: meal.mealType, size: r.scale(28)),
        SizedBox(width: r.scale(8)),
        Expanded(
          child: Text(
            meal.mealType,
            style: TextStyle(
              fontSize: r.scale(14),
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
        Text(
          meal.timeLabel,
          style: TextStyle(
            fontSize: r.scale(13),
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          size: r.scale(18),
          color: AppColors.textSecondary,
        ),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.value,
    required this.unit,
    required this.label,
  });

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(6),
        vertical: r.scale(10),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: r.scale(13),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: TextStyle(
                    fontSize: r.scale(10),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: r.scale(2)),
          Text(
            label,
            style: TextStyle(
              fontSize: r.scale(10),
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
