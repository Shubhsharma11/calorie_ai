import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/main_controller.dart';
import '../core/app_route_observer.dart';
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

  static const _pages = [
    DashboardView(),
    DailyLogView(),
    ScanView(),
    AnalyticsView(),
    ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    if (r.isWide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              Obx(
                () => NavigationRail(
                  selectedIndex: controller.tabIndex.value,
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
              ),
              const VerticalDivider(width: 1, thickness: 1),
              const Expanded(child: _TabStack(pages: _pages)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: const SafeArea(
        bottom: false,
        child: _TabStack(pages: _pages),
      ),
      bottomNavigationBar: Obx(
        () => FloatingBottomNavBar(
          selectedIndex: controller.tabIndex.value,
          onTap: controller.changeTab,
          items: _tabs,
        ),
      ),
    );
  }
}

/// Uses [setState] instead of wrapping [IndexedStack] in [Obx].
class _TabStack extends StatefulWidget {
  const _TabStack({required this.pages});

  final List<Widget> pages;

  @override
  State<_TabStack> createState() => _TabStackState();
}

class _TabStackState extends State<_TabStack> with RouteAware {
  late final MainController _controller;
  Worker? _tabWorker;
  late final List<bool> _activated;

  /// True while another route (Settings, etc.) covers MainView.
  bool _coveredByRoute = false;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<MainController>();
    _activated = List<bool>.filled(widget.pages.length, false);
    _activated[_controller.tabIndex.value] = true;
    _tabWorker = ever<int>(_controller.tabIndex, (index) {
      if (!mounted) return;
      if (index < 0 || index >= _activated.length) return;
      if (!_activated[index]) {
        _activated[index] = true;
      }
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _tabWorker?.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    if (!_coveredByRoute) setState(() => _coveredByRoute = true);
  }

  @override
  void didPopNext() {
    if (_coveredByRoute) setState(() => _coveredByRoute = false);
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = _controller.tabIndex.value;

    return IndexedStack(
      index: activeIndex,
      children: [
        for (var i = 0; i < widget.pages.length; i++)
          KeyedSubtree(
            key: ValueKey<String>('main-tab-$i'),
            child: !_activated[i]
                ? const SizedBox.shrink()
                : _TabThemeGate(
                    // Freeze every tab while Settings (or any route) covers us.
                    active: !_coveredByRoute && i == activeIndex,
                    child: widget.pages[i],
                  ),
          ),
      ],
    );
  }
}

/// Freezes [Theme] for inactive/covered tabs so theme toggles stay snappy.
class _TabThemeGate extends StatefulWidget {
  const _TabThemeGate({
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  State<_TabThemeGate> createState() => _TabThemeGateState();
}

class _TabThemeGateState extends State<_TabThemeGate> {
  ThemeData? _frozen;

  @override
  Widget build(BuildContext context) {
    // Avoid Theme.of when inactive so parent theme swaps don't rebuild this gate.
    if (widget.active) {
      _frozen = Theme.of(context);
      return TickerMode(
        enabled: true,
        child: widget.child,
      );
    }

    if (_frozen == null) {
      _frozen = Theme.of(context);
    }
    return TickerMode(
      enabled: false,
      child: Theme(
        data: _frozen!,
        child: widget.child,
      ),
    );
  }
}
