import '../controllers/user_controller.dart';
import '../routes/app_routes.dart';
import '../services/local_storage_service.dart';

/// Same cold-start routing on every Android version (and iOS).
///
/// Existing users open Home from the local session immediately. Profile /
/// meals / coins sync quietly via [HomeHydrate] after the first frame —
/// the same pattern other production apps use (no login API stampede).
Future<String> resolveStartupRoute({
  required UserController user,
  LocalStorageService? storage,
}) async {
  final local = storage ?? LocalStorageService();
  await local.wipeLegacyApiCachesIfNeeded();
  await user.loadAuthSession();

  if (user.isLoggedIn && user.accessToken.isNotEmpty) {
    try {
      await local.saveWelcomeIntroSeen(seen: true);
    } catch (_) {}

    // Setup already finished (or profile basics cached) → Home now.
    if (user.isSetupComplete || user.user.hasProfileBasics) {
      return AppRoutes.main;
    }

    // Incomplete setup — one soft profile read to decide resume step.
    await user.fetchProfile(refreshGoalTarget: true);
    final status = user.lastProfileFetchStatusCode;
    if (status == 401 || status == 403) {
      await user.clearInvalidSession(
        // TEMPORARY — HOME_STUCK_DEBUG
        debugController: 'resolveStartupRoute',
        debugEndpoint: 'GET /onboarding',
        debugStatusCode: status,
        debugRequestType: 'GET',
      );
    } else if (status == 429) {
      // Don't block a returning user behind rate limits.
      return AppRoutes.main;
    }

    if (user.isLoggedIn && user.accessToken.isNotEmpty) {
      return user.resolveSetupResumeRoute();
    }
  }

  try {
    if (await local.isWelcomeIntroSeen()) return AppRoutes.login;
  } catch (_) {}
  return AppRoutes.onboarding;
}
