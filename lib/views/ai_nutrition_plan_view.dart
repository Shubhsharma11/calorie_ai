import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/nutrition_plan_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/tracker_controller.dart';
import '../controllers/user_controller.dart';
import '../core/responsive.dart';
import '../core/weight_chart_data.dart';
import '../models/goal_type.dart';
import '../models/user_model.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/responsive_page.dart';

class AiNutritionPlanView extends StatefulWidget {
  const AiNutritionPlanView({super.key});

  @override
  State<AiNutritionPlanView> createState() => _AiNutritionPlanViewState();
}

class _AiNutritionPlanViewState extends State<AiNutritionPlanView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<NutritionPlanController>()) {
        Get.find<NutritionPlanController>().loadPlan(force: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final userController = Get.find<UserController>();
    final r = context.responsive;
    final planController = Get.isRegistered<NutritionPlanController>()
        ? Get.find<NutritionPlanController>()
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppAppBar(
        title: 'AI Nutrition Plan',
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Share',
          ),
        ],
      ),
      body: ResponsivePage(
        scrollable: true,
        child: Obx(() {
          final user = userController.user;
          final plan = planController?.plan.value;
          final isLoading = planController?.isLoading.value ?? false;
          final _ = planController?.revision.value;
          if (Get.isRegistered<TrackerController>()) {
            Get.find<TrackerController>().weightRevision.value;
          }
          final useMetric = Get.isRegistered<SettingsController>()
              ? Get.find<SettingsController>().useMetricUnits.value
              : true;

          final calories = plan?.calories ?? user.dailyCalorieGoal;
          final protein = plan?.proteinG ?? user.proteinGoalG;
          final carbs = plan?.carbsG ?? user.carbsGoalG;
          final fat = plan?.fatG ?? user.fatGoalG;
          final tips = plan?.tips ?? const <String>[];
          final weightGoalLine = _weightGoalSummary(
            user: user,
            planTargetKg: plan?.targetWeightKg,
            useMetricUnits: useMetric,
          );

          if (isLoading && plan == null) {
            return Padding(
              padding: EdgeInsets.only(top: r.scale(48)),
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: r.scale(8)),
              _PlanSummaryCard(
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                weightGoalLine: weightGoalLine,
              ),
              SizedBox(height: r.scale(16)),
              const _SectionHeader(title: 'AI Tips for You'),
              SizedBox(height: r.scale(9)),
              if (tips.isEmpty)
                _TipsEmptyState(isLoading: isLoading)
              else
                _AiTipsCard(tips: tips),
              SizedBox(height: r.scale(14)),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: Get.back,
                  icon: const Icon(Icons.fact_check_rounded, size: 19),
                  label: const Text('Save My Plan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(height: r.scale(10)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: r.scale(13),
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: r.scale(5)),
                  Text(
                    'Your plan is private and secure',
                    style: TextStyle(
                      fontSize: r.scale(12),
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: MediaQuery.viewPaddingOf(context).bottom +
                    r.scale(16),
              ),
            ],
          );
        }),
      ),
    );
  }

  String _weightGoalSummary({
    required UserModel user,
    required double? planTargetKg,
    required bool useMetricUnits,
  }) {
    final currentKg = Get.isRegistered<TrackerController>()
        ? Get.find<TrackerController>().currentWeight.value
        : user.weightKg.toDouble();
    final targetKg = planTargetKg ?? user.goalWeightKg;
    final deltaKg = targetKg - currentKg;

    if (user.goal == GoalType.maintainWeight || deltaKg.abs() < 0.1) {
      return 'Maintain current weight';
    }

    final amount = WeightChartData.formatWeight(deltaKg.abs(), useMetricUnits);
    final byDate = DateFormat('dd MMM').format(user.targetDate);
    if (deltaKg < 0) {
      return 'Lose $amount · by $byDate';
    }
    return 'Gain $amount · by $byDate';
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.weightGoalLine,
  });

  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final String weightGoalLine;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(r.scale(14)),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Daily Nutrition Plan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.scale(16, tablet: 17),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: r.scale(4)),
                      Text(
                        weightGoalLine,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: r.scale(13, tablet: 14),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: r.scale(2)),
                      Text(
                        'Based on your profile and goal',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: r.scale(11, tablet: 12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const _ClipboardAppleIllustration(),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: r.scale(10),
              vertical: r.scale(13),
            ),
            child: Row(
              children: [
                _MacroPlanStat(value: '$calories', label: 'Calories / day'),
                _MacroPlanStat(value: '${protein}g', label: 'Protein'),
                _MacroPlanStat(value: '${carbs}g', label: 'Carbs'),
                _MacroPlanStat(value: '${fat}g', label: 'Fat'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClipboardAppleIllustration extends StatelessWidget {
  const _ClipboardAppleIllustration();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return SizedBox(
      width: r.scale(78),
      height: r.scale(58),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            right: 8,
            child: Icon(
              Icons.eco_rounded,
              color: Colors.white.withValues(alpha: 0.16),
              size: r.scale(58),
            ),
          ),
          Container(
            width: r.scale(43),
            height: r.scale(54),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(7),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: r.scale(9),
                        color: AppColors.primary,
                      ),
                      SizedBox(width: r.scale(3)),
                      Container(
                        width: r.scale(17),
                        height: r.scale(3),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: r.scale(2),
            bottom: r.scale(2),
            child: Icon(
              Icons.apple_rounded,
              color: AppColors.error,
              size: r.scale(31),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroPlanStat extends StatelessWidget {
  const _MacroPlanStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.scale(18, tablet: 20),
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: r.scale(2)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.scale(10, tablet: 11),
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Row(
      children: [
        Container(
          width: 4,
          height: r.scale(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        SizedBox(width: r.scale(9)),
        Text(
          title,
          style: TextStyle(
            fontSize: r.scale(15, tablet: 16),
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TipsEmptyState extends StatelessWidget {
  const _TipsEmptyState({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.scale(18)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: r.scale(36),
            color: AppColors.textSecondary,
          ),
          SizedBox(height: r.scale(10)),
          Text(
            isLoading ? 'Loading your tips...' : 'No tips available yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(14),
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiTipsCard extends StatelessWidget {
  const _AiTipsCard({required this.tips});

  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.scale(13)),
      decoration: BoxDecoration(
        color: AppColors.selectionFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: tips.map((tip) => _TipLine(text: tip)).toList(),
            ),
          ),
          SizedBox(width: r.scale(10)),
          const _WaterBottleIllustration(),
        ],
      ),
    );
  }
}

class _TipLine extends StatelessWidget {
  const _TipLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Padding(
      padding: EdgeInsets.only(bottom: r.scale(6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: AppColors.primary,
            size: r.scale(15),
          ),
          SizedBox(width: r.scale(6)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: r.scale(12, tablet: 13),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterBottleIllustration extends StatelessWidget {
  const _WaterBottleIllustration();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return SizedBox(
      width: r.scale(72),
      height: r.scale(96),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: Icon(
              Icons.eco_rounded,
              color: AppColors.primary.withValues(alpha: 0.25),
              size: r.scale(54),
            ),
          ),
          Positioned(
            right: 0,
            bottom: r.scale(6),
            child: Icon(
              Icons.eco_rounded,
              color: AppColors.primary.withValues(alpha: 0.22),
              size: r.scale(48),
            ),
          ),
          Icon(
            Icons.water_drop_rounded,
            color: AppColors.primary.withValues(alpha: 0.55),
            size: r.scale(72),
          ),
        ],
      ),
    );
  }
}
