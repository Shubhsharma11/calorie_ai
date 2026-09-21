import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../controllers/food_controller.dart';
import '../controllers/notifications_controller.dart';
import '../controllers/nutrition_plan_controller.dart';
import '../controllers/rewards_controller.dart';
import '../controllers/tracker_controller.dart';
import '../controllers/user_controller.dart';
import '../models/meal_entry.dart';
import '../services/api_client.dart';
import 'app_log.dart';
import 'home_stuck_debug.dart'; // TEMPORARY — HOME_STUCK_DEBUG

/// Single quiet home sync — like other production apps.
///
/// Controllers must not stampede the API from [onInit]. [MainController]
/// calls [run] after the first frame so Home paints first, then syncs.
///
/// Concurrency rules:
/// - [resetSession] bumps [_generation] so stale work exits at the next check.
/// - It must NOT null [_inFlight] (that allowed overlapping cascades).
/// - [run] `(force: true)` waits for any previous cascade to finish aborting
///   before starting network work — generation checks alone only run *after*
///   an await, so a mid-flight HTTP call would otherwise overlap the next login.
class HomeHydrate {
  HomeHydrate._();

  static Future<void>? _inFlight;
  static int? _inFlightGeneration;
  static Future<void>? _secondaryInFlight;
  static int _generation = 0;
  static bool _completedThisSession = false;
  static bool _bootstrapQuiet = false;

  /// Cascades currently inside the network section (must stay ≤ 1).
  static int _activeNetworkCascades = 0;

  /// Cancelable pre-network paint delay so [resetSession] / logout do not leave
  /// a pending timer (and so abort is immediate, not after 400ms).
  static Timer? _paintDelayTimer;
  static Completer<void>? _paintDelayCompleter;

  /// Controllers skip their own onInit network when this is true.
  static bool get ownsBootstrap => true;

  /// True while the primary sequential sync is running (skip side POSTs / FCM).
  static bool get isBootstrapQuiet => _bootstrapQuiet;

  static bool get completedThisSession => _completedThisSession;

  @visibleForTesting
  static int get debugGeneration => _generation;

  /// TEMPORARY — HOME_STUCK_DEBUG — remove with home_stuck_debug.dart
  static int get stuckDebugGeneration => _generation;

  @visibleForTesting
  static int get debugActiveNetworkCascades => _activeNetworkCascades;

  @visibleForTesting
  static Future<void>? get debugInFlight => _inFlight;

  @visibleForTesting
  static Future<void>? get debugSecondaryInFlight => _secondaryInFlight;

  /// Test hook: when set, [_run] / [refresh] delegate to this instead of real API work.
  @visibleForTesting
  static Future<void> Function(int gen)? debugRunOverride;

  @visibleForTesting
  static void debugReset() {
    _cancelPaintDelay();
    _inFlight = null;
    _inFlightGeneration = null;
    _secondaryInFlight = null;
    _generation = 0;
    _completedThisSession = false;
    _bootstrapQuiet = false;
    _activeNetworkCascades = 0;
    debugRunOverride = null;
  }

  static void resetSession() {
    final prev = _generation;
    _generation++;
    _completedThisSession = false;
    _bootstrapQuiet = false;
    _cancelPaintDelay();
    appLog(
      'HomeHydrate: resetSession gen $prev → $_generation '
      '(inFlight=${_inFlight != null} activeNet=$_activeNetworkCascades)',
    );
    // TEMPORARY — HOME_STUCK_DEBUG
    HomeStuckDebug.log(
      'HomeHydrate.resetSession',
      {
        'genBefore': prev,
        'genAfter': _generation,
        'inFlight': _inFlight != null,
        'activeNet': _activeNetworkCascades,
      },
    );
    // Keep [_inFlight] — the old run will see a generation mismatch and exit.
  }

  static void _cancelPaintDelay() {
    _paintDelayTimer?.cancel();
    _paintDelayTimer = null;
    final pending = _paintDelayCompleter;
    _paintDelayCompleter = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
  }

  static Future<void> run({bool force = false}) {
    if (!force && _completedThisSession) {
      appLog('HomeHydrate: run skipped (already completed this session)');
      HomeStuckDebug.log('HomeHydrate.run SKIP completedThisSession');
      return Future.value();
    }
    if (_inFlight != null && !force) {
      appLog(
        'HomeHydrate: run joined in-flight gen=$_inFlightGeneration',
      );
      HomeStuckDebug.log(
        'HomeHydrate.run JOIN',
        {'gen': _inFlightGeneration, 'force': force},
      );
      return _inFlight!;
    }

    // Capture previous *before* claiming the slot so force can await abort.
    final previous = force ? _inFlight : null;
    final previousGen = force ? _inFlightGeneration : null;

    if (force) {
      final prev = _generation;
      _generation++;
      _completedThisSession = false;
      _bootstrapQuiet = false;
      appLog(
        'HomeHydrate: run(force) gen $prev → $_generation '
        '(waitingOnPrev=${previous != null} prevGen=$previousGen)',
      );
      // TEMPORARY — HOME_STUCK_DEBUG
      HomeStuckDebug.log(
        'HomeHydrate.generation change',
        {
          'from': prev,
          'to': _generation,
          'reason': 'run(force)',
        },
      );
    }

    final gen = _generation;
    // TEMPORARY — HOME_STUCK_DEBUG
    HomeStuckDebug.log(
      'HomeHydrate.run START',
      {'gen': gen, 'force': force, 'waitingOnPrev': previous != null},
    );
    late final Future<void> started;
    started = () async {
      if (previous != null) {
        appLog(
          'HomeHydrate: gen=$gen waiting for prev gen=$previousGen to abort',
        );
        try {
          await previous;
        } catch (_) {
          // Previous cascade errors must not block the new session.
        }
        if (!_isCurrent(gen)) {
          appLog('HomeHydrate: gen=$gen superseded while waiting — abort');
          HomeStuckDebug.log(
            'HomeHydrate.run ABORT supersededWhileWaiting',
            {'gen': gen},
          );
          return;
        }
        appLog('HomeHydrate: gen=$gen previous aborted; starting cascade');
      }
      await _run(gen);
    }();

    _inFlight = started;
    _inFlightGeneration = gen;
    started.whenComplete(() {
      if (_inFlightGeneration == gen) {
        _inFlight = null;
        _inFlightGeneration = null;
        appLog('HomeHydrate: gen=$gen cleared in-flight slot');
      } else {
        appLog(
          'HomeHydrate: gen=$gen finished but slot owned by '
          'gen=$_inFlightGeneration — leave slot',
        );
      }
      // TEMPORARY — HOME_STUCK_DEBUG
      HomeStuckDebug.log(
        'HomeHydrate.run FINISH',
        {
          'gen': gen,
          'stillCurrent': _isCurrent(gen),
          'slotOwner': _inFlightGeneration,
        },
      );
    });
    return started;
  }

  /// Coordinated Home pull-to-refresh / explicit refresh.
  ///
  /// Joins any in-flight primary cascade or secondary tail rather than starting
  /// a competing Home API storm. When idle, re-runs primary Home data only —
  /// never kicks off secondary (yesterday claimable, history, etc.).
  static Future<void> refresh() {
    if (_inFlight != null) {
      appLog(
        'HomeHydrate: refresh joined in-flight gen=$_inFlightGeneration',
      );
      HomeStuckDebug.log(
        'HomeHydrate.refresh JOIN primary',
        {'gen': _inFlightGeneration},
      );
      return _inFlight!;
    }
    if (_secondaryInFlight != null) {
      appLog('HomeHydrate: refresh joined secondary tail');
      HomeStuckDebug.log('HomeHydrate.refresh JOIN secondary');
      return _secondaryInFlight!;
    }

    final gen = _generation;
    HomeStuckDebug.log('HomeHydrate.refresh START', {'gen': gen});
    late final Future<void> started;
    started = () async {
      final override = debugRunOverride;
      if (override != null) {
        await _enterNetwork(gen, () => override(gen));
        return;
      }

      await _waitOutRateLimit();
      if (!_isCurrent(gen)) {
        appLog('HomeHydrate: refresh gen=$gen aborted after rate-limit wait');
        return;
      }

      if (!Get.isRegistered<UserController>()) {
        appLog('HomeHydrate: refresh gen=$gen abort — UserController missing');
        return;
      }
      final user = Get.find<UserController>();
      if (!user.isLoggedIn || user.accessToken.isEmpty) {
        appLog('HomeHydrate: refresh gen=$gen abort — not signed in');
        HomeStuckDebug.log(
          'HomeHydrate.refresh ABORT notSignedIn',
          {'gen': gen},
        );
        return;
      }

      await _enterNetwork(
        gen,
        () => _syncPrimary(gen, user, runSecondary: false),
      );
    }();

    _inFlight = started;
    _inFlightGeneration = gen;
    started.whenComplete(() {
      if (_inFlightGeneration == gen) {
        _inFlight = null;
        _inFlightGeneration = null;
        appLog('HomeHydrate: refresh gen=$gen cleared in-flight slot');
      }
      HomeStuckDebug.log(
        'HomeHydrate.refresh FINISH',
        {'gen': gen, 'stillCurrent': _isCurrent(gen)},
      );
    });
    return started;
  }

  static bool _isCurrent(int gen) => gen == _generation;

  static Future<void> _run(int gen) async {
    final override = debugRunOverride;
    if (override != null) {
      await _enterNetwork(gen, () => override(gen));
      return;
    }

    // Let Home paint first.
    appLog('HomeHydrate: gen=$gen paint delay 400ms');
    final delay = Completer<void>();
    _paintDelayCompleter = delay;
    _paintDelayTimer?.cancel();
    _paintDelayTimer = Timer(const Duration(milliseconds: 400), () {
      if (!delay.isCompleted) delay.complete();
    });
    await delay.future;
    if (_paintDelayCompleter == delay) {
      _paintDelayCompleter = null;
      _paintDelayTimer = null;
    }
    if (!_isCurrent(gen)) {
      appLog('HomeHydrate: gen=$gen aborted after paint delay');
      return;
    }

    await _waitOutRateLimit();
    if (!_isCurrent(gen)) {
      appLog('HomeHydrate: gen=$gen aborted after rate-limit wait');
      return;
    }

    if (!Get.isRegistered<UserController>()) {
      appLog('HomeHydrate: gen=$gen abort — UserController missing');
      return;
    }
    final user = Get.find<UserController>();
    if (!user.isLoggedIn || user.accessToken.isEmpty) {
      appLog('HomeHydrate: gen=$gen abort — not signed in');
      return;
    }

    await _enterNetwork(
      gen,
      () => _syncPrimary(gen, user, runSecondary: true),
    );
  }

  static Future<void> _enterNetwork(
    int gen,
    Future<void> Function() body,
  ) async {
    if (!_isCurrent(gen)) {
      appLog('HomeHydrate: gen=$gen abort before network');
      return;
    }

    _activeNetworkCascades++;
    if (_activeNetworkCascades > 1) {
      appLog(
        'HomeHydrate: BUG concurrent network cascades='
        '$_activeNetworkCascades gen=$gen',
      );
    }
    _bootstrapQuiet = true;
    appLog(
      'HomeHydrate: gen=$gen NETWORK START '
      '(activeNet=$_activeNetworkCascades)',
    );

    try {
      await body();
    } finally {
      if (_isCurrent(gen)) {
        _bootstrapQuiet = false;
      }
      _activeNetworkCascades =
          (_activeNetworkCascades - 1).clamp(0, 1 << 30);
      appLog(
        'HomeHydrate: gen=$gen NETWORK END '
        '(activeNet=$_activeNetworkCascades current=${_isCurrent(gen)})',
      );
    }
  }

  static Future<void> _syncPrimary(
    int gen,
    UserController user, {
    required bool runSecondary,
  }) async {
    appLog(
      'HomeHydrate: gen=$gen primary sync begin '
      '(secondary=$runSecondary)',
    );

    // TEMPORARY — HOME_STUCK_DEBUG helper (behavior unchanged: rethrow)
    Future<void> step(String name, Future<void> Function() body) async {
      HomeStuckDebug.log('HomeHydrate.step START', {'gen': gen, 'step': name});
      try {
        await body();
        HomeStuckDebug.log(
          'HomeHydrate.step SUCCESS',
          {'gen': gen, 'step': name, 'stillCurrent': _isCurrent(gen)},
        );
      } catch (error) {
        HomeStuckDebug.log(
          'HomeHydrate.step FAIL',
          {
            'gen': gen,
            'step': name,
            'errorType': error.runtimeType.toString(),
          },
        );
        rethrow;
      }
    }

    // 1) Profile
    appLog('HomeHydrate: gen=$gen step=profile');
    await step('profile', () => user.fetchProfile(refreshGoalTarget: false));
    if (!_isCurrent(gen)) {
      appLog('HomeHydrate: gen=$gen aborted after profile');
      return;
    }
    if (ApiClient.isRateLimited) {
      appLog('HomeHydrate: gen=$gen stopped after profile (rate-limited)');
      HomeStuckDebug.log(
        'HomeHydrate STOP rateLimited',
        {'gen': gen, 'after': 'profile'},
      );
      return;
    }

    // 2) Wallet + today’s claimable
    if (Get.isRegistered<RewardsController>()) {
      final rewards = Get.find<RewardsController>();
      appLog('HomeHydrate: gen=$gen step=wallet');
      await step(
        'wallet',
        () => rewards.refreshWalletFromApi(retryOnRateLimit: true),
      );
      if (!_isCurrent(gen)) return;
      if (ApiClient.isRateLimited) return;
      appLog('HomeHydrate: gen=$gen step=claimable_today');
      await step(
        'claimable_today',
        () => rewards.refreshClaimableFromApi(includeYesterday: false),
      );
      if (!_isCurrent(gen)) return;
    }

    if (ApiClient.isRateLimited) return;

    // 3) Today’s meals
    if (Get.isRegistered<FoodController>()) {
      appLog('HomeHydrate: gen=$gen step=meals');
      await step(
        'meals',
        () => Get.find<FoodController>().refreshMealsFromApi(),
      );
      if (!_isCurrent(gen)) return;
    }

    if (ApiClient.isRateLimited) return;

    // 4) Water + steps (today only; no steps POST during bootstrap)
    if (Get.isRegistered<TrackerController>()) {
      final tracker = Get.find<TrackerController>();
      final today = MealEntry.normalizeDate(DateTime.now());
      appLog('HomeHydrate: gen=$gen step=water_today');
      await step('water_today', () => tracker.refreshWaterForDate(today));
      if (!_isCurrent(gen)) return;
      if (ApiClient.isRateLimited) return;
      appLog('HomeHydrate: gen=$gen step=steps_today (no POST)');
      await step(
        'steps_today',
        () => tracker.refreshStepsFromApi(allowSyncPush: false),
      );
      if (!_isCurrent(gen)) return;
    }

    if (ApiClient.isRateLimited) return;

    // 5) Nutrition plan if missing
    if (Get.isRegistered<NutritionPlanController>()) {
      final nutrition = Get.find<NutritionPlanController>();
      if (nutrition.plan.value == null) {
        appLog('HomeHydrate: gen=$gen step=nutrition_plan');
        await step('nutrition_plan', nutrition.loadPlan);
        if (!_isCurrent(gen)) return;
      } else {
        appLog('HomeHydrate: gen=$gen step=nutrition_plan skipped (cached)');
        HomeStuckDebug.log(
          'HomeHydrate.step SKIP',
          {'gen': gen, 'step': 'nutrition_plan', 'reason': 'cached'},
        );
      }
    }

    if (!_isCurrent(gen)) return;
    _completedThisSession = true;
    appLog('HomeHydrate: gen=$gen primary sync COMPLETE');
    HomeStuckDebug.log('HomeHydrate.primary COMPLETE', {'gen': gen});

    if (runSecondary) {
      _startSecondary(gen);
    }
  }

  static void _startSecondary(int gen) {
    final work = _secondary(gen);
    _secondaryInFlight = work;
    work.whenComplete(() {
      if (identical(_secondaryInFlight, work)) {
        _secondaryInFlight = null;
        appLog('HomeHydrate: gen=$gen cleared secondary slot');
      }
    });
  }

  static Future<void> _secondary(int gen) async {
    appLog('HomeHydrate: gen=$gen secondary delay 3s');
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!_isCurrent(gen)) {
      appLog('HomeHydrate: gen=$gen secondary aborted after delay');
      return;
    }
    if (ApiClient.isRateLimited) {
      appLog('HomeHydrate: gen=$gen secondary skipped (rate-limited)');
      return;
    }

    if (Get.isRegistered<RewardsController>()) {
      appLog('HomeHydrate: gen=$gen secondary=claimable_yesterday');
      await Get.find<RewardsController>().refreshClaimableForDate(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      if (!_isCurrent(gen)) return;
    }
    if (ApiClient.isRateLimited) return;

    if (Get.isRegistered<TrackerController>()) {
      final tracker = Get.find<TrackerController>();
      appLog('HomeHydrate: gen=$gen secondary=water_history');
      await tracker.refreshWaterHistory();
      if (!_isCurrent(gen)) return;
      if (ApiClient.isRateLimited) return;
      appLog('HomeHydrate: gen=$gen secondary=weight');
      await tracker.refreshWeightFromApi();
      if (!_isCurrent(gen)) return;
    }
    if (ApiClient.isRateLimited) return;

    if (Get.isRegistered<FoodController>()) {
      appLog('HomeHydrate: gen=$gen secondary=last_logged_meals');
      await Get.find<FoodController>().ensureLastLoggedMealsLoaded();
      if (!_isCurrent(gen)) return;
    }
    if (ApiClient.isRateLimited) return;

    if (Get.isRegistered<NotificationsController>()) {
      appLog('HomeHydrate: gen=$gen secondary=unread_count');
      await Get.find<NotificationsController>().refreshUnreadCount();
    }
    appLog('HomeHydrate: gen=$gen secondary COMPLETE');
  }

  static Future<void> _waitOutRateLimit() async {
    if (!ApiClient.isRateLimited) return;
    final until = ApiClient.rateLimitedUntil ??
        DateTime.now().add(const Duration(seconds: 90));
    final wait = until.difference(DateTime.now()) + const Duration(seconds: 1);
    appLog(
      'HomeHydrate: waiting ${wait.inSeconds.clamp(1, 120)}s for rate-limit',
    );
    // TEMPORARY — HOME_STUCK_DEBUG
    HomeStuckDebug.log(
      'HomeHydrate.waitOutRateLimit',
      {'waitSeconds': wait.inSeconds},
    );
    await Future<void>.delayed(
      wait.isNegative ? const Duration(seconds: 2) : wait,
    );
  }
}
