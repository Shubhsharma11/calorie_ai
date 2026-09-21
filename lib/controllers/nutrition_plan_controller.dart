import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/nutrition_plan_model.dart';
import '../repositories/nutrition_plan_repository.dart';
import '../services/nutrition_plan_api_service.dart';
import 'user_controller.dart';

class NutritionPlanController extends GetxController {
  NutritionPlanController({NutritionPlanRepository? repository})
    : _repository = repository ?? NutritionPlanRepository();

  final NutritionPlanRepository _repository;
  Future<void>? _loadPlanInFlight;
  int _fetchGeneration = 0;

  final isLoading = false.obs;
  /// True after at least one GET attempt finishes (success, missing, or error).
  final hasCompletedFetch = false.obs;
  final errorMessage = RxnString();
  final plan = Rxn<NutritionPlanModel>();
  final revision = 0.obs;

  bool get hasWeeklyPlan => plan.value?.weeklyPlan?.isNotEmpty == true;

  /// Useful Home preview content (success presentation).
  bool get hasHomePreview {
    final preview = plan.value?.previewMeal;
    if (preview == null) return false;
    return preview.displayName.trim().isNotEmpty || preview.calories > 0;
  }

  /// Successful response with no usable plan content (not an API error).
  bool get isMissingPlan =>
      hasCompletedFetch.value &&
      errorMessage.value == null &&
      !hasHomePreview;

  @override
  void onInit() {
    super.onInit();
    // Already hydrated from onboarding — avoid a forced refetch that flickers Home/Profile.
    if (plan.value != null) {
      hasCompletedFetch.value = true;
      return;
    }
    // Network load is owned by [HomeHydrate].
  }

  void setLoadedPlan(NutritionPlanModel loadedPlan) {
    // Cancel any in-flight GET so a late response cannot overwrite this plan.
    _fetchGeneration++;
    plan.value = loadedPlan;
    isLoading.value = false;
    errorMessage.value = null;
    hasCompletedFetch.value = true;
    revision.value++;
  }

  /// Home Retry — nutrition GET only (never HomeHydrate / other sections).
  Future<void> retryPlan() => loadPlan(force: true);

  /// Concurrent callers join the same in-flight Future (no duplicate GET).
  Future<void> loadPlan({bool force = false}) {
    if (!force &&
        plan.value != null &&
        errorMessage.value == null &&
        hasCompletedFetch.value) {
      return Future.value();
    }

    final inFlight = _loadPlanInFlight;
    if (inFlight != null) {
      debugPrint('NutritionPlanController: loadPlan JOIN in-flight');
      return inFlight;
    }

    late final Future<void> started;
    started = _loadPlan().whenComplete(() {
      if (identical(_loadPlanInFlight, started)) {
        _loadPlanInFlight = null;
      }
    });
    _loadPlanInFlight = started;
    return started;
  }

  Future<void> _loadPlan() async {
    final userController = Get.find<UserController>();
    await userController.localProfileReady;
    await userController.loadAuthSession();

    if (!userController.isLoggedIn || userController.accessToken.isEmpty) {
      debugPrint(
        'NutritionPlanController: skipped nutrition plan API — not signed in',
      );
      errorMessage.value = 'Please sign in to load your nutrition plan.';
      isLoading.value = false;
      hasCompletedFetch.value = true;
      revision.value++;
      return;
    }

    final generation = ++_fetchGeneration;
    final token = userController.accessToken;
    isLoading.value = true;
    errorMessage.value = null;
    revision.value++;

    try {
      debugPrint('NutritionPlanController: calling GET nutrition plan API');
      final fetchedPlan = await _repository.fetchPlan(accessToken: token);
      if (generation != _fetchGeneration) {
        debugPrint('NutritionPlanController: ignoring stale plan response');
        return;
      }
      if (!userController.isLoggedIn || userController.accessToken != token) {
        debugPrint(
          'NutritionPlanController: ignoring plan — session changed',
        );
        return;
      }
      plan.value = fetchedPlan;
      errorMessage.value = null;
      debugPrint(
        'NutritionPlanController: loaded plan '
        'calories=${fetchedPlan.calories} '
        'meals=${fetchedPlan.meals.length} '
        'weeklyDays=${fetchedPlan.weeklyPlan?.days.length ?? 0} '
        'weeklyMeals=${fetchedPlan.weeklyPlan?.days.fold<int>(0, (n, d) => n + d.meals.length) ?? 0} '
        'preview=${fetchedPlan.previewMeal?.displayName}',
      );
      await userController.applyNutritionPlan(
        fetchedPlan,
        applyTargetWeight: false,
      );
    } on NutritionPlanApiException catch (error) {
      if (generation != _fetchGeneration) return;
      debugPrint('NutritionPlanController: load failed: $error');
      // Never retry 401/403 — clear the dead session once.
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _clearSessionOnAuthFailure(statusCode: error.statusCode);
        return;
      }
      // 404 = no plan yet (missing), not a hard API failure.
      if (error.statusCode == 404) {
        plan.value = null;
        errorMessage.value = null;
        debugPrint('NutritionPlanController: no plan (404) — missing state');
        return;
      }
      errorMessage.value = error.message;
    } catch (error) {
      if (generation != _fetchGeneration) return;
      debugPrint('NutritionPlanController: load failed: $error');
      errorMessage.value =
          'Unable to load your nutrition plan. Please check your connection and try again.';
    } finally {
      if (generation == _fetchGeneration) {
        isLoading.value = false;
        hasCompletedFetch.value = true;
      }
      revision.value++;
    }
  }

  /// Force-refresh for Weekly Meal Plan. If GET has no weekly meals, regenerate
  /// via POST so day schedules can appear.
  Future<void> ensureWeeklyPlan({bool regenerateIfEmpty = true}) async {
    await loadPlan(force: true);
    if (!regenerateIfEmpty) return;
    if (hasWeeklyPlan) return;

    final userController = Get.find<UserController>();
    if (!userController.isLoggedIn || userController.accessToken.isEmpty) {
      return;
    }

    final generation = ++_fetchGeneration;
    final token = userController.accessToken;
    isLoading.value = true;
    errorMessage.value = null;
    revision.value++;

    try {
      debugPrint(
        'NutritionPlanController: weekly empty — POST /nutrition/plan',
      );
      final body = userController.nutritionPlanRequestBody();
      final created = await _repository.createPlan(
        accessToken: token,
        body: body,
      );
      final hasMeals = created.previewMeal != null ||
          created.meals.isNotEmpty ||
          (created.weeklyPlan?.isNotEmpty ?? false);
      final refreshed = hasMeals
          ? created
          : await _repository.fetchPlan(accessToken: token);
      if (generation != _fetchGeneration) return;
      if (!userController.isLoggedIn || userController.accessToken != token) {
        return;
      }
      plan.value = refreshed;
      debugPrint(
        'NutritionPlanController: regenerated plan '
        'weeklyDays=${refreshed.weeklyPlan?.days.length ?? 0} '
        'weeklyMeals=${refreshed.weeklyPlan?.days.fold<int>(0, (n, d) => n + d.meals.length) ?? 0}',
      );
      await userController.applyNutritionPlan(
        refreshed,
        applyTargetWeight: false,
      );
      if (!hasWeeklyPlan) {
        errorMessage.value =
            'Weekly meal plan is not available yet. Please try again later.';
      }
    } on NutritionPlanApiException catch (error) {
      if (generation != _fetchGeneration) return;
      debugPrint('NutritionPlanController: regenerate failed: $error');
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _clearSessionOnAuthFailure(statusCode: error.statusCode);
        return;
      }
      errorMessage.value = error.message;
    } catch (error) {
      if (generation != _fetchGeneration) return;
      debugPrint('NutritionPlanController: regenerate failed: $error');
      errorMessage.value =
          'Unable to refresh your weekly meal plan. Please try again.';
    } finally {
      if (generation == _fetchGeneration) {
        isLoading.value = false;
        hasCompletedFetch.value = true;
      }
      revision.value++;
    }
  }

  Future<void> _clearSessionOnAuthFailure({required int? statusCode}) async {
    if (!Get.isRegistered<UserController>()) return;
    final user = Get.find<UserController>();
    if (user.isLoggingOut || user.isDeletingAccount || !user.isLoggedIn) {
      return;
    }
    await user.clearInvalidSession(
      // TEMPORARY — HOME_STUCK_DEBUG
      debugController: 'NutritionPlanController',
      debugEndpoint: 'GET|POST /nutrition/plan',
      debugStatusCode: statusCode,
      debugRequestType: 'HTTP',
    );
  }

  int get recommendedCalories {
    final apiCalories = plan.value?.calories ?? 0;
    if (apiCalories > 0) return apiCalories;
    return Get.find<UserController>().user.calculatedDailyCalorieGoal;
  }

  bool get hasApiPlan => plan.value != null;

  List<String> get tips => plan.value?.tips ?? [];

  void clearSessionData() {
    _fetchGeneration++;
    _loadPlanInFlight = null;
    plan.value = null;
    errorMessage.value = null;
    isLoading.value = false;
    hasCompletedFetch.value = false;
    revision.value++;
    debugPrint('NutritionPlanController: session data cleared');
  }
}
