import '../controllers/user_controller.dart';
import '../routes/app_routes.dart';
import '../services/local_storage_service.dart';

/// Same cold-start routing on every Android version (and iOS).
///
/// 1. Restore a local session if one exists.
/// 2. Hydrate profile from the API before opening Home (same as login).
/// 3. Drop the session and show login if the token is rejected.
Future<String> resolveStartupRoute({
  required UserController user,
  LocalStorageService? storage,
}) async {
  final local = storage ?? LocalStorageService();
  await local.wipeLegacyApiCachesIfNeeded();
  await user.loadAuthSession();

  if (user.isLoggedIn && user.accessToken.isNotEmpty) {
    await user.fetchProfile(refreshGoalTarget: true, maxAttempts: 3);
    final status = user.lastProfileFetchStatusCode;
    if (status == 401 || status == 403) {
      await user.clearInvalidSession();
    }
  }

  if (user.isLoggedIn && user.accessToken.isNotEmpty) {
    try {
      await local.saveWelcomeIntroSeen(seen: true);
    } catch (_) {}
    return user.resolveSetupResumeRoute();
  }

  try {
    if (await local.isWelcomeIntroSeen()) return AppRoutes.login;
  } catch (_) {}
  return AppRoutes.onboarding;
}
