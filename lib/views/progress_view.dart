import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/dashboard_controller.dart';
import '../controllers/food_controller.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';

class ProgressView extends GetView<DashboardController> {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    final food = Get.find<FoodController>();

    return Scaffold(
      body: SafeArea(
        child: Obx(() {
          final _ = food.entriesRevision.value;
          final daysOnGoal = controller.daysOnGoal;
          final avgCalories = controller.weeklyAverageCalories;
          final mealsLogged =
              controller.weeklyNutrition.fold(0, (sum, d) => sum + d.mealCount);

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 100,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Great Job!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You hit your calorie goal $daysOnGoal days this week.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                _StatRow(label: 'Avg Calories', value: '$avgCalories kcal'),
                _StatRow(label: 'Days on Goal', value: '$daysOnGoal / 7'),
                _StatRow(label: 'Meals Logged', value: '$mealsLogged'),
                const Spacer(),
                PrimaryButton(
                  label: 'Continue',
                  onPressed: () => Get.offAllNamed(AppRoutes.main),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
