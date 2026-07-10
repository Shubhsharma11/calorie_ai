import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../controllers/settings_controller.dart';
import '../controllers/theme_controller.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';

import '../widgets/app_app_bar.dart';
import '../widgets/responsive_page.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  Future<void> _pickMealReminderTime(
    BuildContext context,
    MealReminderSlot slot,
    TimeOfDay initialTime,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: switch (slot) {
        MealReminderSlot.breakfast => 'Breakfast reminder',
        MealReminderSlot.lunch => 'Lunch reminder',
        MealReminderSlot.dinner => 'Dinner reminder',
      },
    );
    if (picked == null) return;
    await controller.setMealReminderTime(slot, picked);
  }

  Future<void> _pickWaterInterval(BuildContext context) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final hours in [1, 2, 3, 4])
              ListTile(
                onTap: () => Navigator.of(context).pop(hours),
                title: Text(hours == 1 ? 'Every hour' : 'Every $hours hours'),
                trailing: controller.waterReminderIntervalHours.value == hours
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await controller.setWaterReminderInterval(selected);
  }

  Future<void> _pickWaterGoal(BuildContext context) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final ml in SettingsController.waterGoalMlOptions)
              ListTile(
                onTap: () => Navigator.of(context).pop(ml),
                title: Text('$ml ml per day'),
                subtitle: Text(
                  '~${ml ~/ SettingsController.mlPerGlass} glasses',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: controller.waterGoalMl.value == ml
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await controller.setWaterGoalMl(selected);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      appBar: const AppAppBar(title: 'Settings'),

      body: Obx(() {
        final pushEnabled = controller.pushNotifications.value;

        return ResponsivePage(
          scrollable: true,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                'App Preferences',
                style: TextStyle(
                  fontSize: r.scale(22, tablet: 24),
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              SizedBox(height: r.scale(24)),

              Obx(() {
                final theme = Get.find<ThemeController>();
                return _SettingsGroup(
                  title: 'Appearance',
                  children: [
                    _SettingsSwitchTile(
                      icon: Icons.brightness_auto_rounded,
                      title: 'Use Device Theme',
                      subtitle: 'Follow your phone light or dark mode',
                      value: theme.isSystemMode,
                      onChanged: (enabled) {
                        if (enabled) {
                          theme.setThemeMode(ThemeMode.system);
                        } else {
                          theme.setThemeMode(
                            theme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
                          );
                        }
                      },
                    ),
                    _SettingsSwitchTile(
                      icon: Icons.dark_mode_rounded,
                      title: 'Dark Mode',
                      subtitle: theme.isSystemMode
                          ? 'Turn off device theme to change manually'
                          : 'Use a dark color scheme across the app',
                      value: theme.isDarkMode,
                      enabled: !theme.isSystemMode,
                      onChanged: theme.toggleDarkMode,
                    ),
                  ],
                );
              }),

              SizedBox(height: r.scale(20)),

              _SettingsGroup(
                title: 'Notifications',

                children: [
                  _SettingsSwitchTile(
                    icon: Icons.notifications_active_rounded,

                    title: 'Notifications',

                    subtitle: pushEnabled
                        ? 'Alerts are enabled for selected categories'
                        : 'All app alerts are paused',

                    value: pushEnabled,

                    onChanged: controller.togglePushNotifications,
                  ),

                  _SettingsSwitchTile(
                    icon: Icons.restaurant_rounded,

                    title: 'Meal Reminders',

                    subtitle: 'Breakfast 8 AM, lunch 1 PM, dinner 7:30 PM',

                    value: controller.mealReminders.value,

                    enabled: pushEnabled,

                    onChanged: controller.toggleMealReminders,
                  ),

                  _SettingsActionTile(
                    icon: Icons.schedule_rounded,
                    title: 'Breakfast Reminder',
                    subtitle: controller.formatTime(
                      context,
                      controller.breakfastReminder.value,
                    ),
                    enabled: pushEnabled && controller.mealReminders.value,
                    onTap: () => _pickMealReminderTime(
                      context,
                      MealReminderSlot.breakfast,
                      controller.breakfastReminder.value,
                    ),
                  ),

                  _SettingsActionTile(
                    icon: Icons.lunch_dining_rounded,
                    title: 'Lunch Reminder',
                    subtitle: controller.formatTime(
                      context,
                      controller.lunchReminder.value,
                    ),
                    enabled: pushEnabled && controller.mealReminders.value,
                    onTap: () => _pickMealReminderTime(
                      context,
                      MealReminderSlot.lunch,
                      controller.lunchReminder.value,
                    ),
                  ),

                  _SettingsActionTile(
                    icon: Icons.dinner_dining_rounded,
                    title: 'Dinner Reminder',
                    subtitle: controller.formatTime(
                      context,
                      controller.dinnerReminder.value,
                    ),
                    enabled: pushEnabled && controller.mealReminders.value,
                    onTap: () => _pickMealReminderTime(
                      context,
                      MealReminderSlot.dinner,
                      controller.dinnerReminder.value,
                    ),
                  ),

                  _SettingsSwitchTile(
                    icon: Icons.water_drop_rounded,

                    title: 'Water Reminders',

                    subtitle: 'Hydration alerts every 2 hours',

                    value: controller.waterReminders.value,

                    enabled: pushEnabled,

                    onChanged: controller.toggleWaterReminders,
                  ),

                  _SettingsActionTile(
                    icon: Icons.timer_outlined,
                    title: 'Hydration Frequency',
                    subtitle: controller.waterIntervalSummary,
                    enabled: pushEnabled && controller.waterReminders.value,
                    onTap: () => _pickWaterInterval(context),
                  ),

                  _SettingsSwitchTile(
                    icon: Icons.track_changes_rounded,
                    title: 'Goal Progress Alerts',
                    subtitle: 'Updates when you are close to daily targets',
                    value: controller.goalProgressAlerts.value,
                    enabled: pushEnabled,
                    onChanged: controller.toggleGoalProgressAlerts,
                  ),

                  _SettingsSwitchTile(
                    icon: Icons.local_fire_department_rounded,
                    title: 'Streak Reminders',
                    subtitle: 'Remind you to log meals and keep your streak',
                    value: controller.streakReminders.value,
                    enabled: pushEnabled,
                    onChanged: controller.toggleStreakReminders,
                  ),

                  _SettingsSwitchTile(
                    icon: Icons.insights_rounded,

                    title: 'Weekly Report',

                    subtitle: 'Sunday summary of your nutrition',

                    value: controller.weeklyReport.value,

                    enabled: pushEnabled,

                    onChanged: controller.toggleWeeklyReport,
                  ),

                  _SettingsSwitchTile(
                    icon: Icons.campaign_rounded,
                    title: 'App Updates',
                    subtitle: 'Future product updates and announcements',
                    value: controller.appUpdates.value,
                    enabled: pushEnabled,
                    onChanged: controller.toggleAppUpdates,
                  ),
                ],
              ),

              SizedBox(height: r.scale(20)),

              _SettingsGroup(
                title: 'General',

                children: [
                  _SettingsActionTile(
                    icon: Icons.water_drop_outlined,
                    title: 'Daily Water Goal',
                    subtitle: controller.waterGoalSummary,
                    onTap: () => _pickWaterGoal(context),
                  ),
                  _SettingsSwitchTile(
                    icon: Icons.straighten_rounded,

                    title: 'Metric Units',

                    subtitle: 'Use kg and cm (off for lbs & ft)',

                    value: controller.useMetricUnits.value,

                    onChanged: controller.toggleUseMetricUnits,
                  ),
                ],
              ),

              SizedBox(height: r.scale(20)),

              _SettingsGroup(
                title: 'About',

                children: [
                  const _SettingsInfoTile(
                    icon: Icons.info_outline_rounded,

                    title: 'App Version',

                    value: '1.0.0',
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Padding(
          padding: EdgeInsets.only(left: r.scale(4), bottom: r.scale(10)),

          child: Text(
            title.toUpperCase(),

            style: TextStyle(
              fontSize: r.scale(12),

              fontWeight: FontWeight.w600,

              color: AppColors.textSecondary,

              letterSpacing: 0.6,
            ),
          ),
        ),

        Container(
          decoration: BoxDecoration(
            color: AppColors.card,

            borderRadius: BorderRadius.circular(16),

            border: Border.all(color: AppColors.border),
          ),

          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],

                if (i < children.length - 1)
                  Divider(height: 1, indent: 56, color: AppColors.border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,

    required this.title,

    required this.subtitle,

    required this.value,

    required this.onChanged,

    this.enabled = true,
  });

  final IconData icon;

  final String title;

  final String subtitle;

  final bool value;

  final bool enabled;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondary.withValues(
      alpha: enabled ? 1 : 0.6,
    );

    return SwitchListTile(
      secondary: _SettingsIcon(icon: icon, enabled: enabled),

      title: Text(
        title,

        style: TextStyle(
          fontWeight: FontWeight.w600,

          color: enabled ? null : textSecondary,
        ),
      ),

      subtitle: Text(
        subtitle,

        style: TextStyle(fontSize: 12, color: textSecondary),
      ),

      value: value,

      onChanged: enabled ? onChanged : null,

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,

    required this.title,

    required this.subtitle,

    required this.onTap,

    this.enabled = true,
  });

  final IconData icon;

  final String title;

  final String subtitle;

  final VoidCallback onTap;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondary.withValues(
      alpha: enabled ? 1 : 0.6,
    );

    return ListTile(
      onTap: enabled ? onTap : null,

      leading: _SettingsIcon(icon: icon, enabled: enabled),

      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: enabled ? null : textSecondary,
        ),
      ),

      subtitle: Text(
        subtitle,

        style: TextStyle(fontSize: 12, color: textSecondary),
      ),

      trailing: Icon(Icons.chevron_right_rounded, color: textSecondary),

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _SettingsInfoTile extends StatelessWidget {
  const _SettingsInfoTile({
    required this.icon,

    required this.title,

    required this.value,
  });

  final IconData icon;

  final String title;

  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _SettingsIcon(icon: icon),

      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),

      trailing: Text(
        value,

        style: TextStyle(
          color: AppColors.textSecondary,

          fontWeight: FontWeight.w500,
        ),
      ),

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, this.enabled = true});

  final IconData icon;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,

      height: 40,

      alignment: Alignment.center,

      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: enabled ? 0.1 : 0.05),

        borderRadius: BorderRadius.circular(10),
      ),

      child: Icon(
        icon,

        color: enabled ? AppColors.primary : AppColors.textSecondary,

        size: 20,
      ),
    );
  }
}
