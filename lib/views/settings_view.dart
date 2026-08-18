import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../controllers/settings_controller.dart';
import '../controllers/theme_controller.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

import '../widgets/app_app_bar.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/responsive_page.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final ThemeController _theme;
  late final SettingsController _settings;

  @override
  void initState() {
    super.initState();
    _theme = Get.find<ThemeController>();
    _settings = Get.find<SettingsController>();
    _theme.beginLocalThemeOverlay();
  }

  @override
  void dispose() {
    _theme.endLocalThemeOverlay();
    super.dispose();
  }

  // Future<void> _pickMealReminderTime(
  //   BuildContext context,
  //   MealReminderSlot slot,
  //   TimeOfDay initialTime,
  // ) async {
  //   final picked = await showTimePicker(
  //     context: context,
  //     initialTime: initialTime,
  //     helpText: switch (slot) {
  //       MealReminderSlot.breakfast => 'Breakfast reminder',
  //       MealReminderSlot.lunch => 'Lunch reminder',
  //       MealReminderSlot.dinner => 'Dinner reminder',
  //     },
  //   );
  //   if (picked == null) return;
  //   await _settings.setMealReminderTime(slot, picked);
  // }

  // Future<void> _pickWaterInterval(BuildContext context) async {
  //   final selected = await showModalBottomSheet<int>(
  //     context: context,
  //     backgroundColor: AppColors.card,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  //     ),
  //     builder: (_) => SafeArea(
  //       child: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           const SizedBox(height: 8),
  //           for (final hours in [1, 2, 3, 4])
  //             ListTile(
  //               onTap: () => Navigator.of(context).pop(hours),
  //               title: Text(hours == 1 ? 'Every hour' : 'Every $hours hours'),
  //               trailing: _settings.waterReminderIntervalHours.value == hours
  //                   ? const Icon(Icons.check_rounded, color: AppColors.primary)
  //                   : null,
  //             ),
  //         ],
  //       ),
  //     ),
  //   );
  //   if (selected == null) return;
  //   await _settings.setWaterReminderInterval(selected);
  // }

  Future<void> _pickWaterGoal(BuildContext context) async {
    final selected = await showAppOptionsSheet<int>(
      context: context,
      title: 'Daily water goal',
      selected: _settings.waterGoalMl.value,
      options: [
        for (final ml in SettingsController.waterGoalMlOptions)
          AppSheetOption(
            value: ml,
            label: '$ml ml per day',
            subtitle: '~${ml ~/ SettingsController.mlPerGlass} glasses',
          ),
      ],
    );
    if (selected == null) return;
    await _settings.setWaterGoalMl(selected);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Obx(() {
      // Read both so device-theme + manual dark mode both refresh the page.
      _theme.themeMode.value;
      _theme.platformBrightness.value;
      final brightness = _theme.effectiveBrightness;
      AppColors.syncWithBrightness(brightness);

      // Local Theme so every section (Appearance + Notifications + General)
      // paints together. Global theme still applies when leaving Settings.
      return Theme(
        key: ValueKey<Brightness>(brightness),
        data: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppAppBar(
            key: ValueKey<String>('settings-app-bar-$brightness'),
            title: 'Settings',
          ),
          body: ResponsivePage(
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
                _SettingsGroup(
                  title: 'Appearance',
                  children: [
                    _SettingsSwitchTile(
                      icon: Icons.brightness_auto_rounded,
                      title: 'Use Device Theme',
                      subtitle: 'Follow your phone light or dark mode',
                      value: _theme.isSystemMode,
                      onChanged: (enabled) {
                        if (enabled) {
                          _theme.setThemeMode(ThemeMode.system);
                        } else {
                          // Lock to whatever the screen is showing now.
                          _theme.setThemeMode(
                            _theme.isDarkMode
                                ? ThemeMode.dark
                                : ThemeMode.light,
                          );
                        }
                      },
                    ),
                    _SettingsSwitchTile(
                      icon: Icons.dark_mode_rounded,
                      title: 'Dark Mode',
                      subtitle: _theme.isSystemMode
                          ? 'Changing this turns off device theme'
                          : 'Use a dark color scheme across the app',
                      value: _theme.isDarkMode,
                      onChanged: (enabled) {
                        // Always apply — toggling leaves system mode.
                        _theme.toggleDarkMode(enabled);
                      },
                    ),
                  ],
                ),
                SizedBox(height: r.scale(20)),
                // Built inside Obx (not captured outside) so cards refresh with theme.
                // _NotificationsSettings(
                //   settings: _settings,
                //   themeRevision: Object.hash(
                //     _theme.themeMode.value,
                //     _theme.platformBrightness.value,
                //     brightness,
                //   ),
                //   onPickMealTime: _pickMealReminderTime,
                //   onPickWaterInterval: _pickWaterInterval,
                // ),
                // SizedBox(height: r.scale(20)),
                _GeneralSettings(
                  settings: _settings,
                  themeRevision: Object.hash(
                    _theme.themeMode.value,
                    _theme.platformBrightness.value,
                    brightness,
                  ),
                  onPickWaterGoal: _pickWaterGoal,
                ),
                SizedBox(height: r.scale(20)),
                _SettingsGroup(
                  key: ValueKey<String>('settings-about-$brightness'),
                  title: 'About',
                  children: const [
                    _SettingsInfoTile(
                      icon: Icons.info_outline_rounded,
                      title: 'App Version',
                      value: '1.0.0',
                    ),
                  ],
                ),
                // Clear the home indicator / system gesture bar.
                SizedBox(
                  height:
                      MediaQuery.viewPaddingOf(context).bottom + r.scale(16),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/* class _NotificationsSettings extends StatelessWidget {
  const _NotificationsSettings({
    required this.settings,
    required this.themeRevision,
    required this.onPickMealTime,
    required this.onPickWaterInterval,
  });

  final SettingsController settings;
  final int themeRevision;
  final Future<void> Function(
    BuildContext context,
    MealReminderSlot slot,
    TimeOfDay initialTime,
  )
  onPickMealTime;
  final Future<void> Function(BuildContext context) onPickWaterInterval;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Keep listening to prefs; themeRevision from parent forces theme refresh.
      final pushEnabled = settings.pushNotifications.value;
      final _ = themeRevision;
      return _SettingsGroup(
        title: 'Notifications',
        children: [
          _SettingsSwitchTile(
            icon: Icons.notifications_active_rounded,
            title: 'Notifications',
            subtitle: pushEnabled
                ? 'Alerts are enabled for selected categories'
                : 'All app alerts are paused',
            value: pushEnabled,
            onChanged: settings.togglePushNotifications,
          ),
          _SettingsSwitchTile(
            icon: Icons.restaurant_rounded,
            title: 'Meal Reminders',
        subtitle:
    'Breakfast ${settings.formatTime(context, settings.breakfastReminder.value)}, '
    'Lunch ${settings.formatTime(context, settings.lunchReminder.value)}, '
    'Dinner ${settings.formatTime(context, settings.dinnerReminder.value)}',
            value: settings.mealReminders.value,
            enabled: pushEnabled,
            onChanged: settings.toggleMealReminders,
          ),
          _SettingsActionTile(
            icon: Icons.schedule_rounded,
            title: 'Breakfast Reminder',
            subtitle: settings.formatTime(
              context,
              settings.breakfastReminder.value,
            ),
            enabled: pushEnabled && settings.mealReminders.value,
            onTap: () => onPickMealTime(
              context,
              MealReminderSlot.breakfast,
              settings.breakfastReminder.value,
            ),
          ),
          _SettingsActionTile(
            icon: Icons.lunch_dining_rounded,
            title: 'Lunch Reminder',
            subtitle: settings.formatTime(
              context,
              settings.lunchReminder.value,
            ),
            enabled: pushEnabled && settings.mealReminders.value,
            onTap: () => onPickMealTime(
              context,
              MealReminderSlot.lunch,
              settings.lunchReminder.value,
            ),
          ),
          _SettingsActionTile(
            icon: Icons.dinner_dining_rounded,
            title: 'Dinner Reminder',
            subtitle: settings.formatTime(
              context,
              settings.dinnerReminder.value,
            ),
            enabled: pushEnabled && settings.mealReminders.value,
            onTap: () => onPickMealTime(
              context,
              MealReminderSlot.dinner,
              settings.dinnerReminder.value,
            ),
          ),
          _SettingsSwitchTile(
            icon: Icons.water_drop_rounded,
            title: 'Water Reminders',
       subtitle: settings.waterIntervalSummary,
            value: settings.waterReminders.value,
            enabled: pushEnabled,
            onChanged: settings.toggleWaterReminders,
          ),
          _SettingsActionTile(
            icon: Icons.timer_outlined,
            title: 'Hydration Frequency',
            subtitle: settings.waterIntervalSummary,
            enabled: pushEnabled && settings.waterReminders.value,
            onTap: () => onPickWaterInterval(context),
          ),

          _SettingsSwitchTile(
            icon: Icons.insights_rounded,
            title: 'Weekly Report',
            subtitle: 'Sunday summary of your nutrition',
            value: settings.weeklyReport.value,
            enabled: pushEnabled,
            onChanged: settings.toggleWeeklyReport,
          ),
          _SettingsSwitchTile(
            icon: Icons.campaign_rounded,
            title: 'App Updates',
            subtitle: 'Future product updates and announcements',
            value: settings.appUpdates.value,
            enabled: pushEnabled,
            onChanged: settings.toggleAppUpdates,
          ),
        ],
      );
    });
  }
} */

class _GeneralSettings extends StatelessWidget {
  const _GeneralSettings({
    required this.settings,
    required this.themeRevision,
    required this.onPickWaterGoal,
  });

  final SettingsController settings;
  final int themeRevision;
  final Future<void> Function(BuildContext context) onPickWaterGoal;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final _ = themeRevision;
      settings.useMetricUnits.value;
      settings.waterGoalMl.value;
      return _SettingsGroup(
        title: 'General',
        children: [
          _SettingsActionTile(
            icon: Icons.water_drop_outlined,
            title: 'Daily Water Goal',
            subtitle: settings.waterGoalSummary,
            onTap: () => onPickWaterGoal(context),
          ),
          _SettingsSwitchTile(
            icon: Icons.straighten_rounded,
            title: 'Metric Units',
            subtitle: 'Use kg and cm (off for lbs & ft)',
            value: settings.useMetricUnits.value,
            onChanged: settings.toggleUseMetricUnits,
          ),
        ],
      );
    });
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    super.key,
    required this.title,
    required this.children,
  });

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
        Material(
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
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
          color: enabled ? AppColors.textPrimary : textSecondary,
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
          color: enabled ? AppColors.textPrimary : textSecondary,
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
      leading: _SettingsIcon(icon: icon, enabled: true),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Text(value, style: TextStyle(color: AppColors.textSecondary)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, required this.enabled});

  final IconData icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: enabled ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 20,
        color: enabled
            ? AppColors.primary
            : AppColors.primary.withValues(alpha: 0.45),
      ),
    );
  }
}
