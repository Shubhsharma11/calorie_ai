import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/analytics_controller.dart';
import '../controllers/tracker_controller.dart';
import '../controllers/user_controller.dart';
import '../core/route_args.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

class WeightTrackerView extends GetView<TrackerController> {
  const WeightTrackerView({super.key});

  @override
  Widget build(BuildContext context) {
    final analytics = Get.find<AnalyticsController>();
    final user = Get.find<UserController>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Weight Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Obx(() {
          final weight = controller.currentWeight.value;
          final history = analytics.weightHistory;
          final goalWeight = user.goalWeightKg;
          final toGo = (goalWeight - weight).abs();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${weight.toStringAsFixed(1)} kg',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Current weight',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => Get.toNamed(
                  AppRoutes.goalWeight,
                  arguments: RouteArgs.fromProfileMap,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Goal weight',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${goalWeight.toStringAsFixed(1)} kg '
                              '(${toGo.toStringAsFixed(1)} kg to go)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: history.asMap().entries.map((e) {
                    final h = ((e.value - 69) / 4 * 120).clamp(20.0, 140.0);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: e.key == history.length - 1
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Last 7 entries',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 32),
              Slider(
                value: weight,
                min: 40,
                max: 150,
                divisions: 220,
                label: '${weight.toStringAsFixed(1)} kg',
                onChanged: controller.updateWeight,
              ),
              Text(
                'Slide to log today\'s weight',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          );
        }),
      ),
    );
  }
}
