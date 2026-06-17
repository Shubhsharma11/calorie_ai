import 'package:flutter/material.dart';

import 'package:get/get.dart';



import '../controllers/food_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/theme_controller.dart';
import '../controllers/user_controller.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';

import '../widgets/responsive_page.dart';



class SettingsView extends GetView<SettingsController> {

  const SettingsView({super.key});



  @override

  Widget build(BuildContext context) {

    final r = context.responsive;



    return Scaffold(

      appBar: AppBar(title: const Text('Settings')),

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

                ),

              ),

              SizedBox(height: r.scale(24)),

              Obx(
                () => _SettingsGroup(
                  title: 'Appearance',
                  children: [
                    _SettingsSwitchTile(
                      icon: Icons.dark_mode_rounded,
                      title: 'Dark Mode',
                      subtitle: 'Use a dark color scheme across the app',
                      value: Get.find<ThemeController>().isDarkMode,
                      onChanged: Get.find<ThemeController>().toggleDarkMode,
                    ),
                  ],
                ),
              ),

              SizedBox(height: r.scale(20)),

              _SettingsGroup(

                title: 'Notifications',

                children: [

                  _SettingsSwitchTile(

                    icon: Icons.notifications_active_rounded,

                    title: 'Push Notifications',

                    subtitle: 'Master switch for all app alerts',

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

                  _SettingsSwitchTile(

                    icon: Icons.water_drop_rounded,

                    title: 'Water Reminders',

                    subtitle: 'Hydration alerts every 2 hours',

                    value: controller.waterReminders.value,

                    enabled: pushEnabled,

                    onChanged: controller.toggleWaterReminders,

                  ),

                  _SettingsSwitchTile(

                    icon: Icons.insights_rounded,

                    title: 'Weekly Report',

                    subtitle: 'Sunday summary of your nutrition',

                    value: controller.weeklyReport.value,

                    enabled: pushEnabled,

                    onChanged: controller.toggleWeeklyReport,

                  ),

                ],

              ),

              SizedBox(height: r.scale(20)),

              GetBuilder<UserController>(
                builder: (ctrl) => _SettingsGroup(
                  title: 'Goals',
                  children: [
                    _SettingsActionTile(
                      icon: Icons.flag_outlined,
                      title: 'Goal Weight',
                      subtitle:
                          '${ctrl.user.goalWeightKg.toStringAsFixed(1)} kg target',
                      onTap: () => Get.toNamed(
                        AppRoutes.goalWeight,
                        arguments: RouteArgs.fromProfileMap,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: r.scale(20)),

              _SettingsGroup(

                title: 'General',

                children: [

                  _SettingsSwitchTile(

                    icon: Icons.straighten_rounded,

                    title: 'Metric Units',

                    subtitle: 'Use kg and cm (off for lbs & ft)',

                    value: controller.useMetricUnits.value,

                    onChanged: controller.toggleUseMetricUnits,

                  ),

                  _SettingsActionTile(

                    icon: Icons.delete_outline_rounded,

                    title: 'Clear Recent Foods',

                    subtitle: 'Remove your food search history',

                    onTap: () {

                      if (Get.isRegistered<FoodController>()) {

                        Get.find<FoodController>().clearRecentFoods();

                      }

                      _showSnack(context, 'Recent foods cleared');

                    },

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



  void _showSnack(BuildContext context, String message) {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(content: Text(message)),

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

  });



  final IconData icon;

  final String title;

  final String subtitle;

  final VoidCallback onTap;



  @override

  Widget build(BuildContext context) {

    return ListTile(

      onTap: onTap,

      leading: _SettingsIcon(icon: icon),

      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),

      subtitle: Text(

        subtitle,

        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),

      ),

      trailing: Icon(

        Icons.chevron_right_rounded,

        color: AppColors.textSecondary,

      ),

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

