import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../models/access_token_resolution.dart';
import '../models/activity_level.dart';
import '../models/goal_type.dart';
import '../models/health_concern.dart';
import '../models/nutrition_plan_model.dart';
import '../models/onboarding_request_model.dart';
import '../models/onboarding_response_model.dart';
import '../models/profile_sync_snapshot.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/nutrition_plan_repository.dart';
import '../repositories/onboarding_repository.dart';
import '../routes/app_routes.dart';
import '../core/app_snackbar.dart';
import '../services/auth_api_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/nutrition_plan_api_service.dart';
import '../services/onboarding_api_service.dart';
import 'dashboard_controller.dart';
import 'main_controller.dart';
import 'nutrition_plan_controller.dart';
// import 'streak_controller.dart';
import 'tracker_controller.dart';

class UserController extends GetxController {
  UserController({
    LocalStorageService? storage,
    AuthRepository? authRepository,
    OnboardingRepository? onboardingRepository,
    NutritionPlanRepository? nutritionPlanRepository,
  }) : _storage = storage ?? LocalStorageService(),
       _authRepository = authRepository ?? AuthRepository(),
       _onboardingRepository = onboardingRepository ?? OnboardingRepository(),
       _nutritionPlanRepository =
           nutritionPlanRepository ?? NutritionPlanRepository();

  final user = UserModel();
  final _imagePicker = ImagePicker();
  final LocalStorageService _storage;
  final AuthRepository _authRepository;
  final OnboardingRepository _onboardingRepository;
  final NutritionPlanRepository _nutritionPlanRepository;
  bool isLoggedIn = false;
  bool isLoggingOut = false;
  bool isDeletingAccount = false;
  bool isSubmittingOnboarding = false;
  bool isPatchingOnboarding = false;
  bool isLoadingProfile = false;
  String userId = '';
  String authProvider = '';
  String accessToken = '';
  String refreshToken = '';
  Map<String, dynamic> backendLoginResponse = {};
  final calorieGoalRevision = 0.obs;
  Completer<void>? _localProfileReady;
  Timer? _onboardingDraftSaveTimer;
  bool hasOnboardingDraft = false;
  bool personalDetailsComplete = false;

  /// Goal weight the user entered during onboarding (before AI recommendation).
  double? userOnboardingGoalWeightKg;

  /// AI / plan recommended target weight (does not replace the user's goal).
  double? aiRecommendedGoalWeightKg;

  /// Which target is currently driving the nutrition plan.
  final weightTargetSource = WeightTargetSource.user.obs;
  final isRefreshingWeightTarget = false.obs;

  static const int calorieStep = 50;
  static const int minDailyCalories = 1200;
  static const int maxDailyCalories = 4000;

  static const _setupRouteOrder = <String>[
    AppRoutes.personalDetails,
    AppRoutes.goalSetup,
    AppRoutes.goalAmount,
    AppRoutes.activityLevel,
    AppRoutes.healthProblem,
    AppRoutes.nutritionPlanLoading,
    AppRoutes.dailyCalorieGoal,
  ];

  @override
  void onInit() {
    super.onInit();
    _localProfileReady = Completer<void>();
    unawaited(_initializeLocalProfile());
  }

  Future<void> get localProfileReady =>
      _localProfileReady?.future ?? Future.value();

  Future<void> _initializeLocalProfile() async {
    try {
      await Future.wait([
        loadAuthSession(),
        _loadCalorieAdjustment(),
        _loadHealthProblem(),
        _loadNutritionTargets(),
      ]);
      await restoreOnboardingProgress();
      _notifyCalorieGoalChanged();
      update();
    } finally {
      if (_localProfileReady != null && !_localProfileReady!.isCompleted) {
        _localProfileReady!.complete();
      }
    }
  }

  Future<void> loadAuthSession() async {
    final saved = await _authRepository.loadSession();
    if (saved.isEmpty) {
      isLoggedIn = false;
      userId = '';
      authProvider = '';
      accessToken = '';
      refreshToken = '';
      backendLoginResponse = {};
      return;
    }

    isLoggedIn = true;
    userId = saved['userId'] as String? ?? '';
    authProvider = saved['provider'] as String? ?? '';
    accessToken = saved['accessToken'] as String? ?? '';
    refreshToken = saved['refreshToken'] as String? ?? '';
    user.email = saved['email'] as String? ?? user.email;
    user.name = saved['name'] as String? ?? user.name;

    final savedBackendResponse = saved['backendResponse'];
    backendLoginResponse = savedBackendResponse is Map<String, dynamic>
        ? savedBackendResponse
        : {};
    if (accessToken.isEmpty) {
      accessToken = readBackendString(backendLoginResponse, 'accessToken');
    }
    if (refreshToken.isEmpty) {
      refreshToken = readBackendString(backendLoginResponse, 'refreshToken');
    }
    update();
  }

  Future<String?> resolveAccessToken() async {
    final resolution = await resolveAccessTokenWithDiagnostics();
    if (!resolution.isResolved) {
      debugPrint(
        'UserController.resolveAccessToken: MISSING '
        'stage=${resolution.failureStage} '
        'at ${resolution.failureLocation}',
      );
      return null;
    }

    debugPrint(
      'UserController.resolveAccessToken: OK '
      'source=${resolution.source} length=${resolution.tokenLength}',
    );
    return resolution.token;
  }

  Future<AccessTokenResolution> resolveAccessTokenWithDiagnostics() async {
    await localProfileReady;
    final saved = await _authRepository.loadSession();
    if (saved.isEmpty) {
      isLoggedIn = false;
      accessToken = '';
      refreshToken = '';
      backendLoginResponse = {};
      return const AccessTokenResolution(
        failureStage: 'storage',
        failureLocation:
            'lib/controllers/user_controller.dart loadAuthSession — '
            'no persisted auth session (user may not have completed Google Sign-In)',
      );
    }

    await loadAuthSession();

    if (!isLoggedIn) {
      return const AccessTokenResolution(
        failureStage: 'retrieval',
        failureLocation:
            'lib/controllers/user_controller.dart resolveAccessToken — '
            'isLoggedIn is false after loadAuthSession',
      );
    }

    if (accessToken.isNotEmpty) {
      return AccessTokenResolution(token: accessToken, source: 'session');
    }

    final resolved = readBackendString(backendLoginResponse, 'accessToken');
    if (resolved.isEmpty) {
      return const AccessTokenResolution(
        failureStage: 'hydration',
        failureLocation:
            'lib/controllers/user_controller.dart resolveAccessToken — '
            'accessToken empty in session and backendResponse '
            '(check lib/controllers/auth_controller.dart loginWithGoogle lines 53-58)',
      );
    }

    accessToken = resolved;
    update();
    return AccessTokenResolution(token: accessToken, source: 'backendResponse');
  }

  static String readBackendString(Map<String, dynamic> response, String key) {
    for (final map in _authResponseMaps(response)) {
      final value = map[key];
      if (value is String && value.isNotEmpty) return value;

      final tokens = map['tokens'];
      if (tokens is Map<String, dynamic>) {
        final tokenValue = tokens[key];
        if (tokenValue is String && tokenValue.isNotEmpty) return tokenValue;
      }
    }
    return '';
  }

  bool get isEmailVerified => readEmailVerified(backendLoginResponse);

  static bool readEmailVerified(Map<String, dynamic> response) {
    return _readBackendFlag(response, 'emailVerified');
  }

  static bool _readBackendFlag(Map<String, dynamic> response, String key) {
    for (final map in _authResponseMaps(response)) {
      final value = map[key];
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      if (value is num) return value != 0;
    }
    return false;
  }

  static Iterable<Map<String, dynamic>> _authResponseMaps(
    Map<String, dynamic> response,
  ) sync* {
    yield response;

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      yield data;
      final nestedUser = data['user'];
      if (nestedUser is Map<String, dynamic>) yield nestedUser;
    }

    final user = response['user'];
    if (user is Map<String, dynamic>) yield user;
  }

  Future<void> _loadCalorieAdjustment() async {
    user.manualCalorieAdjustment = await _storage.loadCalorieAdjustment();
  }

  Future<void> _loadNutritionTargets() async {
    final saved = await _storage.loadNutritionTargets();
    if (saved.isEmpty) return;

    user.nutritionPlanBaseCalories = saved['baseCalories'];
    user.nutritionPlanDailyCalories = saved['dailyCalories'];
    user.nutritionPlanProteinG = saved['proteinG'];
    user.nutritionPlanCarbsG = saved['carbsG'];
    user.nutritionPlanFatG = saved['fatG'];
  }

  Future<void> _persistCalorieAdjustment() async {
    await _storage.saveCalorieAdjustment(user.manualCalorieAdjustment);
  }

  Future<void> _persistNutritionTargets() async {
    await _storage.saveNutritionTargets(
      baseCalories: user.nutritionPlanBaseCalories,
      dailyCalories: user.nutritionPlanDailyCalories,
      proteinG: user.nutritionPlanProteinG,
      carbsG: user.nutritionPlanCarbsG,
      fatG: user.nutritionPlanFatG,
    );
  }

  void _notifyCalorieGoalChanged() {
    calorieGoalRevision.value++;
    _notifyDashboard();
  }

  Future<void> _loadHealthProblem() async {
    final saved = await _storage.loadHealthConcerns();
    if (saved.isEmpty) return;

    user.healthConcerns = saved;
    update();
  }

  Future<void> pickProfilePhoto(ImageSource source) async {
    final file = await _imagePicker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    user.profilePhotoBytes = await file.readAsBytes();
    update();
  }

  void removeProfilePhoto() {
    user.profilePhotoBytes = null;
    update();
  }

  Future<void> showProfilePhotoOptions(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            if (user.profilePhotoBytes != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  removeProfilePhoto();
                },
              ),
          ],
        ),
      ),
    );
    if (source != null) await pickProfilePhoto(source);
  }

  void selectGoal(GoalType goal) {
    user.goal = goal;
    if (goal == GoalType.maintainWeight) {
      user.manualGoalWeightKg = null;
    } else {
      user.manualGoalWeightKg = null;
    }
    update();
    scheduleOnboardingDraftSave();
  }

  /// Sets [user.goal] from how [targetKg] compares to current weight.
  void inferGoalFromWeight(double targetKg) {
    final current = user.weightKg.toDouble();
    final diff = targetKg - current;
    if (diff.abs() < 0.1) {
      user.goal = GoalType.maintainWeight;
      user.manualGoalWeightKg = null;
    } else if (diff < 0) {
      user.goal = GoalType.loseWeight;
    } else {
      user.goal = GoalType.gainWeight;
    }
    update();
  }

  void setGoalWeight(double kg, {required bool manual}) {
    if (manual) {
      user.manualGoalWeightKg = kg.clamp(40.0, 200.0);
    } else {
      user.manualGoalWeightKg = null;
    }
    update();
    scheduleOnboardingDraftSave();
  }

  void useRecommendedGoalWeight() {
    user.manualGoalWeightKg = null;
    update();
    scheduleOnboardingDraftSave();
  }

  void onProfileUpdated() {
    if (user.goal == GoalType.maintainWeight) {
      user.manualGoalWeightKg = null;
    }
    update();
  }

  void syncWeightFromProfile() {
    if (Get.isRegistered<TrackerController>()) {
      Get.find<TrackerController>().updateWeight(user.weightKg.toDouble());
    }
  }

  Future<String?> fetchProfile() async {
    if (isLoadingProfile) return null;

    final token = await resolveAccessToken();
    if (token == null || token.isEmpty) {
      return 'Sign in to load your profile.';
    }

    isLoadingProfile = true;
    update();

    try {
      final response = await _onboardingRepository.fetchOnboarding(
        accessToken: token,
      );
      _applyOnboardingResponse(response);
      syncWeightFromProfile();
      return null;
    } on OnboardingApiException catch (error) {
      debugPrint('UserController: fetchProfile failed: $error');
      return error.message;
    } catch (error) {
      debugPrint('UserController: fetchProfile failed: $error');
      return 'Unable to load your profile. Please try again.';
    } finally {
      isLoadingProfile = false;
      update();
    }
  }

  Future<PickTargetDateResult> pickTargetDate(
    BuildContext context, {
    ProfileSyncSnapshot? syncBaseline,
  }) async {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: user.targetDate.isBefore(today) ? today : user.targetDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return const PickTargetDateResult.cancelled();

    final newDate = DateTime(picked.year, picked.month, picked.day);
    final changed =
        !(newDate.year == user.targetDate.year &&
            newDate.month == user.targetDate.month &&
            newDate.day == user.targetDate.day);
    user.targetDate = newDate;
    update();

    if (!changed) return const PickTargetDateResult.unchanged();

    if (syncBaseline != null) {
      final error = await patchGoalProfileIfChanged(syncBaseline);
      if (error != null) return PickTargetDateResult.failed(error);
    }
    return const PickTargetDateResult.saved();
  }

  void selectActivity(ActivityLevel level) {
    user.activityLevel = level;
    update();
    scheduleOnboardingDraftSave();
  }

  Future<void> saveHealthConcerns(List<HealthConcern> concerns) async {
    user.healthConcerns = List<HealthConcern>.from(concerns);
    update();
    await _storage.saveHealthConcerns(concerns);
  }

  @Deprecated('Use saveHealthConcerns')
  Future<void> saveHealthProblem({
    required String category,
    required String description,
    String? duration,
    String? severity,
    String? medication,
  }) async {
    if (category == HealthConcern.noneCategory) {
      await saveHealthConcerns([HealthConcern.none()]);
      return;
    }

    final categories = category
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    await saveHealthConcerns(
      categories
          .map(
            (value) => HealthConcern(
              category: value,
              description: description,
              duration: duration,
              severity: severity,
              medication: medication,
            ),
          )
          .toList(),
    );
  }

  void adjustCalorieGoal(int delta) {
    final target = (user.dailyCalorieGoal + delta).clamp(
      minDailyCalories,
      maxDailyCalories,
    );

    if (user.nutritionPlanDailyCalories != null) {
      user.nutritionPlanDailyCalories = target;
      unawaited(_persistNutritionTargets());
    } else {
      user.manualCalorieAdjustment = target - user.calculatedDailyCalorieGoal;
      unawaited(_persistCalorieAdjustment());
    }

    update();
    _notifyCalorieGoalChanged();
  }

  void resetCalorieAdjustment() {
    if (user.nutritionPlanBaseCalories != null) {
      user.nutritionPlanDailyCalories = user.nutritionPlanBaseCalories;
      unawaited(_persistNutritionTargets());
    } else {
      user.manualCalorieAdjustment = 0;
      unawaited(_persistCalorieAdjustment());
    }

    update();
    _notifyCalorieGoalChanged();
  }

  Future<void> applyNutritionPlan(NutritionPlanModel plan) async {
    _captureUserOnboardingGoalWeightIfNeeded();

    if (plan.calories > 0) {
      user.nutritionPlanBaseCalories = plan.calories;
      user.nutritionPlanDailyCalories = plan.calories;
      user.manualCalorieAdjustment = 0;
      await _persistCalorieAdjustment();
    }

    if (plan.proteinG > 0) user.nutritionPlanProteinG = plan.proteinG;
    if (plan.carbsG > 0) user.nutritionPlanCarbsG = plan.carbsG;
    if (plan.fatG > 0) user.nutritionPlanFatG = plan.fatG;
    if (plan.targetWeightKg != null) {
      _storeAiRecommendedGoalWeight(plan.targetWeightKg!);
    }

    await _persistNutritionTargets();
    update();
    _notifyCalorieGoalChanged();
  }

  void _captureUserOnboardingGoalWeightIfNeeded() {
    if (userOnboardingGoalWeightKg != null) return;
    if (user.goal == GoalType.maintainWeight) {
      userOnboardingGoalWeightKg = user.weightKg.toDouble();
      return;
    }
    if (user.manualGoalWeightKg != null) {
      userOnboardingGoalWeightKg = user.manualGoalWeightKg;
    }
  }

  void _storeAiRecommendedGoalWeight(double kg) {
    aiRecommendedGoalWeightKg = kg.clamp(40.0, 200.0);
    // Keep the user's onboarding target active by default.
    if (userOnboardingGoalWeightKg != null &&
        weightTargetSource.value == WeightTargetSource.user) {
      user.manualGoalWeightKg = userOnboardingGoalWeightKg;
    }
  }

  bool get shouldShowWeightTargetChoice {
    final goal = user.goal;
    if (goal == null || goal == GoalType.maintainWeight) return false;

    final userKg = resolvedUserGoalWeightKg;
    final aiKg = resolvedAiGoalWeightKg;
    if (userKg == null || aiKg == null) return false;
    return (userKg - aiKg).abs() >= 0.5;
  }

  double? get resolvedUserGoalWeightKg =>
      userOnboardingGoalWeightKg ?? user.manualGoalWeightKg;

  double? get resolvedAiGoalWeightKg =>
      aiRecommendedGoalWeightKg ??
      (user.goal == null || user.goal == GoalType.maintainWeight
          ? null
          : user.recommendedGoalWeightKg);

  Future<void> _ensurePlanMatchesSelectedWeightTarget({
    required String accessToken,
  }) async {
    if (!shouldShowWeightTargetChoice) return;
    if (weightTargetSource.value != WeightTargetSource.user) return;

    final targetKg = resolvedUserGoalWeightKg;
    if (targetKg == null) return;

    // If AI target is already effectively the same, no second create needed.
    final aiKg = resolvedAiGoalWeightKg;
    if (aiKg != null && (aiKg - targetKg).abs() < 0.5) return;

    final patchError = await patchOnboarding(
      OnboardingPatchModel.goalWeightOnly(
        targetKg,
        goalTimeline: user.goalTimeline,
        goalTimelineCustomDate: user.goalTimelineCustomDate,
      ),
    );
    if (patchError != null) {
      debugPrint(
        'UserController: could not sync user goal weight for plan: $patchError',
      );
      return;
    }

    user.manualGoalWeightKg = targetKg.clamp(40.0, 200.0);
    await _nutritionPlanRepository.createPlan(accessToken: accessToken);
    final refreshed = await _nutritionPlanRepository.fetchPlan(
      accessToken: accessToken,
    );
    await applyNutritionPlan(refreshed);
    _syncNutritionPlanController(refreshed);
  }

  Future<String?> selectWeightTarget(WeightTargetSource source) async {
    if (isRefreshingWeightTarget.value) return null;
    if (weightTargetSource.value == source) return null;

    final targetKg = switch (source) {
      WeightTargetSource.user => resolvedUserGoalWeightKg,
      WeightTargetSource.ai => resolvedAiGoalWeightKg,
    };
    if (targetKg == null) {
      return 'Unable to update your weight target.';
    }

    final previousSource = weightTargetSource.value;
    final previousWeight = user.manualGoalWeightKg;

    isRefreshingWeightTarget.value = true;
    weightTargetSource.value = source;
    user.manualGoalWeightKg = targetKg.clamp(40.0, 200.0);
    update();

    try {
      final token = await resolveAccessToken();
      if (token == null || token.isEmpty) {
        throw const OnboardingApiException('Please sign in again.');
      }

      final patchError = await patchOnboarding(
        OnboardingPatchModel.goalWeightOnly(
          user.manualGoalWeightKg!,
          goalTimeline: user.goalTimeline,
          goalTimelineCustomDate: user.goalTimelineCustomDate,
        ),
      );
      if (patchError != null) {
        weightTargetSource.value = previousSource;
        user.manualGoalWeightKg = previousWeight;
        update();
        return patchError;
      }

      await _nutritionPlanRepository.createPlan(accessToken: token);
      final plan = await _nutritionPlanRepository.fetchPlan(accessToken: token);
      await applyNutritionPlan(plan);
      _syncNutritionPlanController(plan);
      return null;
    } on NutritionPlanApiException catch (error) {
      weightTargetSource.value = previousSource;
      user.manualGoalWeightKg = previousWeight;
      update();
      return error.message;
    } on OnboardingApiException catch (error) {
      weightTargetSource.value = previousSource;
      user.manualGoalWeightKg = previousWeight;
      update();
      return error.message;
    } catch (error) {
      weightTargetSource.value = previousSource;
      user.manualGoalWeightKg = previousWeight;
      update();
      return 'Unable to update your plan. Please try again.';
    } finally {
      isRefreshingWeightTarget.value = false;
      update();
    }
  }

  void finishSetup() {
    unawaited(persistOnboardingStep(AppRoutes.healthProblem));
    Get.toNamed(AppRoutes.healthProblem);
  }

  static const _resumeableSetupRoutes = <String>{
    AppRoutes.personalDetails,
    AppRoutes.goalSetup,
    AppRoutes.goalAmount,
    AppRoutes.activityLevel,
    AppRoutes.healthProblem,
    AppRoutes.nutritionPlanLoading,
    AppRoutes.dailyCalorieGoal,
  };

  void resetPersonalDetailsForOnboarding() {
    user.age = 0;
    user.gender = '';
    user.heightCm = 0;
    user.weightKg = 0;
  }

  void markPersonalDetailsComplete() {
    personalDetailsComplete = true;
  }

  Map<String, dynamic> _onboardingDraftFromUser() {
    final target = user.targetDate;
    return {
      'userId': userId,
      'personalDetailsComplete': personalDetailsComplete,
      'age': user.age,
      'gender': user.gender,
      'heightCm': user.heightCm,
      'weightKg': user.weightKg,
      'goal': user.goal?.apiValue,
      'manualGoalWeightKg': user.manualGoalWeightKg,
      'activityLevel': user.activityLevel?.name,
      'targetDate':
          '${target.year.toString().padLeft(4, '0')}-'
          '${target.month.toString().padLeft(2, '0')}-'
          '${target.day.toString().padLeft(2, '0')}',
    };
  }

  void _applyPersonalDetailsFromDraft(Map<String, dynamic> draft) {
    if (draft['personalDetailsComplete'] == true) {
      personalDetailsComplete = true;
      final age = draft['age'];
      if (age is num) user.age = age.round();

      final gender = draft['gender'];
      if (gender is String && gender.isNotEmpty) user.gender = gender;

      final heightCm = draft['heightCm'];
      if (heightCm is num) user.heightCm = heightCm.round();

      final weightKg = draft['weightKg'];
      if (weightKg is num) user.weightKg = weightKg.round();
      return;
    }

    personalDetailsComplete = false;
    resetPersonalDetailsForOnboarding();

    final age = draft['age'];
    if (age is num && age > 0) user.age = age.round();

    final gender = draft['gender'];
    if (gender is String && gender.isNotEmpty) user.gender = gender;

    final heightCm = draft['heightCm'];
    if (heightCm is num && heightCm > 0) user.heightCm = heightCm.round();

    final weightKg = draft['weightKg'];
    if (weightKg is num && weightKg > 0) user.weightKg = weightKg.round();
  }

  void _applyOnboardingDraft(Map<String, dynamic> draft) {
    _applyPersonalDetailsFromDraft(draft);

    final goal = draft['goal'];
    if (goal is String) {
      user.goal = _parseGoalType(goal);
    }

    final manualGoal = draft['manualGoalWeightKg'];
    if (manualGoal == null) {
      user.manualGoalWeightKg = null;
    } else if (manualGoal is num) {
      user.manualGoalWeightKg = manualGoal.toDouble();
    }

    final activity = draft['activityLevel'];
    if (activity is String) {
      user.activityLevel = _parseActivityLevel(activity);
    } else if (activity == null) {
      user.activityLevel = null;
    }

    final targetRaw = draft['targetDate'];
    if (targetRaw is String) {
      final parsed = _parseApiDate(targetRaw);
      if (parsed != null) {
        user.targetDate = DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
  }

  Future<void> saveOnboardingDraft() async {
    _onboardingDraftSaveTimer?.cancel();
    await _storage.saveOnboardingDraft(_onboardingDraftFromUser());
    hasOnboardingDraft = true;
  }

  void scheduleOnboardingDraftSave() {
    if (!isLoggedIn || accessToken.isEmpty) return;
    _onboardingDraftSaveTimer?.cancel();
    _onboardingDraftSaveTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(saveOnboardingDraft());
    });
  }

  Future<void> persistOnboardingStep(String route) async {
    await saveOnboardingDraft();
    await _storage.saveOnboardingStep(route);
  }

  String? previousOnboardingRoute(String currentRoute) {
    if (currentRoute == AppRoutes.dailyCalorieGoal) {
      // Skip the loading screen so Back does not re-trigger setup.
      return AppRoutes.healthProblem;
    }
    if (currentRoute == AppRoutes.activityLevel) {
      final goal = user.goal;
      if (goal == null || goal == GoalType.maintainWeight) {
        return AppRoutes.goalSetup;
      }
      return AppRoutes.goalAmount;
    }
    final index = _setupRouteOrder.indexOf(currentRoute);
    if (index <= 0) return null;
    return _setupRouteOrder[index - 1];
  }

  /// Saves draft, marks the previous step as current, then opens that route.
  Future<void> goToPreviousOnboardingStep(String currentRoute) async {
    final previous = previousOnboardingRoute(currentRoute);
    if (previous == null) return;

    await persistOnboardingStep(previous);
    // Always navigate by name. Get.back() is unreliable here because the plan
    // loading screen uses offNamed (stack may not match the intended step),
    // and PopScope(canPop: false) on setup screens can interfere with pops.
    Get.offNamed(previous);
  }

  Future<void> restoreOnboardingProgress() async {
    final completed = await _storage.isOnboardingCompleted();
    if (completed) return;

    final draft = await _storage.loadOnboardingDraft();
    if (draft == null) return;

    final draftUserId = draft['userId'];
    if (draftUserId is String &&
        draftUserId.isNotEmpty &&
        userId.isNotEmpty &&
        draftUserId != userId) {
      await clearOnboardingProgress();
      return;
    }

    _applyOnboardingDraft(draft);
    hasOnboardingDraft = true;
  }

  Future<String> resolveSetupResumeRoute() async {
    final completed = await _storage.isOnboardingCompleted();
    if (completed) return AppRoutes.main;

    final step = await _storage.loadOnboardingStep();
    if (step != null && _resumeableSetupRoutes.contains(step)) {
      if (step == AppRoutes.goalAmount) {
        final goal = user.goal;
        if (goal == null) return AppRoutes.goalSetup;
        if (goal == GoalType.maintainWeight) return AppRoutes.activityLevel;
      }
      return step;
    }

    // Verified accounts with no pending step are fully set up.
    if (isEmailVerified) return AppRoutes.main;

    return AppRoutes.personalDetails;
  }

  Future<void> clearOnboardingProgress() async {
    _onboardingDraftSaveTimer?.cancel();
    hasOnboardingDraft = false;
    personalDetailsComplete = false;
    await _storage.clearOnboardingProgress();
  }

  @override
  void onClose() {
    _onboardingDraftSaveTimer?.cancel();
    super.onClose();
  }

  String? validateOnboardingPayload() {
    if (!isLoggedIn || accessToken.isEmpty) {
      return 'Please sign in with Google to complete setup.';
    }
    if (user.goal == null) {
      return 'Please select a fitness goal.';
    }
    if (user.activityLevel == null) {
      return 'Please select your activity level.';
    }
    if (user.age < 13 || user.age > 100) {
      return 'Please enter a valid age between 13 and 100.';
    }
    if (user.heightCm <= 0) {
      return 'Please enter a valid height.';
    }
    if (user.weightKg <= 0) {
      return 'Please enter a valid weight.';
    }
    if (!user.hasHealthConcernsConfigured) {
      return 'Please complete the health concern step.';
    }
    return null;
  }

  Future<String?> submitOnboarding() {
    return completeOnboardingWithProgress(onProgress: (_, _) {});
  }

  Future<String?> patchOnboarding(OnboardingPatchModel patch) async {
    await localProfileReady;
    await loadAuthSession();

    if (!isLoggedIn || accessToken.isEmpty) {
      return 'Please sign in to save changes.';
    }

    final payload = patch.toJson();
    if (payload.isEmpty) {
      debugPrint('UserController: PATCH skipped — no changed profile fields');
      return null;
    }

    while (isPatchingOnboarding) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }

    debugPrint(
      'UserController: PATCH onboarding fields: ${payload.keys.join(', ')}',
    );

    isPatchingOnboarding = true;
    update();

    try {
      final response = await _onboardingRepository.patchOnboarding(
        accessToken: accessToken,
        payload: payload,
      );
      _applyOnboardingResponse(response);
      return null;
    } on OnboardingApiException catch (error) {
      return error.message;
    } catch (error) {
      debugPrint('UserController: PATCH onboarding failed: $error');
      return 'Unable to save changes. Please try again.';
    } finally {
      isPatchingOnboarding = false;
      update();
    }
  }

  ProfileSyncSnapshot captureProfileSyncSnapshot() {
    return ProfileSyncSnapshot.fromUser(user);
  }

  Future<String?> patchProfileIfChanged(ProfileSyncSnapshot baseline) {
    return patchOnboarding(OnboardingPatchModel.profileDiff(user, baseline));
  }

  Future<String?> patchPersonalDetailsIfChanged(ProfileSyncSnapshot baseline) {
    return patchOnboarding(
      OnboardingPatchModel.personalDetailsDiff(user, baseline),
    );
  }

  Future<String?> patchGoalIfChanged(
    GoalType goal,
    ProfileSyncSnapshot baseline,
  ) {
    return patchOnboarding(OnboardingPatchModel.goalDiff(goal, baseline));
  }

  Future<String?> patchGoalProfileIfChanged(ProfileSyncSnapshot baseline) {
    return patchOnboarding(
      OnboardingPatchModel.goalProfileDiff(user, baseline),
    );
  }

  Future<String?> patchActivityLevelIfChanged(
    ActivityLevel level,
    ProfileSyncSnapshot baseline,
  ) {
    return patchOnboarding(
      OnboardingPatchModel.activityLevelDiff(level, baseline),
    );
  }

  Future<String?> patchHealthConcernsIfChanged(
    List<HealthConcern> concerns,
    ProfileSyncSnapshot baseline,
  ) {
    return patchOnboarding(
      OnboardingPatchModel.healthConcernsDiff(concerns, baseline),
    );
  }

  Future<String?> completeOnboardingWithProgress({
    required void Function(double progress, int activeStep) onProgress,
  }) async {
    if (isSubmittingOnboarding) return null;

    await localProfileReady;
    await loadAuthSession();

    final validationError = validateOnboardingPayload();
    if (validationError != null) return validationError;

    isSubmittingOnboarding = true;
    update();
    onProgress(0, 0);

    try {
      _captureUserOnboardingGoalWeightIfNeeded();
      final request = OnboardingRequestModel.fromUser(user);
      debugPrint(
        'UserController: calling onboarding API with token '
        '${accessToken.isNotEmpty ? 'present' : 'missing'}',
      );
      final response = await _onboardingRepository.submitOnboarding(
        accessToken: accessToken,
        request: request,
      );

      _applyOnboardingResponse(response);
      await _markEmailVerifiedLocally();
      onProgress(1 / 3, 1);

      debugPrint('UserController: calling POST nutrition plan API');
      await _nutritionPlanRepository.createPlan(accessToken: accessToken);
      onProgress(2 / 3, 2);

      debugPrint('UserController: calling GET nutrition plan API');
      final plan = await _nutritionPlanRepository.fetchPlan(
        accessToken: accessToken,
      );
      await applyNutritionPlan(plan);
      _syncNutritionPlanController(plan);
      await _ensurePlanMatchesSelectedWeightTarget(accessToken: accessToken);
      onProgress(1, 3);

      return null;
    } on OnboardingPayloadException catch (error) {
      return error.message;
    } on OnboardingApiException catch (error) {
      return error.message;
    } on NutritionPlanApiException catch (error) {
      return error.message;
    } catch (error) {
      return 'Unable to complete setup. Please check your connection and try again.';
    } finally {
      isSubmittingOnboarding = false;
      update();
    }
  }

  void _syncNutritionPlanController(NutritionPlanModel plan) {
    if (!Get.isRegistered<NutritionPlanController>()) {
      Get.put(NutritionPlanController(), permanent: true);
    }
    Get.find<NutritionPlanController>().setLoadedPlan(plan);
  }

  Future<void> finishOnboardingSetup() async {
    await _storage.saveOnboardingCompleted(completed: true);
    await clearOnboardingProgress();
    _notifyDashboard();
    MainController.resetHomeTabIfRegistered();
    Get.offAllNamed(AppRoutes.main);
  }

  void _applyOnboardingResponse(OnboardingResponseModel response) {
    final raw = response.raw;
    if (raw == null) return;

    for (final map in _onboardingResponseMaps(raw)) {
      final nestedPersonal = map['personalDetails'];
      if (nestedPersonal is Map<String, dynamic>) {
        _applyPersonalDetailsMap(nestedPersonal);
      } else if (map.containsKey('age') ||
          map.containsKey('heightCm') ||
          map.containsKey('weight')) {
        _applyPersonalDetailsMap(map);
      }

      final activity = _readResponseString(map, const [
        'activityLevel',
        'activity_level',
      ]);
      final parsedActivity = _parseActivityLevel(activity);
      if (parsedActivity != null) {
        user.activityLevel = parsedActivity;
      }

      final goal = map['goal'];
      if (goal is String) {
        user.goal = _parseGoalType(goal);
      } else if (goal is Map<String, dynamic>) {
        final goalType = _readResponseString(goal, const [
          'type',
          'goal',
          'goalType',
        ]);
        final parsedGoal = _parseGoalType(goalType);
        if (parsedGoal != null) {
          user.goal = parsedGoal;
        }

        final targetDate = _readResponseString(goal, const [
          'targetDate',
          'target_date',
        ]);
        final parsedDate = _parseApiDate(targetDate);
        if (parsedDate != null) {
          user.targetDate = parsedDate;
        }

        final isManual = _readResponseBool(goal, const [
          'isGoalWeightManual',
          'is_goal_weight_manual',
        ]);
        if (isManual != null && !isManual) {
          user.manualGoalWeightKg = null;
        }
      }

      final calories = _readResponseInt(map, const [
        'dailyCalorieGoal',
        'dailyCalories',
        'calories',
        'recommendedCalories',
      ]);
      if (calories != null) {
        user.nutritionPlanBaseCalories = calories;
        user.nutritionPlanDailyCalories = calories;
        user.manualCalorieAdjustment = 0;
        unawaited(_persistCalorieAdjustment());
        unawaited(_persistNutritionTargets());
      }

      final goalWeight = _readResponseDouble(map, const [
        'goalWeight',
        'targetWeight',
      ]);
      if (goalWeight != null) {
        _storeAiRecommendedGoalWeight(goalWeight);
      }
    }

    update();
    _notifyCalorieGoalChanged();
  }

  void _applyPersonalDetailsMap(Map<String, dynamic> personal) {
    final age = _readResponseInt(personal, const ['age']);
    if (age != null) user.age = age;

    final gender = _readResponseString(personal, const ['gender']);
    if (gender != null) user.gender = gender;

    final heightCm = _readResponseInt(personal, const [
      'heightCm',
      'height_cm',
    ]);
    if (heightCm != null) user.heightCm = heightCm;

    final weight = _readResponseDouble(personal, const [
      'weight',
      'weightKg',
      'weight_kg',
    ]);
    if (weight != null) user.weightKg = weight.round();
  }

  static Iterable<Map<String, dynamic>> _onboardingResponseMaps(
    Map<String, dynamic> response,
  ) sync* {
    yield response;

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      yield data;
      final profile = data['profile'];
      if (profile is Map<String, dynamic>) yield profile;
      final goal = data['goal'];
      if (goal is Map<String, dynamic>) yield goal;
      final personal = data['personalDetails'];
      if (personal is Map<String, dynamic>) yield personal;
    }

    final personal = response['personalDetails'];
    if (personal is Map<String, dynamic>) yield personal;

    final goal = response['goal'];
    if (goal is Map<String, dynamic>) yield goal;
  }

  static String? _readResponseString(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static bool? _readResponseBool(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      if (value is num) return value != 0;
    }
    return null;
  }

  static GoalType? _parseGoalType(String? value) {
    if (value == null) return null;
    return switch (value) {
      'loseWeight' => GoalType.loseWeight,
      'gainWeight' => GoalType.gainWeight,
      'maintainWeight' => GoalType.maintainWeight,
      _ => null,
    };
  }

  static ActivityLevel? _parseActivityLevel(String? value) {
    if (value == null) return null;
    for (final level in ActivityLevel.values) {
      if (level.name == value) return level;
    }
    return null;
  }

  static DateTime? _parseApiDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  static int? _readResponseInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.round();
      if (value is String) return int.tryParse(value);
    }
    return null;
  }

  static double? _readResponseDouble(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
    }
    return null;
  }

  Future<String?> completeOnboarding() async {
    await finishOnboardingSetup();
    return null;
  }

  Future<void> saveGoogleLoginDetails({
    String? userId,
    required String provider,
    required String email,
    required String name,
    required String accessToken,
    String? refreshToken,
    required Map<String, dynamic> backendResponse,
  }) async {
    isLoggedIn = true;
    this.userId = userId ?? '';
    authProvider = provider;
    this.accessToken = accessToken;
    this.refreshToken = refreshToken ?? '';
    backendLoginResponse = backendResponse;
    user.email = email;
    user.name = name;
    update();

    await _authRepository.saveSession(
      userId: this.userId,
      provider: authProvider,
      email: email,
      name: name,
      accessToken: accessToken,
      refreshToken: refreshToken,
      backendResponse: backendResponse,
    );

    unawaited(
      NotificationService.instance.syncTokenWithBackend(
        accessToken: accessToken,
      ),
    );

    // Streak unused — skip streak API on auth change.
    // if (Get.isRegistered<StreakController>()) {
    //   unawaited(Get.find<StreakController>().onAuthChanged());
    // }
  }

  Future<void> markOnboardingComplete() async {
    await _storage.saveOnboardingCompleted(completed: true);
    await clearOnboardingProgress();
  }

  Future<void> _markEmailVerifiedLocally() async {
    backendLoginResponse = Map<String, dynamic>.from(backendLoginResponse)
      ..['emailVerified'] = true;

    if (!isLoggedIn || accessToken.isEmpty) {
      update();
      return;
    }

    await _authRepository.saveSession(
      userId: userId,
      provider: authProvider,
      email: user.email,
      name: user.name,
      accessToken: accessToken,
      refreshToken: refreshToken.isEmpty ? null : refreshToken,
      backendResponse: backendLoginResponse,
    );
    update();
  }

  void notifyGoalConsumers() => _notifyDashboard();

  void _notifyDashboard() {
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().update();
    }
  }

  Future<bool> performDeleteAccount() async {
    if (isDeletingAccount || isLoggingOut) return false;

    isDeletingAccount = true;
    update();

    try {
      if (accessToken.isEmpty) await loadAuthSession();

      if (accessToken.isEmpty) {
        AppSnackbar.error('You are not signed in.', title: 'Delete failed');
        return false;
      }

      await _authRepository.deleteAccount(accessToken: accessToken);
      _clearInMemoryAuthState();
      user.resetToDefaults();

      MainController.resetHomeTabIfRegistered();
      Get.offAllNamed(AppRoutes.login);
      AppSnackbar.success(
        'Your account and data have been permanently removed.',
        title: 'Account deleted',
      );
      return true;
    } on AuthApiException catch (e) {
      AppSnackbar.error(e.message, title: 'Delete failed');
      return false;
    } catch (e) {
      AppSnackbar.error(
        'Could not delete your account. Please try again.',
        title: 'Delete failed',
      );
      return false;
    } finally {
      isDeletingAccount = false;
      update();
    }
  }

  Future<void> performLogout() async {
    if (isLoggingOut) return;

    isLoggingOut = true;
    update();

    try {
      if (refreshToken.isEmpty) await loadAuthSession();

      final result = await _authRepository.logout(refreshToken: refreshToken);
      _clearInMemoryAuthState();
      user.resetToDefaults();

      MainController.resetHomeTabIfRegistered();
      Get.offAllNamed(AppRoutes.login);

      if (result.backendRevoked) {
        AppSnackbar.success(
          'You have been logged out successfully.',
          title: 'Logged out',
        );
      } else if (result.hasBackendError) {
        AppSnackbar.info(
          'Could not reach the server, but your session was cleared.',
          title: 'Logged out locally',
        );
      } else {
        AppSnackbar.success('Your session was cleared.', title: 'Logged out');
      }
    } finally {
      isLoggingOut = false;
      update();
    }
  }

  void _clearInMemoryAuthState() {
    isLoggedIn = false;
    userId = '';
    authProvider = '';
    accessToken = '';
    refreshToken = '';
    backendLoginResponse = {};
    userOnboardingGoalWeightKg = null;
    aiRecommendedGoalWeightKg = null;
    weightTargetSource.value = WeightTargetSource.user;
    isRefreshingWeightTarget.value = false;
  }
}

enum WeightTargetSource { user, ai }

/// Outcome of [UserController.pickTargetDate].
enum PickTargetDateStatus { cancelled, unchanged, saved, failed }

class PickTargetDateResult {
  const PickTargetDateResult._(this.status, [this.error]);

  const PickTargetDateResult.cancelled()
    : this._(PickTargetDateStatus.cancelled);
  const PickTargetDateResult.unchanged()
    : this._(PickTargetDateStatus.unchanged);
  const PickTargetDateResult.saved() : this._(PickTargetDateStatus.saved);
  const PickTargetDateResult.failed(String error)
    : this._(PickTargetDateStatus.failed, error);

  final PickTargetDateStatus status;
  final String? error;
}
