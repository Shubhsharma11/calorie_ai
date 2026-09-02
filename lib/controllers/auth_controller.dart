import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
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

  static const indiaDialCode = '+91';

  /// Temporary: skip Firebase phone auth until billing is enabled.
  /// Set to `false` to restore real OTP sending/verification.
  static const bypassPhoneAuth = true;

  final AuthApiService _authApi;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final otpController = TextEditingController();

  final isSigningInWithGoogle = false.obs;
  final isSigningInWithApple = false.obs;
  final isSendingPhoneOtp = false.obs;
  final isVerifyingPhoneOtp = false.obs;
  final phoneNumber = ''.obs;
  final canResendOtp = false.obs;
  final resendCountdown = 0.obs;

  /// Sync lock so rapid taps cannot re-enter before Obx rebuilds.
  bool _googleAuthInFlight = false;
  bool _appleAuthInFlight = false;
  bool _phoneAuthInFlight = false;
  String? _phoneVerificationId;
  int? _phoneResendToken;
  Timer? _resendTimer;

  bool get isSigningIn =>
      isSigningInWithGoogle.value ||
      isSigningInWithApple.value ||
      isSendingPhoneOtp.value ||
      isVerifyingPhoneOtp.value ||
      _googleAuthInFlight ||
      _appleAuthInFlight ||
      _phoneAuthInFlight;

  String get formattedPhoneNumber {
    final digits = phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    return '$indiaDialCode$digits';
  }

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
    if (_googleAuthInFlight || _appleAuthInFlight || isSigningIn) {
      debugPrint('AuthController: ignoring Google sign-in (already in progress)');
      return;
    }

    // Sync lock only — don't show loading while the account picker is open.
    _googleAuthInFlight = true;

    try {
      debugPrint('AuthController: starting Google sign-in');
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '950645223660-73fq24ua6hn9h7u92bc9nhtg22rjag1d.apps.googleusercontent.com',
      );
      final googleUser = await GoogleSignIn.instance.authenticate();

      // Account chosen — now show loading for backend auth.
      isSigningInWithGoogle.value = true;

      debugPrint('AuthController: Google sign-in returned ${googleUser.email}');

      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      debugPrint(
        'AuthController: Google ID token length=${idToken?.length ?? 0}',
      );
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
        // Do not refetch while rate-limited — cooldown in UserController owns the next try.
      } else {
        await user.restoreOnboardingProgress();
        final resumeRoute = await user.resolveSetupResumeRoute();
        Get.offAllNamed(resumeRoute);
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('AuthController: Google sign-in canceled by user');
        return;
      }
      debugPrint(
        'AuthController: GoogleSignInException code=${e.code} '
        'description=${e.description}',
      );
      _showAuthError(e.description ?? 'Google sign-in failed.');
    } on AuthApiException catch (e) {
      debugPrint('AuthController: Google backend auth failed: ${e.message}');
      _showAuthError(e.message);
    } catch (e, stackTrace) {
      debugPrint('GOOGLE SIGN IN ERROR: $e');
      debugPrint('STACK TRACE: $stackTrace');

      _showAuthError('Unable to sign in with Google: $e');
    } finally {
      _googleAuthInFlight = false;
      isSigningInWithGoogle.value = false;
    }
  }

  Future<void> loginWithApple() async {
    if (_googleAuthInFlight || _appleAuthInFlight || isSigningIn) {
      debugPrint('AuthController: ignoring Apple sign-in (already in progress)');
      return;
    }

    // Sync lock only — don't show loading while the system sheet is open.
    _appleAuthInFlight = true;

    try {
      debugPrint('AuthController: starting Apple sign-in');

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Account chosen — now show loading for backend auth.
      isSigningInWithApple.value = true;

      final identityToken = credential.identityToken;

      if (identityToken == null || identityToken.isEmpty) {
        throw const AuthApiException(
          'Apple identity token was not returned.',
        );
      }

      debugPrint('AuthController: Apple sign-in success');
      debugPrint('Apple email: ${credential.email}');
      debugPrint(
        'Apple name: ${credential.givenName} ${credential.familyName}',
      );

      final appleName = appleDisplayName(
        givenName: credential.givenName,
        familyName: credential.familyName,
      );

      debugPrint('AuthController: sending Apple token to backend');

      final backendResponse = await _authApi.loginWithAppleIdToken(
        identityToken,
        name: appleName.isEmpty ? null : appleName,
        givenName: credential.givenName,
        familyName: credential.familyName,
      );

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
      final backendName = UserController.readDisplayName(backendResponse);

      await user.saveGoogleLoginDetails(
        userId: _claimString(claims, 'sub'),
        provider: 'apple',
        email: _claimString(claims, 'email') ?? credential.email ?? '',
        name: appleName,
        accessToken: accessToken,
        refreshToken: refreshToken.isEmpty ? null : refreshToken,
        backendResponse: backendResponse,
      );
      if (appleName.isNotEmpty && backendName.isEmpty) {
        await user.updateDisplayName(appleName, force: true);
      }
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
        debugPrint('AuthController: Apple sign-in canceled by user');
        return;
      }

      debugPrint(
        'AuthController: AppleAuthorizationException code=${e.code} '
        'message=${e.message}',
      );
      _showAuthError(e.message);
    } on AuthApiException catch (e) {
      debugPrint('AuthController: Apple backend auth failed: ${e.message}');
      _showAuthError(e.message);
    } catch (e, stackTrace) {
      debugPrint('APPLE SIGN IN ERROR: $e');
      debugPrint(stackTrace.toString());

      _showAuthError('Unable to sign in with Apple: $e');
    } finally {
      _appleAuthInFlight = false;
      isSigningInWithApple.value = false;
    }
  }

  Future<void> sendPhoneOtp({bool isResend = false}) async {
    if (_phoneAuthInFlight || isSigningIn) {
      debugPrint('AuthController: ignoring phone OTP send (already in progress)');
      return;
    }

    final digits = phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      _showAuthError('Enter a valid 10-digit mobile number.');
      return;
    }

    final e164 = '$indiaDialCode$digits';
    _phoneAuthInFlight = true;
    isSendingPhoneOtp.value = true;
    phoneNumber.value = e164;

    if (bypassPhoneAuth) {
      debugPrint(
        'AuthController: phone auth bypass enabled — opening OTP screen for $e164',
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _phoneVerificationId = 'bypass-verification-id';
      _phoneAuthInFlight = false;
      isSendingPhoneOtp.value = false;
      otpController.clear();
      _startResendCountdown();
      if (!isResend) {
        Get.toNamed(AppRoutes.otpVerify);
      } else {
        AppSnackbar.success(
          'A new code was sent to $e164',
          title: 'Code resent',
        );
      }
      return;
    }

    try {
      debugPrint('AuthController: sending phone OTP to $e164');
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: e164,
        forceResendingToken: isResend ? _phoneResendToken : null,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          debugPrint('AuthController: phone auto-verification completed');
          await _completePhoneSignIn(credential);
        },
        verificationFailed: (error) {
          debugPrint(
            'AuthController: phone verification failed '
            'code=${error.code} message=${error.message}',
          );
          _phoneAuthInFlight = false;
          isSendingPhoneOtp.value = false;
          _showAuthError(error.message ?? 'Unable to send verification code.');
        },
        codeSent: (verificationId, resendToken) {
          debugPrint('AuthController: phone OTP sent verificationId=$verificationId');
          _phoneVerificationId = verificationId;
          _phoneResendToken = resendToken;
          _phoneAuthInFlight = false;
          isSendingPhoneOtp.value = false;
          otpController.clear();
          _startResendCountdown();
          if (!isResend) {
            Get.toNamed(AppRoutes.otpVerify);
          } else {
            AppSnackbar.success(
              'A new code was sent to $e164',
              title: 'Code resent',
            );
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _phoneVerificationId = verificationId;
          _phoneAuthInFlight = false;
          isSendingPhoneOtp.value = false;
        },
      );
    } catch (e, stackTrace) {
      debugPrint('PHONE OTP SEND ERROR: $e');
      debugPrint('$stackTrace');
      _phoneAuthInFlight = false;
      isSendingPhoneOtp.value = false;
      _showAuthError('Unable to send verification code: $e');
    }
  }

  Future<void> verifyPhoneOtp() async {
    if (_phoneAuthInFlight || isSigningIn) {
      debugPrint('AuthController: ignoring OTP verify (already in progress)');
      return;
    }

    final smsCode = otpController.text.trim();
    if (smsCode.length < 6) {
      _showAuthError('Enter the 6-digit verification code.');
      return;
    }

    if (bypassPhoneAuth) {
      debugPrint('AuthController: phone auth bypass — skipping OTP verify');
      _phoneAuthInFlight = true;
      isVerifyingPhoneOtp.value = true;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      _phoneAuthInFlight = false;
      isVerifyingPhoneOtp.value = false;
      Get.offAllNamed(AppRoutes.personalDetails);
      return;
    }

    final verificationId = _phoneVerificationId;
    if (verificationId == null || verificationId.isEmpty) {
      _showAuthError('Verification expired. Please request a new code.');
      return;
    }

    _phoneAuthInFlight = true;
    isVerifyingPhoneOtp.value = true;

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _completePhoneSignIn(credential);
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'AuthController: OTP verify failed code=${e.code} message=${e.message}',
      );
      _showAuthError(e.message ?? 'Invalid verification code.');
    } catch (e, stackTrace) {
      debugPrint('PHONE OTP VERIFY ERROR: $e');
      debugPrint('$stackTrace');
      _showAuthError('Unable to verify code: $e');
    } finally {
      _phoneAuthInFlight = false;
      isVerifyingPhoneOtp.value = false;
    }
  }

  Future<void> resendPhoneOtp() async {
    if (!canResendOtp.value || isSigningIn) return;
    await sendPhoneOtp(isResend: true);
  }

  Future<void> _completePhoneSignIn(PhoneAuthCredential credential) async {
    try {
      debugPrint('AuthController: completing phone Firebase sign-in');
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw const AuthApiException('Phone sign-in did not return a user.');
      }

      final idToken = await firebaseUser.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw const AuthApiException('Phone ID token was not returned.');
      }

      debugPrint('AuthController: sending phone ID token to backend');
      final backendResponse = await _authApi.loginWithPhoneIdToken(idToken);
      final accessToken = _readBackendString(backendResponse, 'accessToken');
      final refreshToken = _readBackendString(backendResponse, 'refreshToken');
      if (accessToken.isEmpty) {
        throw const AuthApiException(
          'Backend phone login did not return an access token.',
        );
      }

      final claims = _decodeJwtClaims(accessToken);
      final user = Get.find<UserController>();
      await user.saveGoogleLoginDetails(
        userId: _claimString(claims, 'sub'),
        provider: _claimString(claims, 'provider') ?? 'phone',
        email: _claimString(claims, 'email') ?? firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? '',
        accessToken: accessToken,
        refreshToken: refreshToken.isEmpty ? null : refreshToken,
        backendResponse: backendResponse,
      );
      await _logAuthAnalytics(user: user, method: 'phone');

      if (user.user.hasProfileBasics || user.isSetupComplete) {
        await user.markOnboardingComplete();
        MainController.resetHomeTabIfRegistered();
        Get.offAllNamed(AppRoutes.main);
      } else if (user.lastProfileFetchStatusCode == 429 &&
          (UserController.readEmailVerified(backendResponse) ||
              user.isLikelyExistingBackendUser)) {
        await user.markOnboardingComplete();
        MainController.resetHomeTabIfRegistered();
        Get.offAllNamed(AppRoutes.main);
      } else {
        await user.restoreOnboardingProgress();
        final resumeRoute = await user.resolveSetupResumeRoute();
        Get.offAllNamed(resumeRoute);
      }
    } on AuthApiException catch (e) {
      debugPrint('AuthController: phone backend auth failed: ${e.message}');
      _showAuthError(e.message);
    } catch (e, stackTrace) {
      debugPrint('PHONE SIGN IN ERROR: $e');
      debugPrint('$stackTrace');
      _showAuthError('Unable to sign in with phone: $e');
    } finally {
      _phoneAuthInFlight = false;
      isSendingPhoneOtp.value = false;
      isVerifyingPhoneOtp.value = false;
    }
  }

  void _startResendCountdown({int seconds = 45}) {
    _resendTimer?.cancel();
    canResendOtp.value = false;
    resendCountdown.value = seconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendCountdown.value <= 1) {
        timer.cancel();
        resendCountdown.value = 0;
        canResendOtp.value = true;
        return;
      }
      resendCountdown.value = resendCountdown.value - 1;
    });
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
    AppSnackbar.error(message, title: 'Sign-in failed');
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

  /// Apple only returns given/family name on the first authorization.
  static String appleDisplayName({String? givenName, String? familyName}) {
    return [
      givenName?.trim() ?? '',
      familyName?.trim() ?? '',
    ].where((part) => part.isNotEmpty).join(' ');
  }

  @override
  void onClose() {
    _resendTimer?.cancel();
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    phoneController.dispose();
    otpController.dispose();
    super.onClose();
  }
}
