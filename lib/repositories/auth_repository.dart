import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/logout_result.dart';
import '../services/auth_api_service.dart';
import '../services/local_storage_service.dart';

/// Handles authentication session persistence and backend logout.
class AuthRepository {
  AuthRepository({
    AuthApiService? authApi,
    LocalStorageService? storage,
  })  : _authApi = authApi ?? AuthApiService(),
        _storage = storage ?? LocalStorageService();

  final AuthApiService _authApi;
  final LocalStorageService _storage;

  Future<Map<String, dynamic>> loadSession() => _storage.loadAuthSession();

  Future<void> saveSession({
    required String userId,
    required String provider,
    required String email,
    required String name,
    required String accessToken,
    String? refreshToken,
    required Map<String, dynamic> backendResponse,
  }) {
    return _storage.saveAuthSession(
      userId: userId,
      provider: provider,
      email: email,
      name: name,
      accessToken: accessToken,
      refreshToken: refreshToken,
      backendResponse: backendResponse,
    );
  }

  Future<String?> resolveRefreshToken({String? inMemoryToken}) async {
    if (inMemoryToken != null && inMemoryToken.isNotEmpty) {
      return inMemoryToken;
    }

    final session = await loadSession();
    return _extractRefreshToken(session);
  }

  Future<void> deleteAccount({required String accessToken}) async {
    debugPrint('AuthRepository: calling delete account API');
    await _authApi.deleteAccount(accessToken: accessToken);
    await clearLocalAuthData();
    await _signOutFromGoogle();
  }

  Future<LogoutResult> logout({String? refreshToken}) async {
    final token = await resolveRefreshToken(inMemoryToken: refreshToken);
    String? backendError;

    if (token != null && token.isNotEmpty) {
      try {
        debugPrint('AuthRepository: calling logout API with refresh token');
        await _authApi.logoutWithRefreshToken(token);
      } on AuthApiException catch (e, stackTrace) {
        backendError = e.message;
        debugPrint('AuthRepository: backend logout failed: $e\n$stackTrace');
      } catch (e, stackTrace) {
        backendError = e.toString();
        debugPrint('AuthRepository: unexpected logout error: $e\n$stackTrace');
      }
    } else {
      debugPrint('AuthRepository: no refresh token found, clearing local session');
    }

    await clearLocalAuthData();
    await _signOutFromGoogle();

    return LogoutResult(
      backendRevoked: backendError == null && token != null && token.isNotEmpty,
      errorMessage: backendError,
    );
  }

  Future<void> clearLocalAuthData() async {
    await _storage.clearAuthSession();
    await _storage.clearUserProfileCache();
  }

  Future<void> _signOutFromGoogle() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e, stackTrace) {
      debugPrint('AuthRepository: Google sign-out failed: $e\n$stackTrace');
    }
  }

  String? _extractRefreshToken(Map<String, dynamic> session) {
    if (session.isEmpty) return null;

    final direct = session['refreshToken'];
    if (direct is String && direct.isNotEmpty) return direct;

    final backendResponse = session['backendResponse'];
    if (backendResponse is! Map<String, dynamic>) return null;

    final tokens = backendResponse['tokens'];
    if (tokens is Map<String, dynamic>) {
      final nested = tokens['refreshToken'];
      if (nested is String && nested.isNotEmpty) return nested;
    }

    final nestedDirect = backendResponse['refreshToken'];
    if (nestedDirect is String && nestedDirect.isNotEmpty) {
      return nestedDirect;
    }

    return null;
  }
}
