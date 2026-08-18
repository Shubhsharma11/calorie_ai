import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/settings_controller.dart';
import '../controllers/tracker_controller.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'app_bottom_sheet.dart';

abstract final class NotificationsSheet {
  static void show(BuildContext context) {
    if (!Get.isRegistered<SettingsController>()) {
      Get.put(SettingsController());
    }

    showAppBottomSheet<void>(
      context: context,
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

    return AppSheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                      ? settings.mealReminderSummary
                      : 'Off',
                  active: pushOn && settings.mealReminders.value,
                  enabled: pushOn,
                  onTap: () => settings.toggleMealReminders(
                    !settings.mealReminders.value,
                  ),
                  trailing: Switch(
                    value: pushOn && settings.mealReminders.value,
                    onChanged: pushOn ? settings.toggleMealReminders : null,
                  ),
                ),
                const SizedBox(height: 10),
                _NotificationRow(
                  icon: Icons.water_drop_rounded,
                  title: 'Water Reminders',
                  subtitle: pushOn && settings.waterReminders.value
                      ? settings.waterIntervalSummary
                      : 'Off',
                  active: pushOn && settings.waterReminders.value,
                  enabled: pushOn,
                  onTap: () => settings.toggleWaterReminders(
                    !settings.waterReminders.value,
                  ),
                  trailing: Switch(
                    value: pushOn && settings.waterReminders.value,
                    onChanged: pushOn ? settings.toggleWaterReminders : null,
                  ),
                ),
                const SizedBox(height: 10),
                _NotificationRow(
                  icon: Icons.insights_rounded,
                  title: 'Weekly Report',
                  subtitle: pushOn && settings.weeklyReport.value
                      ? 'Sunday nutrition summary'
                      : 'Off',
                  active: pushOn && settings.weeklyReport.value,
                  enabled: pushOn,
                  onTap: () =>
                      settings.toggleWeeklyReport(!settings.weeklyReport.value),
                  trailing: Switch(
                    value: pushOn && settings.weeklyReport.value,
                    onChanged: pushOn ? settings.toggleWeeklyReport : null,
                  ),
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
                          : '${tracker.waterMl} / ${TrackerController.waterGoalMl} ml logged',
                      active: !waterDone,
                      accentColor: const Color(0xFF007AFF),
                      onTap: () {
                        Navigator.pop(context);
                        Get.toNamed(AppRoutes.waterTracker);
                      },
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                      ),
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
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
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
    this.enabled = true,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final Color? accentColor;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: enabled ? 0.12 : 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: enabled ? color : AppColors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
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
              if (trailing != null)
                trailing!
              else if (active)
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
        ),
      ),
    );
  }
}
