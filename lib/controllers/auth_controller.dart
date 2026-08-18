import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../routes/app_routes.dart';
import '../core/app_snackbar.dart';
import '../services/analytics_service.dart';
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

  final isSigningInWithGoogle = false.obs;
  final isSigningInWithApple = false.obs;

  bool get isSigningIn =>
      isSigningInWithGoogle.value || isSigningInWithApple.value;

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
    if (isSigningIn) return;

    isSigningInWithGoogle.value = true;

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
      await _logAuthAnalytics(
        user: user,
        method: 'google',
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
        unawaited(user.fetchProfile(refreshGoalTarget: false, maxAttempts: 4));
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
    } catch (e, stackTrace) {
      debugPrint('GOOGLE SIGN IN ERROR: $e');
      debugPrint('STACK TRACE: $stackTrace');

      _showAuthError('Unable to sign in with Google: $e');
    } finally {
      isSigningInWithGoogle.value = false;
    }
  }

  Future<void> loginWithApple() async {
    if (isSigningIn) return;

    isSigningInWithApple.value = true;

    try {
      debugPrint('AuthController: starting Apple sign-in');

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;

      if (identityToken == null || identityToken.isEmpty) {
        throw const AuthApiException(
          'Apple identity token was not returned.',
        );
      }

      debugPrint('AuthController: Apple sign-in success');
      debugPrint('Apple email: ${credential.email}');
      debugPrint('Apple name: ${credential.givenName}');

      debugPrint('AuthController: sending Apple token to backend');

      final backendResponse =
          await _authApi.loginWithAppleIdToken(identityToken);

      debugPrint('APPLE BACKEND RESPONSE: $backendResponse');

      final accessToken = _readBackendString(backendResponse, 'accessToken');
      final refreshToken = _readBackendString(backendResponse, 'refreshToken');

      if (accessToken.isEmpty) {
        throw const AuthApiException(
          'Backend Apple login did not return access token.',
        );
      }

      final claims = _decodeJwtClaims(accessToken);
      final user = Get.find<UserController>();

      await user.saveGoogleLoginDetails(
        userId: _claimString(claims, 'sub'),
        provider: 'apple',
        email: _claimString(claims, 'email') ?? credential.email ?? '',
        name: credential.givenName ?? '',
        accessToken: accessToken,
        refreshToken: refreshToken.isEmpty ? null : refreshToken,
        backendResponse: backendResponse,
      );
      await _logAuthAnalytics(
        user: user,
        method: 'apple',
      );

      debugPrint('AuthController: Apple user saved');

      if (user.user.hasProfileBasics || user.isSetupComplete) {
        await user.markOnboardingComplete();
        MainController.resetHomeTabIfRegistered();
        Get.offAllNamed(AppRoutes.main);
      } else {
        await user.restoreOnboardingProgress();
        final route = await user.resolveSetupResumeRoute();
        Get.offAllNamed(route);
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return;
      }

      _showAuthError(e.message);
    } on AuthApiException catch (e) {
      _showAuthError(e.message);
    } catch (e, stackTrace) {
      debugPrint('APPLE SIGN IN ERROR: $e');
      debugPrint(stackTrace.toString());

      _showAuthError('Unable to sign in with Apple: $e');
    } finally {
      isSigningInWithApple.value = false;
    }
  }


  Future<void> _logAuthAnalytics({
    required UserController user,
    required String method,
  }) async {
    await AnalyticsService.setUser(
      userId: user.userId.isEmpty ? null : user.userId,
      email: user.user.email,
      name: user.user.name,
      provider: method,
    );

    final isExisting =
        user.isLikelyExistingBackendUser || user.user.hasProfileBasics;
    if (isExisting) {
      await AnalyticsService.logLogin(method: method);
    } else {
      await AnalyticsService.logSignup(method: method);
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
