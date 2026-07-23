import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../core/streak_calculator.dart';
import '../models/meal_streak_model.dart';
import '../repositories/meal_streak_repository.dart';
import '../repositories/meals_repository.dart';
import '../services/local_storage_service.dart';
import '../services/meal_streak_api_service.dart';
import '../services/meals_api_service.dart';
import '../widgets/streak_milestone_dialog.dart';
import 'user_controller.dart';

class StreakController extends GetxController {
  StreakController({
    LocalStorageService? storage,
    MealStreakRepository? repository,
    MealsRepository? mealsRepository,
  })  : _storage = storage ?? LocalStorageService(),
        _repository = repository ?? MealStreakRepository(),
        _mealsRepository = mealsRepository ?? MealsRepository();

  final LocalStorageService _storage;
  final MealStreakRepository _repository;
  final MealsRepository _mealsRepository;

  final RxSet<int> celebratedMilestones = <int>{}.obs;
  final RxInt revision = 0.obs;
  final RxBool isLoadingApi = false.obs;
  final RxnString apiErrorMessage = RxnString();

  MealStreakModel? _apiStreak;
  Set<DateTime> _calendarLoggedDates = {};
  late final Future<void> _ready;
  bool _isFetchingApi = false;
  bool _pendingRefresh = false;

  bool get usesApiStreak => _apiStreak != null;

  bool get isLoggedIn {
    if (!Get.isRegistered<UserController>()) return false;
    final user = Get.find<UserController>();
    return user.isLoggedIn && user.accessToken.isNotEmpty;
  }

  StreakStats get stats {
    revision.value;
    if (!isLoggedIn || _apiStreak == null) return StreakStats.empty;

    return _apiStreak!.toStreakStats(calendarDates: _calendarLoggedDates);
  }

  int get currentStreak => stats.currentStreak;
  int get longestStreak => stats.longestStreak;
  bool get hasLoggedToday => stats.hasLoggedToday;
  bool get isAtRisk => stats.isAtRisk;
  bool get streakBroken => stats.streakBroken;
  List<StreakDay> get recentDays => stats.recentDays;

  String get statusMessage {
    if (!isLoggedIn) {
      return 'Sign in to track your meal logging streak.';
    }
    if (_apiStreak == null && isLoadingApi.value) {
      return 'Loading your streak...';
    }
    if (_apiStreak == null && apiErrorMessage.value != null) {
      return 'Could not load streak. Pull to refresh.';
    }
    if (currentStreak == 0) {
      if (streakBroken) {
        return 'You missed a day — log today to start a new streak.';
      }
      return 'Log a meal today to start your streak.';
    }
    if (hasLoggedToday) {
      return 'You logged today — streak secured!';
    }
    return 'Log a meal today to keep your $currentStreak-day streak alive.';
  }

  @override
  void onInit() {
    super.onInit();
    _ready = _loadMetadata();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _ready;
    revision.value++;
    // Streak unused — do not hit GET /api/v1/meals/streak on startup.
    // await refreshFromApi();
  }

  Future<void> _loadMetadata() async {
    celebratedMilestones
      ..clear()
      ..addAll(await _storage.loadCelebratedMilestones());
    revision.value++;
  }

  Future<Set<DateTime>> _loadCalendarDates({
    required String accessToken,
    required MealStreakModel streak,
  }) async {
    if (streak.loggedDates.isNotEmpty) {
      return streak.loggedDates;
    }

    try {
      final meals = await _mealsRepository.fetchMeals(accessToken: accessToken);
      return StreakCalculator.loggedDatesFrom(meals);
    } on MealsApiException catch (error) {
      debugPrint('StreakController: meals API for calendar failed: $error');
      return const {};
    } catch (error) {
      debugPrint('StreakController: meals API for calendar failed: $error');
      return const {};
    }
  }

  Future<void> refreshFromApi() async {
    // Streak is unused in the app — skip GET /api/v1/meals/streak.
    debugPrint(
      'StreakController: refreshFromApi skipped (streak feature disabled)',
    );
    return;

    // ignore: dead_code
    debugPrint('StreakController: refreshFromApi entered');
    if (_isFetchingApi) {
      _pendingRefresh = true;
      return;
    }
    if (!Get.isRegistered<UserController>()) return;

    final userController = Get.find<UserController>();
    await userController.localProfileReady;
    await userController.loadAuthSession();

    if (!userController.isLoggedIn || userController.accessToken.isEmpty) {
      _apiStreak = null;
      _calendarLoggedDates = {};
      apiErrorMessage.value = null;
      isLoadingApi.value = false;
      revision.value++;
      return;
    }

    _isFetchingApi = true;
    isLoadingApi.value = true;
    apiErrorMessage.value = null;
    revision.value++;

    try {
      debugPrint('StreakController: calling GET meals streak API');
      final streak = await _repository.fetchStreak(
        accessToken: userController.accessToken,
      );
      _calendarLoggedDates = await _loadCalendarDates(
        accessToken: userController.accessToken,
        streak: streak,
      );
      _apiStreak = streak;
      revision.value++;
      await _maybeCelebrateMilestone(streak.currentStreak);
    } on MealStreakApiException catch (error) {
      debugPrint('StreakController: meals streak API failed: $error');
      apiErrorMessage.value = error.message;
    } catch (error) {
      debugPrint('StreakController: meals streak API failed: $error');
      apiErrorMessage.value =
          'Unable to load your streak. Please check your connection.';
    } finally {
      _isFetchingApi = false;
      isLoadingApi.value = false;
      revision.value++;
      if (_pendingRefresh) {
        _pendingRefresh = false;
        unawaited(refreshFromApi());
      }
    }
  }

  Future<void> onMealsChanged() async {
    // Streak unused — do not refresh streak API when meals change.
    return;
    // ignore: dead_code
    await _ready;

    if (!Get.isRegistered<UserController>()) return;

    final user = Get.find<UserController>();
    await user.localProfileReady;
    await user.loadAuthSession();

    if (!user.isLoggedIn || user.accessToken.isEmpty) return;

    await refreshFromApi();
  }

  Future<void> onAuthChanged() async {
    // Streak unused — do not refresh streak API on auth changes.
    return;
    // ignore: dead_code
    await _ready;
    revision.value++;
    await refreshFromApi();
  }

  Future<void> _maybeCelebrateMilestone(int streak) async {
    if (streak <= 0) return;

    for (final milestone in StreakMilestones.values) {
      if (streak < milestone) continue;
      if (celebratedMilestones.contains(milestone)) continue;

      celebratedMilestones.add(milestone);
      await _storage.saveCelebratedMilestones(celebratedMilestones);

      if (Get.isDialogOpen != true) {
        await StreakMilestoneDialog.show(days: milestone);
      }
      break;
    }
  }
}
