import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/tracker_controller.dart';
import '../controllers/settings_controller.dart';
import '../core/responsive.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

/// Compact water intake row for the Home screen summary area.
class WaterIntakeBanner extends StatelessWidget {
  const WaterIntakeBanner({super.key});

  static const _waterBlue = Color(0xFF007AFF);

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    if (!Get.isRegistered<TrackerController>()) {
      return const SizedBox.shrink();
    }
    final tracker = Get.find<TrackerController>();

    return Obx(() {
      if (Get.isRegistered<SettingsController>()) {
        Get.find<SettingsController>().waterGoalMl.value;
      }
      final waterMl = tracker.waterMl;
      final goalMl = TrackerController.waterGoalMl;
      final glasses = tracker.waterGlasses;
      final progress = tracker.waterProgress;
      final isComplete = tracker.isWaterGoalComplete;
      final overMl = tracker.waterMlOverGoal;
      final remainingMl = tracker.waterMlRemaining;
      final _ = tracker.waterByDate.length;
      final color = isComplete ? AppColors.primary : _waterBlue;
      final subtitle = overMl > 0
          ? 'Goal reached · +$overMl ml extra'
          : isComplete
              ? 'Goal reached · ≈ $glasses glass${glasses == 1 ? '' : 'es'}'
              : glasses > 0
                  ? '$remainingMl ml left · ≈ $glasses glass${glasses == 1 ? '' : 'es'}'
                  : '$remainingMl ml left';

      return Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Get.toNamed(AppRoutes.waterTracker),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: EdgeInsets.all(r.scale(14)),
                    child: Row(
                      children: [
                        Icon(
                          Icons.water_drop_rounded,
                          color: color,
                          size: r.scale(22),
                        ),
                        SizedBox(width: r.scale(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Water Intake',
                                    style: TextStyle(
                                      fontSize: r.scale(14),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$waterMl / $goalMl ml',
                                    style: TextStyle(
                                      fontSize: r.scale(14),
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: r.scale(4)),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: r.scale(11),
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: r.scale(8)),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: AppColors.border,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: r.scale(8)),
              child: IconButton.filled(
                onPressed: tracker.addWater,
                icon: Icon(Icons.add, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: AppColors.onPrimary,
                  disabledBackgroundColor: AppColors.border,
                ),
                tooltip: 'Add 250 ml',
              ),
            ),
          ],
        ),
      );
    });
  }
}
