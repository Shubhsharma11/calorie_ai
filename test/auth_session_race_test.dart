import 'dart:async';

import 'package:calorie_ai/controllers/user_controller.dart';
import 'package:calorie_ai/repositories/auth_repository.dart';
import 'package:calorie_ai/services/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(storage: LocalStorageService());

  Map<String, dynamic> disk = {};
  Completer<void>? gate;

  @override
  Future<Map<String, dynamic>> loadSession() async {
    final g = gate;
    if (g != null) await g.future;
    return Map<String, dynamic>.from(disk);
  }

  @override
  Future<void> saveSession({
    required String userId,
    required String provider,
    required String email,
    required String name,
    required String accessToken,
    String? refreshToken,
    required Map<String, dynamic> backendResponse,
    bool setupComplete = false,
    String? avatarUrl,
    String? avatarExpiresAt,
  }) async {
    disk = {
      'userId': userId,
      'provider': provider,
      'email': email,
      'name': name,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'backendResponse': backendResponse,
      'setupComplete': setupComplete,
    };
  }

  @override
  Future<void> clearLocalAuthData() async {
    disk = {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
    await Get.deleteAll(force: true);
  });

  tearDown(() async {
    await Get.deleteAll(force: true);
  });

  test(
    'loadAuthSession does not overwrite a fresh login token with a stale disk read',
    () async {
      final repo = _FakeAuthRepository();
      repo.disk = {
        'userId': 'u1',
        'provider': 'google',
        'email': 'old@example.com',
        'name': 'Old',
        'accessToken': 'revoked-old-token-aaaaaa',
        'refreshToken': 'old-refresh',
        'backendResponse': <String, dynamic>{},
        'setupComplete': true,
      };

      // Gate the first disk read so it spans the login window.
      repo.gate = Completer<void>();

      // Bypass onInit: complete localProfileReady without racing our assertions.
      final user = UserController(authRepository: repo);
      // Prevent onInit's unawaited load from using the gated disk forever.
      repo.gate = null;
      Get.put(user, permanent: true);
      await user.localProfileReady;

      // Re-arm gate for the race.
      repo.disk = {
        'userId': 'u1',
        'provider': 'google',
        'email': 'old@example.com',
        'name': 'Old',
        'accessToken': 'revoked-old-token-aaaaaa',
        'refreshToken': 'old-refresh',
        'backendResponse': <String, dynamic>{},
        'setupComplete': true,
      };
      await user.loadAuthSession();
      expect(user.accessToken, 'revoked-old-token-aaaaaa');

      repo.gate = Completer<void>();

      // Start a stale load that still sees the revoked token on disk.
      final staleLoad = user.loadAuthSession();
      await Future<void>.delayed(Duration.zero);

      await user.saveGoogleLoginDetails(
        userId: 'u1',
        provider: 'google',
        email: 'new@example.com',
        name: 'New',
        accessToken: 'fresh-new-token-bbbbbb',
        refreshToken: 'new-refresh',
        backendResponse: {
          'data': {
            'tokens': {
              'accessToken': 'fresh-new-token-bbbbbb',
              'refreshToken': 'new-refresh',
            },
            // Make isLikelyExistingBackendUser true so post-login skips network.
            'createdAt': '2024-01-01T00:00:00.000Z',
            'lastLoginAt': '2024-06-01T00:00:00.000Z',
            'user': {
              'name': 'New',
              'email': 'new@example.com',
            },
          },
        },
      );

      expect(user.accessToken, 'fresh-new-token-bbbbbb');

      // Release the stale disk read — must not clobber the new token.
      repo.gate!.complete();
      await staleLoad;

      expect(
        user.accessToken,
        'fresh-new-token-bbbbbb',
        reason: 'stale loadAuthSession revived revoked token',
      );
    },
  );

  test(
    'loadAuthSession empty disk keeps in-memory token during login save gap',
    () async {
      final repo = _FakeAuthRepository();
      repo.disk = {};
      final user = UserController(authRepository: repo);
      // Bypass onInit network/local init side effects for this unit check.
      user.isLoggedIn = true;
      user.accessToken = 'fresh-memory-token-cccccc';

      await user.loadAuthSession();

      expect(user.accessToken, 'fresh-memory-token-cccccc');
      expect(user.isLoggedIn, isTrue);
    },
  );
}
