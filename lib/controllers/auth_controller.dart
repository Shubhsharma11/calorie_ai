import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../routes/app_routes.dart';
import '../core/app_snackbar.dart';
import '../services/auth_api_service.dart';
import 'main_controller.dart';
import 'user_controller.dart';

class AuthController extends GetxController {
  AuthController({AuthApiService? authApi})
    : _authApi = authApi ?? AuthApiService();

  final AuthApiService _authApi;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  final isSigningIn = false.obs;

  void login() {
    final user = Get.find<UserController>();
    user.user.email = emailController.text.trim();
    if (nameController.text.isNotEmpty) {
      user.user.name = nameController.text.trim();
    }
    Get.offAllNamed(AppRoutes.personalDetails);
  }

  void register() {
    final user = Get.find<UserController>();
    user.user.name = nameController.text.trim();
    user.user.email = emailController.text.trim();
    user.update();
    Get.offAllNamed(AppRoutes.personalDetails);
  }

  Future<void> loginWithGoogle() async {
    if (isSigningIn.value) return;

    isSigningIn.value = true;

    try {
      debugPrint('AuthController: starting Google sign-in');
      final googleUser = await GoogleSignIn.instance.authenticate();

      debugPrint('AuthController: Google sign-in returned ${googleUser.email}');

      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      debugPrint('AuthController: Google ID token: $idToken');
      if (idToken == null || idToken.isEmpty) {
        throw const AuthApiException('Google ID token was not returned.');
      }

      debugPrint('AuthController: sending Google ID token to backend');
      final backendResponse = await _authApi.loginWithGoogleIdToken(idToken);
      debugPrint('AuthController: backend Google login completed');

      final accessToken = _readBackendString(backendResponse, 'accessToken');
      final refreshToken = _readBackendString(backendResponse, 'refreshToken');
      if (accessToken.isEmpty) {
        throw const AuthApiException(
          'Backend login did not return an access token.',
        );
      }
      final accessTokenClaims = _decodeJwtClaims(accessToken);

      final user = Get.find<UserController>();
      final displayName = googleUser.displayName?.trim();
      await user.saveGoogleLoginDetails(
        userId: _claimString(accessTokenClaims, 'sub'),
        provider: _claimString(accessTokenClaims, 'provider') ?? 'google',
        email: _claimString(accessTokenClaims, 'email') ?? googleUser.email,
        name: (displayName != null && displayName.isNotEmpty)
            ? displayName
            : '',
        accessToken: accessToken,
        refreshToken: refreshToken.isEmpty ? null : refreshToken,
        backendResponse: backendResponse,
      );
      debugPrint(
        'AuthController: access token saved length=${accessToken.length}',
      );

      // Profile is loaded inside saveGoogleLoginDetails. Rate limits (429) must
      // not send an existing account through personal-details again.
      if (user.user.hasProfileBasics || user.isSetupComplete) {
        await user.markOnboardingComplete();
        MainController.resetHomeTabIfRegistered();
        Get.offAllNamed(AppRoutes.main);
      } else if (user.lastProfileFetchStatusCode == 429 &&
          (UserController.readEmailVerified(backendResponse) ||
              user.isLikelyExistingBackendUser)) {
        debugPrint(
          'AuthController: profile rate-limited for existing user — opening home',
        );
        await user.markOnboardingComplete();
        MainController.resetHomeTabIfRegistered();
        Get.offAllNamed(AppRoutes.main);
        unawaited(user.fetchProfile(refreshGoalTarget: true, maxAttempts: 4));
      } else {
        await user.restoreOnboardingProgress();
        final resumeRoute = await user.resolveSetupResumeRoute();
        Get.offAllNamed(resumeRoute);
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      _showAuthError(e.description ?? 'Google sign-in failed.');
    } on AuthApiException catch (e) {
      _showAuthError(e.message);
    } catch (e) {
      _showAuthError('Unable to sign in with Google: $e');
    } finally {
      isSigningIn.value = false;
    }
  }

  void _showAuthError(String message) {
    AppSnackbar.error(message, title: 'Login failed');
  }

  String _readBackendString(Map<String, dynamic> response, String key) {
    final value = response[key];
    if (value is String) return value;

    final tokens = response['tokens'];
    if (tokens is Map<String, dynamic>) {
      final tokenValue = tokens[key];
      if (tokenValue is String) return tokenValue;
    }

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final nestedValue = data[key];
      if (nestedValue is String) return nestedValue;

      final nestedTokens = data['tokens'];
      if (nestedTokens is Map<String, dynamic>) {
        final tokenValue = nestedTokens[key];
        if (tokenValue is String) return tokenValue;
      }
    }

    return '';
  }

  Map<String, dynamic> _decodeJwtClaims(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return {};

    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException {
      return {};
    }
  }

  String? _claimString(Map<String, dynamic> claims, String key) {
    final value = claims[key];
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.onClose();
  }
}
