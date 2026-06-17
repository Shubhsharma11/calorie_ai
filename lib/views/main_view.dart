import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/main_controller.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import '../widgets/floating_bottom_nav_bar.dart';
import 'analytics_view.dart';
import 'daily_log_view.dart';
import 'dashboard_view.dart';
import 'profile_view.dart';
import 'scan_view.dart';

class MainView extends GetView<MainController> {
  const MainView({super.key});

  static const _tabs = [
    (icon: Icons.home, label: 'Home'),
    (icon: Icons.menu_book, label: 'Diary'),
    (icon: Icons.camera_alt, label: 'Scan'),
    (icon: Icons.bar_chart, label: 'Stats'),
    (icon: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    const pages = [
      DashboardView(),
      DailyLogView(),
      ScanView(),
      AnalyticsView(),
      ProfileView(),
    ];

    final r = context.responsive;

    return Obx(() {
      final tab = controller.tabIndex.value;

      if (r.isWide) {
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: tab,
                onDestinationSelected: controller.changeTab,
                labelType: r.isDesktop
                    ? NavigationRailLabelType.all
                    : NavigationRailLabelType.selected,
                backgroundColor: AppColors.background,
                indicatorColor: AppColors.primary.withValues(alpha: 0.2),
                selectedIconTheme: const IconThemeData(
                  color: AppColors.primary,
                ),
                destinations: [
                  for (final t in _tabs)
                    NavigationRailDestination(
                      icon: Icon(t.icon),
                      label: Text(t.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: pages[tab]),
            ],
          ),
        );
      }

      return Scaffold(
        body: pages[tab],
        bottomNavigationBar: FloatingBottomNavBar(
          selectedIndex: tab,
          onTap: controller.changeTab,
          items: _tabs,
        ),
      );
    });
  }
}
