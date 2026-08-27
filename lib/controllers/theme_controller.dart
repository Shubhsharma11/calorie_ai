import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';

class ThemeController extends GetxController with WidgetsBindingObserver {
  static const _themeModeKey = 'theme_mode';

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final Rx<Brightness> platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness.obs;

  /// Last brightness applied to the shell / Settings local Theme.
  final Rx<Brightness> appliedBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness.obs;

  /// Settings (etc.) is open — covered tabs stay frozen via [MainView].
  int _localThemeOverlayDepth = 0;
  bool _publishScheduled = false;
  bool _themeModeSyncScheduled = false;

  bool get isLocalThemeOverlayActive => _localThemeOverlayDepth > 0;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    appliedBrightness.value = effectiveBrightness;
  }

  @override
  void onReady() {
    super.onReady();
    // GetMaterialApp is mounted — push stored mode into the shell ThemeMode.
    _syncGetMaterialThemeMode();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  /// Call from Settings (and similar) while the page is visible.
  void beginLocalThemeOverlay() {
    _localThemeOverlayDepth++;
    if (_localThemeOverlayDepth == 1) {
      AppColors.setOverlayBrightnessResolver(() => effectiveBrightness);
    }
  }

  /// Re-sync root Theme when the overlay closes (usually already current).
  void endLocalThemeOverlay() {
    if (_localThemeOverlayDepth > 0) {
      _localThemeOverlayDepth--;
    }
    if (_localThemeOverlayDepth == 0) {
      AppColors.setOverlayBrightnessResolver(null);
      _publishAppliedBrightness();
      AppColors.syncWithBrightness(effectiveBrightness);
      // Always defer — Settings dispose runs while Flutter is finalizing the
      // tree; sync Get.changeThemeMode then crashes GetMaterialController.
      _syncGetMaterialThemeMode(forceDefer: true);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!isClosed) update();
      });
    }
  }

  @override
  void didChangePlatformBrightness() {
    platformBrightness.value =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (themeMode.value != ThemeMode.system) return;
    AppColors.syncWithBrightness(effectiveBrightness);
    _publishAppliedBrightness();
    _syncGetMaterialThemeMode();
    _safeUpdate();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themeModeKey);
    if (stored == null) {
      _publishAppliedBrightness();
      AppColors.syncWithBrightness(effectiveBrightness);
      _syncGetMaterialThemeMode();
      _safeUpdate();
      return;
    }

    final mode = ThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => ThemeMode.system,
    );
    _applyMode(mode, persist: false);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode.value == mode) return;
    _applyMode(mode, persist: true);
  }

  Future<void> toggleDarkMode(bool enabled) async {
    await setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }

  void _applyMode(ThemeMode mode, {required bool persist}) {
    themeMode.value = mode;
    AppColors.syncWithBrightness(effectiveBrightness);
    _publishAppliedBrightness();
    _syncGetMaterialThemeMode();
    // Rebuild GetBuilder listeners (Settings) without Obx wrapping Theme.
    _safeUpdate();

    if (persist) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        unawaited(_persistMode(mode));
      });
    }
  }

  /// Push ThemeMode into GetMaterialApp without setState during a locked tree.
  void _syncGetMaterialThemeMode({bool forceDefer = false}) {
    void apply() {
      _themeModeSyncScheduled = false;
      if (isClosed) return;
      if (!Get.isRegistered<GetMaterialController>()) return;
      Get.changeThemeMode(themeMode.value);
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    final canApplyNow = !forceDefer &&
        (phase == SchedulerPhase.idle ||
            phase == SchedulerPhase.postFrameCallbacks);

    if (canApplyNow) {
      apply();
      return;
    }
    if (_themeModeSyncScheduled) return;
    _themeModeSyncScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) => apply());
  }

  void _safeUpdate() {
    if (isClosed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      update();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!isClosed) update();
    });
  }

  /// Publish after the current frame so no Obx/Theme rebuild races DefaultTextStyle.
  void _publishAppliedBrightness() {
    if (appliedBrightness.value == effectiveBrightness) return;
    if (_publishScheduled) return;
    _publishScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _publishScheduled = false;
      if (isClosed) return;
      final brightness = effectiveBrightness;
      if (appliedBrightness.value != brightness) {
        appliedBrightness.value = brightness;
      }
    });
  }

  Future<void> _persistMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  bool get isSystemMode => themeMode.value == ThemeMode.system;

  Brightness get effectiveBrightness {
    return switch (themeMode.value) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system => platformBrightness.value,
    };
  }

  bool get isDarkMode => effectiveBrightness == Brightness.dark;
}
