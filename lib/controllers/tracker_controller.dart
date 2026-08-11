  import 'dart:async';

  import 'package:flutter/foundation.dart';
  import 'package:get/get.dart';

  import '../core/app_snackbar.dart';
  import '../core/weight_chart_data.dart';
  import '../models/daily_water_intake.dart';
  import '../models/exercise_entry.dart';
  import '../models/exercise_type.dart';
  import '../models/meal_entry.dart';
  import '../models/water_log_entry.dart';
  import '../models/water_period.dart';
  import '../models/weight_entry.dart';
  import '../repositories/water_repository.dart';
  import '../repositories/weight_repository.dart';
  import '../services/local_storage_service.dart';
  import '../services/step_tracking_service.dart';
  import '../services/water_api_service.dart';
  import '../services/weight_api_service.dart';
  import '../widgets/water_goal_success_dialog.dart';
  import 'settings_controller.dart';
  import 'user_controller.dart';
  import '../services/analytics_service.dart';

  enum WeightLogStatus { unchanged, savedAndSynced, failed }

  enum WeightDeleteStatus { deleted, failed, missingId }

  enum WaterDeleteStatus { deleted, failed, missingId }

  class WaterDeleteOutcome {
    const WaterDeleteOutcome(
      this.status, {
      this.message,
    });

    final WaterDeleteStatus status;
    final String? message;
  }

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
      WaterRepository? waterRepository,
    }) : _storage = storage ?? LocalStorageService(),
        _stepTracking = stepTracking ?? StepTrackingService(),
        _weightRepository = weightRepository ?? WeightRepository(),
        _waterRepository = waterRepository ?? WaterRepository() {
      if (initialWeight != null) {
        currentWeight.value = initialWeight;
      }
    }

    final LocalStorageService _storage;
    final StepTrackingService _stepTracking;
    final WeightRepository _weightRepository;
    final WaterRepository _waterRepository;
    final RxMap<DateTime, int> waterByDate = <DateTime, int>{}.obs;
    final RxList<WaterLogEntry> waterEntries = <WaterLogEntry>[].obs;
    final Rx<WaterPeriod> waterPeriod = WaterPeriod.week.obs;

    final RxDouble currentWeight = 0.0.obs;
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
    /// Bumped on every water ml change so Obx rebuilds even when map length is unchanged.
    final RxInt waterRevision = 0.obs;
    final RxBool needsHealthConnectInstall = false.obs;
    final RxBool usesHealthConnect = false.obs;

    static const int mlPerGlass = DailyWaterIntake.mlPerGlass;
    static const int defaultWaterGoalMl = SettingsController.defaultWaterGoalMl;

    static int get waterGoalMl {
      if (Get.isRegistered<SettingsController>()) {
        return Get.find<SettingsController>().waterGoalMl.value;
      }
      return defaultWaterGoalMl;
    }
    static const int weightApiLimit = 30;
    static const int stepsGoal = 10000;
    static const String defaultWeightApiPeriod = '1week';
    static const int waterApiPageLimit = 30;

    bool _waterGoalCelebrationShown = false;
    bool _waterGoalListenerBound = false;
    bool _waterApi404Logged = false;
    WeightChartPeriod _weightChartPeriod = WeightChartPeriod.week;
    WeightChartCustomRange? _weightChartCustomRange;

    DateTime get _today => MealEntry.normalizeDate(DateTime.now());

    void _bumpWaterRevision() {
      waterByDate.refresh();
      waterRevision.value++;
    }

    List<double> get weightHistory =>
        weightEntries.map((entry) => entry.kg).toList();

    List<WeightEntry> get recentWeightEntries => weightEntries.toList();

    Future<void>? _refreshWaterFuture;
    DateTime? _lastWaterRefreshAt;
    static const Duration _waterRefreshCooldown = Duration(seconds: 8);

    Future<void>? _refreshWeightFuture;
    String? _lastWeightRefreshKey;
    DateTime? _lastWeightRefreshAt;
    static const Duration _weightRefreshCooldown = Duration(seconds: 10);

    @override
    void onInit() {
      super.onInit();
      _migrateLegacyWaterCounts();
      unawaited(_loadWeightHistory());
      unawaited(_loadActivityLog());
      unawaited(refreshWaterFromApi(force: true));
      _bindWaterGoalListener();
    }

    @override
    void onReady() {
      super.onReady();
      _bindWaterGoalListener();
    }

    /// Drop in-memory water/weight so a prior session cannot leak after logout.
    void clearSessionData() {
      waterByDate.clear();
      waterEntries.clear();
      weightEntries.clear();
      exerciseEntries.clear();
      stepsByDate.clear();
      _stepsBaselineByDate.clear();
      _lastWaterRefreshAt = null;
      _lastWeightRefreshAt = null;
      _lastWeightRefreshKey = null;
      _waterApi404Logged = false;
      _waterGoalCelebrationShown = false;
      currentWeight.value = 0;
      activityRevision.value++;
      weightRevision.value++;
      waterRevision.value++;
      update();
      debugPrint('TrackerController: session data cleared');
    }

    /// Reload water + weight from the API after login.
    Future<void> reloadAfterLogin() async {
      _lastWaterRefreshAt = null;
      _lastWeightRefreshAt = null;
      _lastWeightRefreshKey = null;
      await Future.wait([
        refreshWaterFromApi(force: true),
        refreshWeightFromApi(),
      ]);
    }

    void _bindWaterGoalListener() {
      if (_waterGoalListenerBound || !Get.isRegistered<SettingsController>()) {
        return;
      }
      _waterGoalListenerBound = true;
      ever(
        Get.find<SettingsController>().waterGoalMl,
        (_) => syncWaterGoalCelebration(),
      );
    }

    /// Converts pre-ml glass counts (1, 2, 3…) left in memory after hot reload.
    void _migrateLegacyWaterCounts() {
      var changed = false;
      for (final entry in waterByDate.entries.toList()) {
        final raw = entry.value;
        if (!_isLegacyGlassCount(raw)) continue;
        waterByDate[entry.key] = raw * mlPerGlass;
        changed = true;
      }
      if (changed) _bumpWaterRevision();
    }

    bool _isLegacyGlassCount(int value) =>
        value > 0 && value <= 24 && value % mlPerGlass != 0;

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

    List<ExerciseEntry> exercisesForDate(DateTime date) {
      final day = MealEntry.normalizeDate(date);
      return exerciseEntries
          .where((entry) => entry.normalizedDate == day)
          .toList();
    }

    int caloriesBurnedForDate(DateTime date) {
      final fromExercises = exercisesForDate(date).fold(
        0,
        (sum, entry) => sum + entry.calories,
      );
      final fromSteps = (stepsForDate(date) * 0.04).round();
      return fromExercises + fromSteps;
    }

    int stepsForDate(DateTime date) =>
        stepsByDate[MealEntry.normalizeDate(date)] ?? 0;

    /// Total millilitres logged today.
    int get waterMl => waterForDate(_today);

    /// Glass equivalent of today's intake, for display.
    int get waterGlasses => (waterMl / mlPerGlass).round();

    double get waterProgress =>
        waterGoalMl > 0 ? (waterMl / waterGoalMl).clamp(0.0, 1.0) : 0.0;

    bool get isWaterGoalComplete => waterMl >= waterGoalMl;

    int get waterMlOverGoal => (waterMl - waterGoalMl).clamp(0, 1000000);

    int get waterMlRemaining => (waterGoalMl - waterMl).clamp(0, waterGoalMl);

    /// Total millilitres logged on [date].
    int waterForDate(DateTime date) {
      final key = MealEntry.normalizeDate(date);
      final raw = waterByDate[key] ?? 0;
      if (!_isLegacyGlassCount(raw)) return raw;
      // Read-only conversion — never write during widget builds (breaks Obx).
      return raw * mlPerGlass;
    }

    List<DailyWaterIntake> waterForLastDays(int dayCount) {
      final today = _today;
      return List.generate(dayCount, (index) {
        final day = today.subtract(Duration(days: dayCount - 1 - index));
        return DailyWaterIntake(date: day, totalMl: waterForDate(day));
      });
    }

    List<DailyWaterIntake> get activeWaterDays => switch (waterPeriod.value) {
      WaterPeriod.today => [
        DailyWaterIntake(date: _today, totalMl: waterMl),
      ],
      WaterPeriod.yesterday => [
        DailyWaterIntake(
          date: _today.subtract(const Duration(days: 1)),
          totalMl: waterForDate(_today.subtract(const Duration(days: 1))),
        ),
      ],
      WaterPeriod.week => waterForLastDays(7),
      WaterPeriod.month => waterForLastDays(30),
    };

    void setWaterPeriod(WaterPeriod period) {
      waterPeriod.value = period;
      unawaited(_refreshWaterForPeriod(period));
    }

    String periodLabelFor(WaterPeriod period) => switch (period) {
      WaterPeriod.today => 'Today',
      WaterPeriod.yesterday => 'Yesterday',
      WaterPeriod.week => '7 Days',
      WaterPeriod.month => '30 Days',
    };

    /// Adds one standard glass (250 ml). Pass [date] to log for a past day.
    void addWater({DateTime? date}) => addWaterMl(mlPerGlass, date: date);

    void addWaterMl(int ml, {DateTime? date}) =>
        unawaited(_addWaterMl(ml, date: date));

    Future<void> _addWaterMl(int ml, {DateTime? date}) async {
      if (ml <= 0) return;
      final day = MealEntry.normalizeDate(date ?? _today);
      final previous = waterForDate(day);
      final wasComplete = previous >= waterGoalMl;

      waterByDate[day] = previous + ml;
      _bumpWaterRevision();
      await AnalyticsService.logWaterLogged(1);
      AppSnackbar.success(_waterLoggedMessage(ml), title: 'Water');
      _maybeShowWaterGoalCelebration(wasComplete, forDate: day);

      final accessToken = await _weightAccessToken();
      if (accessToken == null) return;

      try {
        final response = await _waterRepository.logWater(
          accessToken: accessToken,
          amountMl: ml,
          date: day == _today ? null : day,
        );
        final loggedEntry = response.entry;
        if (loggedEntry != null) {
          _upsertWaterEntries([loggedEntry]);
        }
        final serverTotal = response.dailyTotalMl;
        if (serverTotal != null) {
          waterByDate[day] = serverTotal;
          _bumpWaterRevision();
        } else {
          await refreshWaterForDate(day);
        }
      } on WaterApiException catch (error) {
        _logWaterApi404Once(error);
        debugPrint('TrackerController: water log failed: $error');
      } catch (error) {
        debugPrint('TrackerController: water log failed: $error');
      }
    }

    static String _waterLoggedMessage(int ml) {
      if (ml == mlPerGlass) return 'Added 1 glass.';
      if (ml > 0 && ml % mlPerGlass == 0) {
        final glasses = ml ~/ mlPerGlass;
        return 'Added $glasses glasses.';
      }
      return 'Added ${formatWaterMl(ml)}.';
    }

    void _logWaterApi404Once(WaterApiException error) {
      if (error.statusCode != 404 || _waterApi404Logged) return;
      _waterApi404Logged = true;
      debugPrint(
        'TrackerController: water API route not found (404) — '
        'local tracking continues. Deploy /api/v1/water or run with '
        '--dart-define=API_BASE_URL=http://10.0.2.2:3000',
      );
    }

    void _maybeShowWaterGoalCelebration(
      bool wasComplete, {
      DateTime? forDate,
    }) {
      final day = forDate == null ? _today : MealEntry.normalizeDate(forDate);
      final complete = waterForDate(day) >= waterGoalMl;
      if (!wasComplete && complete && !_waterGoalCelebrationShown) {
        _waterGoalCelebrationShown = true;
        unawaited(
          AnalyticsService.logGoalCompleted(goalType: 'water_daily'),
        );
        WaterGoalSuccessDialog.show();
      }
    }

    /// Removes one standard glass (250 ml). Pass [date] to edit a past day.
    void removeWater({DateTime? date}) => removeWaterMl(mlPerGlass, date: date);

    void removeWaterMl(int ml, {DateTime? date}) =>
        unawaited(_removeWaterMl(ml, date: date));

    Future<void> _removeWaterMl(int ml, {DateTime? date}) async {
      if (ml <= 0) return;
      final day = MealEntry.normalizeDate(date ?? _today);
      final current = waterForDate(day);
      if (current <= 0) return;

      final entry = _latestWaterEntryForDate(day, preferredMl: ml);
      if (entry != null) {
        final outcome = await deleteWaterEntry(entry);
        if (outcome.status == WaterDeleteStatus.deleted) {
          AppSnackbar.success(_waterRemovedMessage(ml), title: 'Water');
          if (waterForDate(day) < waterGoalMl) {
            _waterGoalCelebrationShown = false;
          }
          return;
        }
      }

      final next = current - ml;
      if (next <= 0) {
        waterByDate.remove(day);
      } else {
        waterByDate[day] = next;
      }
      _bumpWaterRevision();
      AppSnackbar.success(_waterRemovedMessage(ml), title: 'Water');

      if (waterForDate(day) < waterGoalMl) {
        _waterGoalCelebrationShown = false;
      }
    }

    static String _waterRemovedMessage(int ml) {
      if (ml == mlPerGlass) return 'Removed 1 glass.';
      if (ml > 0 && ml % mlPerGlass == 0) {
        final glasses = ml ~/ mlPerGlass;
        return 'Removed $glasses glasses.';
      }
      return 'Removed ${formatWaterMl(ml)}.';
    }

    Future<WaterDeleteOutcome> deleteWaterEntry(WaterLogEntry entry) async {
      final entryId = entry.id?.trim();
      if (entryId == null || entryId.isEmpty) {
        return const WaterDeleteOutcome(
          WaterDeleteStatus.missingId,
          message: 'This entry cannot be deleted without a server id.',
        );
      }

      final accessToken = await _weightAccessToken();
      if (accessToken == null) {
        return const WaterDeleteOutcome(
          WaterDeleteStatus.failed,
          message: 'Sign in to delete water from your account.',
        );
      }

      try {
        debugPrint(
          'TrackerController: DELETE /api/v1/water/$entryId starting',
        );
        await _waterRepository.deleteWater(
          accessToken: accessToken,
          waterId: entryId,
        );
        waterEntries.removeWhere((item) => item.id == entryId);
        waterEntries.refresh();
        await refreshWaterForDate(entry.normalizedDate);
        debugPrint(
          'TrackerController: water entry deleted — '
          'today=${waterForDate(_today)}ml',
        );
        return const WaterDeleteOutcome(WaterDeleteStatus.deleted);
      } on WaterApiException catch (error) {
        _logWaterApi404Once(error);
        if (error.statusCode == 404) {
          debugPrint(
            'TrackerController: delete water API returned 404 for $entryId',
          );
          waterEntries.removeWhere((item) => item.id == entryId);
          waterEntries.refresh();
          await refreshWaterForDate(entry.normalizedDate);
          return const WaterDeleteOutcome(WaterDeleteStatus.deleted);
        }

        return WaterDeleteOutcome(
          WaterDeleteStatus.failed,
          message: error.message,
        );
      } catch (error) {
        return WaterDeleteOutcome(
          WaterDeleteStatus.failed,
          message: error.toString(),
        );
      }
    }

    WaterLogEntry? _latestWaterEntryForDate(
      DateTime day, {
      int? preferredMl,
    }) {
      final dayEntries = waterEntries
          .where((entry) => entry.normalizedDate == day)
          .toList();
      if (dayEntries.isEmpty) return null;

      if (preferredMl != null) {
        final matches =
            dayEntries.where((entry) => entry.amountMl == preferredMl).toList();
        if (matches.isNotEmpty) return matches.last;
      }

      return dayEntries.last;
    }

    void syncWaterGoalCelebration() {
      if (!isWaterGoalComplete) {
        _waterGoalCelebrationShown = false;
      }
      _bumpWaterRevision();
    }

    /// Loads today's water total and paginated history from the API.
    Future<void> refreshWaterFromApi({bool force = false}) {
      final now = DateTime.now();
      if (!force &&
          _lastWaterRefreshAt != null &&
          now.difference(_lastWaterRefreshAt!) < _waterRefreshCooldown) {
        return _refreshWaterFuture ?? Future<void>.value();
      }
      if (_refreshWaterFuture != null) {
        return _refreshWaterFuture!;
      }

      _refreshWaterFuture = () async {
        await refreshWaterForDate(_today);
        await refreshWaterHistory();
      }().whenComplete(() {
        _refreshWaterFuture = null;
        _lastWaterRefreshAt = DateTime.now();
      });
      return _refreshWaterFuture!;
    }

    Future<void> _refreshWaterForPeriod(WaterPeriod period) async {
      switch (period) {
        case WaterPeriod.today:
          await refreshWaterForDate(_today);
        case WaterPeriod.yesterday:
          await refreshWaterForDate(_today.subtract(const Duration(days: 1)));
        case WaterPeriod.week:
        case WaterPeriod.month:
          await refreshWaterHistory();
      }
    }

    void _applyWaterFetchResult(
      WaterFetchResult result, {
      DateTime? replaceEntriesForDate,
    }) {
      if (result.entries.isNotEmpty) {
        if (replaceEntriesForDate != null) {
          final day = MealEntry.normalizeDate(replaceEntriesForDate);
          waterEntries.removeWhere((entry) => entry.normalizedDate == day);
          waterEntries.addAll(result.entries);
        } else {
          _upsertWaterEntries(result.entries);
        }
        waterEntries.refresh();
      }
      if (result.dailyTotalsMl.isNotEmpty) {
        for (final entry in result.dailyTotalsMl.entries) {
          waterByDate[entry.key] = entry.value;
        }
      }
      // Always notify — entries-only payloads must still rebuild the chart.
      _bumpWaterRevision();
    }

    void _upsertWaterEntries(List<WaterLogEntry> incoming) {
      for (final entry in incoming) {
        final id = entry.id?.trim();
        if (id != null && id.isNotEmpty) {
          final index = waterEntries.indexWhere((item) => item.id == id);
          if (index == -1) {
            waterEntries.add(entry);
          } else {
            waterEntries[index] = entry;
          }
          continue;
        }

        waterEntries.add(entry);
      }
    }

    Future<void> refreshWaterForDate(DateTime date) async {
      final accessToken = await _weightAccessToken();
      if (accessToken == null) return;

      try {
        final result = await _waterRepository.fetchWaterByDate(
          accessToken: accessToken,
          date: date,
        );
        _applyWaterFetchResult(result, replaceEntriesForDate: date);
      } on WaterApiException catch (error) {
        _logWaterApi404Once(error);
        debugPrint('TrackerController: water date fetch failed: $error');
      } catch (error) {
        debugPrint('TrackerController: water date fetch failed: $error');
      }
    }

    Future<void> refreshWaterHistory({int page = 1}) async {
      final accessToken = await _weightAccessToken();
      if (accessToken == null) return;

      try {
        final result = await _waterRepository.fetchWaterHistory(
          accessToken: accessToken,
          page: page,
          limit: waterApiPageLimit,
        );
        _applyWaterFetchResult(result);
      } on WaterApiException catch (error) {
        _logWaterApi404Once(error);
        debugPrint('TrackerController: water history fetch failed: $error');
      } catch (error) {
        debugPrint('TrackerController: water history fetch failed: $error');
      }
    }

    Future<void> _loadWeightHistory() async {
      await refreshWeightFromApi(period: defaultWeightApiPeriod);
      if (weightEntries.isEmpty) {
        _seedDisplayWeightFromProfile();
      }
    }

    void setWeightChartPeriod(
      WeightChartPeriod period, {
      WeightChartCustomRange? customRange,
    }) {
      _weightChartPeriod = period;
      _weightChartCustomRange = customRange;
    }

    Future<void> refreshWeightForChartPeriod({
      WeightChartPeriod? period,
      WeightChartCustomRange? customRange,
      bool keepExistingOnEmpty = false,
      List<WeightEntry> authoritativeEntries = const [],
    }) async {
      final effectivePeriod = period ?? _weightChartPeriod;
      final effectiveRange = customRange ?? _weightChartCustomRange;

      if (effectivePeriod == WeightChartPeriod.custom) {
        final range = effectiveRange;
        if (range == null) {
          await refreshWeightFromApi(
            period: defaultWeightApiPeriod,
            keepExistingOnEmpty: keepExistingOnEmpty,
            authoritativeEntries: authoritativeEntries,
          );
          return;
        }
        await refreshWeightFromApi(
          fromDate: range.start,
          toDate: range.end,
          keepExistingOnEmpty: keepExistingOnEmpty,
          authoritativeEntries: authoritativeEntries,
        );
        return;
      }

      await refreshWeightFromApi(
        period: effectivePeriod.apiPeriod,
        keepExistingOnEmpty: keepExistingOnEmpty,
        authoritativeEntries: authoritativeEntries,
      );
    }

    Future<void> refreshWeightFromApi({
      String? period,
      DateTime? fromDate,
      DateTime? toDate,
      bool keepExistingOnEmpty = false,
      List<WeightEntry> authoritativeEntries = const [],
    }) {
      final cacheKey =
          '${period ?? ''}|${fromDate?.toIso8601String() ?? ''}|'
          '${toDate?.toIso8601String() ?? ''}';
      final force = authoritativeEntries.isNotEmpty;
      final now = DateTime.now();
      if (!force &&
          _lastWeightRefreshKey == cacheKey &&
          _lastWeightRefreshAt != null &&
          now.difference(_lastWeightRefreshAt!) < _weightRefreshCooldown &&
          weightEntries.isNotEmpty) {
        return _refreshWeightFuture ?? Future<void>.value();
      }
      if (!force &&
          _refreshWeightFuture != null &&
          _lastWeightRefreshKey == cacheKey) {
        return _refreshWeightFuture!;
      }

      _lastWeightRefreshKey = cacheKey;
      _refreshWeightFuture = _refreshWeightFromApi(
        period: period,
        fromDate: fromDate,
        toDate: toDate,
        keepExistingOnEmpty: keepExistingOnEmpty,
        authoritativeEntries: authoritativeEntries,
      ).whenComplete(() {
        _refreshWeightFuture = null;
        _lastWeightRefreshAt = DateTime.now();
      });
      return _refreshWeightFuture!;
    }

    Future<void> _refreshWeightFromApi({
      String? period,
      DateTime? fromDate,
      DateTime? toDate,
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
          period: period,
          fromDate: fromDate,
          toDate: toDate,
          page: period == null && fromDate == null && toDate == null ? 1 : null,
          limit: period == null && fromDate == null && toDate == null
              ? weightApiLimit
              : null,
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

      final kg = (Get.find<UserController>().user.weightKg?.toDouble() ?? 0);
      if (kg > 0) {
        currentWeight.value = kg;
      }
    }

    /// Public hook for Goal screens when weight history hasn't loaded yet.
    void syncWeightFromProfileIfEmpty() {
      if (currentWeight.value > 0 || weightEntries.isNotEmpty) return;
      _seedDisplayWeightFromProfile();
      if (currentWeight.value > 0) {
        weightRevision.value++;
        update();
      }
    }


    void _applyWeightEntries(List<WeightEntry> entries) {
      final sorted = WeightEntry.collapseToLatestPerDay(entries);
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

    /// Collapses API history to one row per day (newest [WeightEntry.loggedAt]),
    /// then applies [overrides] (e.g. a just-saved log) as the source of truth.
    static List<WeightEntry> _mergeWeightEntries(
      List<WeightEntry> base,
      List<WeightEntry> overrides,
    ) {
      final collapsed = WeightEntry.collapseToLatestPerDay(base);
      if (overrides.isEmpty) return collapsed;

      final byDay = <DateTime, WeightEntry>{
        for (final entry in collapsed)
          MealEntry.normalizeDate(entry.date): entry,
      };
      for (final entry in overrides) {
        byDay[MealEntry.normalizeDate(entry.date)] = entry;
      }

      return byDay.values.toList()
        ..sort((left, right) => left.date.compareTo(right.date));
    }

    /// Keeps home "current weight" aligned with weight API history.
    /// Does not write into onboarding profile / target weight.
    void _syncProfileWeightFromEntries(List<WeightEntry> entries) {
      if (entries.isEmpty) return;

      final kg = _resolveDisplayWeight(entries);
      if (kg <= 0) return;
      if ((currentWeight.value - kg).abs() < 0.05) return;

      currentWeight.value = kg;
      weightRevision.value++;
      debugPrint(
        'TrackerController: current weight synced from API history — $kg kg',
      );
    }

    /// Prefers today's logged weight for the summary card; otherwise latest entry.
    double _resolveDisplayWeight(List<WeightEntry> entries) {
      if (entries.isEmpty) return currentWeight.value;

      final sorted = WeightEntry.collapseToLatestPerDay(entries);
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
      final loggedAt = fromApi?.loggedAt ?? DateTime.now();
      if (fromApi == null) {
        return WeightEntry(date: logDate, kg: kg, loggedAt: loggedAt);
      }

      return WeightEntry(
        id: fromApi.id,
        date: logDate,
        kg: kg,
        loggedAt: loggedAt,
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

          // Always keep the just-logged value as current when logging for today.
          // A stale GET (or profile patch) can otherwise restore the previous weight.
          if (logDate == _today) {
            currentWeight.value = kg;
          } else {
            currentWeight.value = _resolveDisplayWeight(weightEntries);
          }

          _syncLocalDisplayWeightAfterLog(
            kg: kg,
            logDate: logDate,
          );

          weightApiErrorMessage.value = null;
          weightRevision.value++;
      await AnalyticsService.logWeightUpdated(kg);
          debugPrint(
            'TrackerController: weight log complete — '
            'current=${currentWeight.value}kg history=${weightEntries.length} '
            'profileUpdated=${response.profileUpdated}',
          );

          // Weight API rewrites onboarding profile (goal → maintain, goalWeight ≈
          // current). Always re-assert the pinned lose/gain target + type.
          if (Get.isRegistered<UserController>()) {
            unawaited(
              Get.find<UserController>().reaffirmPinnedGoalWeightAfterWeightLog(),
            );
          }

          // Refresh chart history in the background so Save is never blocked
          // by a slow/hanging GET.
          unawaited(
            refreshWeightForChartPeriod(
              keepExistingOnEmpty: true,
              authoritativeEntries: [savedEntry],        
            ),
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

    /// Updates the Weight Progress "current" display after a today's log.
    /// Does not change onboarding profile weight or target weight.
    void _syncLocalDisplayWeightAfterLog({
      required double kg,
      required DateTime logDate,
    }) {
      if (logDate != _today) return;
      updateWeight(kg);
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

    Future<WeightDeleteOutcome> deleteWeightEntry(
      WeightEntry entry, {
      bool applyLocally = true,                                                
    }) async {
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

        if (applyLocally) {
          await _applyWeightDeletedLocally(entryId);
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
          if (applyLocally) {
            await _applyWeightDeletedLocally(entryId);
          }
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

    /// Keeps the trash Lottie on screen long enough to read (API is often ms).
    Future<WeightDeleteOutcome> deleteWeightEntryWithFeedback(
      WeightEntry entry,
    ) async {
      final started = DateTime.now();
      final outcome = await deleteWeightEntry(entry, applyLocally: false);

      const minVisible = Duration(milliseconds: 1100);
      final elapsed = DateTime.now().difference(started);
      if (elapsed < minVisible) {
        await Future<void>.delayed(minVisible - elapsed);
      }

      if (outcome.status == WeightDeleteStatus.deleted) {
        final entryId = entry.id?.trim();
        if (entryId != null && entryId.isNotEmpty) {
          await _applyWeightDeletedLocally(entryId);
        }
      }
      return outcome;
    }

    Future<void> _applyWeightDeletedLocally(String entryId) async {
      // Remove only this entry locally first — never wipe the whole list
      // if the follow-up GET comes back empty/stale.
      _removeWeightEntryById(entryId);
      await refreshWeightForChartPeriod(keepExistingOnEmpty: true);

      if (weightEntries.isEmpty) {
        _seedDisplayWeightFromProfile();
        weightRevision.value++;
        
      }
    }

    void _removeWeightEntryById(String entryId) {
      final remaining = weightEntries
          .where((item) => (item.id?.trim() ?? '') != entryId)
          .toList();
      if (remaining.length == weightEntries.length) return;
      _applyWeightEntries(remaining);
    }

    void syncActivity() {
      unawaited(_enableAndStartStepTracking());
    }

    Future<void> installHealthConnect() async {
      await _stepTracking.installHealthConnect();
      await _enableAndStartStepTracking();
    }

    Future<void> disconnectStepTracking() async {
      await _storage.saveStepTrackingEnabled(false);
      await _stepTracking.stop();
      isStepTrackingActive.value = false;
      usesHealthConnect.value = false;
      needsHealthConnectInstall.value = false;
      stepTrackingMessage.value =
          'Step tracking disconnected. Connect again anytime.';
      _notifyActivityChanged();
    }

    Future<void> _enableAndStartStepTracking() async {
      await _storage.saveStepTrackingEnabled(true);
      await _startAutoStepTracking(force: true);
    }

    Future<void> _loadActivityLog() async {
      final storedSteps = await _storage.loadStepsByDate();
      final storedBaselines = await _storage.loadStepsBaselinesByDate();
      final storedExercises = await _storage.loadExerciseEntries();
      final trackingEnabled = await _storage.loadStepTrackingEnabled();

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

      if (trackingEnabled) {
        // Requests native Health Connect / activity permission when needed.
        unawaited(_startAutoStepTracking(force: true));
      } else {
        stepTrackingMessage.value =
            'Step tracking is off. Tap Connect to enable.';
      }
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

      final enabled = await _storage.loadStepTrackingEnabled();
      if (!enabled && !force) return;

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
          needsHealthConnectInstall.value =
              message.contains('Install Health Connect');
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
          ? (Get.find<UserController>().user.weightKg?.toDouble() ?? 0)
          : 0.0;
      final safeWeight = weightKg > 0 ? weightKg : 70.0; // estimate only
      final calories = ExerciseType.estimateCalories(
        type: type,
        weightKg: safeWeight,
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
