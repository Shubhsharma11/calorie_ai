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

  /// Root [Theme] brightness driven by [themeMode] / device brightness.
  final Rx<Brightness> appliedBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness.obs;

  /// Settings (etc.) is open — covered tabs stay frozen via [MainView].
  int _localThemeOverlayDepth = 0;

  bool get isLocalThemeOverlayActive => _localThemeOverlayDepth > 0;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    appliedBrightness.value = effectiveBrightness;
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
    }
  }

  @override
  void didChangePlatformBrightness() {
    platformBrightness.value =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (themeMode.value != ThemeMode.system) return;
    AppColors.syncWithBrightness(effectiveBrightness);
    _publishAppliedBrightness();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themeModeKey);
    if (stored == null) {
      _publishAppliedBrightness();
      AppColors.syncWithBrightness(effectiveBrightness);
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
    Get.rootController.themeMode = mode;
    // Always publish — deferring left Settings on a dark paint while the shell
    // Theme stayed light, so MainView.syncFromContext wiped Dark Mode back.
    _publishAppliedBrightness();

    if (persist) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        unawaited(_persistMode(mode));
      });
    }
  }

  void _publishAppliedBrightness() {
    final brightness = effectiveBrightness;
    if (appliedBrightness.value != brightness) {
      appliedBrightness.value = brightness;
    }
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
