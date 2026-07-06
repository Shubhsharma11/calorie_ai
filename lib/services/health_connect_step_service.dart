import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

/// Reads daily step counts from [Health Connect](https://developer.android.com/health-and-fitness/health-connect) on Android.
class HealthConnectStepService {
  HealthConnectStepService({Health? health}) : _health = health ?? Health();

  static const _types = [HealthDataType.STEPS];
  static const _permissions = [HealthDataAccess.READ];

  final Health _health;
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<HealthConnectSdkStatus?> sdkStatus() async {
    if (!isSupported) return null;
    await _ensureConfigured();
    return _health.getHealthConnectSdkStatus();
  }

  Future<bool> isAvailable() async {
    if (!isSupported) return false;
    await _ensureConfigured();
    return _health.isHealthConnectAvailable();
  }

  Future<void> install() async {
    if (!isSupported) return;
    await _ensureConfigured();
    await _health.installHealthConnect();
  }

  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    await _ensureConfigured();
    return await _health.hasPermissions(_types, permissions: _permissions) ??
        false;
  }

  Future<bool> requestPermission() async {
    if (!isSupported) return false;

    if (Platform.isAndroid) {
      final activityStatus = await Permission.activityRecognition.request();
      if (!activityStatus.isGranted) return false;
    }

    await _ensureConfigured();
    return _health.requestAuthorization(_types, permissions: _permissions);
  }

  Future<int?> todaySteps() async {
    if (!isSupported) return null;
    await _ensureConfigured();

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return _health.getTotalStepsInInterval(start, now);
  }
}
