import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/macro_emojis.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/activity_level.dart';
import '../models/user_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_page.dart';

class DailyCalorieGoalView extends GetView<UserController> {
  const DailyCalorieGoalView({super.key});

  Map<String, bool> get _editArgs => RouteArgs.isEditingFromProfile
      ? RouteArgs.fromProfileMap
      : RouteArgs.returnToDailyGoalMap;

  void _showMacroInfo(BuildContext context, UserModel user) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Macro targets'),
        content: SingleChildScrollView(
          child: Text(
            'Macros are the protein, carbohydrates, and fats that make up '
            'your daily calories. The ranges shown follow common nutrition '
            'guidelines.\n\n'
            'Your current targets from ${user.dailyCalorieGoal} kcal:\n'
            '• Protein: ${user.proteinGoalG}g (30%)\n'
            '• Carbohydrates: ${user.carbsGoalG}g (40%)\n'
            '• Fats: ${user.fatGoalG}g (30%)',
            style: TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceInfo(BuildContext context, UserModel user) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Maintenance calories'),
        content: SingleChildScrollView(
          child: Text(
            'Maintenance calories (${user.maintenanceCalories} kcal) are the '
            'estimated amount you need each day to maintain your current '
            'weight. They are based on your age, height, weight, gender, '
            'and activity level.\n\n'
            'Your daily goal adjusts from this number depending on whether '
            'you want to lose, gain, or maintain weight.',
            style: TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your Daily Goal'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: GetBuilder<UserController>(
        builder: (_) {
          final u = controller.user;
          final r = context.responsive;
          final calculated = u.calculatedDailyCalorieGoal;
          final goal = u.dailyCalorieGoal;
          final canDecrease = goal > UserController.minDailyCalories;
          final canIncrease = goal < UserController.maxDailyCalories;

          return SetupScreenLayout(
            scrollable: true,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroSection(r: r),
                SizedBox(height: r.scale(20)),
                _CalorieGoalPicker(
                  goal: goal,
                  canDecrease: canDecrease,
                  canIncrease: canIncrease,
                  onDecrease: () =>
                      controller.adjustCalorieGoal(-UserController.calorieStep),
                  onIncrease: () =>
                      controller.adjustCalorieGoal(UserController.calorieStep),
                ),
                SizedBox(height: r.scale(14)),
                _RecommendationBanner(
                  calories: calculated,
                  showReset: u.hasManualCalorieAdjustment,
                  onReset: controller.resetCalorieAdjustment,
                ),
                SizedBox(height: r.scale(16)),
                _ProfileSummaryRow(
                  user: u,
                  onGoalWeightTap: RouteArgs.isEditingFromProfile
                      ? () => Get.toNamed(
                            AppRoutes.goalWeight,
                            arguments: _editArgs,
                          )
                      : null,
                  onActivityLevelTap: () => Get.toNamed(
                    AppRoutes.activityLevel,
                    arguments: _editArgs,
                  ),
                  onMaintenanceTap: () => _showMaintenanceInfo(context, u),
                ),
                SizedBox(height: r.scale(24)),
                Row(
                  children: [
                    Text(
                      'Macro targets',
                      style: TextStyle(
                        fontSize: r.scale(16),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => _showMacroInfo(context, u),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Learn more',
                              style: TextStyle(
                                fontSize: r.scale(13),
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.info_outline_rounded,
                              size: r.scale(16),
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.scale(12)),
                Row(
                  children: [
                    _MacroRangeCard(
                      label: 'Protein',
                      emoji: MacroEmojis.protein,
                      grams: u.proteinGoalG,
                      rangeLabel: '20–30%',
                      percent: _macroPercent(u, MacroKind.protein),
                      rangeMin: 20,
                      rangeMax: 30,
                      color: const Color(0xFFE8A317),
                    ),
                    const SizedBox(width: 10),
                    _MacroRangeCard(
                      label: 'Carbohydrates',
                      emoji: MacroEmojis.carbs,
                      grams: u.carbsGoalG,
                      rangeLabel: '45–65%',
                      percent: _macroPercent(u, MacroKind.carbs),
                      rangeMin: 45,
                      rangeMax: 65,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    _MacroRangeCard(
                      label: 'Fats',
                      emoji: MacroEmojis.fat,
                      grams: u.fatGoalG,
                      rangeLabel: '20–35%',
                      percent: _macroPercent(u, MacroKind.fat),
                      rangeMin: 20,
                      rangeMax: 35,
                      color: const Color(0xFF5AC46A),
                    ),
                  ],
                ),
              ],
            ),
            action: PrimaryButton(
              label: RouteArgs.isEditingFromProfile ? 'Save' : 'Start Tracking',
              onPressed: () {
                if (RouteArgs.isEditingFromProfile) {
                  controller.notifyGoalConsumers();
                  Get.back();
                } else {
                  controller.completeOnboarding();
                }
              },
            ),
          );
        },
      ),
    );
  }

  static int _macroPercent(UserModel u, MacroKind kind) {
    final calories = u.dailyCalorieGoal;
    if (calories <= 0) return 0;
    return switch (kind) {
      MacroKind.protein => (u.proteinGoalG * 4 / calories * 100).round(),
      MacroKind.carbs => (u.carbsGoalG * 4 / calories * 100).round(),
      MacroKind.fat => (u.fatGoalG * 9 / calories * 100).round(),
    };
  }
}

enum MacroKind { protein, carbs, fat }

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.r});

  final Responsive r;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: r.scale(24, tablet: 26),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                  children: const [
                    TextSpan(text: 'Set your daily '),
                    TextSpan(
                      text: 'calorie',
                      style: TextStyle(color: AppColors.primary),
                    ),
                    TextSpan(text: ' goal'),
                  ],
                ),
              ),
              SizedBox(height: r.scale(8)),
              Text(
                'Adjust up or down from the recommended amount.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: r.scale(8)),
        const _HeroIllustration(),
      ],
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final size = r.scale(88, tablet: 96);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 4,
            right: 0,
            child: Icon(
              Icons.eco_rounded,
              size: r.scale(28),
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          Positioned(
            top: 18,
            left: 2,
            child: Icon(
              Icons.spa_rounded,
              size: r.scale(22),
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          Positioned(
            bottom: 6,
            right: 8,
            child: Container(
              width: r.scale(52),
              height: r.scale(52),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: r.scale(28),
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalorieGoalPicker extends StatelessWidget {
  const _CalorieGoalPicker({
    required this.goal,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int goal;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(16),
        vertical: r.scale(24),
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'DAILY GOAL',
            style: TextStyle(
              fontSize: r.scale(11),
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: AppColors.textSecondary.withValues(alpha: 0.85),
            ),
          ),
          SizedBox(height: r.scale(16)),
          Row(
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                onPressed: canDecrease ? onDecrease : null,
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$goal',
                      style: TextStyle(
                        fontSize: r.scale(44, tablet: 48),
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        height: 1,
                        letterSpacing: -1,
                      ),
                    ),
                    SizedBox(width: r.scale(6)),
                    Text(
                      'kcal / day',
                      style: TextStyle(
                        fontSize: r.scale(14),
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                onPressed: canIncrease ? onIncrease : null,
              ),
            ],
          ),
          SizedBox(height: r.scale(16)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '±${UserController.calorieStep} kcal per tap',
              style: TextStyle(
                fontSize: r.scale(11),
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: r.scale(48),
          height: r.scale(48),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(
            icon,
            size: 22,
            color: onPressed == null
                ? AppColors.textSecondary.withValues(alpha: 0.35)
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _RecommendationBanner extends StatelessWidget {
  const _RecommendationBanner({
    required this.calories,
    required this.showReset,
    required this.onReset,
  });

  final int calories;
  final bool showReset;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(14),
        vertical: r.scale(12),
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.star_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: r.scale(14),
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                    children: [
                      const TextSpan(text: 'Recommended for you: '),
                      TextSpan(
                        text: '$calories kcal',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Based on your profile and activity level.',
                  style: TextStyle(
                    fontSize: r.scale(12),
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                if (showReset) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onReset,
                    child: const Text(
                      'Reset to recommended',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummaryRow extends StatelessWidget {
  const _ProfileSummaryRow({
    required this.user,
    required this.onGoalWeightTap,
    required this.onActivityLevelTap,
    required this.onMaintenanceTap,
  });

  final UserModel user;
  final VoidCallback? onGoalWeightTap;
  final VoidCallback onActivityLevelTap;
  final VoidCallback onMaintenanceTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _ProfileSummaryCell(
                icon: Icons.monitor_weight_outlined,
                label: 'Goal Weight',
                value:
                    '${user.weightKg} kg → ${user.goalWeightKg.toStringAsFixed(1)} kg',
                onTap: onGoalWeightTap,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.border,
              indent: r.scale(14),
              endIndent: r.scale(14),
            ),
            Expanded(
              child: _ProfileSummaryCell(
                icon: Icons.directions_run_rounded,
                label: 'Activity Level',
                value: user.activityLevel.title,
                onTap: onActivityLevelTap,
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.border,
              indent: r.scale(14),
              endIndent: r.scale(14),
            ),
            Expanded(
              child: _ProfileSummaryCell(
                icon: Icons.local_fire_department_rounded,
                label: 'Maintenance\nCalories',
                value: '${user.maintenanceCalories} kcal',
                onTap: onMaintenanceTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSummaryCell extends StatelessWidget {
  const _ProfileSummaryCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: onTap == null ? 0.85 : 1,
          child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(6),
            vertical: r.scale(14),
          ),
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              SizedBox(height: r.scale(8)),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: r.scale(10),
                  color: AppColors.textSecondary,
                  height: 1.2,
                ),
              ),
              SizedBox(height: r.scale(4)),
              Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: r.scale(11),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _MacroRangeCard extends StatelessWidget {
  const _MacroRangeCard({
    required this.label,
    required this.emoji,
    required this.grams,
    required this.rangeLabel,
    required this.percent,
    required this.rangeMin,
    required this.rangeMax,
    required this.color,
  });

  final String label;
  final String emoji;
  final int grams;
  final String rangeLabel;
  final int percent;
  final int rangeMin;
  final int rangeMax;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final rangeSpan = (rangeMax - rangeMin).clamp(1, 100);
    final fill = ((percent - rangeMin) / rangeSpan).clamp(0.0, 1.0);

    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.scale(8),
          vertical: r.scale(14),
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: TextStyle(fontSize: r.scale(22))),
            SizedBox(height: r.scale(6)),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: r.scale(11),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            SizedBox(height: r.scale(4)),
            Text(
              rangeLabel,
              style: TextStyle(
                fontSize: r.scale(11),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            SizedBox(height: r.scale(4)),
            Text(
              '${grams}g',
              style: TextStyle(
                fontSize: r.scale(13),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: r.scale(8)),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fill,
                minHeight: 5,
                backgroundColor: color.withValues(alpha: 0.15),
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
