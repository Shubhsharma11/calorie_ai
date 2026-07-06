import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/nutrition_plan_controller.dart';
import '../controllers/user_controller.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/activity_level.dart';
import '../models/goal_type.dart';
import '../models/user_model.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_page.dart';

class DailyCalorieGoalView extends GetView<UserController> {
  const DailyCalorieGoalView({super.key});

  static const _pageBg = Color(0xFFF4F5F2);
  static const _carbsColor = Color(0xFF5CB87A);
  static const _proteinColor = Color(0xFF9B8FD9);
  static const _fatColor = Color(0xFFF0A060);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: GetBuilder<UserController>(
        builder: (_) {
          final user = controller.user;
          final r = context.responsive;
          final planController = Get.find<NutritionPlanController>();
          final goal = user.dailyCalorieGoal;
          final canDecrease = goal > UserController.minDailyCalories;
          final canIncrease = goal < UserController.maxDailyCalories;
          final editing = RouteArgs.isEditingFromProfile;

          return Obx(() {
            if (planController.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            return SafeArea(
              child: SetupScreenLayout(
                scrollable: true,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BackButton(),
                    SizedBox(height: r.scale(20)),
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
                      'A personalized plan designed around your goals and lifestyle.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: r.scale(14, tablet: 15),
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    SizedBox(height: r.scale(28)),
                    _DailyCaloriesCard(
                      goal: goal,
                      goalLabel: user.goal?.title ?? 'Maintain Weight',
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
                      progress: _macroProgress(user, user.proteinGoalG, 4),
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
                    SizedBox(height: r.scale(24)),
                    _OptimizationBox(
                      goalLabel: user.goal?.summaryLabel ?? 'Maintenance',
                      activityLabel: _activityLabel(user.activityLevel),
                    ),
                  ],
                ),
                action: PrimaryButton(
                  label: editing ? 'Save' : 'Start Tracking',
                  onPressed: () async {
                    if (editing) {
                      controller.notifyGoalConsumers();
                      Get.back();
                      return;
                    }
                    await controller.finishOnboardingSetup();
                  },
                ),
              ),
            );
          });
        },
      ),
    );
  }

  static double _macroProgress(UserModel user, int grams, int calPerGram) {
    final calories = user.dailyCalorieGoal;
    if (calories <= 0) return 0;
    return (grams * calPerGram / calories).clamp(0.0, 1.0);
  }

  static String _activityLabel(ActivityLevel level) {
    return switch (level) {
      ActivityLevel.sedentary => 'Sedentary',
      ActivityLevel.lightlyActive => 'Light',
      ActivityLevel.moderatelyActive => 'Moderate',
      ActivityLevel.veryActive => 'Very Active',
    };
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: Get.back,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textPrimary,
            ),
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

    return Center(
      child: Container(
        width: r.scale(52),
        height: r.scale(52),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: DailyCalorieGoalView._carbsColor.withValues(alpha: 0.12),
          boxShadow: [
            BoxShadow(
              color: DailyCalorieGoalView._carbsColor.withValues(alpha: 0.25),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.auto_awesome_rounded,
          size: r.scale(24),
          color: DailyCalorieGoalView._carbsColor,
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

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: r.scale(26, tablet: 28),
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.25,
          letterSpacing: -0.5,
        ),
        children: [
          const TextSpan(text: 'Your nutrition plan is ready,\n'),
          TextSpan(
            text: '$firstName.',
            style: TextStyle(color: DailyCalorieGoalView._carbsColor),
          ),
        ],
      ),
    );
  }
}

class _DailyCaloriesCard extends StatelessWidget {
  const _DailyCaloriesCard({
    required this.goal,
    required this.goalLabel,
    required this.showAdjusters,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int goal;
  final String goalLabel;
  final bool showAdjusters;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.scale(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                Text(
                  goalLabel,
                  style: TextStyle(
                    fontSize: r.scale(13),
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
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
          color: Colors.white.withValues(alpha: 0.65),
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
        color: Colors.white,
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
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: r.scale(20), color: color),
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

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(16),
        vertical: r.scale(16),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
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
                      'This plan is optimized for your $goalLabel goal.',
                      style: TextStyle(
                        fontSize: r.scale(12),
                        color: AppColors.textSecondary,
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
