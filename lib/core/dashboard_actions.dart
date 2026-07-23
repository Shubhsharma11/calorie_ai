import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/food_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/tracker_controller.dart';
import '../models/meal_entry.dart';
import '../routes/app_routes.dart';

abstract final class DashboardActions {
  static void openFoodSearch() {
    // Keep the currently selected diary day so past-day browsing stays consistent.
    Get.toNamed(AppRoutes.addFood);
  }

  static Future<void> openCalendar(BuildContext context) async {
    final food = Get.find<FoodController>();
    final today = MealEntry.normalizeDate(DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: food.selectedLogDate.value,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today,
      helpText: 'Select a day to view',
    );
    if (picked == null) return;

    // Stay on the current tab — Home and Diary both follow this date.
    food.setSelectedLogDate(picked);
  }

  static void openNotifications(BuildContext context) {
    Get.toNamed(AppRoutes.notifications);
  }

  static bool get hasNotificationBadge {
    if (!Get.isRegistered<SettingsController>()) return false;

    final settings = Get.find<SettingsController>();
    if (!settings.pushNotifications.value) return false;

    final remindersOn =
        settings.mealReminders.value || settings.waterReminders.value;

    final waterPending =
        Get.isRegistered<TrackerController>() &&
        !Get.find<TrackerController>().isWaterGoalComplete;

    return remindersOn || waterPending;
  }
}

/// Formats the diary header date label.
String formatLogDateLabel(DateTime date) {
  final today = MealEntry.normalizeDate(DateTime.now());
  final yesterday = today.subtract(const Duration(days: 1));
  final day = MealEntry.normalizeDate(date);

  if (day == today) return 'Today';
  if (day == yesterday) return 'Yesterday';

  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final weekday = weekdays[day.weekday - 1];
  final month = months[day.month - 1];
  return '$weekday, ${day.day} $month ${day.year}';
}
