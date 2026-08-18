import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/main_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/user_controller.dart';
import '../core/app_coach_marks.dart';
import '../core/app_route_observer.dart';
import '../services/local_storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/floating_bottom_nav_bar.dart';
import 'analytics_view.dart';
import 'daily_log_view.dart';
import 'dashboard_view.dart';
import 'profile_view.dart';
import 'scan_view.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
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

  final _storage = LocalStorageService();
  bool _markedCoachMarksSeen = false;

  LocalStorageService get _coachStorage {
    final id = Get.isRegistered<UserController>()
        ? Get.find<UserController>().userId.trim()
        : '';
    if (id.isEmpty) return _storage;
    return LocalStorageService(null, id);
  }

  void _onCoachMarksFinished() {
    if (_markedCoachMarksSeen) return;
    _markedCoachMarksSeen = true;
    if (Get.isRegistered<MainController>()) {
      Get.find<MainController>().resetToHomeTab();
    }
    if (Get.isRegistered<DashboardController>()) {
      // After overlay teardown, land at the top of Home.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<DashboardController>().scrollHomeToTop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final controller = Get.find<MainController>();

    final shell = Scaffold(
      body: const SafeArea(
        bottom: false,
        child: _TabStack(pages: _pages),
      ),
      bottomNavigationBar: FloatingBottomNavBar(
        onTap: controller.changeTab,
        items: _tabs,
        coachKeys: AppCoachMarks.navKeys,
      ),
    );

    return CoachMarkHost(
      storage: _coachStorage,
      onFinished: _onCoachMarksFinished,
      child: shell,
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
