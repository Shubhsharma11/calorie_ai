import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import 'health_connect_step_service.dart';

enum StepTrackingBackend { none, healthConnect, pedometer }

/// Reads step data from Health Connect on Android, with pedometer fallback.
class StepTrackingService {
  StepTrackingService({HealthConnectStepService? healthConnect})
    : _healthConnect = healthConnect ?? HealthConnectStepService();

  final HealthConnectStepService _healthConnect;

  StreamSubscription<StepCount>? _pedometerSubscription;
  Timer? _healthPollTimer;
  bool _isListening = false;
  StepTrackingBackend _backend = StepTrackingBackend.none;

  bool get isListening => _isListening;
  StepTrackingBackend get backend => _backend;
  int? _lastRawSteps;
  int? get lastRawSteps => _lastRawSteps;

  bool get usesHealthConnect => _backend == StepTrackingBackend.healthConnect;

  Future<bool> isHealthConnectAvailable() => _healthConnect.isAvailable();

  Future<void> installHealthConnect() => _healthConnect.install();

  Future<bool> hasPermission() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid && await _healthConnect.isAvailable()) {
      return _healthConnect.hasPermission();
    }
    if (Platform.isAndroid) {
      return Permission.activityRecognition.isGranted;
    }
    return true;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid && await _healthConnect.isAvailable()) {
      return _healthConnect.requestPermission();
    }
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.request();
      return status.isGranted;
    }
    return true;
  }

  Future<void> start({
    required String todayKey,
    required Map<String, int> baselinesByDate,
    required int savedStepsToday,
    required void Function(int dailySteps) onDailySteps,
    required void Function(Map<String, int> baselines) persistBaselines,
    void Function(String message)? onError,
    void Function(StepTrackingBackend backend)? onBackendChanged,
  }) async {
    if (kIsWeb) {
      onError?.call('Step tracking is not available on web.');
      return;
    }

    await stop();

    if (Platform.isAndroid) {
      final started = await _startHealthConnect(
        onDailySteps: onDailySteps,
        onError: onError,
        onBackendChanged: onBackendChanged,
      );
      if (started) return;
    }

    await _startPedometer(
      todayKey: todayKey,
      baselinesByDate: baselinesByDate,
      savedStepsToday: savedStepsToday,
      onDailySteps: onDailySteps,
      persistBaselines: persistBaselines,
      onError: onError,
      onBackendChanged: onBackendChanged,
    );
  }

  Future<bool> _startHealthConnect({
    required void Function(int dailySteps) onDailySteps,
    void Function(String message)? onError,
    void Function(StepTrackingBackend backend)? onBackendChanged,
  }) async {
    final status = await _healthConnect.sdkStatus();
    if (status == HealthConnectSdkStatus.sdkUnavailable) {
      onError?.call(
        'Install Health Connect to sync steps from your fitness apps.',
      );
      return false;
    }
    if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
      onError?.call('Update Health Connect to sync steps automatically.');
      return false;
    }
    if (!await _healthConnect.isAvailable()) {
      return false;
    }

    final granted =
        await _healthConnect.hasPermission() ||
        await _healthConnect.requestPermission();
    if (!granted) {
      onError?.call(
        'Allow Health Connect step access to track calories burned.',
      );
      return false;
    }

    Future<void> pollSteps() async {
      try {
        final steps = await _healthConnect.todaySteps();
        if (steps == null) return;
        onDailySteps(steps.clamp(0, 50000));
      } catch (error) {
        onError?.call('Could not read steps from Health Connect: $error');
      }
    }

    await pollSteps();

    _healthPollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(pollSteps()),
    );

    _isListening = true;
    _backend = StepTrackingBackend.healthConnect;
    onBackendChanged?.call(_backend);
    return true;
  }

  Future<void> _startPedometer({
    required String todayKey,
    required Map<String, int> baselinesByDate,
    required int savedStepsToday,
    required void Function(int dailySteps) onDailySteps,
    required void Function(Map<String, int> baselines) persistBaselines,
    void Function(String message)? onError,
    void Function(StepTrackingBackend backend)? onBackendChanged,
  }) async {
    final granted = await hasPermission() || await requestPermission();
    if (!granted) {
      onError?.call('Allow activity recognition to track steps automatically.');
      return;
    }

    try {
      final stream = Pedometer.stepCountStream;
      _pedometerSubscription = stream.listen(
        (event) {
          final raw = event.steps;
          _lastRawSteps = raw;

          var baseline = baselinesByDate[todayKey];
          if (baseline == null) {
            baseline = raw - savedStepsToday;
            baselinesByDate[todayKey] = baseline;
            persistBaselines(Map<String, int>.from(baselinesByDate));
          }

          final daily = (raw - baseline).clamp(0, 50000);
          onDailySteps(daily);
        },
        onError: (Object error) {
          onError?.call('Step sensor unavailable: $error');
        },
      );
      _isListening = true;
      _backend = StepTrackingBackend.pedometer;
      onBackendChanged?.call(_backend);
    } catch (error) {
      onError?.call('Could not start step tracking: $error');
      _isListening = false;
      _backend = StepTrackingBackend.none;
    }
  }

  Future<void> stop() async {
    await _pedometerSubscription?.cancel();
    _pedometerSubscription = null;
    _healthPollTimer?.cancel();
    _healthPollTimer = null;
    _isListening = false;
    _backend = StepTrackingBackend.none;
  }

  Future<void> dispose() async {
    await stop();
  }
}
