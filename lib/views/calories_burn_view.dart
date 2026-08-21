import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/tracker_controller.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/responsive_page.dart';

class CaloriesBurnView extends GetView<TrackerController> {
  const CaloriesBurnView({super.key});

  static const _burnOrange = Color(0xFFFF9500);
  static const _stepsBlue = Color(0xFF007AFF);

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      appBar: const AppAppBar(title: 'Calories Burned'),
      body: ResponsivePage(
        scrollable: true,
        child: Obx(() {
          final burned = controller.stepsCalories;
          final steps = controller.todaySteps;
          final stepsProgress = controller.stepsProgress;
          final isComplete = controller.isStepsGoalComplete;
          final isAutoTracking = controller.isStepTrackingActive.value;
          final trackingMessage = controller.stepTrackingMessage.value;
          final needsHealthConnectInstall =
              controller.needsHealthConnectInstall.value;
          final _ = controller.activityRevision.value;
          final remaining =
              (TrackerController.stepsGoal - steps).clamp(0, TrackerController.stepsGoal);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.all(r.scale(20)),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _burnOrange.withValues(alpha: 0.18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowColor,
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: _burnOrange,
                      size: r.scale(28),
                    ),
                    SizedBox(height: r.scale(10)),
                    Text(
                      '$burned',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: r.scale(48, tablet: 52),
                        fontWeight: FontWeight.w800,
                        color: _burnOrange,
                        height: 1,
                        letterSpacing: -1,
                      ),
                    ),
                    SizedBox(height: r.scale(6)),
                    Text(
                      'kcal burned today',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: r.scale(15),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: r.scale(10)),
                    Text(
                      _formatSteps(steps),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: r.scale(16),
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: r.scale(4)),
                    Text(
                      'Estimated from your steps (~0.04 kcal/step)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: r.scale(12),
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.scale(20)),
              if (!isAutoTracking && steps == 0)
                _EmptyConnectCard(
                  needsInstall: needsHealthConnectInstall,
                  onConnect: needsHealthConnectInstall
                      ? controller.installHealthConnect
                      : controller.syncActivity,
                )
              else ...[
                Text(
                  'Daily step goal',
                  style: TextStyle(
                    fontSize: r.scale(18),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: r.scale(6)),
                Text(
                  isComplete
                      ? 'Goal reached — great work today!'
                      : isAutoTracking
                          ? 'Auto-detected from your device'
                          : 'Allow health access to keep your steps updated',
                  style: TextStyle(
                    fontSize: r.scale(13),
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: r.scale(12)),
                Container(
                  padding: EdgeInsets.all(r.scale(14)),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$steps',
                            style: TextStyle(
                              fontSize: r.scale(16),
                              fontWeight: FontWeight.w800,
                              color: isComplete ? AppColors.primary : _stepsBlue,
                            ),
                          ),
                          Text(
                            ' / ${TrackerController.stepsGoal}',
                            style: TextStyle(
                              fontSize: r.scale(15),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            isComplete
                                ? 'Done'
                                : '$remaining left',
                            style: TextStyle(
                              fontSize: r.scale(12),
                              fontWeight: FontWeight.w700,
                              color: isComplete
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: r.scale(12)),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LinearProgressIndicator(
                          value: stepsProgress,
                          minHeight: 12,
                          backgroundColor: AppColors.card,
                          color: isComplete ? AppColors.primary : _stepsBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.scale(12)),
                _StepTrackingStatus(
                  isActive: isAutoTracking,
                  message: trackingMessage,
                  onEnable: controller.syncActivity,
                  onDisconnect: controller.disconnectStepTracking,
                  onInstallHealthConnect: needsHealthConnectInstall
                      ? controller.installHealthConnect
                      : null,
                ),
              ],
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
            ],
          );
        }),
      ),
    );
  }

  static String _formatSteps(int steps) {
    final formatted = steps.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '$formatted step${steps == 1 ? '' : 's'}';
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
            icon: Icon(needsInstall ? Icons.download_rounded : Icons.link_rounded),
            label: Text(needsInstall ? 'Install Health Connect' : 'Enable steps'),
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
        horizontal: r.scale(14),
        vertical: r.scale(12),
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
