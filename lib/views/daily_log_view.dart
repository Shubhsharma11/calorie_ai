import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/dashboard_controller.dart';
import '../controllers/food_controller.dart';
import '../core/dashboard_actions.dart';
import '../core/responsive.dart';
import '../models/meal_entry.dart';
import '../models/meal_type.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/food_emoji_avatar.dart';
import '../widgets/responsive_page.dart';

class DailyLogView extends GetView<FoodController> {
  const DailyLogView({super.key});

  @override
  Widget build(BuildContext context) {
    final dash = Get.find<DashboardController>();
    final r = context.responsive;

    return Obx(() {
      final _ = controller.entriesRevision.value;
      final logDate = controller.selectedLogDate.value;
      final eaten = controller.selectedDateCalories;
      final goal = dash.calorieGoal;
      final progress = goal > 0 ? (eaten / goal).clamp(0.0, 1.0) : 0.0;
      final dateLabel = formatLogDateLabel(logDate);

      return ResponsivePage(
        scrollable: false,
        child: Column(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Daily Log',
                        style: TextStyle(
                          fontSize: r.scale(24, tablet: 26, desktop: 28),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => DashboardActions.openCalendar(context),
                      icon: Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(dateLabel),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.scale(12)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: r.scale(10, tablet: 12),
                    backgroundColor: AppColors.surface,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: r.scale(8)),
                Text(
                  '$eaten / $goal kcal · $dateLabel',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            SizedBox(height: r.scale(8)),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(
                  top: r.scale(8),
                  bottom: MediaQuery.paddingOf(context).bottom + 8,
                ),
                children: [
                  for (final meal in MealType.all) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meal,
                                style: TextStyle(
                                  fontSize: r.scale(17, tablet: 18),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${controller.caloriesForMealOnSelectedDate(meal)} kcal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            controller.setSelectedMeal(meal);
                            Get.toNamed(AppRoutes.addFood);
                          },
                          icon: Icon(
                            Icons.add,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          label: Text(
                            'Add',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: r.scale(8)),
                    ...controller.mealsForSelectedDate(meal)
                        .map((e) => _LogEntryTile(entry: e)),
                    if (controller.mealsForSelectedDate(meal).isEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: r.scale(12)),
                        child: Text(
                          'No items yet',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    SizedBox(height: r.scale(16)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _LogEntryTile extends GetView<FoodController> {
  const _LogEntryTile({required this.entry});

  final MealEntry entry;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.delete_outline, color: AppColors.error),
      ),
      onDismissed: (_) => controller.removeEntry(entry),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 2),
        onTap: () => Get.toNamed(AppRoutes.editMeal, arguments: entry),
        leading: FoodEmojiAvatar(emoji: entry.food.emoji, size: 44),
        title: Text(entry.food.name),
        subtitle: Text('${entry.grams}g · ${entry.meal}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${entry.calories} kcal'),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}
