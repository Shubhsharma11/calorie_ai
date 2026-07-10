import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../core/streak_calculator.dart';
import '../models/meal_streak_model.dart';
import '../repositories/meal_streak_repository.dart';
import '../services/local_storage_service.dart';
import '../services/meal_streak_api_service.dart';
import '../widgets/streak_milestone_dialog.dart';
import 'user_controller.dart';

class StreakController extends GetxController {
  StreakController({
    LocalStorageService? storage,
    MealStreakRepository? repository,
  })  : _storage = storage ?? LocalStorageService(),
        _repository = repository ?? MealStreakRepository();

  final LocalStorageService _storage;
  final MealStreakRepository _repository;

  final RxInt storedLongestStreak = 0.obs;
  final RxSet<int> celebratedMilestones = <int>{}.obs;
  final RxInt revision = 0.obs;
  final RxBool isLoadingApi = false.obs;
  final RxnString apiErrorMessage = RxnString();

  MealStreakModel? _apiStreak;
  late final Future<void> _ready;
  bool _isFetchingApi = false;
  bool _pendingRefresh = false;

  bool get usesApiStreak => _apiStreak != null;

  StreakStats get stats {
    revision.value;
    if (_apiStreak != null) {
      return _apiStreak!.toStreakStats(
        storedLongest: storedLongestStreak.value,
      );
    }
    return StreakStats(
      currentStreak: 0,
      longestStreak: storedLongestStreak.value,
      hasLoggedToday: false,
      isAtRisk: false,
      recentDays: StreakCalculator.buildRecentDays(const {}),
    );
  }

  int get currentStreak => stats.currentStreak;
  int get longestStreak => stats.longestStreak;
  bool get hasLoggedToday => stats.hasLoggedToday;
  bool get isAtRisk => stats.isAtRisk;
  List<StreakDay> get recentDays => stats.recentDays;

  String get statusMessage {
    if (currentStreak == 0) {
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
    unawaited(refreshFromApi());
  }

  Future<void> _loadMetadata() async {
    storedLongestStreak.value = await _storage.loadLongestStreak();
    celebratedMilestones
      ..clear()
      ..addAll(await _storage.loadCelebratedMilestones());
    revision.value++;
  }

  Future<void> refreshFromApi() async {
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
      apiErrorMessage.value = null;
      isLoadingApi.value = false;
      revision.value++;
      return;
    }

    _isFetchingApi = true;
    isLoadingApi.value = true;
    apiErrorMessage.value = null;

    try {
      debugPrint('StreakController: calling GET meals streak API');
      final streak = await _repository.fetchStreak(
        accessToken: userController.accessToken,
      );
      _apiStreak = streak;

      if (streak.longestStreak > storedLongestStreak.value) {
        storedLongestStreak.value = streak.longestStreak;
        await _storage.saveLongestStreak(streak.longestStreak);
      }

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
    await _ready;

    if (!Get.isRegistered<UserController>()) return;

    final user = Get.find<UserController>();
    await user.localProfileReady;
    await user.loadAuthSession();

    if (!user.isLoggedIn || user.accessToken.isEmpty) return;

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
