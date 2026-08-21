import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/nutrition_plan_controller.dart';
import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/activity_level.dart';
import '../models/goal_type.dart';
import '../models/user_model.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_page.dart';

class DailyCalorieGoalView extends GetView<UserController> {
  const DailyCalorieGoalView({super.key});

  static Color get _pageBg => AppColors.background;
  static const _carbsColor = Color(0xFF5CB87A);
  static const _proteinColor = Color(0xFF9B8FD9);
  static const _fatColor = Color(0xFFF0A060);

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final editing = RouteArgs.isEditingFromProfile;

    return PopScope(
      // Onboarding: this is the final setup step — no going back.
      canPop: editing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !editing) return;
        Get.back<void>();
      },
      child: Scaffold(
        backgroundColor: _pageBg,
        appBar: editing
            ? AppAppBar.backOnly(onBack: () => Get.back<void>())
            : AppBar(
                backgroundColor: _pageBg,
                elevation: 0,
                scrolledUnderElevation: 0,
                automaticallyImplyLeading: false,
              ),
        body: GetBuilder<UserController>(
          builder: (_) {
            final user = controller.user;
            final r = context.responsive;
            final planController = Get.find<NutritionPlanController>();
            final goal = user.dailyCalorieGoal;
            final canDecrease = goal > UserController.minDailyCalories;
            final canIncrease = goal < UserController.maxDailyCalories;

            return Obx(() {
              planController.revision.value;
              controller.calorieGoalRevision.value;
              if (planController.isLoading.value &&
                  !controller.isRefreshingWeightTarget.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final refreshing = controller.isRefreshingWeightTarget.value;
              final showWeightChoice =
                  !editing && controller.shouldShowWeightTargetChoice;

              return SetupScreenLayout(
                scrollable: true,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: r.scale(8)),
                    if (planController.errorMessage.value != null) ...[
                      _PlanErrorBanner(
                        message: planController.errorMessage.value!,
                        onRetry: planController.loadPlan,
                      ),
                      SizedBox(height: r.scale(16)),
                    ],
                    const _HeaderStar(),
                    SizedBox(height: r.scale(18)),
                    _PlanTitle(firstName: user.firstName),
                    SizedBox(height: r.scale(8)),
                    Text(
                      'Built around your goals and lifestyle.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: r.scale(14, tablet: 15),
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    SizedBox(height: r.scale(28)),
                    Stack(
                      children: [
                        _DailyCaloriesCard(
                          goal: goal,
                          goalType: user.goal ?? GoalType.maintainWeight,
                          currentWeightKg: user.weightKg?.toDouble() ?? 0,
                          targetWeightKg: user.goalWeightKg,
                          goalExplanation: _WeightTargetSection.planGoalExplanation(
                            user.goal ?? GoalType.maintainWeight,
                            user.weightKg?.toDouble() ?? 0,
                            user.goalWeightKg,
                          ),
                          showAdjusters: editing,
                          canDecrease: canDecrease,
                          canIncrease: canIncrease,
                          onDecrease: () => controller.adjustCalorieGoal(
                            -UserController.calorieStep,
                          ),
                          onIncrease: () => controller.adjustCalorieGoal(
                            UserController.calorieStep,
                          ),
                        ),
                        if (refreshing)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.card.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: r.scale(28)),
                    Text(
                      'MACRONUTRIENTS',
                      style: TextStyle(
                        fontSize: r.scale(11),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: r.scale(14)),
                    Opacity(
                      opacity: refreshing ? 0.55 : 1,
                      child: Column(
                        children: [
                          _MacroNutrientRow(
                            icon: Icons.eco_rounded,
                            label: 'Carbohydrates',
                            grams: user.carbsGoalG,
                            rangeLabel: '45–65%',
                            color: _carbsColor,
                            progress: _macroProgress(user, user.carbsGoalG, 4),
                          ),
                          SizedBox(height: r.scale(14)),
                          _MacroNutrientRow(
                            icon: Icons.fitness_center_rounded,
                            label: 'Protein',
                            grams: user.proteinGoalG,
                            rangeLabel: '20–30%',
                            color: _proteinColor,
                            progress:
                                _macroProgress(user, user.proteinGoalG, 4),
                          ),
                          SizedBox(height: r.scale(14)),
                          _MacroNutrientRow(
                            icon: Icons.water_drop_outlined,
                            label: 'Fats',
                            grams: user.fatGoalG,
                            rangeLabel: '20–35%',
                            color: _fatColor,
                            progress: _macroProgress(user, user.fatGoalG, 9),
                          ),
                        ],
                      ),
                    ),
                    if (showWeightChoice) ...[
                      SizedBox(height: r.scale(24)),
                      _WeightTargetSection(
                        goal: user.goal!,
                        currentWeightKg: user.weightKg?.toDouble() ?? 0,
                        userTargetKg: controller.resolvedUserGoalWeightKg!,
                        aiTargetKg: controller.resolvedAiGoalWeightKg!,
                        selected: controller.weightTargetSource.value,
                        enabled: !refreshing,
                        onSelect: (source) async {
                          final error =
                              await controller.selectWeightTarget(source);
                          if (error != null) {
                            AppSnackbar.error(error, title: 'Plan update failed');
                          }
                        },
                      ),
                    ],
                    SizedBox(height: r.scale(24)),
                    _OptimizationBox(
                      goalLabel: user.goal?.summaryLabel ?? 'Maintenance',
                      activityLabel: _activityLabel(user.activityLevel),
                    ),
                  ],
                ),
                action: PrimaryButton(
                  label: editing ? 'Save' : 'Start Tracking',
                  onPressed: refreshing
                      ? null
                      : () async {
                          if (editing) {
                            controller.notifyGoalConsumers();
                            Get.back();
                            return;
                          }
                          await controller.finishOnboardingSetup();
                        },
                ),
              );
            });
          },
        ),
      ),
    );
  }

  static double _macroProgress(UserModel user, int grams, int calPerGram) {
    final calories = user.dailyCalorieGoal;
    if (calories <= 0) return 0;
    return (grams * calPerGram / calories).clamp(0.0, 1.0);
  }

  static String _activityLabel(ActivityLevel? level) {
    return switch (level) {
      ActivityLevel.sedentary => 'Sedentary',
      ActivityLevel.lightlyActive => 'Light',
      ActivityLevel.moderatelyActive => 'Moderate',
      ActivityLevel.veryActive => 'Very Active',
      null => 'Not set',
    };
  }
}

class _WeightTargetSection extends StatelessWidget {
  const _WeightTargetSection({
    required this.goal,
    required this.currentWeightKg,
    required this.userTargetKg,
    required this.aiTargetKg,
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  final GoalType goal;
  final double currentWeightKg;
  final double userTargetKg;
  final double aiTargetKg;
  final WeightTargetSource selected;
  final bool enabled;
  final ValueChanged<WeightTargetSource> onSelect;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.scale(14)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose your weight target',
            style: TextStyle(
              fontSize: r.scale(16, tablet: 17),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: r.scale(12)),
          _WeightTargetOptionCard(
            title: 'Your goal',
            changeLabel: changeLabel(goal, currentWeightKg, userTargetKg),
            targetLabel: 'Target ${_formatKg(userTargetKg)} kg',
            selected: selected == WeightTargetSource.user,
            enabled: enabled,
            onTap: () => onSelect(WeightTargetSource.user),
          ),
          SizedBox(height: r.scale(10)),
          _WeightTargetOptionCard(
            title: 'AI recommended',
            changeLabel: changeLabel(goal, currentWeightKg, aiTargetKg),
            targetLabel: 'Target ${_formatKg(aiTargetKg)} kg',
            helper: 'Steadier pace for your profile',
            selected: selected == WeightTargetSource.ai,
            enabled: enabled,
            onTap: () => onSelect(WeightTargetSource.ai),
          ),
          SizedBox(height: r.scale(12)),
          Text(
            'Choosing a target updates your calorie plan.',
            style: TextStyle(
              fontSize: r.scale(12),
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatKg(double kg) {
    return kg == kg.roundToDouble()
        ? kg.toStringAsFixed(0)
        : kg.toStringAsFixed(1);
  }

  static String changeLabel(
    GoalType goal,
    double currentKg,
    double targetKg,
  ) {
    final delta = (targetKg - currentKg).abs();
    if (goal == GoalType.maintainWeight || delta < 0.1) {
      return 'Keep current weight';
    }
    final amount = _formatKg(delta);
    return switch (goal) {
      GoalType.loseWeight => 'Lose $amount kg',
      GoalType.gainWeight => 'Gain $amount kg',
      GoalType.maintainWeight => 'Keep current weight',
    };
  }

  /// Longer AI-style copy for the daily calories card.
  static String planGoalExplanation(
    GoalType goal,
    double currentKg,
    double targetKg,
  ) {
    final delta = (targetKg - currentKg).abs();
    final target = _formatKg(targetKg);
    if (goal == GoalType.maintainWeight || delta < 0.1) {
      return 'AI set this daily calorie target to help you maintain '
          'your weight at $target kg.';
    }
    final amount = _formatKg(delta);
    return switch (goal) {
      GoalType.loseWeight =>
        'AI set this daily calorie target to help you lose $amount kg '
            'and reach $target kg.',
      GoalType.gainWeight =>
        'AI set this daily calorie target to help you gain $amount kg '
            'and reach $target kg.',
      GoalType.maintainWeight =>
        'AI set this daily calorie target to help you maintain '
            'your weight at $target kg.',
    };
  }
}

class _WeightTargetOptionCard extends StatelessWidget {
  const _WeightTargetOptionCard({
    required this.title,
    required this.changeLabel,
    required this.targetLabel,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.helper,
  });

  final String title;
  final String changeLabel;
  final String targetLabel;
  final String? helper;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.06)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(r.scale(12)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.border.withValues(alpha: 0.8),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: r.scale(2)),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: r.scale(20),
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              SizedBox(width: r.scale(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: r.scale(13),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(
                            Icons.check_circle_rounded,
                            size: r.scale(18),
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                    SizedBox(height: r.scale(4)),
                    Text(
                      changeLabel,
                      style: TextStyle(
                        fontSize: r.scale(17, tablet: 18),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: r.scale(2)),
                    Text(
                      targetLabel,
                      style: TextStyle(
                        fontSize: r.scale(13),
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (helper != null) ...[
                      SizedBox(height: r.scale(4)),
                      Text(
                        helper!,
                        style: TextStyle(
                          fontSize: r.scale(11),
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStar extends StatelessWidget {
  const _HeaderStar();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final glowAlpha = AppColors.isDark(context) ? 0.18 : 0.25;

    return Center(
      child: Padding(
        // Keep the soft glow inside the scroll clip bounds.
        padding: EdgeInsets.all(r.scale(10)),
        child: Container(
          width: r.scale(52),
          height: r.scale(52),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: DailyCalorieGoalView._carbsColor.withValues(alpha: 0.12),
            boxShadow: [
              BoxShadow(
                color: DailyCalorieGoalView._carbsColor.withValues(
                  alpha: glowAlpha,
                ),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: r.scale(24),
            color: DailyCalorieGoalView._carbsColor,
          ),
        ),
      ),
    );
  }
}

class _PlanTitle extends StatelessWidget {
  const _PlanTitle({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final baseStyle = TextStyle(
      fontSize: r.scale(26, tablet: 28),
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      height: 1.3,
      letterSpacing: -0.5,
    );

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'Your nutrition plan is ready,\n'),
          TextSpan(
            text: '$firstName.',
            style: baseStyle.copyWith(
              color: DailyCalorieGoalView._carbsColor,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _DailyCaloriesCard extends StatelessWidget {
  const _DailyCaloriesCard({
    required this.goal,
    required this.goalType,
    required this.currentWeightKg,
    required this.targetWeightKg,
    required this.goalExplanation,
    required this.showAdjusters,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int goal;
  final GoalType goalType;
  final double currentWeightKg;
  final double targetWeightKg;
  final String goalExplanation;
  final bool showAdjusters;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  IconData get _goalIcon => switch (goalType) {
        GoalType.loseWeight => Icons.trending_down_rounded,
        GoalType.gainWeight => Icons.trending_up_rounded,
        GoalType.maintainWeight => Icons.balance_rounded,
      };

  String _formatKg(double kg) {
    return kg == kg.roundToDouble()
        ? kg.toStringAsFixed(0)
        : kg.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final currentLabel = '${_formatKg(currentWeightKg)} kg';
    final targetLabel = '${_formatKg(targetWeightKg)} kg';
    final isMaintain = goalType == GoalType.maintainWeight ||
        (targetWeightKg - currentWeightKg).abs() < 0.1;

    return Container(
      padding: EdgeInsets.all(r.scale(20)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: DailyCalorieGoalView._carbsColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: r.scale(8)),
                    Text(
                      'Daily Calories',
                      style: TextStyle(
                        fontSize: r.scale(14),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.scale(14)),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: r.scale(36, tablet: 40),
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1,
                      letterSpacing: -1.5,
                    ),
                    children: [
                      TextSpan(text: '$goal '),
                      TextSpan(
                        text: 'kcal',
                        style: TextStyle(
                          fontSize: r.scale(18),
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.scale(14)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.scale(10),
                    vertical: r.scale(6),
                  ),
                  decoration: BoxDecoration(
                    color: DailyCalorieGoalView._carbsColor.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _goalIcon,
                        size: r.scale(14),
                        color: DailyCalorieGoalView._carbsColor,
                      ),
                      SizedBox(width: r.scale(5)),
                      Text(
                        goalType.title,
                        style: TextStyle(
                          fontSize: r.scale(12),
                          fontWeight: FontWeight.w700,
                          color: DailyCalorieGoalView._carbsColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.scale(10)),
                Text(
                  isMaintain
                      ? 'Target weight  $targetLabel'
                      : '$currentLabel  →  $targetLabel',
                  style: TextStyle(
                    fontSize: r.scale(14, tablet: 15),
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: r.scale(6)),
                Text(
                  goalExplanation,
                  style: TextStyle(
                    fontSize: r.scale(12, tablet: 13),
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                if (showAdjusters) ...[
                  SizedBox(height: r.scale(14)),
                  Row(
                    children: [
                      _MiniAdjustButton(
                        icon: Icons.remove_rounded,
                        onPressed: canDecrease ? onDecrease : null,
                      ),
                      SizedBox(width: r.scale(8)),
                      _MiniAdjustButton(
                        icon: Icons.add_rounded,
                        onPressed: canIncrease ? onIncrease : null,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: r.scale(12)),
          _DecorativeDiscs(size: r.scale(92, tablet: 100)),
        ],
      ),
    );
  }
}

class _DecorativeDiscs extends StatelessWidget {
  const _DecorativeDiscs({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: size * 0.06,
            right: size * 0.04,
            child: _GlassDisc(
              diameter: size * 0.48,
              color: DailyCalorieGoalView._carbsColor,
            ),
          ),
          Positioned(
            left: 0,
            bottom: size * 0.14,
            child: _GlassDisc(
              diameter: size * 0.42,
              color: DailyCalorieGoalView._proteinColor,
            ),
          ),
          Positioned(
            right: size * 0.18,
            bottom: size * 0.02,
            child: _GlassDisc(
              diameter: size * 0.34,
              color: DailyCalorieGoalView._fatColor,
            ),
          ),
          Positioned(
            top: size * 0.22,
            left: size * 0.28,
            child: _SparkDot(diameter: size * 0.07),
          ),
          Positioned(
            bottom: size * 0.34,
            right: size * 0.02,
            child: _SparkDot(diameter: size * 0.055),
          ),
        ],
      ),
    );
  }
}

class _GlassDisc extends StatelessWidget {
  const _GlassDisc({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.28),
          ],
        ),
        border: Border.all(
          color: AppColors.onPrimary.withValues(alpha: 0.65),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );
  }
}

class _SparkDot extends StatelessWidget {
  const _SparkDot({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.card,
        boxShadow: [
          BoxShadow(
            color: DailyCalorieGoalView._carbsColor.withValues(alpha: 0.25),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

class _MiniAdjustButton extends StatelessWidget {
  const _MiniAdjustButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DailyCalorieGoalView._pageBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            icon,
            size: 18,
            color: onPressed == null
                ? AppColors.textSecondary.withValues(alpha: 0.35)
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _MacroNutrientRow extends StatelessWidget {
  const _MacroNutrientRow({
    required this.icon,
    required this.label,
    required this.grams,
    required this.rangeLabel,
    required this.color,
    required this.progress,
  });

  final IconData icon;
  final String label;
  final int grams;
  final String rangeLabel;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: r.scale(40),
          height: r.scale(40),
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: AppColors.isDark(context) ? 0.22 : 0.14,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: r.scale(20),
            color: color,
          ),
        ),
        SizedBox(width: r.scale(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: r.scale(14),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: r.scale(8)),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: r.scale(4),
                  backgroundColor: AppColors.border,
                  color: color,
                ),
              ),
              SizedBox(height: r.scale(8)),
              Row(
                children: [
                  Text(
                    '${grams}g',
                    style: TextStyle(
                      fontSize: r.scale(14),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(width: r.scale(8)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.scale(10),
                      vertical: r.scale(4),
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      rangeLabel,
                      style: TextStyle(
                        fontSize: r.scale(11),
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptimizationBox extends StatelessWidget {
  const _OptimizationBox({
    required this.goalLabel,
    required this.activityLabel,
  });

  final String goalLabel;
  final String activityLabel;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final isDark = AppColors.isDark(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(16),
        vertical: r.scale(16),
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: r.scale(18),
                    color: DailyCalorieGoalView._carbsColor,
                  ),
                  SizedBox(width: r.scale(10)),
                  Expanded(
                    child: Text(
                      'This plan is tailored to your ${goalLabel.toLowerCase()} goal.',
                      style: TextStyle(
                        fontSize: r.scale(12),
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              margin: EdgeInsets.symmetric(horizontal: r.scale(12)),
              color: AppColors.border,
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Activity level',
                    style: TextStyle(
                      fontSize: r.scale(11),
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: r.scale(4)),
                  Text(
                    activityLabel,
                    style: TextStyle(
                      fontSize: r.scale(14),
                      fontWeight: FontWeight.w700,
                      color: DailyCalorieGoalView._carbsColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanErrorBanner extends StatelessWidget {
  const _PlanErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.scale(12)),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: r.scale(12),
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
