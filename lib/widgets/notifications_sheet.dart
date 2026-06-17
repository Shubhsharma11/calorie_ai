import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/settings_controller.dart';
import '../controllers/tracker_controller.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

abstract final class NotificationsSheet {
  static void show(BuildContext context) {
    if (!Get.isRegistered<SettingsController>()) {
      Get.put(SettingsController());
    }

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _NotificationsSheetBody(),
    );
  }
}

class _NotificationsSheetBody extends StatelessWidget {
  const _NotificationsSheetBody();

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsController>();
    final tracker = Get.isRegistered<TrackerController>()
        ? Get.find<TrackerController>()
        : null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Notifications',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Obx(() {
              final pushOn = settings.pushNotifications.value;
              return Column(
                children: [
                  _NotificationRow(
                    icon: Icons.restaurant_rounded,
                    title: 'Meal Reminders',
                    subtitle: pushOn && settings.mealReminders.value
                        ? 'Breakfast, lunch & dinner alerts on'
                        : 'Off',
                    active: pushOn && settings.mealReminders.value,
                  ),
                  const SizedBox(height: 10),
                  _NotificationRow(
                    icon: Icons.water_drop_rounded,
                    title: 'Water Reminders',
                    subtitle: pushOn && settings.waterReminders.value
                        ? 'Hydration alerts every 2 hours'
                        : 'Off',
                    active: pushOn && settings.waterReminders.value,
                  ),
                  const SizedBox(height: 10),
                  _NotificationRow(
                    icon: Icons.insights_rounded,
                    title: 'Weekly Report',
                    subtitle: pushOn && settings.weeklyReport.value
                        ? 'Sunday nutrition summary'
                        : 'Off',
                    active: pushOn && settings.weeklyReport.value,
                  ),
                  if (tracker != null) ...[
                    const SizedBox(height: 10),
                    Obx(() {
                      final waterDone = tracker.isWaterGoalComplete;
                      return _NotificationRow(
                        icon: Icons.water_drop_outlined,
                        title: 'Water Goal Today',
                        subtitle: waterDone
                            ? 'You reached your daily goal!'
                            : '${tracker.waterGlasses} / ${TrackerController.waterGoal} glasses logged',
                        active: !waterDone,
                        accentColor: const Color(0xFF007AFF),
                      );
                    }),
                  ],
                ],
              );
            }),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                Get.toNamed(AppRoutes.settings);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Manage in Settings',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (active)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
