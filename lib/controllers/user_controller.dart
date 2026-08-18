import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../models/access_token_resolution.dart';
import '../models/activity_level.dart';
import '../models/avatar_upload_result.dart';
import '../models/goal_type.dart';
import '../models/health_concern.dart';
import '../models/health_problem_api_mapper.dart';
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
import '../core/image_downscale.dart';
import '../core/media_url.dart';
import '../core/photo_permission.dart';
import '../core/pick_cropped_image.dart';
import '../core/wait_for_resume.dart';
import '../core/weight_goal_calculator.dart';
import '../services/auth_api_service.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import '../services/nutrition_plan_api_service.dart';
import '../services/onboarding_api_service.dart';
import '../widgets/profile_photo_sheet.dart';
import 'dashboard_controller.dart';
import 'food_controller.dart';
import 'main_controller.dart';
import 'notifications_controller.dart';
import 'nutrition_plan_controller.dart';
import 'scan_controller.dart';
// import 'streak_controller.dart';
import 'tracker_controller.dart';

class UserController extends GetxController with WidgetsBindingObserver {
  UserController({
    AuthRepository? authRepository,
    OnboardingRepository? onboardingRepository,
    NutritionPlanRepository? nutritionPlanRepository,
  }) : _authRepository = authRepository ?? AuthRepository(),
       _onboardingRepository = onboardingRepository ?? OnboardingRepository(),
       _nutritionPlanRepository =
           nutritionPlanRepository ?? NutritionPlanRepository();

  final user = UserModel();
  final _imagePicker = ImagePicker();
  final AuthRepository _authRepository;
  final OnboardingRepository _onboardingRepository;
  final NutritionPlanRepository _nutritionPlanRepository;
  bool isLoggedIn = false;
  bool isLoggingOut = false;
  bool isDeletingAccount = false;
  /// Drives the full-screen lock overlay during logout / account deletion.
  final isSessionBusy = false.obs;
  bool isSubmittingOnboarding = false;
  bool isPatchingOnboarding = false;
  bool isLoadingProfile = false;
  bool isUploadingAvatar = false;
  bool _avatarRemovedLocally = false;
  bool _pickingProfilePhoto = false;
  bool _recoveringLostAvatar = false;
  bool _avatarUiDirty = false;
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

  /// In-memory setup resume (not persisted — profile/onboarding API is source of truth).
  Map<String, dynamic>? _onboardingDraft;
  String? _onboardingStep;
  bool _onboardingCompleted = false;

  /// Last HTTP status from [fetchProfile] (e.g. 429 rate limit).
  int? lastProfileFetchStatusCode;
  Future<String?>? _fetchProfileInFlight;

  /// Bumped on login/logout so an in-flight profile fetch cannot apply to
  /// the next session (wrong calorie / weight goal after sign-in).
  int _sessionEpoch = 0;
  int _profileFetchEpoch = -1;

  /// Goal weight the user entered during onboarding (before AI recommendation).
  double? userOnboardingGoalWeightKg;

  /// AI / plan recommended target weight (does not replace the user's goal).
  double? aiRecommendedGoalWeightKg;

  /// Which target is currently driving the nutrition plan.
  final weightTargetSource = WeightTargetSource.user.obs;
  final isRefreshingWeightTarget = false.obs;

  /// Snapshot of API-synced goal state when the user opens Goals edit.
  /// Diffs / restores against this so lose/gain/maintain always PATCH correctly.
  _GoalEditCheckpoint? _goalEditCheckpoint;

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
    WidgetsBinding.instance.addObserver(this);
    _localProfileReady = Completer<void>();
    unawaited(_initializeLocalProfile());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || isClosed) return;
    if (!_avatarUiDirty) return;
    _avatarUiDirty = false;
    update();
  }

  Future<void> get localProfileReady =>
      _localProfileReady?.future ?? Future.value();

  Future<void> _initializeLocalProfile() async {
    try {
      await loadAuthSession();
      await restoreOnboardingProgress();
      _notifyCalorieGoalChanged();
      update();
    } finally {
      // Unlock startup routing immediately — do not wait on API/profile.
      if (_localProfileReady != null && !_localProfileReady!.isCompleted) {
        _localProfileReady!.complete();
      }
    }

    if (isLoggedIn && accessToken.isNotEmpty) {
      unawaited(hydrateProfileInBackground());
      unawaited(recoverLostAvatarIfNeeded());
    }
  }

  void _applyStoredAvatar(Map<String, dynamic> saved) {
    final url = saved['avatarUrl'];
    if (url is String && url.trim().isNotEmpty) {
      user.avatarUrl = url.trim();
    }
    final expiresAt = saved['avatarExpiresAt'];
    if (expiresAt is String && expiresAt.isNotEmpty) {
      user.avatarExpiresAt = DateTime.tryParse(expiresAt);
    }
  }

  /// Loads onboarding/profile from the API after the UI is already showing.
  Future<void> hydrateProfileInBackground({
    bool refreshGoalTarget = false,
  }) async {
    try {
      await fetchProfile(
        refreshGoalTarget: refreshGoalTarget,
        maxAttempts: 3,
      );
      await refreshAvatarUrl(force: true);
    } catch (error, stackTrace) {
      debugPrint(
        'UserController: background profile hydrate failed: $error\n$stackTrace',
      );
    } finally {
      _notifyCalorieGoalChanged();
      update();
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
      _onboardingCompleted = false;
      return;
    }

    isLoggedIn = true;
    userId = saved['userId'] as String? ?? '';
    authProvider = saved['provider'] as String? ?? '';
    accessToken = saved['accessToken'] as String? ?? '';
    refreshToken = saved['refreshToken'] as String? ?? '';
    user.email = saved['email'] as String? ?? user.email;
    user.name = saved['name'] as String? ?? user.name;
    _onboardingCompleted = saved['setupComplete'] == true;

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
    // Login payload still has Google's `picture`. Apply it first, then the
    // dedicated session avatarUrl so a custom upload from /auth/me wins.
    _applyAvatarFromResponse(backendLoginResponse);
    _applyStoredAvatar(saved);
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
    // Prefer an already-hydrated in-memory token. Waiting on [localProfileReady]
    // here deadlocks startup: _initializeLocalProfile → fetchProfile → here.
    if (isLoggedIn && accessToken.isNotEmpty) {
      return AccessTokenResolution(token: accessToken, source: 'memory');
    }

    final ready = _localProfileReady;
    if (ready == null || ready.isCompleted) {
      await localProfileReady;
    }

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

  /// Persisted / in-memory flag that setup finished (survives cold start via session).
  bool get isSetupComplete => _onboardingCompleted;

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

  Future<void> _persistCalorieAdjustment() async {
    // Calorie adjustment is server-managed via onboarding / nutrition plan APIs.
  }

  Future<void> _persistNutritionTargets() async {
    // Nutrition targets are server-managed via nutrition plan APIs.
  }

  void _notifyCalorieGoalChanged() {
    // Home calorie/macro Obx listens to calorieGoalRevision — bump it whenever
    // goals or plan fields change so the UI refreshes without a manual reload.
    calorieGoalRevision.value++;
    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().update();
    }
  }

  Future<void> pickProfilePhoto(ImageSource source) async {
    if (isUploadingAvatar || _pickingProfilePhoto) return;
    _pickingProfilePhoto = true;
    try {
      await _prepareForExternalImageCapture();

      final allowed = await ensureImageSourcePermission(source);
      if (!allowed) {
        if (!isClosed) {
          AppSnackbar.error(
            photoPermissionDeniedMessage(source),
            title: 'Permission needed',
          );
        }
        return;
      }

      XFile? file;
      try {
        // Do not pass maxWidth/imageQuality — the Android plugin decodes the
        // full camera bitmap to resize, which OOMs and kills MainActivity.
        file = await _imagePicker.pickImage(
          source: source,
          requestFullMetadata: false,
        );
      } catch (error, stackTrace) {
        debugPrint('UserController: image pick failed: $error\n$stackTrace');
        final resumed = await waitForAppResumed();
        if (resumed && !isClosed) {
          AppSnackbar.error(
            'Could not open the camera or gallery. Please try again.',
            title: 'Photo failed',
          );
        }
        return;
      }

      final resumed = await waitForAppResumed();
      if (isClosed || !resumed) return;

      if (file == null) {
        await recoverLostAvatarIfNeeded();
        return;
      }

      Uint8List scaled;
      try {
        final cropped = await cropPhotoAtPath(
          sourcePath: file.path,
          cropTitle: 'Crop profile photo',
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          lockAspectRatio: true,
          maxEdge: kAvatarMaxEdge,
        );
        final cropResumed = await waitForAppResumed();
        if (isClosed || !cropResumed) return;
        if (cropped == null) return;

        scaled = cropped.isEmpty
            ? await downscaleImageBytes(await file.readAsBytes())
            : await downscaleImageBytes(cropped);
      } catch (error, stackTrace) {
        debugPrint('UserController: photo read failed: $error\n$stackTrace');
        AppSnackbar.error(
          'Could not read that photo. Please try another one.',
          title: 'Photo failed',
        );
        return;
      }
      if (scaled.isEmpty || isClosed) return;
      await _uploadAvatarBytes(scaled);
    } finally {
      _pickingProfilePhoto = false;
    }
  }

  Future<void> recoverLostAvatarIfNeeded() async {
    if (_pickingProfilePhoto ||
        _recoveringLostAvatar ||
        isUploadingAvatar ||
        isClosed ||
        !isLoggedIn) {
      return;
    }
    _recoveringLostAvatar = true;
    try {
      final lost = await _imagePicker.retrieveLostData();
      if (lost.isEmpty) return;
      final file = lost.file ??
          ((lost.files != null && lost.files!.isNotEmpty)
              ? lost.files!.first
              : null);
      if (file == null) return;
      debugPrint('UserController: recovered profile photo after camera restart');
      final resumed = await waitForAppResumed();
      if (!resumed || isClosed) return;
      Uint8List bytes;
      try {
        final cropped = await cropPhotoAtPath(
          sourcePath: file.path,
          cropTitle: 'Crop profile photo',
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          lockAspectRatio: true,
          maxEdge: kAvatarMaxEdge,
        );
        final cropResumed = await waitForAppResumed();
        if (!cropResumed || isClosed) return;
        if (cropped == null) return;
        bytes = cropped.isEmpty ? await file.readAsBytes() : cropped;
      } catch (error, stackTrace) {
        debugPrint('UserController: recovered crop failed: $error\n$stackTrace');
        bytes = await file.readAsBytes();
      }
      if (bytes.isEmpty || isClosed) return;
      final scaled = await downscaleImageBytes(bytes);
      if (scaled.isEmpty || isClosed) return;
      await _uploadAvatarBytes(scaled);
    } catch (error, stackTrace) {
      debugPrint('UserController: retrieveLostData: $error\n$stackTrace');
    } finally {
      _recoveringLostAvatar = false;
    }
  }

  Future<void> _prepareForExternalImageCapture() async {
    if (Get.isRegistered<ScanController>()) {
      await Get.find<ScanController>().releaseHardwareCamera();
    }
    // Do not clear imageCache here. Evicting the current avatar bitmap and
    // then pausing for the gallery re-decodes it on a destroyed surface and
    // kills the Flutter engine on Android (Lost connection to device).
  }

  Future<void> _uploadAvatarBytes(Uint8List bytes) async {
    if (isClosed || isUploadingAvatar || bytes.isEmpty) return;

    final token = await resolveAccessToken();
    if (token == null || token.isEmpty || isClosed) return;

    // Keep the existing photo on screen and only show a spinner. Swapping in
    // a new MemoryImage before the surface is stable is what crashes re-upload.
    isUploadingAvatar = true;
    _refreshAvatarUi();
    try {
      final result = await _authRepository.uploadAvatar(
        accessToken: token,
        imageBytes: bytes,
        filename: avatarUploadFilename(bytes),
      );
      await waitForAppResumed();
      if (isClosed) return;
      user.profilePhotoBytes = bytes;
      _applyAvatarUrl(result.avatarUrl, expiresIn: result.expiresIn);
      _avatarRemovedLocally = false;
      await _persistCurrentAuthSession();
    } on AuthApiException catch (error) {
      if (isAppResumed) {
        AppSnackbar.error(error.message, title: 'Photo upload failed');
      }
    } catch (error, stackTrace) {
      debugPrint('UserController: avatar upload failed: $error\n$stackTrace');
      if (isAppResumed) {
        AppSnackbar.error(
          'Could not upload your photo. Please try again.',
          title: 'Photo upload failed',
        );
      }
    } finally {
      isUploadingAvatar = false;
      if (!isClosed) _refreshAvatarUi();
    }
  }

  void removeProfilePhoto() {
    user.profilePhotoBytes = null;
    user.avatarUrl = null;
    user.avatarExpiresAt = null;
    _avatarRemovedLocally = true;
    unawaited(_persistCurrentAuthSession());
    update();
  }

  Future<void> refreshAvatarUrl({bool force = false}) async {
    if (_avatarRemovedLocally && !force) return;
    final token = await resolveAccessToken();
    if (token == null || token.isEmpty) return;

    final expiresAt = user.avatarExpiresAt;
    final stillFresh =
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now().add(const Duration(minutes: 5)));
    final currentIsGoogle = MediaUrl.isGooglePhoto(user.avatarUrl);
    // Google photos are a fallback. Always re-read /auth/me so a custom
    // `avatars/…` upload is not stuck behind the Google Sign-In picture.
    if (!force &&
        !currentIsGoogle &&
        user.avatarUrl != null &&
        stillFresh) {
      return;
    }

    try {
      final me = await _authRepository.fetchMe(accessToken: token);
      _applyAvatarFromResponse(me);
      await _persistCurrentAuthSession();
    } catch (error, stackTrace) {
      debugPrint('UserController: avatar refresh failed: $error\n$stackTrace');
    }
  }

  void _applyAvatarFromResponse(Map<String, dynamic>? response) {
    final url = AvatarUploadResult.urlFromResponse(response);
    if (url == null || url.isEmpty) return;
    if (!MediaUrl.shouldReplaceAvatar(user.avatarUrl, url)) return;
    _applyAvatarUrl(
      url,
      expiresIn: AvatarUploadResult.expiresInFromResponse(response),
    );
  }

  void _applyAvatarUrl(String url, {int? expiresIn}) {
    user.avatarUrl = url;
    if (MediaUrl.isGooglePhoto(url)) {
      // Do not treat Google's photo as a fresh custom avatar. /auth/me must
      // still run after login so the uploaded S3 object can win.
      user.avatarExpiresAt = null;
    } else {
      final ttl = expiresIn ?? 3600;
      if (ttl > 0) {
        user.avatarExpiresAt = DateTime.now().add(Duration(seconds: ttl));
      }
    }
    if (MediaUrl.isUploadedAvatar(url)) {
      _rememberUploadedAvatarInLoginPayload(url);
    }
  }

  /// Stops the original Google login JSON from overwriting a custom upload
  /// the next time the session is loaded or persisted.
  void _rememberUploadedAvatarInLoginPayload(String url) {
    Map<String, dynamic> copyMap(Map<dynamic, dynamic> source) =>
        Map<String, dynamic>.from(source);

    void writeAvatar(Map<String, dynamic> map) {
      map['avatarUrl'] = url;
      map.remove('picture');
      map.remove('photoUrl');
      map.remove('photo_url');
    }

    final next = copyMap(backendLoginResponse);
    writeAvatar(next);
    final data = next['data'];
    if (data is Map) {
      final dataMap = copyMap(data);
      writeAvatar(dataMap);
      final nestedUser = dataMap['user'];
      if (nestedUser is Map) {
        final userMap = copyMap(nestedUser);
        writeAvatar(userMap);
        dataMap['user'] = userMap;
      }
      next['data'] = dataMap;
    }
    final nestedUser = next['user'];
    if (nestedUser is Map) {
      final userMap = copyMap(nestedUser);
      writeAvatar(userMap);
      next['user'] = userMap;
    }
    backendLoginResponse = next;
  }

  void _refreshAvatarUi() {
    if (isClosed) return;
    if (isAppResumed) {
      _avatarUiDirty = false;
      update();
      return;
    }
    _avatarUiDirty = true;
  }

  Future<void> showProfilePhotoOptions(BuildContext context) async {
    if (isUploadingAvatar) return;
    // The photo sheet is a modal route, so MainView freezes/remounts Profile
    // while it is open. Do not reuse Profile's BuildContext after the sheet.
    final navigator = Navigator.of(context, rootNavigator: true);
    final action = await showProfilePhotoSheet(context: context, user: user);
    if (action == null || isClosed) return;

    if (action == ProfilePhotoAction.remove) {
      removeProfilePhoto();
      return;
    }

    // Wait for the sheet route to finish disposing before opening native UI
    // or another overlay. Opening during teardown can drop GetMaterialApp's
    // navigator child and leave Profile on a white screen.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (isClosed || isUploadingAvatar || !navigator.mounted) return;

    if (action == ProfilePhotoAction.view) {
      await showProfilePhotoViewer(context: navigator.context, user: user);
      return;
    }

    await pickProfilePhoto(
      action == ProfilePhotoAction.camera
          ? ImageSource.camera
          : ImageSource.gallery,
    );
  }

  /// True while editing goals from My Goals (in-memory journey, API commit on save).
  bool get isGoalEditFromProfile => _goalEditCheckpoint != null;

  /// Capture API-synced goal state before the user mutates lose/gain/maintain.
  void beginGoalEditFromProfile() {
    if (_goalEditCheckpoint != null) return;
    final u = user;
    _goalEditCheckpoint = _GoalEditCheckpoint(
      syncBaseline: ProfileSyncSnapshot.fromUser(u),
      goal: u.goal,
      pinnedGoalType: u.pinnedGoalType,
      pinnedGoalWeightKg: u.pinnedGoalWeightKg,
      manualGoalWeightKg: u.manualGoalWeightKg,
      goalStartWeightKg: u.goalStartWeightKg,
      targetDate: DateTime(
        u.targetDate.year,
        u.targetDate.month,
        u.targetDate.day,
      ),
    );
  }

  /// Discard in-memory goal edits and restore the pre-edit API snapshot.
  void cancelGoalEditFromProfile() {
    final cp = _goalEditCheckpoint;
    if (cp == null) return;
    user.goal = cp.goal;
    user.pinnedGoalType = cp.pinnedGoalType;
    user.pinnedGoalWeightKg = cp.pinnedGoalWeightKg;
    user.manualGoalWeightKg = cp.manualGoalWeightKg;
    user.goalStartWeightKg = cp.goalStartWeightKg;
    user.targetDate = cp.targetDate;
    _goalEditCheckpoint = null;
    update();
    _notifyCalorieGoalChanged();
  }

  void commitGoalEditFromProfile() {
    _goalEditCheckpoint = null;
  }

  /// Baseline for goal PATCH: journey start when editing from profile.
  ProfileSyncSnapshot baselineForGoalProfileSave() {
    return _goalEditCheckpoint?.syncBaseline ?? captureProfileSyncSnapshot();
  }

  /// After a successful profile goal save, return to My Goals (not Goal Setup).
  void popToMyGoals() {
    if (Get.currentRoute == AppRoutes.myGoals) return;
    Get.until(
      (route) =>
          route.settings.name == AppRoutes.myGoals || route.isFirst,
    );
    if (Get.currentRoute != AppRoutes.myGoals) {
      Get.offNamed(AppRoutes.myGoals);
    }
  }

  void selectGoal(GoalType goal, {bool persistDraft = true}) {
    final previous = user.goal;
    user.goal = goal;
    user.pinnedGoalType = goal;

    if (goal == GoalType.maintainWeight) {
      // Pin current weight once — later weigh-ins must not move this target.
      final current = resolvedCurrentWeightKg();
      if (current > 0) {
        user.pinGoalWeight(current, goalType: GoalType.maintainWeight);
      } else {
        user.pinnedGoalType = GoalType.maintainWeight;
      }
      _captureGoalStartWeight();
    } else {
      final current = resolvedCurrentWeightKg();
      final pinned = user.pinnedGoalWeightKg;
      final pinStillValid = pinned != null &&
          current > 0 &&
          WeightGoalCalculator.targetMatchesGoal(
            goal: goal,
            currentKg: current,
            targetKg: pinned,
          );

      if (pinStillValid) {
        user.pinGoalWeight(pinned, goalType: goal);
      } else if (current > 0) {
        // Goal type changed — retarget from live weight (not stale profile kg).
        user.pinGoalWeight(
          recommendedTargetKg(goal),
          goalType: goal,
        );
        _captureGoalStartWeight();
      } else if (previous != goal) {
        // No reliable current weight yet — drop stale pin from the old goal.
        user.clearPinnedGoalWeight();
        user.pinnedGoalType = goal;
        user.goal = goal;
      }
    }
    update();
    _notifyCalorieGoalChanged();
    if (persistDraft) scheduleOnboardingDraftSave();
  }

  /// Live weight for goal checks: latest log → tracker display → profile.
  double resolvedCurrentWeightKg() {
    if (Get.isRegistered<TrackerController>()) {
      final tracker = Get.find<TrackerController>();
      if (tracker.weightEntries.isNotEmpty) {
        final latest = tracker.weightEntries.last.kg;
        if (latest > 0) return latest;
      }
      if (tracker.currentWeight.value > 0) {
        return tracker.currentWeight.value;
      }
    }
    return user.weightKg?.toDouble() ?? 0;
  }

  /// Recommended target from live current weight (API progress baseline).
  double recommendedTargetKg([GoalType? forGoal]) {
    final g = forGoal ?? user.pinnedGoalType ?? user.goal;
    final current = resolvedCurrentWeightKg();
    if (current <= 0) {
      return user.pinnedGoalWeightKg ??
          user.manualGoalWeightKg ??
          user.weightKg?.toDouble() ??
          0;
    }
    return WeightGoalCalculator.recommendedGoalWeight(
      goal: g,
      currentWeightKg: current,
      heightCm: user.heightCm,
      age: user.age,
      gender: user.gender,
    );
  }

  /// Sets [user.goal] from how [targetKg] compares to current weight.
  void inferGoalFromWeight(double targetKg) {
    final current = resolvedCurrentWeightKg();
    final diff = targetKg - current;
    if (current <= 0) return;
    if (diff.abs() < 0.1) {
      user.goal = GoalType.maintainWeight;
      user.pinGoalWeight(
        targetKg > 0 ? targetKg : current,
        goalType: GoalType.maintainWeight,
      );
    } else if (diff < 0) {
      user.goal = GoalType.loseWeight;
    } else {
      user.goal = GoalType.gainWeight;
    }
    update();
    _notifyCalorieGoalChanged();
  }

  /// Fills a missing goal type from current vs target weight.
  void ensureGoalFromWeight() {
    if (user.goal != null) return;
    if (resolvedCurrentWeightKg() <= 0) return;
    inferGoalFromWeight(user.goalWeightKg);
  }

  void setGoalWeight(double kg, {required bool manual}) {
    final previousTarget = user.goalWeightKg;
    user.pinGoalWeight(kg, goalType: user.goal);
    final newTarget = user.goalWeightKg;
    // New journey baseline whenever the active target meaningfully changes.
    if ((previousTarget - newTarget).abs() > 0.05 ||
        user.goalStartWeightKg == null) {
      _captureGoalStartWeight();
    }
    update();
    _notifyCalorieGoalChanged();
    if (!isGoalEditFromProfile) scheduleOnboardingDraftSave();
  }

  void useRecommendedGoalWeight() {
    final previousTarget = user.goalWeightKg;
    // Pin once for lose/gain/maintain — do not let it track live weigh-ins.
    user.pinGoalWeight(recommendedTargetKg(), goalType: user.goal);
    final newTarget = user.goalWeightKg;
    if ((previousTarget - newTarget).abs() > 0.05 ||
        user.goalStartWeightKg == null) {
      _captureGoalStartWeight();
    }
    update();
    _notifyCalorieGoalChanged();
    if (!isGoalEditFromProfile) scheduleOnboardingDraftSave();
  }

  void onProfileUpdated() {
    update();
    _notifyCalorieGoalChanged();
  }

  double _currentWeightKg() => resolvedCurrentWeightKg();

  void _captureGoalStartWeight() {
    final current = _currentWeightKg();
    if (current <= 0) return;
    user.goalStartWeightKg = current;
  }

  /// Seeds tracker only when there is no weight history yet.
  void syncWeightFromProfile() {
    if (!Get.isRegistered<TrackerController>()) return;
    final tracker = Get.find<TrackerController>();
    if (tracker.weightEntries.isNotEmpty) return;
    if ((user.weightKg ?? 0) <= 0) return;
    tracker.updateWeight(user.weightKg!.toDouble());
  }

  Future<String?> fetchProfile({
    bool refreshGoalTarget = false,
    int maxAttempts = 3,
  }) {
    if (_fetchProfileInFlight != null && _profileFetchEpoch == _sessionEpoch) {
      return _fetchProfileInFlight!;
    }

    final epoch = _sessionEpoch;
    _profileFetchEpoch = epoch;
    final future = _fetchProfile(
      refreshGoalTarget: refreshGoalTarget,
      maxAttempts: maxAttempts,
      epoch: epoch,
    );
    _fetchProfileInFlight = future;
    return future.whenComplete(() {
      if (identical(_fetchProfileInFlight, future)) {
        _fetchProfileInFlight = null;
      }
    });
  }

  Future<String?> _fetchProfile({
    required bool refreshGoalTarget,
    required int maxAttempts,
    required int epoch,
  }) async {
    final token = await resolveAccessToken();
    if (token == null || token.isEmpty) {
      return 'Sign in to load your profile.';
    }
    if (epoch != _sessionEpoch) {
      return 'Profile fetch cancelled.';
    }

    isLoadingProfile = true;
    lastProfileFetchStatusCode = null;
    update();

    try {
      OnboardingApiException? lastError;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        if (epoch != _sessionEpoch) return 'Profile fetch cancelled.';
        try {
          final response = await _onboardingRepository.fetchOnboarding(
            accessToken: token,
          );
          if (epoch != _sessionEpoch) return 'Profile fetch cancelled.';
          lastProfileFetchStatusCode = 200;
          // Once the user has a pinned target (lose/gain/maintain), casual profile
          // refreshes must not adopt server mutations caused by weight logs
          // (goalWeight rewritten ≈ current).
          final hasPinnedTarget = user.pinnedGoalWeightKg != null &&
              (user.pinnedGoalType ?? user.goal) != null;
          _applyOnboardingResponse(
            response,
            applyGoalFields: refreshGoalTarget || !hasPinnedTarget,
          );
          syncWeightFromProfile();
          // Profile loaded from API — treat setup as done when personal basics exist.
          if (user.hasProfileBasics) {
            _onboardingCompleted = true;
            _onboardingStep = null;
            _onboardingDraft = null;
            hasOnboardingDraft = false;
            unawaited(_persistCurrentAuthSession());
          }
          return null;
        } on OnboardingApiException catch (error) {
          lastError = error;
          lastProfileFetchStatusCode = error.statusCode;
          debugPrint(
            'UserController: fetchProfile failed '
            '(attempt $attempt/$maxAttempts): $error',
          );
          final isRateLimited = error.statusCode == 429;
          final isTransient = isRateLimited ||
              error.statusCode == 503 ||
              error.statusCode == 502;
          if (!isTransient || attempt >= maxAttempts) {
            return error.message;
          }
          // Back off before retry — avoids compounding API rate limits.
          await Future<void>.delayed(Duration(milliseconds: 700 * attempt));
        }
      }
      return lastError?.message ?? 'Unable to load your profile. Please try again.';
    } catch (error) {
      debugPrint('UserController: fetchProfile failed: $error');
      return 'Unable to load your profile. Please try again.';
    } finally {
      if (epoch == _sessionEpoch) {
        isLoadingProfile = false;
        update();
      }
    }
  }

  /// Drops a restored session that the API rejected (401/403) without navigating.
  Future<void> clearInvalidSession() async {
    _clearApiOwnedControllers();
    _clearInMemoryAuthState();
    user.resetToDefaults();
    await _authRepository.clearLocalAuthData();
    update();
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
    // Persisted via onboarding / profile API — not SharedPreferences.
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

  /// Applies calories/macros from the nutrition plan.
  ///
  /// [applyTargetWeight] must only be true during onboarding / explicit
  /// weight-target choice — routine home loads must not rewrite the user's goal.
  Future<void> applyNutritionPlan(
    NutritionPlanModel plan, {
    bool applyTargetWeight = false,
  }) async {
    if (!isLoggedIn) return;
    if (applyTargetWeight) {
      _captureUserOnboardingGoalWeightIfNeeded();
    }

    if (plan.calories > 0) {
      user.nutritionPlanBaseCalories = plan.calories;
      user.nutritionPlanDailyCalories = plan.calories;
      user.manualCalorieAdjustment = 0;
      await _persistCalorieAdjustment();
    }

    if (plan.proteinG > 0) user.nutritionPlanProteinG = plan.proteinG;
    if (plan.carbsG > 0) user.nutritionPlanCarbsG = plan.carbsG;
    if (plan.fatG > 0) user.nutritionPlanFatG = plan.fatG;

    if (applyTargetWeight && plan.targetWeightKg != null) {
      _storeAiRecommendedGoalWeight(plan.targetWeightKg!);
    } else if (plan.targetWeightKg != null) {
      // Remember AI suggestion for comparison UI only — do not pin/replace goal.
      aiRecommendedGoalWeightKg = plan.targetWeightKg!.clamp(40.0, 200.0);
    }

    await _persistNutritionTargets();
    update();
    _notifyCalorieGoalChanged();
  }

  void _captureUserOnboardingGoalWeightIfNeeded() {
    if (userOnboardingGoalWeightKg != null) return;
    if (user.goal == GoalType.maintainWeight) {
      userOnboardingGoalWeightKg =
          user.pinnedGoalWeightKg ?? user.weightKg?.toDouble();
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
      user.pinGoalWeight(userOnboardingGoalWeightKg!);
      if (user.goalStartWeightKg == null) {
        _captureGoalStartWeight();
      }
    }
  }

  /// Applies the server's goal/target weight as the active home + profile target.
  /// Lose/gain/maintain targets are pinned so logging weight cannot move the goal.
  void _applyServerGoalWeight(double kg, {bool? isManual}) {
    final clamped = kg.clamp(40.0, 200.0);
    aiRecommendedGoalWeightKg = clamped;

    final effectiveGoal = user.pinnedGoalType ?? user.goal;
    if (effectiveGoal == GoalType.maintainWeight) {
      // Keep an existing maintain pin — weight API must not chase live weight.
      if (user.pinnedGoalWeightKg != null) {
        user.goal = GoalType.maintainWeight;
        user.pinnedGoalType = GoalType.maintainWeight;
        return;
      }
      user.pinGoalWeight(clamped, goalType: GoalType.maintainWeight);
      return;
    }

    if (isManual == false && userOnboardingGoalWeightKg != null) {
      user.pinGoalWeight(
        userOnboardingGoalWeightKg!,
        goalType: user.goal,
      );
    } else {
      user.pinGoalWeight(clamped, goalType: user.goal);
    }

    if (user.goalStartWeightKg == null) {
      _captureGoalStartWeight();
    }
  }

  /// Weight API mutates onboarding profile (often rewrites goalWeight ≈ current).
  /// Always re-assert the user's pinned target for lose/gain/maintain.
  Future<void> reaffirmPinnedGoalWeightAfterWeightLog() async {
    final goal = user.pinnedGoalType ?? user.goal;
    final pinned = user.pinnedGoalWeightKg ?? user.manualGoalWeightKg;
    if (goal == null || pinned == null) {
      debugPrint('UserController: skip goal reaffirm — no pinned target');
      return;
    }

    debugPrint(
      'UserController: reaffirming goal=${goal.apiValue} target=$pinned kg '
      'after weight log',
    );

    // Keep local pin intact even if the network call fails.
    user.goal = goal;
    user.pinGoalWeight(pinned, goalType: goal);
    update();
    _notifyCalorieGoalChanged();

    await patchOnboarding(
      OnboardingPatchModel.goalWeightOnly(
        pinned,
        goalType: goal,
        goalTimeline: user.goalTimeline,
        goalTimelineCustomDate: user.goalTimelineCustomDate,
        startWeightKg: user.goalStartWeightKg,
      ),
    );
    user.goal = goal;
    user.pinGoalWeight(pinned, goalType: goal);
    update();
    _notifyCalorieGoalChanged();
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
      userOnboardingGoalWeightKg ??
      user.pinnedGoalWeightKg ??
      user.manualGoalWeightKg;

  double? get resolvedAiGoalWeightKg =>
      aiRecommendedGoalWeightKg ??
      (user.goal == null || user.goal == GoalType.maintainWeight
          ? null
          : recommendedTargetKg());

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
        startWeightKg: user.goalStartWeightKg ?? _currentWeightKg(),
      ),
    );
    if (patchError != null) {
      debugPrint(
        'UserController: could not sync user goal weight for plan: $patchError',
      );
      return;
    }

    user.pinGoalWeight(targetKg);
    await _nutritionPlanRepository.createPlan(accessToken: accessToken);
    final refreshed = await _nutritionPlanRepository.fetchPlan(
      accessToken: accessToken,
    );
    await applyNutritionPlan(refreshed, applyTargetWeight: true);
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
    final previousPinned =
        user.pinnedGoalWeightKg ?? user.manualGoalWeightKg;

    isRefreshingWeightTarget.value = true;
    weightTargetSource.value = source;
    user.pinGoalWeight(targetKg);
    update();

    try {
      final token = await resolveAccessToken();
      if (token == null || token.isEmpty) {
        throw const OnboardingApiException('Please sign in again.');
      }

      final patchError = await patchOnboarding(
        OnboardingPatchModel.goalWeightOnly(
          user.goalWeightKg,
          goalTimeline: user.goalTimeline,
          goalTimelineCustomDate: user.goalTimelineCustomDate,
          startWeightKg: user.goalStartWeightKg ?? _currentWeightKg(),
        ),
      );
      if (patchError != null) {
        weightTargetSource.value = previousSource;
        if (previousPinned != null) {
          user.pinGoalWeight(previousPinned);
        } else {
          user.clearPinnedGoalWeight();
        }
        update();
        return patchError;
      }

      await _nutritionPlanRepository.createPlan(accessToken: token);
      final plan = await _nutritionPlanRepository.fetchPlan(accessToken: token);
      await applyNutritionPlan(plan, applyTargetWeight: true);
      _syncNutritionPlanController(plan);
      return null;
    } on NutritionPlanApiException catch (error) {
      weightTargetSource.value = previousSource;
      if (previousPinned != null) {
        user.pinGoalWeight(previousPinned);
      } else {
        user.clearPinnedGoalWeight();
      }
      update();
      return error.message;
    } on OnboardingApiException catch (error) {
      weightTargetSource.value = previousSource;
      if (previousPinned != null) {
        user.pinGoalWeight(previousPinned);
      } else {
        user.clearPinnedGoalWeight();
      }
      update();
      return error.message;
    } catch (error) {
      weightTargetSource.value = previousSource;
      if (previousPinned != null) {
        user.pinGoalWeight(previousPinned);
      } else {
        user.clearPinnedGoalWeight();
      }
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
    user.age = null;
    user.gender = null;
    user.heightCm = null;
    user.weightKg = null;
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
      'pinnedGoalWeightKg': user.pinnedGoalWeightKg,
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
    final pinnedGoal = draft['pinnedGoalWeightKg'];
    if (pinnedGoal is num) {
      user.pinGoalWeight(pinnedGoal.toDouble());
    } else if (manualGoal is num) {
      user.pinGoalWeight(manualGoal.toDouble());
    } else if (manualGoal == null && pinnedGoal == null) {
      user.clearPinnedGoalWeight();
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
    _onboardingDraft = _onboardingDraftFromUser();
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
    _onboardingStep = route;
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
    if (_onboardingCompleted) return;

    final draft = _onboardingDraft;
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
    // API profile / persisted setupComplete are the cold-start source of truth
    // (in-memory flags alone reset when the process dies).
    if (user.hasProfileBasics || _onboardingCompleted) {
      _onboardingCompleted = true;
      _onboardingStep = null;
      return AppRoutes.main;
    }

    final step = _onboardingStep;
    if (step != null && _resumeableSetupRoutes.contains(step)) {
      if (step == AppRoutes.goalAmount) {
        final goal = user.goal;
        if (goal == null) return AppRoutes.goalSetup;
        if (goal == GoalType.maintainWeight) return AppRoutes.activityLevel;
      }
      return step;
    }

    // Signed in but setup not finished — continue onboarding, never login.
    return AppRoutes.personalDetails;
  }

  Future<void> clearOnboardingProgress() async {
    _onboardingDraftSaveTimer?.cancel();
    hasOnboardingDraft = false;
    personalDetailsComplete = false;
    _onboardingDraft = null;
    _onboardingStep = null;
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
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
    final age = user.age;
    final heightCm = user.heightCm;
    final weightKg = user.weightKg;
    final gender = user.gender?.trim() ?? '';
    if (age == null || age < 13 || age > 100) {
      return 'Please enter a valid age between 13 and 100.';
    }
    if (heightCm == null || heightCm <= 0) {
      return 'Please enter a valid height.';
    }
    if (weightKg == null || weightKg <= 0) {
      return 'Please enter a valid weight.';
    }
    if (gender.isEmpty) {
      return 'Please select your gender.';
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
      _applyOnboardingResponse(
        response,
        applyGoalFields: patch.touchesGoalFields,
      );
      if (patch.shouldRefreshNutritionPlan) {
        // Goal / body / activity changes need a fresh nutrition plan so home
        // calories + macros update immediately.
        unawaited(_refreshNutritionPlanAfterProfileChange());
      }
      _notifyCalorieGoalChanged();
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

  /// Recreate + apply nutrition plan after a profile goal edit (API-only).
  Future<void> _refreshNutritionPlanAfterProfileChange() async {
    try {
      final token = await resolveAccessToken();
      if (token == null || token.isEmpty) return;

      await _nutritionPlanRepository.createPlan(accessToken: token);
      final plan = await _nutritionPlanRepository.fetchPlan(accessToken: token);
      await applyNutritionPlan(plan, applyTargetWeight: false);
      _syncNutritionPlanController(plan);
      debugPrint('UserController: nutrition plan refreshed after profile change');
    } catch (error, stackTrace) {
      debugPrint(
        'UserController: nutrition plan refresh failed: $error\n$stackTrace',
      );
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
      await applyNutritionPlan(plan, applyTargetWeight: true);
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
    _onboardingCompleted = true;
    await clearOnboardingProgress();
    await _persistCurrentAuthSession();
    _notifyDashboard();
    unawaited(
      AnalyticsService.logGoalCompleted(goalType: 'onboarding'),
    );
    MainController.resetHomeTabIfRegistered();
    Get.offAllNamed(AppRoutes.main);
  }

  void _applyOnboardingResponse(
    OnboardingResponseModel response, {
    bool applyGoalFields = true,
  }) {
    final raw = response.raw;
    if (raw == null) return;
    if (!_avatarRemovedLocally) {
      _applyAvatarFromResponse(raw);
    }

    // Weight-only / casual profile syncs must not overwrite the user's target.
    final preservedPinnedGoal =
        user.pinnedGoalWeightKg ?? user.manualGoalWeightKg;
    final preservedGoalType = user.pinnedGoalType ?? user.goal;
    final preservedStartWeight = user.goalStartWeightKg;
    var receivedGoalWeight = false;

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

      _applyHealthProblemsFromMap(map);

      if (!applyGoalFields) {
        // Still allow calorie fields from a full payload if present.
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
        continue;
      }

      final goal = map['goal'];
      if (goal is String) {
        user.goal = _parseGoalType(goal);
      } else if (goal is Map<String, dynamic>) {
        final goalType = _readResponseString(goal, const [
          'type',
          'goal',
          'goalType',
          'goal_type',
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
        final nestedGoalWeight = _readResponseDouble(goal, const [
          'goalWeight',
          'targetWeight',
          'goal_weight',
          'target_weight',
        ]);
        final nestedStartWeight = _readResponseDouble(goal, const [
          'startWeight',
          'goalStartWeight',
          'start_weight',
          'goal_start_weight',
        ]);
        if (nestedStartWeight != null && nestedStartWeight > 0) {
          user.goalStartWeightKg = nestedStartWeight.clamp(40.0, 200.0);
        }
        if (nestedGoalWeight != null) {
          receivedGoalWeight = true;
          _applyServerGoalWeight(nestedGoalWeight, isManual: isManual);
        }
        // Never clear a pinned lose/gain target just because isManual=false.
      }

      // Some APIs send goal type as a sibling field.
      if (user.goal == null) {
        final goalType = _readResponseString(map, const [
          'goalType',
          'goal_type',
          'fitnessGoal',
          'fitness_goal',
        ]);
        final parsedGoal = _parseGoalType(goalType);
        if (parsedGoal != null) {
          user.goal = parsedGoal;
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
        'goal_weight',
        'target_weight',
      ]);
      final startWeight = _readResponseDouble(map, const [
        'startWeight',
        'goalStartWeight',
        'start_weight',
        'goal_start_weight',
      ]);
      if (startWeight != null && startWeight > 0) {
        user.goalStartWeightKg = startWeight.clamp(40.0, 200.0);
      }
      if (goalWeight != null) {
        receivedGoalWeight = true;
        final isManual = _readResponseBool(map, const [
          'isGoalWeightManual',
          'is_goal_weight_manual',
        ]);
        _applyServerGoalWeight(goalWeight, isManual: isManual);
      }
    }

    if (applyGoalFields) {
      // If the payload had no goal weight, keep the user's existing target.
      if (!receivedGoalWeight &&
          preservedPinnedGoal != null &&
          preservedGoalType != null) {
        user.pinGoalWeight(preservedPinnedGoal, goalType: preservedGoalType);
      }
      if (user.goalStartWeightKg == null && preservedStartWeight != null) {
        user.goalStartWeightKg = preservedStartWeight;
      }
      // If goal type is still missing but we have a target weight, infer it.
      ensureGoalFromWeight();
      if (user.goal != null && user.pinnedGoalWeightKg != null) {
        user.pinnedGoalType = user.goal;
      }
    } else {
      // Keep the intentional goal + target; still allow personal weight refresh.
      if (preservedGoalType != null) {
        user.goal = preservedGoalType;
        user.pinnedGoalType = preservedGoalType;
      }
      if (preservedPinnedGoal != null && preservedGoalType != null) {
        user.pinGoalWeight(preservedPinnedGoal, goalType: preservedGoalType);
      }
      if (preservedStartWeight != null) {
        user.goalStartWeightKg = preservedStartWeight;
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

  void _applyHealthProblemsFromMap(Map<String, dynamic> map) {
    final raw = map['healthProblems'] ?? map['healthProblem'];
    if (raw == null &&
        !map.containsKey('healthProblems') &&
        !map.containsKey('healthProblem')) {
      return;
    }
    final parsed = HealthProblemApiMapper.parseConcerns(raw);
    if (parsed == null) return;
    user.healthConcerns = parsed;
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
      final onboarding = data['onboarding'];
      if (onboarding is Map<String, dynamic>) yield onboarding;
    }

    final nestedOnboarding = response['onboarding'];
    if (nestedOnboarding is Map<String, dynamic>) yield nestedOnboarding;

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
    final normalized = value.trim().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');
    return switch (normalized) {
      'loseweight' || 'lose_weight' || 'lose' || 'weight_loss' || 'weightloss' =>
        GoalType.loseWeight,
      'gainweight' || 'gain_weight' || 'gain' || 'weight_gain' || 'weightgain' =>
        GoalType.gainWeight,
      'maintainweight' ||
      'maintain_weight' ||
      'maintain' ||
      'maintenance' ||
      'keep_weight' =>
        GoalType.maintainWeight,
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
    // Drop previous account's in-memory profile + diary before applying new identity.
    // Otherwise a new email briefly (or permanently) shows the last user's /
    // placeholder John / 70kg / calorie numbers.
    _clearApiOwnedControllers();
    user.resetToDefaults();
    _clearInMemoryAuthState();

    isLoggedIn = true;
    this.userId = userId ?? '';
    authProvider = provider;
    this.accessToken = accessToken;
    this.refreshToken = refreshToken ?? '';
    backendLoginResponse = backendResponse;
    user.email = email;
    user.name = name.trim().isNotEmpty ? name.trim() : '';
    _applyAvatarFromResponse(backendResponse);
    update();

    // Persist tokens first. Defer FCM until after profile — parallel bursts
    // right after Google login were triggering 429 rate limits.
    await _authRepository.saveSession(
      userId: this.userId,
      provider: authProvider,
      email: email,
      name: user.name,
      accessToken: accessToken,
      refreshToken: refreshToken,
      backendResponse: backendResponse,
      setupComplete: _onboardingCompleted || user.hasProfileBasics,
      avatarUrl: user.avatarUrl,
      avatarExpiresAt: user.avatarExpiresAt?.toIso8601String(),
    );

    // Keep in-memory refresh in sync with what was persisted (may be nested).
    if (this.refreshToken.isEmpty) {
      final session = await _authRepository.loadSession();
      final savedRefresh = session['refreshToken'];
      if (savedRefresh is String && savedRefresh.isNotEmpty) {
        this.refreshToken = savedRefresh;
      }
    }

    // Profile first (with retries), then diary — never stampede the API.
    await _reloadApiOwnedDataAfterLogin();

    unawaited(
      NotificationService.instance.syncTokenWithBackend(
        accessToken: accessToken,
      ),
    );
  }

  Future<void> _reloadApiOwnedDataAfterLogin() async {
    debugPrint('UserController: reloading API-owned data after login');

    // Gate every other call on profile — this decides home vs setup.
    await fetchProfile(refreshGoalTarget: false, maxAttempts: 4);
    await refreshAvatarUrl(force: true);

    if (Get.isRegistered<FoodController>()) {
      await Get.find<FoodController>().reloadAfterLogin();
    }
    if (Get.isRegistered<TrackerController>()) {
      await Get.find<TrackerController>().reloadAfterLogin();
    }
    if (Get.isRegistered<NutritionPlanController>()) {
      await Get.find<NutritionPlanController>().loadPlan(force: true);
    }
    // Notifications are non-blocking for routing — don't delay / cause 429s.
    if (Get.isRegistered<NotificationsController>()) {
      unawaited(Get.find<NotificationsController>().refreshUnreadCount());
    }
    _notifyDashboard();
  }

  /// True when the Google login payload looks like an existing account
  /// (created earlier), not a brand-new signup in this request.
  bool get isLikelyExistingBackendUser {
    for (final map in _authResponseMaps(backendLoginResponse)) {
      final createdRaw = map['createdAt'] ?? map['created_at'];
      final loginRaw = map['lastLoginAt'] ?? map['last_login_at'];
      if (createdRaw is! String || loginRaw is! String) continue;
      final created = DateTime.tryParse(createdRaw);
      final lastLogin = DateTime.tryParse(loginRaw);
      if (created == null || lastLogin == null) continue;
      return lastLogin.difference(created).inSeconds.abs() >= 90;
    }
    return false;
  }

  void _clearApiOwnedControllers() {
    if (Get.isRegistered<FoodController>()) {
      Get.find<FoodController>().clearSessionData();
    }
    if (Get.isRegistered<TrackerController>()) {
      Get.find<TrackerController>().clearSessionData();
    }
    if (Get.isRegistered<NutritionPlanController>()) {
      Get.find<NutritionPlanController>().clearSessionData();
    }
    if (Get.isRegistered<NotificationsController>()) {
      Get.find<NotificationsController>().clearSessionData();
    }
    _notifyDashboard();
  }

  Future<void> markOnboardingComplete() async {
    _onboardingCompleted = true;
    await clearOnboardingProgress();
    await _persistCurrentAuthSession();
  }

  Future<void> _persistCurrentAuthSession() async {
    if (!isLoggedIn || accessToken.isEmpty) return;
    await _authRepository.saveSession(
      userId: userId,
      provider: authProvider,
      email: user.email,
      name: user.name,
      accessToken: accessToken,
      refreshToken: refreshToken.isEmpty ? null : refreshToken,
      backendResponse: backendLoginResponse,
      setupComplete: _onboardingCompleted || user.hasProfileBasics,
      avatarUrl: user.avatarUrl,
      avatarExpiresAt: user.avatarExpiresAt?.toIso8601String(),
    );
  }

  Future<void> _markEmailVerifiedLocally() async {
    backendLoginResponse = Map<String, dynamic>.from(backendLoginResponse)
      ..['emailVerified'] = true;

    if (!isLoggedIn || accessToken.isEmpty) {
      update();
      return;
    }

    await _persistCurrentAuthSession();
    update();
  }

  void notifyGoalConsumers() => _notifyCalorieGoalChanged();

  void _notifyDashboard() => _notifyCalorieGoalChanged();

  Future<bool> performDeleteAccount() async {
    if (isDeletingAccount || isLoggingOut) return false;

    isDeletingAccount = true;
    isSessionBusy.value = true;
    update();

    try {
      if (accessToken.isEmpty) await loadAuthSession();

      if (accessToken.isEmpty) {
        AppSnackbar.error('You are not signed in.', title: 'Delete failed');
        return false;
      }

      debugPrint(
        'UserController: delete account — calling API with access token',
      );
      await _authRepository.deleteAccount(accessToken: accessToken);
      _clearApiOwnedControllers();
      _clearInMemoryAuthState();
      user.resetToDefaults();

      MainController.resetHomeTabIfRegistered();
      Get.offAllNamed(AppRoutes.login);
      AppSnackbar.success(
        'Your account has been permanently deleted.',
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
      isSessionBusy.value = false;
      update();
    }
  }

  Future<void> performLogout() async {
    if (isLoggingOut) return;

    isLoggingOut = true;
    isSessionBusy.value = true;
    update();

    try {
      if (refreshToken.isEmpty || accessToken.isEmpty) {
        await loadAuthSession();
      }

      debugPrint(
        'UserController: logout — refresh=${refreshToken.isNotEmpty} '
        'access=${accessToken.isNotEmpty}',
      );
      final result = await _authRepository.logout(
        refreshToken: refreshToken,
        accessToken: accessToken,
      );
      _clearApiOwnedControllers();
      _clearInMemoryAuthState();
      user.resetToDefaults();
      unawaited(AnalyticsService.clearUser());

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
      isSessionBusy.value = false;
      update();
    }
  }

  void _clearInMemoryAuthState() {
    _sessionEpoch++;
    _fetchProfileInFlight = null;
    isLoggedIn = false;
    userId = '';
    authProvider = '';
    accessToken = '';
    refreshToken = '';
    backendLoginResponse = {};
    userOnboardingGoalWeightKg = null;
    aiRecommendedGoalWeightKg = null;
    user.goalStartWeightKg = null;
    user.clearPinnedGoalWeight();
    user.pinnedGoalType = null;
    _goalEditCheckpoint = null;
    weightTargetSource.value = WeightTargetSource.user;
    isRefreshingWeightTarget.value = false;
    isUploadingAvatar = false;
    _avatarRemovedLocally = false;
    _avatarUiDirty = false;

    // Must reset setup flags — otherwise a prior account's completed onboarding
    // makes a new email skip setup and/or keep an old in-memory draft.
    _onboardingDraftSaveTimer?.cancel();
    _onboardingDraftSaveTimer = null;
    _onboardingDraft = null;
    _onboardingStep = null;
    _onboardingCompleted = false;
    hasOnboardingDraft = false;
    personalDetailsComplete = false;
  }
}

enum WeightTargetSource { user, ai }

/// In-memory checkpoint for a My Goals → Goal Setup/Amount/Weight edit journey.
class _GoalEditCheckpoint {
  const _GoalEditCheckpoint({
    required this.syncBaseline,
    required this.goal,
    required this.pinnedGoalType,
    required this.pinnedGoalWeightKg,
    required this.manualGoalWeightKg,
    required this.goalStartWeightKg,
    required this.targetDate,
  });

  final ProfileSyncSnapshot syncBaseline;
  final GoalType? goal;
  final GoalType? pinnedGoalType;
  final double? pinnedGoalWeightKg;
  final double? manualGoalWeightKg;
  final double? goalStartWeightKg;
  final DateTime targetDate;
}

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
