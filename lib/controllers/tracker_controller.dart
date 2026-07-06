import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/daily_water_intake.dart';
import '../models/exercise_entry.dart';
import '../models/exercise_type.dart';
import '../models/meal_entry.dart';
import '../models/water_period.dart';
import '../models/weight_entry.dart';
import '../repositories/weight_repository.dart';
import '../services/local_storage_service.dart';
import '../services/step_tracking_service.dart';
import '../services/weight_api_service.dart';
import '../widgets/water_goal_success_dialog.dart';
import 'user_controller.dart';

enum WeightLogStatus { unchanged, savedAndSynced, failed }

enum WeightDeleteStatus { deleted, failed, missingId }

class WeightDeleteOutcome {
  const WeightDeleteOutcome(
    this.status, {
    this.message,
  });

  final WeightDeleteStatus status;
  final String? message;
}

class WeightLogOutcome {
  const WeightLogOutcome(
    this.status, {
    this.profileUpdated = false,
  });

  final WeightLogStatus status;
  final bool profileUpdated;
}

class TrackerController extends GetxController {
  TrackerController({
    double? initialWeight,
    LocalStorageService? storage,
    StepTrackingService? stepTracking,
    WeightRepository? weightRepository,
  }) : _storage = storage ?? LocalStorageService(),
       _stepTracking = stepTracking ?? StepTrackingService(),
       _weightRepository = weightRepository ?? WeightRepository() {
    if (initialWeight != null) {
      currentWeight.value = initialWeight;
    }
  }

  final LocalStorageService _storage;
  final StepTrackingService _stepTracking;
  final WeightRepository _weightRepository;
  final RxMap<DateTime, int> waterByDate = <DateTime, int>{}.obs;
  final Rx<WaterPeriod> waterPeriod = WaterPeriod.week.obs;

  final RxDouble currentWeight = 70.0.obs;
  final RxList<WeightEntry> weightEntries = <WeightEntry>[].obs;
  final RxMap<DateTime, int> stepsByDate = <DateTime, int>{}.obs;
  final Map<String, int> _stepsBaselineByDate = {};
  final RxList<ExerciseEntry> exerciseEntries = <ExerciseEntry>[].obs;
  final RxInt activityRevision = 0.obs;
  final RxBool isStepTrackingActive = false.obs;
  final RxnString stepTrackingMessage = RxnString();
  final RxnString weightApiErrorMessage = RxnString();
  final RxBool isLoadingWeightApi = false.obs;
  final RxInt weightRevision = 0.obs;
  final RxBool needsHealthConnectInstall = false.obs;
  final RxBool usesHealthConnect = false.obs;

  static const int waterGoal = 8;
  static const int weightApiLimit = 30;
  static const int stepsGoal = 10000;

  bool _waterGoalCelebrationShown = false;

  DateTime get _today => MealEntry.normalizeDate(DateTime.now());

  List<double> get weightHistory =>
      weightEntries.map((entry) => entry.kg).toList();

  List<WeightEntry> get recentWeightEntries => weightEntries.toList();

  @override
  void onInit() {
    super.onInit();
    unawaited(_storage.clearWeightEntryLogs());
    unawaited(_loadWeightHistory());
    unawaited(_loadActivityLog());
  }

  @override
  void onClose() {
    unawaited(_stepTracking.dispose());
    super.onClose();
  }

  String get _todayKey => _today.toIso8601String().split('T').first;

  int get todaySteps => stepsForDate(_today);

  double get stepsProgress =>
      (todaySteps / stepsGoal).clamp(0.0, 1.0);

  bool get isStepsGoalComplete => todaySteps >= stepsGoal;

  int get stepsCalories => (todaySteps * 0.04).round();

  int get todayExerciseMinutes => todayExercises.fold(
    0,
    (sum, entry) => sum + entry.durationMinutes,
  );

  int get todayCaloriesBurned {
    final fromExercises = todayExercises.fold(
      0,
      (sum, entry) => sum + entry.calories,
    );
    final fromSteps = stepsCalories;
    return fromExercises + fromSteps;
  }

  List<ExerciseEntry> get todayExercises {
    final today = _today;
    return exerciseEntries
        .where((entry) => entry.normalizedDate == today)
        .toList();
  }

  int stepsForDate(DateTime date) =>
      stepsByDate[MealEntry.normalizeDate(date)] ?? 0;

  int get waterGlasses => waterForDate(_today);

  double get waterProgress => (waterGlasses / waterGoal).clamp(0.0, 1.0);

  bool get isWaterGoalComplete => waterGlasses >= waterGoal;

  int waterForDate(DateTime date) =>
      waterByDate[MealEntry.normalizeDate(date)] ?? 0;

  List<DailyWaterIntake> waterForLastDays(int dayCount) {
    final today = _today;
    return List.generate(dayCount, (index) {
      final day = today.subtract(Duration(days: dayCount - 1 - index));
      return DailyWaterIntake(date: day, glasses: waterForDate(day));
    });
  }

  List<DailyWaterIntake> get activeWaterDays => switch (waterPeriod.value) {
    WaterPeriod.today => [
      DailyWaterIntake(date: _today, glasses: waterGlasses),
    ],
    WaterPeriod.yesterday => [
      DailyWaterIntake(
        date: _today.subtract(const Duration(days: 1)),
        glasses: waterForDate(_today.subtract(const Duration(days: 1))),
      ),
    ],
    WaterPeriod.week => waterForLastDays(7),
    WaterPeriod.month => waterForLastDays(30),
  };

  void setWaterPeriod(WaterPeriod period) => waterPeriod.value = period;

  String periodLabelFor(WaterPeriod period) => switch (period) {
    WaterPeriod.today => 'Today',
    WaterPeriod.yesterday => 'Yesterday',
    WaterPeriod.week => '7 Days',
    WaterPeriod.month => '30 Days',
  };

  void addWater() {
    final today = _today;
    final current = waterForDate(today);
    if (current >= waterGoal) return;

    waterByDate[today] = current + 1;
    waterByDate.refresh();

    if (isWaterGoalComplete && !_waterGoalCelebrationShown) {
      _waterGoalCelebrationShown = true;
      WaterGoalSuccessDialog.show();
    }
  }

  void removeWater() {
    final today = _today;
    final current = waterForDate(today);
    if (current <= 0) return;

    final next = current - 1;
    if (next <= 0) {
      waterByDate.remove(today);
    } else {
      waterByDate[today] = next;
    }
    waterByDate.refresh();

    if (!isWaterGoalComplete) {
      _waterGoalCelebrationShown = false;
    }
  }

  Future<void> _loadWeightHistory() async {
    await refreshWeightFromApi();
    if (weightEntries.isEmpty) {
      _seedDisplayWeightFromProfile();
    }
  }

  Future<void> refreshWeightFromApi({
    bool keepExistingOnEmpty = false,
    List<WeightEntry> authoritativeEntries = const [],
  }) async {
    final accessToken = await _weightAccessToken();
    if (accessToken == null) {
      weightEntries.clear();
      _seedDisplayWeightFromProfile();
      return;
    }

    isLoadingWeightApi.value = true;
    weightApiErrorMessage.value = null;

    try {
      final fetched = await _weightRepository.fetchWeights(
        accessToken: accessToken,
        page: 1,
        limit: weightApiLimit,
      );

      if (fetched.isNotEmpty) {
        _applyWeightEntries(
          _mergeWeightEntries(fetched, authoritativeEntries),
        );
      } else if (keepExistingOnEmpty) {
        // Keep in-memory history when GET returns no rows right after POST.
      } else {
        weightEntries.clear();
        _seedDisplayWeightFromProfile();
      }
    } on WeightApiException catch (error) {
      debugPrint('TrackerController: weight API failed: $error');
      weightApiErrorMessage.value = error.message;
    } catch (error) {
      debugPrint('TrackerController: weight API failed: $error');
      weightApiErrorMessage.value =
          'Unable to load weight history. Please check your connection.';
    } finally {
      isLoadingWeightApi.value = false;
    }
  }

  void _seedDisplayWeightFromProfile() {
    if (!Get.isRegistered<UserController>()) return;

    final kg = Get.find<UserController>().user.weightKg.toDouble();
    if (kg > 0) {
      currentWeight.value = kg;
    }
  }

  void _applyWeightEntries(List<WeightEntry> entries) {
    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
    weightEntries.assignAll(sorted);
    currentWeight.value = _resolveDisplayWeight(sorted);
    weightRevision.value++;
    _syncProfileWeightFromEntries(sorted);
    debugPrint(
      'TrackerController: weight UI refreshed — '
      'current=${currentWeight.value}kg entries=${sorted.length} '
      'revision=${weightRevision.value}',
    );
  }

  static List<WeightEntry> _mergeWeightEntries(
    List<WeightEntry> base,
    List<WeightEntry> overrides,
  ) {
    if (overrides.isEmpty) return base;

    final byDay = <DateTime, WeightEntry>{};
    for (final entry in base) {
      byDay[MealEntry.normalizeDate(entry.date)] = entry;
    }
    for (final entry in overrides) {
      byDay[MealEntry.normalizeDate(entry.date)] = entry;
    }

    return byDay.values.toList()
      ..sort((left, right) => left.date.compareTo(right.date));
  }

  /// Keeps [UserModel.weightKg] aligned with weight API history after login/refresh.
  void _syncProfileWeightFromEntries(List<WeightEntry> entries) {
    if (entries.isEmpty || !Get.isRegistered<UserController>()) return;

    final kg = _resolveDisplayWeight(entries);
    if (kg <= 0) return;

    final userController = Get.find<UserController>();
    final rounded = kg.round();
    if (userController.user.weightKg == rounded) return;

    userController.user.weightKg = rounded;
    userController.update();
    debugPrint(
      'TrackerController: profile weight synced from API — $rounded kg',
    );
  }

  /// Prefers today's logged weight for the summary card; otherwise latest entry.
  double _resolveDisplayWeight(List<WeightEntry> entries) {
    if (entries.isEmpty) return currentWeight.value;

    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
    for (var index = sorted.length - 1; index >= 0; index--) {
      if (MealEntry.normalizeDate(sorted[index].date) == _today) {
        return sorted[index].kg;
      }
    }
    return sorted.last.kg;
  }

  WeightEntry _confirmedLogEntry(
    WeightEntry? fromApi, {
    required DateTime logDate,
    required double kg,
  }) {
    if (fromApi == null) {
      return WeightEntry(date: logDate, kg: kg);
    }

    return WeightEntry(
      id: fromApi.id,
      date: logDate,
      kg: kg,
    );
  }

  Future<String?> _weightAccessToken() async {
    if (!Get.isRegistered<UserController>()) {
      debugPrint(
        'TrackerController: MISSING token — UserController not registered '
        '(lib/controllers/tracker_controller.dart _weightAccessToken)',
      );
      return null;
    }

    final userController = Get.find<UserController>();
    final resolution = await userController.resolveAccessTokenWithDiagnostics();
    if (!resolution.isResolved) {
      debugPrint(
        'TrackerController: MISSING token — stage=${resolution.failureStage} '
        'at ${resolution.failureLocation}',
      );
      return null;
    }

    debugPrint(
      'TrackerController: bearer token ready '
      'source=${resolution.source} length=${resolution.tokenLength}',
    );
    return resolution.token;
  }

  Future<double> resolveWeightForDate(DateTime date, double fallback) async {
    final normalized = MealEntry.normalizeDate(date);
    for (final entry in weightEntries) {
      if (MealEntry.normalizeDate(entry.date) == normalized) {
        return entry.kg;
      }
    }

    final accessToken = await _weightAccessToken();
    if (accessToken == null) return fallback;

    try {
      final fetched = await _weightRepository.fetchWeights(
        accessToken: accessToken,
        date: normalized,
      );
      if (fetched.isNotEmpty) {
        final entry = fetched.last;
        _upsertWeightEntry(entry);
        return entry.kg;
      }
    } on WeightApiException catch (error) {
      debugPrint('TrackerController: weight lookup failed: $error');
    } catch (error) {
      debugPrint('TrackerController: weight lookup failed: $error');
    }

    return fallback;
  }

  void updateWeight(double kg) {
    currentWeight.value = kg;
    weightRevision.value++;
  }

  Future<WeightLogOutcome> logCurrentWeight({
    DateTime? date,
    double? weightKg,
  }) async {
    final kg = double.parse((weightKg ?? currentWeight.value).toStringAsFixed(1));
    final logDate = MealEntry.normalizeDate(date ?? DateTime.now());
    weightApiErrorMessage.value = null;

    final existingIndex = weightEntries.indexWhere(
      (entry) => MealEntry.normalizeDate(entry.date) == logDate,
    );
    if (existingIndex != -1 &&
        (weightEntries[existingIndex].kg - kg).abs() < 0.05) {
      return const WeightLogOutcome(WeightLogStatus.unchanged);
    }

    final accessToken = await _weightAccessToken();
    if (accessToken != null) {
      try {
        debugPrint(
          'TrackerController: POST /api/v1/weight starting '
          'weight=$kg date=${MealEntry.dateToKey(logDate)}',
        );
        final response = await _weightRepository.logWeight(
          accessToken: accessToken,
          weight: kg,
          weightUnit: 'kg',
          recordedAt: logDate,
        );

        final savedEntry = _confirmedLogEntry(
          response.entry,
          logDate: logDate,
          kg: kg,
        );
        _upsertWeightEntry(savedEntry);

        debugPrint('TrackerController: refreshing weight history from GET');
        await refreshWeightFromApi(
          keepExistingOnEmpty: true,
          authoritativeEntries: [savedEntry],
        );

        _syncLocalProfileAfterWeightLog(
          kg: kg,
          logDate: logDate,
          profileUpdatedOnServer: response.profileUpdated,
        );

        weightApiErrorMessage.value = null;
        weightRevision.value++;
        debugPrint(
          'TrackerController: weight log complete — '
          'current=${currentWeight.value}kg history=${weightEntries.length}',
        );
        return WeightLogOutcome(
          WeightLogStatus.savedAndSynced,
          profileUpdated: response.profileUpdated,
        );
      } on WeightApiException catch (error) {
        weightApiErrorMessage.value = error.message;
        return const WeightLogOutcome(WeightLogStatus.failed);
      } catch (_) {
        weightApiErrorMessage.value =
            'Weight could not be saved to the server.';
        return const WeightLogOutcome(WeightLogStatus.failed);
      }
    }

    weightApiErrorMessage.value =
        'Sign in to save weight to your account.';
    return const WeightLogOutcome(WeightLogStatus.failed);
  }

  void _syncLocalProfileAfterWeightLog({
    required double kg,
    required DateTime logDate,
    bool profileUpdatedOnServer = false,
  }) {
    if (logDate != _today || !Get.isRegistered<UserController>()) return;

    final userController = Get.find<UserController>();
    userController.user.weightKg = kg.round();
    userController.onProfileUpdated();
    if (!profileUpdatedOnServer) {
      userController.syncWeightFromProfile();
    }
  }

  void _upsertWeightEntry(WeightEntry entry) {
    final entries = [...weightEntries];
    final logDate = MealEntry.normalizeDate(entry.date);
    final index = entries.indexWhere(
      (item) => MealEntry.normalizeDate(item.date) == logDate,
    );
    if (index == -1) {
      entries.add(entry);
    } else {
      entries[index] = entry;
    }
    _applyWeightEntries(entries);
  }

  Future<WeightDeleteOutcome> deleteWeightEntry(WeightEntry entry) async {
    final entryId = entry.id?.trim();
    if (entryId == null || entryId.isEmpty) {
      return const WeightDeleteOutcome(
        WeightDeleteStatus.missingId,
        message: 'This entry cannot be deleted without a server id.',
      );
    }

    final accessToken = await _weightAccessToken();
    if (accessToken == null) {
      weightApiErrorMessage.value =
          'Sign in to delete weight from your account.';
      return const WeightDeleteOutcome(
        WeightDeleteStatus.failed,
        message: 'Sign in to delete weight from your account.',
      );
    }

    weightApiErrorMessage.value = null;

    try {
      debugPrint(
        'TrackerController: DELETE /api/v1/weight/$entryId starting',
      );
      await _weightRepository.deleteWeight(
        accessToken: accessToken,
        weightId: entryId,
      );
      await refreshWeightFromApi();
      if (weightEntries.isEmpty) {
        _seedDisplayWeightFromProfile();
        weightRevision.value++;
      }
      debugPrint(
        'TrackerController: weight entry deleted — '
        'current=${currentWeight.value}kg history=${weightEntries.length}',
      );
      return const WeightDeleteOutcome(WeightDeleteStatus.deleted);
    } on WeightApiException catch (error) {
      if (error.statusCode == 404) {
        debugPrint(
          'TrackerController: delete weight API returned 404 for $entryId',
        );
        await refreshWeightFromApi();
        return const WeightDeleteOutcome(WeightDeleteStatus.deleted);
      }

      weightApiErrorMessage.value = error.message;
      return WeightDeleteOutcome(
        WeightDeleteStatus.failed,
        message: error.message,
      );
    } catch (_) {
      weightApiErrorMessage.value =
          'Weight entry could not be deleted from the server.';
      return const WeightDeleteOutcome(
        WeightDeleteStatus.failed,
        message: 'Weight entry could not be deleted from the server.',
      );
    }
  }

  void syncActivity() {
    unawaited(_startAutoStepTracking(force: true));
  }

  Future<void> installHealthConnect() async {
    await _stepTracking.installHealthConnect();
    unawaited(_startAutoStepTracking(force: true));
  }

  Future<void> _loadActivityLog() async {
    final storedSteps = await _storage.loadStepsByDate();
    final storedBaselines = await _storage.loadStepsBaselinesByDate();
    final storedExercises = await _storage.loadExerciseEntries();

    stepsByDate.assignAll(
      storedSteps.map(
        (key, value) => MapEntry(
          MealEntry.normalizeDate(DateTime.parse(key)),
          value,
        ),
      ),
    );
    _stepsBaselineByDate
      ..clear()
      ..addAll(storedBaselines);
    exerciseEntries.assignAll(storedExercises);
    _notifyActivityChanged();
  }

  Future<void> _persistActivityLog() async {
    final stepsPayload = stepsByDate.map(
      (date, steps) =>
          MapEntry(date.toIso8601String().split('T').first, steps),
    );
    await _storage.saveActivityLog(
      stepsByDate: stepsPayload,
      stepsBaselineByDate: Map<String, int>.from(_stepsBaselineByDate),
      exercises: exerciseEntries.toList(),
    );
    _notifyActivityChanged();
  }

  void _notifyActivityChanged() {
    activityRevision.value++;
  }

  void _applyDailySteps(int dailySteps) {
    final today = _today;
    final current = stepsForDate(today);
    if (current == dailySteps) return;

    stepsByDate[today] = dailySteps;
    stepsByDate.refresh();
    unawaited(_persistActivityLog());
  }

  Future<void> _startAutoStepTracking({bool force = false}) async {
    if (!force && isStepTrackingActive.value) return;

    stepTrackingMessage.value = null;
    needsHealthConnectInstall.value = false;
    final todayKey = _todayKey;

    await _stepTracking.start(
      todayKey: todayKey,
      baselinesByDate: _stepsBaselineByDate,
      savedStepsToday: stepsForDate(_today),
      onDailySteps: _applyDailySteps,
      persistBaselines: (baselines) async {
        _stepsBaselineByDate
          ..clear()
          ..addAll(baselines);
        await _storage.saveActivityLog(
          stepsByDate: stepsByDate.map(
            (date, steps) =>
                MapEntry(date.toIso8601String().split('T').first, steps),
          ),
          stepsBaselineByDate: Map<String, int>.from(_stepsBaselineByDate),
          exercises: exerciseEntries.toList(),
        );
      },
      onBackendChanged: (backend) {
        usesHealthConnect.value = backend == StepTrackingBackend.healthConnect;
      },
      onError: (message) {
        isStepTrackingActive.value = false;
        stepTrackingMessage.value = message;
        needsHealthConnectInstall.value = message.contains('Install Health Connect');
        _notifyActivityChanged();
      },
    );

    isStepTrackingActive.value = _stepTracking.isListening;
    if (isStepTrackingActive.value) {
      needsHealthConnectInstall.value = false;
      stepTrackingMessage.value = usesHealthConnect.value
          ? 'Steps sync from Health Connect every 30 seconds.'
          : 'Steps update automatically from your device.';
    }
    _notifyActivityChanged();
  }

  Future<void> addExercise({
    required ExerciseType type,
    required int durationMinutes,
    ExerciseIntensity intensity = ExerciseIntensity.normal,
  }) async {
    if (durationMinutes <= 0) return;

    final weightKg = Get.isRegistered<UserController>()
        ? Get.find<UserController>().user.weightKg.toDouble()
        : 70.0;
    final calories = ExerciseType.estimateCalories(
      type: type,
      weightKg: weightKg,
      durationMinutes: durationMinutes,
      intensity: intensity,
    );

    exerciseEntries.add(
      ExerciseEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: type.label,
        durationMinutes: durationMinutes,
        calories: calories,
        date: _today,
        typeId: type.name,
        intensityLabel:
            intensity == ExerciseIntensity.normal ? null : intensity.label,
      ),
    );
    await _persistActivityLog();
  }

  Future<void> removeExercise(String id) async {
    exerciseEntries.removeWhere((entry) => entry.id == id);
    await _persistActivityLog();
  }
}
