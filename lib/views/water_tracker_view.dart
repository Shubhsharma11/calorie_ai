import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/tracker_controller.dart';
import '../core/responsive.dart';
import '../models/water_period.dart';
import '../theme/app_colors.dart';
import '../widgets/period_selector.dart';
import '../widgets/responsive_page.dart';
import '../widgets/water_progress_chart.dart';

class WaterTrackerView extends GetView<TrackerController> {
  const WaterTrackerView({super.key});

  double _chartHeightFor(WaterPeriod period, Responsive r) => switch (period) {
        WaterPeriod.month => r.scale(130, tablet: 150, desktop: 170),
        WaterPeriod.week => r.scale(150, tablet: 170, desktop: 190),
        WaterPeriod.today || WaterPeriod.yesterday =>
          r.scale(140, tablet: 160, desktop: 180),
      };

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      appBar: AppBar(title: const Text('Water Tracker')),
      body: ResponsivePage(
        scrollable: true,
        child: Obx(() {
          final glasses = controller.waterGlasses;
          final goal = TrackerController.waterGoal;
          final period = controller.waterPeriod.value;
          final _ = controller.waterByDate.length;
          final chartHeight = _chartHeightFor(period, r);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Track your daily water intake easily.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '$glasses / $goal',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Text(
                'glasses today',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: controller.waterProgress,
                  minHeight: 14,
                  backgroundColor: AppColors.surface,
                  color: controller.isWaterGoalComplete
                      ? AppColors.primary
                      : const Color(0xFF007AFF),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Hydration History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              PeriodSelector(
                values: WaterPeriod.values,
                selected: period,
                labelFor: controller.periodLabelFor,
                onChanged: controller.setWaterPeriod,
                fontSize: 11,
              ),
              const SizedBox(height: 16),
              WaterProgressChart(
                days: controller.activeWaterDays,
                waterGoal: goal,
                chartHeight: chartHeight,
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: List.generate(goal, (i) {
                  final filled = i < glasses;
                  return Icon(
                    filled ? Icons.local_drink : Icons.local_drink_outlined,
                    size: 40,
                    color: filled
                        ? (controller.isWaterGoalComplete
                            ? AppColors.primary
                            : const Color(0xFF007AFF))
                        : AppColors.border,
                  );
                }),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: controller.removeWater,
                      child: const Text('Remove'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          glasses >= goal ? null : controller.addWater,
                      child: Text(
                        glasses >= goal ? 'Goal Complete!' : 'Add Glass',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
            ],
          );
        }),
      ),
    );
  }
}
