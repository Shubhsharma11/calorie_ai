import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../controllers/scan_controller.dart';
import '../controllers/user_controller.dart';
import '../core/app_log.dart';
import '../core/app_snackbar.dart';
import '../core/home_hydrate.dart';
import '../core/home_stuck_debug.dart'; // TEMPORARY — HOME_STUCK_DEBUG

class MainController extends GetxController {
  final RxInt tabIndex = 0.obs;

  /// False until the first Home frame + core hydrate finish. Blocks early
  /// Profile/Stats taps that looked broken for brand-new users.
  final shellReady = false.obs;

  static const int homeTabIndex = 0;
  static const int diaryTabIndex = 1;
  static const int scanTabIndex = 2;
  static const int statsTabIndex = 3;
  static const int profileTabIndex = 4;

  bool _shellSettleInFlight = false;
  Timer? _shellSettleDelay;
  Completer<void>? _shellSettleDelayCompleter;

  @override
  void onReady() {
    super.onReady();
    // TEMPORARY — HOME_STUCK_DEBUG
    HomeStuckDebug.log(
      'MainController.onReady',
      {
        'shellReady': shellReady.value,
        'tabIndex': tabIndex.value,
      },
    );
    // IndexedStack keeps Scan mounted — leave camera off until that tab is open.
    _scheduleSyncScanCamera(tabIndex.value);
    unawaited(settleShell());
  }

  @override
  void onClose() {
    _shellSettleDelay?.cancel();
    _shellSettleDelay = null;
    final pending = _shellSettleDelayCompleter;
    _shellSettleDelayCompleter = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
    _shellSettleInFlight = false;
    super.onClose();
  }

  /// Wait for Home to mount, then quiet sequential sync (no API stampede).
  Future<void> settleShell({bool force = false}) async {
    // TEMPORARY — HOME_STUCK_DEBUG
    HomeStuckDebug.log(
      'settleShell START',
      {
        'force': force,
        'shellReadyBefore': shellReady.value,
        'settleInFlight': _shellSettleInFlight,
      },
    );
    if (!force && shellReady.value) {
      HomeStuckDebug.log('settleShell SKIP alreadyReady');
      return;
    }
    if (_shellSettleInFlight && !force) {
      HomeStuckDebug.log('settleShell SKIP alreadyInFlight');
      return;
    }

    _shellSettleInFlight = true;
    if (force) {
      _setShellReady(false, reason: 'settleShell(force)');
    }

    try {
      // Let IndexedStack + Dashboard build first.
      await SchedulerBinding.instance.endOfFrame;
      if (isClosed) return;
      final delay = Completer<void>();
      _shellSettleDelayCompleter = delay;
      _shellSettleDelay?.cancel();
      _shellSettleDelay = Timer(const Duration(milliseconds: 200), () {
        if (!delay.isCompleted) delay.complete();
      });
      await delay.future;
      _shellSettleDelay = null;
      _shellSettleDelayCompleter = null;
      if (isClosed) return;

      // Home is usable immediately; sync runs quietly in the background.
      _setShellReady(true, reason: 'settleShell painted');
      if (_canHydrateHome) {
        appLog('MainController: settleShell hydrate force=$force');
        // TEMPORARY — HOME_STUCK_DEBUG
        HomeStuckDebug.log(
          'settleShell hydrate',
          {'force': force, 'canHydrate': true},
        );
        unawaited(HomeHydrate.run(force: force));
      } else {
        appLog(
          'MainController: settleShell SKIP hydrate '
          '(signedOut/loggingOut) force=$force',
        );
        // TEMPORARY — HOME_STUCK_DEBUG
        HomeStuckDebug.log(
          'settleShell SKIP hydrate',
          {'force': force, 'canHydrate': false},
        );
      }
    } finally {
      _shellSettleInFlight = false;
      if (!isClosed && !shellReady.value) {
        _setShellReady(true, reason: 'settleShell finally');
      }
      // TEMPORARY — HOME_STUCK_DEBUG
      HomeStuckDebug.log(
        'settleShell END',
        {'shellReady': shellReady.value, 'force': force},
      );
    }
  }

  bool get _canHydrateHome {
    if (!Get.isRegistered<UserController>()) return false;
    final user = Get.find<UserController>();
    return user.isLoggedIn &&
        user.accessToken.isNotEmpty &&
        !user.isLoggingOut &&
        !user.isDeletingAccount;
  }

  void changeTab(int index) {
    if (_sessionBusy) return;
    if (!shellReady.value && index != homeTabIndex) {
      // TEMPORARY — HOME_STUCK_DEBUG
      HomeStuckDebug.log(
        'SNACKBAR Just a moment — finishing your home setup…',
        {
          'fromTab': tabIndex.value,
          'toTab': index,
          'shellReady': shellReady.value,
        },
      );
      AppSnackbar.info('Just a moment — finishing your home setup…');
      return;
    }
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

  /// Reset to Home tab. [hydrate] starts a forced [HomeHydrate] when logged in.
  /// Pass `false` on logout/delete so we do not fire API calls while signed out
  /// (that race previously doubled hydrate after quick re-login).
  static void resetHomeTabIfRegistered({bool hydrate = true}) {
    if (!Get.isRegistered<MainController>()) {
      // TEMPORARY — HOME_STUCK_DEBUG
      HomeStuckDebug.log(
        'resetHomeTabIfRegistered SKIP notRegistered',
        {'hydrate': hydrate},
      );
      return;
    }
    final main = Get.find<MainController>();
    main.resetToHomeTab();
    appLog('MainController: resetHomeTab hydrate=$hydrate');
    // TEMPORARY — HOME_STUCK_DEBUG
    HomeStuckDebug.log(
      'resetHomeTabIfRegistered',
      {
        'hydrate': hydrate,
        'shellReady': main.shellReady.value,
      },
    );
    if (!hydrate) return;
    unawaited(main.settleShell(force: true));
  }

  void clearShellReady() {
    // TEMPORARY — HOME_STUCK_DEBUG
    HomeStuckDebug.log(
      'clearShellReady CALL',
      {'shellReadyBefore': shellReady.value},
    );
    _setShellReady(false, reason: 'clearShellReady');
    _shellSettleInFlight = false;
  }

  /// TEMPORARY — HOME_STUCK_DEBUG — centralize shellReady transitions.
  void _setShellReady(bool value, {required String reason}) {
    final prev = shellReady.value;
    if (prev == value) {
      shellReady.value = value;
      return;
    }
    shellReady.value = value;
    HomeStuckDebug.log(
      'shellReady ${prev ? 'true' : 'false'} → ${value ? 'true' : 'false'}',
      {'reason': reason},
    );
  }

  bool get _sessionBusy {
    if (!Get.isRegistered<UserController>()) return false;
    final user = Get.find<UserController>();
    return user.isSessionBusy.value ||
        user.isLoggingOut ||
        user.isDeletingAccount;
  }
}
