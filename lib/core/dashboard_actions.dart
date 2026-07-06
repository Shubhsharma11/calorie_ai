import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/food_controller.dart';
import '../controllers/main_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/tracker_controller.dart';
import '../models/meal_entry.dart';
import '../routes/app_routes.dart';

abstract final class DashboardActions {
  static void openFoodSearch() {
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
      helpText: 'View daily log',
    );
    if (picked == null) return;

    food.setSelectedLogDate(picked);
    if (Get.isRegistered<MainController>()) {
      Get.find<MainController>().changeTab(1);
    }
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

  if (date == today) return 'Today';
  if (date == yesterday) return 'Yesterday';
  return DateFormat('EEE, d MMM yyyy').format(date);
}
