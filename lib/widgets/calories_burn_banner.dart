import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/tracker_controller.dart';
import '../core/responsive.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'training_icon.dart';

/// Steps & exercise quick actions for the Home screen Calories Burn area.
class CaloriesBurnBanner extends StatelessWidget {
  const CaloriesBurnBanner({super.key});

  static const _burnOrange = Color(0xFFFF9500);
  static const _stepsBlue = Color(0xFF007AFF);

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final tracker = Get.find<TrackerController>();

    return Obx(() {
      final burned = tracker.todayCaloriesBurned;
      final steps = tracker.todaySteps;
      final exerciseMin = tracker.todayExerciseMinutes;
      final _ = tracker.activityRevision.value;

      return Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Get.toNamed(AppRoutes.caloriesBurn),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.all(r.scale(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TrainingIcon(size: r.scale(24)),
                      SizedBox(width: r.scale(8)),
                      Text(
                        'Calories Burn',
                        style: TextStyle(
                          fontSize: r.scale(14),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$burned kcal',
                        style: TextStyle(
                          fontSize: r.scale(14),
                          fontWeight: FontWeight.w700,
                          color: _burnOrange,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  SizedBox(height: r.scale(12)),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickStat(
                          icon: Icons.directions_walk_rounded,
                          color: _stepsBlue,
                          label: 'Steps',
                          value: _formatSteps(steps),
                          onTap: () => Get.toNamed(AppRoutes.caloriesBurn),
                        ),
                      ),
                      SizedBox(width: r.scale(8)),
                      Expanded(
                        child: _QuickStat(
                          iconWidget: TrainingIcon(size: r.scale(18)),
                          color: _burnOrange,
                          label: 'Exercise',
                          value: '${exerciseMin}m',
                          onTap: () => Get.toNamed(AppRoutes.caloriesBurn),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  static String _formatSteps(int steps) {
    if (steps >= 1000) {
      final thousands = steps / 1000;
      return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}k';
    }
    return '$steps';
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    this.icon,
    this.iconWidget,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData? icon;
  final Widget? iconWidget;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(10),
            vertical: r.scale(10),
          ),
          child: Row(
            children: [
              iconWidget ?? Icon(icon, color: color, size: r.scale(18)),
              SizedBox(width: r.scale(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: r.scale(11),
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: r.scale(14),
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
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
