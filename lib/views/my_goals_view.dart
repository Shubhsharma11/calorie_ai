import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/tracker_controller.dart';
import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../core/weight_goal_calculator.dart';
import '../models/goal_type.dart';
import '../models/user_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/profile_ui.dart';
import '../widgets/responsive_page.dart';

class MyGoalsView extends StatefulWidget {
  const MyGoalsView({super.key});

  static String targetDateLabel(UserModel user) =>
      DateFormat('dd MMM yyyy').format(user.targetDate);

  static bool targetMatchesGoal({
    required GoalType goal,
    required double currentKg,
    required double targetKg,
  }) =>
      WeightGoalCalculator.targetMatchesGoal(
        goal: goal,
        currentKg: currentKg,
        targetKg: targetKg,
      );

  static double weightGoalProgress(UserModel user, double currentWeight) =>
      WeightGoalCalculator.weightGoalProgress(
        user: user,
        currentWeight: currentWeight,
        startWeightKg: _apiStartWeightKg(user),
      );

  /// Prefer API start weight; otherwise oldest weight log from the weight API.
  static double? _apiStartWeightKg(UserModel user) {
    if (user.goalStartWeightKg != null && user.goalStartWeightKg! > 0) {
      return user.goalStartWeightKg;
    }
    if (!Get.isRegistered<TrackerController>()) return null;
    final entries = Get.find<TrackerController>().recentWeightEntries;
    if (entries.isEmpty) return null;
    return entries.first.kg;
  }

  static String? progressSubtitle({
    required UserModel user,
    required double currentWeight,
    required double progress,
  }) {
    final goal = user.pinnedGoalType ?? user.goal;
    if (goal == null) return null;

    if (currentWeight <= 0) {
      return 'Log your current weight to track progress';
    }

    final target = user.goalWeightKg;
    if (!targetMatchesGoal(
      goal: goal,
      currentKg: currentWeight,
      targetKg: target,
    )) {
      return 'Update target weight to match your goal';
    }

    if (goal == GoalType.maintainWeight) {
      final diff = (currentWeight - target).abs();
      if (diff < WeightGoalCalculator.maintainToleranceKg) {
        return 'At target weight';
      }
      return '${diff.toStringAsFixed(1)} kg from target';
    }

    if (progress >= 0.999) return 'Target reached';
    return '${(currentWeight - target).abs().toStringAsFixed(1)} kg to go';
  }

  @override
  State<MyGoalsView> createState() => _MyGoalsViewState();
}

class _MyGoalsViewState extends State<MyGoalsView> {
  UserController get controller => Get.find<UserController>();
  bool _initialLoadStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialLoadStarted) return;
      _initialLoadStarted = true;
      _loadGoals();
    });
  }

  Future<void> _loadGoals() async {
    // Refresh personal details / calories only — do not adopt weight-log
    // mutations of goal / target weight from the onboarding API.
    await controller.fetchProfile(refreshGoalTarget: false);
    if (!mounted) return;

    // Seed display weight from profile when weight API history is empty.
    if (Get.isRegistered<TrackerController>()) {
      final tracker = Get.find<TrackerController>();
      if (tracker.currentWeight.value <= 0 &&
          (controller.user.weightKg ?? 0) > 0) {
        tracker.syncWeightFromProfileIfEmpty();
      }
    }

    // Prefer the pinned goal type over inferring from a mutated target.
    // Do not silently retarget — mismatch is shown until the user saves via API.
    if (controller.user.pinnedGoalType != null) {
      controller.user.goal = controller.user.pinnedGoalType;
      controller.update();
    } else {
      controller.ensureGoalFromWeight();
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: const AppAppBar(title: 'Goal'),
      body: GetBuilder<UserController>(
        builder: (_) {
          final user = controller.user;
          final calorieGoal = user.dailyCalorieGoal;
          final isLoading = controller.isLoadingProfile;

          if (isLoading && user.goal == null && user.dailyCalorieGoal <= 0) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return Obx(() {
            if (Get.isRegistered<TrackerController>()) {
              Get.find<TrackerController>().weightRevision.value;
            }
            final currentWeight = controller.resolvedCurrentWeightKg();
            final progress =
                MyGoalsView.weightGoalProgress(user, currentWeight);
            final goal = user.pinnedGoalType ?? user.goal;
            final target = user.goalWeightKg;
            final canValidate = currentWeight > 0 && target > 0;
            final mismatch = canValidate &&
                goal != null &&
                !MyGoalsView.targetMatchesGoal(
                  goal: goal,
                  currentKg: currentWeight,
                  targetKg: target,
                );

            return Column(
              children: [
                if (isLoading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.primary,
                  ),
                Expanded(
                  child: ResponsivePage(
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
                              value: goal?.title ?? 'Not set',
                              subtitle: goal?.statusLabel,
                              icon: Icons.monitor_weight_outlined,
                              iconColor: AppColors.primary,
                              onTap: () {
                                controller.beginGoalEditFromProfile();
                                Get.toNamed(
                                  AppRoutes.goalSetup,
                                  arguments: RouteArgs.fromProfileMap,
                                );
                              },
                            ),
                            SizedBox(height: r.scale(12)),
                            ProfileGoalField(
                              label: 'Target Weight',
                              value: target > 0
                                  ? '${target.toStringAsFixed(1)} kg'
                                  : 'Not set',
                              subtitle: !canValidate
                                  ? 'Based on your current weight'
                                  : mismatch
                                      ? 'Doesn’t match your goal'
                                      : user.isGoalWeightManual
                                          ? 'Custom target'
                                          : 'Recommended target',
                              icon: Icons.flag_outlined,
                              onTap: () {
                                controller.beginGoalEditFromProfile();
                                final g = user.pinnedGoalType ?? user.goal;
                                if (g == GoalType.loseWeight ||
                                    g == GoalType.gainWeight) {
                                  Get.toNamed(
                                    AppRoutes.goalAmount,
                                    arguments: RouteArgs.fromProfileMap,
                                  );
                                } else {
                                  Get.toNamed(
                                    AppRoutes.goalWeight,
                                    arguments: RouteArgs.fromProfileMap,
                                  );
                                }
                              },
                            ),
                            if (goal != null &&
                                goal != GoalType.maintainWeight) ...[
                              SizedBox(height: r.scale(12)),
                              ProfileGoalField(
                                label: 'Target Date',
                                value: MyGoalsView.targetDateLabel(user),
                                onTap: () async {
                                  final baseline =
                                      controller.captureProfileSyncSnapshot();
                                  final result =
                                      await controller.pickTargetDate(
                                    context,
                                    syncBaseline: baseline,
                                  );

                                  switch (result.status) {
                                    case PickTargetDateStatus.saved:
                                      AppSnackbar.success(
                                        'Target date updated.',
                                      );
                                    case PickTargetDateStatus.failed:
                                      AppSnackbar.error(
                                        result.error ??
                                            'Unable to save changes.',
                                        title: 'Save failed',
                                      );
                                    case PickTargetDateStatus.unchanged:
                                    case PickTargetDateStatus.cancelled:
                                      break;
                                  }
                                },
                              ),
                            ],
                            SizedBox(height: r.scale(12)),
                            ProfileGoalField(
                              label: 'Daily Calorie Goal',
                              value: '$calorieGoal kcal',
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
                            ProfileGoalProgressCard(
                              progress: progress,
                              goalSet: goal != null && !mismatch,
                              detail: MyGoalsView.progressSubtitle(
                                user: user,
                                currentWeight: currentWeight,
                                progress: progress,
                              ),
                            ),
                            SizedBox(
                              height: MediaQuery.viewPaddingOf(context).bottom +
                                  r.scale(16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          });
        },
      ),
    );
  }
}
