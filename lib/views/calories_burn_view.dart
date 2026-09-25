import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/rewards_controller.dart';
import '../controllers/tracker_controller.dart';
import '../core/app_snackbar.dart';
import '../core/dashboard_actions.dart';
import '../core/responsive.dart';
import '../models/meal_entry.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/coin_claim_lottery_dialog.dart';
import '../widgets/responsive_page.dart';
import '../widgets/steps_claim_banner.dart';

/// Quiet open sync for Calories Burned. Extracted for focused tests.
///
/// - One today [TrackerController.refreshStepsFromApi] (POST only if needed).
/// - No unconditional yesterday steps GET or forced POST.
/// - Wallet GET only when not already successfully loaded.
/// - Claimable uses [RewardsController.refreshClaimableForDates] (skips loaded).
@visibleForTesting
Future<void> runCaloriesBurnBootstrap({
  required TrackerController tracker,
  RewardsController? rewards,
}) async {
  await tracker.refreshStepsFromApi(force: true);

  final rewardsController = rewards ??
      (Get.isRegistered<RewardsController>()
          ? Get.find<RewardsController>()
          : null);
  if (rewardsController == null) return;

  final walletOk = rewardsController.hasCompletedWalletFetch.value &&
      rewardsController.walletApiErrorMessage.value == null;
  if (!walletOk) {
    await rewardsController.refreshWalletFromApi(retryOnRateLimit: true);
  }

  final today = MealEntry.normalizeDate(DateTime.now());
  await rewardsController.refreshClaimableForDates([
    today,
    tracker.yesterdayDate,
  ]);
}

class CaloriesBurnView extends StatefulWidget {
  const CaloriesBurnView({super.key});

  static const _burnOrange = Color(0xFFFF9500);
  static const _stepsBlue = Color(0xFF007AFF);

  @override
  State<CaloriesBurnView> createState() => _CaloriesBurnViewState();
}

class _CaloriesBurnViewState extends State<CaloriesBurnView> {
  TrackerController get controller => Get.find<TrackerController>();

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      );

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() => runCaloriesBurnBootstrap(tracker: controller);

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    AppColors.syncFromContext(context);

    return Scaffold(
      appBar: AppAppBar(
        title: 'Calories Burned',
        actions: [
          Padding(
            padding: EdgeInsets.only(right: r.scale(12)),
            child: CoinBalanceChip(
              onTap: StepsClaimBanner.openCoinHistory,
            ),
          ),
        ],
      ),
      body: ResponsivePage(
        scrollable: true,
        child: Obx(() {
          final viewingToday = controller.isViewingStepsToday;
          final selectedDate = controller.selectedStepsDate.value;
          final burned = controller.selectedStepsCalories;
          final steps = controller.selectedSteps;
          final stepsProgress = controller.selectedStepsProgress;
          final isComplete = controller.isSelectedStepsGoalComplete;
          final isAutoTracking = controller.isStepTrackingActive.value;
          final trackingMessage = controller.stepTrackingMessage.value;
          final needsHealthConnectInstall =
              controller.needsHealthConnectInstall.value;
          final _ = controller.activityRevision.value;
          final remaining = (TrackerController.stepsGoal - steps)
              .clamp(0, TrackerController.stepsGoal);
          final showEmptyConnect =
              viewingToday && !isAutoTracking && controller.todaySteps == 0;
          final dateLabel = formatLogDateLabel(selectedDate);
          final kcalLabel = viewingToday
              ? 'kcal burned today'
              : 'kcal burned · $dateLabel';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: InkWell(
                  onTap: () => _openStepsCalendar(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.scale(14),
                      vertical: r.scale(8),
                    ),
                    decoration: BoxDecoration(
                      color: viewingToday
                          ? (AppColors.isDark(context)
                              ? AppColors.surface
                              : Colors.white)
                          : (AppColors.isDark(context)
                              ? CaloriesBurnView._burnOrange
                                  .withValues(alpha: 0.16)
                              : const Color(0xFFFFF3E0)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: viewingToday
                            ? AppColors.border
                            : CaloriesBurnView._burnOrange
                                .withValues(alpha: 0.4),
                      ),
                      boxShadow: viewingToday
                          ? [
                              BoxShadow(
                                color: AppColors.shadowColor,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
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
                              ? AppColors.textSecondary
                              : const Color(0xFFE65100),
                        ),
                        SizedBox(width: r.scale(6)),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: viewingToday
                                ? AppColors.textPrimary
                                : const Color(0xFFE65100),
                            fontSize: r.scale(13),
                          ),
                        ),
                        SizedBox(width: r.scale(4)),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: viewingToday
                              ? AppColors.textSecondary
                              : const Color(0xFFE65100),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!viewingToday) ...[
                SizedBox(height: r.scale(4)),
                Center(
                  child: TextButton(
                    onPressed: controller.backToStepsToday,
                    style: TextButton.styleFrom(
                      foregroundColor: CaloriesBurnView._burnOrange,
                      padding: EdgeInsets.symmetric(
                        horizontal: r.scale(12),
                        vertical: r.scale(4),
                      ),
                      minimumSize: Size(0, r.scale(32)),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Back to Today',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
              SizedBox(height: r.scale(16)),
              Container(
                decoration: _cardDecoration(),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        r.scale(16),
                        r.scale(20),
                        r.scale(16),
                        r.scale(18),
                      ),
                      color: AppColors.isDark(context)
                          ? AppColors.surface
                          : const Color(0xFFFFF8F0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            color: CaloriesBurnView._burnOrange,
                            size: r.scale(28),
                          ),
                          SizedBox(height: r.scale(10)),
                          Text(
                            '$burned',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: r.scale(44, tablet: 48),
                              fontWeight: FontWeight.w800,
                              color: CaloriesBurnView._burnOrange,
                              height: 1,
                              letterSpacing: -1,
                            ),
                          ),
                          SizedBox(height: r.scale(6)),
                          Text(
                            kcalLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: r.scale(14),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: r.scale(8)),
                          Text(
                            _formatSteps(steps),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: r.scale(15),
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: r.scale(14)),
                          _DayCoinsBadge(
                            date: selectedDate,
                            isToday: viewingToday,
                          ),
                        ],
                      ),
                    ),
                    if (!showEmptyConnect)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          r.scale(14),
                          r.scale(14),
                          r.scale(14),
                          r.scale(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Daily step goal',
                                  style: TextStyle(
                                    fontSize: r.scale(14),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '$steps / ${TrackerController.stepsGoal}',
                                  style: TextStyle(
                                    fontSize: r.scale(13),
                                    fontWeight: FontWeight.w700,
                                    color: isComplete
                                        ? AppColors.primary
                                        : CaloriesBurnView._stepsBlue,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: r.scale(6)),
                            Text(
                              isComplete
                                  ? viewingToday
                                      ? 'Goal reached — great work today!'
                                      : 'Goal was reached on this day.'
                                  : viewingToday
                                      ? isAutoTracking
                                          ? 'Auto-detected from your device'
                                          : 'Allow health access to keep steps updated'
                                      : steps == 0
                                          ? 'No steps saved for this day yet.'
                                          : '${(stepsProgress * 100).round()}% of your daily goal',
                              style: TextStyle(
                                fontSize: r.scale(12),
                                color: AppColors.textSecondary,
                              ),
                            ),
                            SizedBox(height: r.scale(10)),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: LinearProgressIndicator(
                                value: stepsProgress,
                                minHeight: 10,
                                backgroundColor: AppColors.surface,
                                color: isComplete
                                    ? AppColors.primary
                                    : CaloriesBurnView._stepsBlue,
                              ),
                            ),
                            if (!viewingToday && remaining > 0) ...[
                              SizedBox(height: r.scale(6)),
                              Text(
                                '$remaining steps short of the goal',
                                style: TextStyle(
                                  fontSize: r.scale(12),
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (viewingToday) ...[
                              SizedBox(height: r.scale(12)),
                              _StepTrackingStatus(
                                isActive: isAutoTracking,
                                message: trackingMessage,
                                onEnable: controller.syncActivity,
                                onDisconnect: controller.disconnectStepTracking,
                                onInstallHealthConnect:
                                    needsHealthConnectInstall
                                        ? controller.installHealthConnect
                                        : null,
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (viewingToday) ...[
                SizedBox(height: r.scale(12)),
                _YesterdayCoinsStrip(date: controller.yesterdayDate),
              ],
              if (showEmptyConnect) ...[
                SizedBox(height: r.scale(16)),
                _EmptyConnectCard(
                  needsInstall: needsHealthConnectInstall,
                  onConnect: needsHealthConnectInstall
                      ? controller.installHealthConnect
                      : controller.syncActivity,
                ),
              ],
              SizedBox(height: r.scale(16)),
              Text(
                'Estimated from your steps (~0.04 kcal/step)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: r.scale(12),
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _openStepsCalendar(BuildContext context) async {
    final today = MealEntry.normalizeDate(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.selectedStepsDate.value,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today,
      helpText: 'Select a day to view calories burned',
    );
    if (picked == null) return;
    controller.setSelectedStepsDate(picked);
  }

  static String _formatSteps(int steps) {
    final formatted = steps.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '$formatted step${steps == 1 ? '' : 's'}';
  }
}

class _DayCoinsBadge extends StatelessWidget {
  const _DayCoinsBadge({
    required this.date,
    required this.isToday,
  });

  final DateTime date;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<RewardsController>()) {
      return const SizedBox.shrink();
    }
    final rewards = Get.find<RewardsController>();
    final r = context.responsive;

    return Obx(() {
      final dateKey = MealEntry.dateToKey(MealEntry.normalizeDate(date));
      rewards.claimableCoins.value;
      rewards.claimableByDate[dateKey];
      rewards.earnedCoinsByDate[dateKey];
      rewards.isClaiming.value;
      rewards.claimedDateKey.value;

      final coins = rewards.coinsDisplayForDate(date);
      final claimable = rewards.claimableForDate(date);
      final claiming = rewards.isClaiming.value;
      final claimedToday = isToday && rewards.hasClaimedToday && claimable <= 0;

      final label = claimable > 0
          ? '+$claimable coins ${isToday ? 'today' : 'available'}'
          : claimedToday
              ? 'Today’s coins claimed'
              : coins > 0
                  ? (isToday
                      ? '+$coins coins earned'
                      : '+$coins coins that day')
                  : isToday
                      ? 'No coins earned yet today'
                      : 'No coins for this day';

      return Material(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: claimable > 0 && !claiming
              ? () => _claim(rewards, date, claimable)
              : () => Get.toNamed(AppRoutes.rewardsShop),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: r.scale(14),
              vertical: r.scale(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RewardCoinIcon(size: r.scale(20)),
                SizedBox(width: r.scale(8)),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: r.scale(13),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF9A6700),
                    ),
                  ),
                ),
                if (claimable > 0) ...[
                  SizedBox(width: r.scale(8)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.scale(10),
                      vertical: r.scale(5),
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0A202),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: claiming
                        ? SizedBox(
                            width: r.scale(12),
                            height: r.scale(12),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Claim',
                            style: TextStyle(
                              fontSize: r.scale(12),
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  Future<void> _claim(
    RewardsController rewards,
    DateTime day,
    int coins,
  ) async {
    HapticFeedback.mediumImpact();
    final ok = await rewards.claimDailyStepReward(date: day);
    if (ok) {
      await CoinClaimLotteryDialog.show(coins: coins);
    } else {
      AppSnackbar.error(
        rewards.lastClaimError.value ?? 'Couldn’t claim coins. Try again.',
        title: 'Claim failed',
      );
    }
  }
}

class _YesterdayCoinsStrip extends StatelessWidget {
  const _YesterdayCoinsStrip({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<RewardsController>()) {
      return const SizedBox.shrink();
    }
    final rewards = Get.find<RewardsController>();
    final r = context.responsive;

    return Obx(() {
      final dateKey = MealEntry.dateToKey(MealEntry.normalizeDate(date));
      rewards.claimableByDate[dateKey];
      rewards.earnedCoinsByDate[dateKey];
      rewards.isClaiming.value;
      final claimable = rewards.claimableForDate(date);
      final earned = rewards.coinsDisplayForDate(date);
      if (claimable <= 0 && earned <= 0) return const SizedBox.shrink();

      final claiming = rewards.isClaiming.value;
      final subtitle = claimable > 0
          ? '+$claimable still waiting to claim'
          : '+$earned coins that day';
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.scale(14),
          vertical: r.scale(12),
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            RewardCoinIcon(size: r.scale(22)),
            SizedBox(width: r.scale(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yesterday’s coins',
                    style: TextStyle(
                      fontSize: r.scale(13),
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: r.scale(12),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (claimable > 0)
              TextButton(
                onPressed: claiming
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        final ok =
                            await rewards.claimDailyStepReward(date: date);
                        if (ok) {
                          await CoinClaimLotteryDialog.show(coins: claimable);
                        } else {
                          AppSnackbar.error(
                            rewards.lastClaimError.value ??
                                'Couldn’t claim coins. Try again.',
                            title: 'Claim failed',
                          );
                        }
                      },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF9A6700),
                  backgroundColor: const Color(0xFFFFF4D6),
                  padding: EdgeInsets.symmetric(
                    horizontal: r.scale(14),
                    vertical: r.scale(8),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: claiming
                    ? SizedBox(
                        width: r.scale(14),
                        height: r.scale(14),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Claim',
                        style: TextStyle(
                          fontSize: r.scale(13),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
          ],
        ),
      );
    });
  }
}

class _EmptyConnectCard extends StatelessWidget {
  const _EmptyConnectCard({
    required this.needsInstall,
    required this.onConnect,
  });

  final bool needsInstall;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.scale(18)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.directions_walk_rounded,
            size: r.scale(40),
            color: CaloriesBurnView._stepsBlue,
          ),
          SizedBox(height: r.scale(12)),
          Text(
            'Start tracking your steps',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(16),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: r.scale(6)),
          Text(
            needsInstall
                ? 'Install Health Connect so we can estimate calories burned from your steps.'
                : 'Allow health access to sync steps and see calories burned automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(13),
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: r.scale(16)),
          FilledButton.icon(
            onPressed: onConnect,
            icon: Icon(
              needsInstall ? Icons.download_rounded : Icons.link_rounded,
            ),
            label: Text(
              needsInstall ? 'Install Health Connect' : 'Enable steps',
            ),
            style: FilledButton.styleFrom(
              minimumSize: Size(0, r.scale(46)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.scale(24)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTrackingStatus extends StatelessWidget {
  const _StepTrackingStatus({
    required this.isActive,
    required this.message,
    required this.onEnable,
    required this.onDisconnect,
    this.onInstallHealthConnect,
  });

  final bool isActive;
  final String? message;
  final VoidCallback onEnable;
  final VoidCallback onDisconnect;
  final VoidCallback? onInstallHealthConnect;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final color = isActive ? AppColors.primary : AppColors.textSecondary;
    final icon =
        isActive ? Icons.directions_walk_rounded : Icons.sensors_off_rounded;
    final text = message ??
        (isActive
            ? 'Steps sync from your health data.'
            : 'Allow health access to track steps automatically.');

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(12),
        vertical: r.scale(10),
      ),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: r.scale(20)),
          SizedBox(width: r.scale(10)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: r.scale(13),
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed: isActive
                ? onDisconnect
                : onInstallHealthConnect ?? onEnable,
            child: Text(
              isActive
                  ? 'Disconnect'
                  : onInstallHealthConnect != null
                      ? 'Install'
                      : 'Connect',
            ),
          ),
        ],
      ),
    );
  }
}
