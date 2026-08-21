import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../controllers/scan_controller.dart';
import '../controllers/user_controller.dart';

class MainController extends GetxController {
  final RxInt tabIndex = 0.obs;

  static const int homeTabIndex = 0;
  static const int diaryTabIndex = 1;
  static const int scanTabIndex = 2;
  static const int statsTabIndex = 3;

  @override
  void onReady() {
    super.onReady();
    // IndexedStack keeps Scan mounted — leave camera off until that tab is open.
    _scheduleSyncScanCamera(tabIndex.value);
  }

  void changeTab(int index) {
    if (_sessionBusy) return;
    if (tabIndex.value == index) return;
    tabIndex.value = index;
    // Defer camera Obx updates until after IndexedStack finishes rebuilding,
    // otherwise Flutter can hit `_elements.contains(element)` assertions.
    _scheduleSyncScanCamera(index);
  }

  void resetToHomeTab() {
    if (tabIndex.value != homeTabIndex) {
      tabIndex.value = homeTabIndex;
    }
    _scheduleSyncScanCamera(homeTabIndex);
  }

  void _scheduleSyncScanCamera(int index) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      // Tab may have changed again before this frame callback runs.
      if (tabIndex.value != index) return;
      _syncScanCamera(index);
    });
  }

  void _syncScanCamera(int index) {
    if (!Get.isRegistered<ScanController>()) return;
    final scan = Get.find<ScanController>();
    if (index == scanTabIndex) {
      // Fire-and-forget; camera start requests permission asynchronously.
      scan.resumeBarcodeScan();
    } else {
      scan.pauseBarcodeScan();
    }
  }

  static void resetHomeTabIfRegistered() {
    if (Get.isRegistered<MainController>()) {
      Get.find<MainController>().resetToHomeTab();
    }
  }

  bool get _sessionBusy {
     if (!Get.isRegistered<UserController>()) return false;
    final user = Get.find<UserController>();
    return user.isSessionBusy.value ||
        user.isLoggingOut ||
        user.isDeletingAccount;
  }
}
 