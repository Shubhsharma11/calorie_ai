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
  bool _isFetching = false;
  int _fetchGeneration = 0;

  final isLoading = false.obs;
  final errorMessage = RxnString();
  final plan = Rxn<NutritionPlanModel>();
  final revision = 0.obs;

  bool get hasWeeklyPlan => plan.value?.weeklyPlan?.isNotEmpty == true;

  @override
  void onInit() {
    super.onInit();
    unawaited(loadPlan(force: true));
  }

  void setLoadedPlan(NutritionPlanModel loadedPlan) {
    plan.value = loadedPlan;
    isLoading.value = false;
    errorMessage.value = null;
    _isFetching = false;
    revision.value++;
  }

  Future<void> loadPlan({bool force = false}) async {
    if (_isFetching && !force) return;
    if (!force && plan.value != null) return;

    final userController = Get.find<UserController>();
    await userController.localProfileReady;
    await userController.loadAuthSession();

    if (!userController.isLoggedIn || userController.accessToken.isEmpty) {
      debugPrint(
        'NutritionPlanController: skipped nutrition plan API — not signed in',
      );
      errorMessage.value = 'Please sign in to load your nutrition plan.';
      isLoading.value = false;
      revision.value++;
      return;
    }

    final generation = ++_fetchGeneration;
    final token = userController.accessToken;
    _isFetching = true;
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
      errorMessage.value = error.message;
    } catch (error) {
      if (generation != _fetchGeneration) return;
      debugPrint('NutritionPlanController: load failed: $error');
      errorMessage.value =
          'Unable to load your nutrition plan. Please check your connection and try again.';
    } finally {
      if (generation == _fetchGeneration) {
        _isFetching = false;
        isLoading.value = false;
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
    _isFetching = true;
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
      errorMessage.value = error.message;
    } catch (error) {
      if (generation != _fetchGeneration) return;
      debugPrint('NutritionPlanController: regenerate failed: $error');
      errorMessage.value =
          'Unable to refresh your weekly meal plan. Please try again.';
    } finally {
      if (generation == _fetchGeneration) {
        _isFetching = false;
        isLoading.value = false;
      }
      revision.value++;
    }
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
    plan.value = null;
    errorMessage.value = null;
    isLoading.value = false;
    _isFetching = false;
    revision.value++;
    debugPrint('NutritionPlanController: session data cleared');
  }
}
