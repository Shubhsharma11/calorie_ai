import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/tracker_controller.dart';
import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/goal_type.dart';
import '../models/user_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/profile_ui.dart';
import '../widgets/responsive_page.dart';

class MyGoalsView extends GetView<UserController> {
  const MyGoalsView({super.key});

  static String targetDateLabel(UserModel user) =>
      DateFormat('dd MMM yyyy').format(user.targetDate);

  static double weightGoalProgress(UserModel user, double currentWeight) {
    final start = user.weightKg.toDouble();
    final target = user.goalWeightKg;

    if (user.goal == GoalType.maintainWeight || user.goal == null) {
      final diff = (currentWeight - target).abs();
      return (1 - (diff / 2).clamp(0.0, 1.0)).clamp(0.0, 1.0);
    }

    final totalChange = (target - start).abs();
    if (totalChange == 0) return 1.0;

    final achieved = user.goal == GoalType.loseWeight
        ? (start - currentWeight).clamp(0.0, totalChange)
        : (currentWeight - start).clamp(0.0, totalChange);

    return (achieved / totalChange).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Goal'),
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: GetBuilder<UserController>(
        builder: (_) {
          final user = controller.user;
          final goal = user.dailyCalorieGoal;

          return Obx(() {
            if (Get.isRegistered<TrackerController>()) {
              Get.find<TrackerController>().weightRevision.value;
            }
            final currentWeight = Get.isRegistered<TrackerController>()
                ? Get.find<TrackerController>().currentWeight.value
                : user.weightKg.toDouble();
            final progress = weightGoalProgress(user, currentWeight);

            return ResponsivePage(
            scrollable: true,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: r.isWide ? 480 : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProfileGoalField(
                      label: 'Goal',
                      value: user.goal?.title ?? 'Not set',
                      icon: Icons.monitor_weight_outlined,
                      iconColor: AppColors.primary,
                      onTap: () => Get.toNamed(
                        AppRoutes.goalSetup,
                        arguments: RouteArgs.fromProfileMap,
                      ),
                    ),
                    SizedBox(height: r.scale(12)),
                    ProfileGoalField(
                      label: 'Target Weight',
                      value: '${user.goalWeightKg.toStringAsFixed(1)} kg',
                      subtitle: user.isGoalWeightManual
                          ? 'Custom target'
                          : 'Recommended target',
                      icon: Icons.flag_outlined,
                      onTap: () => Get.toNamed(
                        AppRoutes.goalWeight,
                        arguments: RouteArgs.fromProfileMap,
                      ),
                    ),
                    SizedBox(height: r.scale(12)),
                    ProfileGoalField(
                      label: 'Target Date',
                      value: targetDateLabel(user),
                      onTap: () async {
                        final baseline =
                            controller.captureProfileSyncSnapshot();
                        final result = await controller.pickTargetDate(
                          context,
                          syncBaseline: baseline,
                        );

                        switch (result.status) {
                          case PickTargetDateStatus.saved:
                            AppSnackbar.success('Target date updated.');
                          case PickTargetDateStatus.failed:
                            AppSnackbar.error(
                              result.error ?? 'Unable to save changes.',
                              title: 'Save failed',
                            );
                          case PickTargetDateStatus.unchanged:
                          case PickTargetDateStatus.cancelled:
                            break;
                        }
                      },
                    ),
                    SizedBox(height: r.scale(12)),
                    ProfileGoalField(
                      label: 'Daily Calorie Goal',
                      value: '$goal kcal',
                      subtitle: user.hasManualCalorieAdjustment
                          ? 'Recommended ${user.calculatedDailyCalorieGoal} kcal '
                              '${user.manualCalorieAdjustment > 0 ? '+' : ''}'
                              '${user.manualCalorieAdjustment}'
                          : 'Based on your profile',
                      icon: Icons.local_fire_department_outlined,
                      onTap: () => Get.toNamed(
                        AppRoutes.dailyCalorieGoal,
                        arguments: RouteArgs.fromProfileMap,
                      ),
                    ),
                    SizedBox(height: r.scale(12)),
                    ProfileGoalProgressCard(progress: progress),
                  ],
                ),
              ),
            ),
          );
          });
        },
      ),
    );
  }
}
