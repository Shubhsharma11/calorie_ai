import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/tracker_controller.dart';
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
    final tracker = Get.find<TrackerController>();

    return Obx(() {
      final glasses = tracker.waterGlasses;
      final goal = TrackerController.waterGoal;
      final progress = tracker.waterProgress;
      final isComplete = tracker.isWaterGoalComplete;
      final _ = tracker.waterByDate.length;
      final color = isComplete ? AppColors.primary : _waterBlue;

      return Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
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
                                    '$glasses / $goal',
                                    style: TextStyle(
                                      fontSize: r.scale(14),
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ],
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
                onPressed: isComplete ? null : tracker.addWater,
                icon: Icon(Icons.add, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.border,
                ),
                tooltip: 'Add glass',
              ),
            ),
          ],
        ),
      );
    });
  }
}
