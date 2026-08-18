import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/android_sdk.dart';

/// Reads daily step counts from Health Connect on Android 13+.
class HealthConnectStepService {
  HealthConnectStepService({Health? health}) : _health = health ?? Health();

  static const _types = [HealthDataType.STEPS];
  static const _permissions = [HealthDataAccess.READ];

  final Health _health;
  bool _configured = false;

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Health Connect is not installable on Android 12 and below.
  Future<bool> isOsSupported() async {
    if (!isSupported) return false;
    final sdk = await readAndroidSdkInt();
    return sdk != null && sdk >= androidHealthConnectMinSdk;
  }

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<HealthConnectSdkStatus?> sdkStatus() async {
    if (!await isOsSupported()) {
      return HealthConnectSdkStatus.sdkUnavailable;
    }
    try {
      await _ensureConfigured();
      return _health.getHealthConnectSdkStatus();
    } catch (error) {
      debugPrint('HealthConnectStepService.sdkStatus: $error');
      return HealthConnectSdkStatus.sdkUnavailable;
    }
  }

  Future<bool> isAvailable() async {
    if (!await isOsSupported()) return false;
    try {
      await _ensureConfigured();
      return _health.isHealthConnectAvailable();
    } catch (error) {
      debugPrint('HealthConnectStepService.isAvailable: $error');
      return false;
    }
  }

  Future<void> install() async {
    if (!await isOsSupported()) return;
    try {
      await _ensureConfigured();
      await _health.installHealthConnect();
    } catch (error) {
      debugPrint('HealthConnectStepService.install: $error');
    }
  }

  Future<bool> hasPermission() async {
    if (!await isOsSupported()) return false;
    try {
      await _ensureConfigured();
      return await _health.hasPermissions(_types, permissions: _permissions) ??
          false;
    } catch (error) {
      debugPrint('HealthConnectStepService.hasPermission: $error');
      return false;
    }
  }

  Future<bool> requestPermission() async {
    if (!await isOsSupported()) return false;

    if (Platform.isAndroid) {
      final activityStatus = await Permission.activityRecognition.request();
      if (!activityStatus.isGranted) return false;
    }

    try {
      await _ensureConfigured();
      return _health.requestAuthorization(_types, permissions: _permissions);
    } catch (error) {
      debugPrint('HealthConnectStepService.requestPermission: $error');
      return false;
    }
  }

  Future<int?> todaySteps() async {
    if (!await isOsSupported()) return null;
    try {
      await _ensureConfigured();
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      return _health.getTotalStepsInInterval(start, now);
    } catch (error) {
      debugPrint('HealthConnectStepService.todaySteps: $error');
      return null;
    }
  }
}
