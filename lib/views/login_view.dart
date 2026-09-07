import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';
import '../widgets/privacy_policy_dialog.dart';
import '../widgets/terms_of_service_dialog.dart';

class LoginView extends GetView<AuthController> {
  const LoginView({super.key});

  static const _logoAsset = 'assets/image/logo1.21.svg';
  static const _googleAsset = 'assets/image/google.svg';
  static const _appleAsset = 'assets/image/apple.svg';

  @override
  Widget build(BuildContext context) {
    return _LoginPhoneHintBootstrap(
      child: _LoginScaffold(controller: controller),
    );
  }
}

class _LoginPhoneHintBootstrap extends StatefulWidget {
  const _LoginPhoneHintBootstrap({required this.child});

  final Widget child;

  @override
  State<_LoginPhoneHintBootstrap> createState() =>
      _LoginPhoneHintBootstrapState();
}

class _LoginPhoneHintBootstrapState extends State<_LoginPhoneHintBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<AuthController>().maybePrefillPhoneNumber();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _LoginScaffold extends StatelessWidget {
  const _LoginScaffold({required this.controller});

  final AuthController controller;

  static const _logoAsset = LoginView._logoAsset;
  static const _googleAsset = LoginView._googleAsset;
  static const _appleAsset = LoginView._appleAsset;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final isDark = AppColors.isDark(context);
    final r = context.responsive;
    final horizontal = r.scale(24, tablet: 32);
    final compact = r.height < 720;

    final logoSize = r.scale(compact ? 60 : 68, tablet: 76);
    final buttonHeight = r.scale(compact ? 52 : 56, tablet: 58);
    final buttonGap = r.scale(compact ? 10 : 12);
    final sectionGap = r.scale(compact ? 20 : 24);
    final topPadding = r.scale(compact ? 36 : 44);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      body: SafeArea(
        bottom: true,
        top: false,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: r.scale(-20),
              right: r.scale(-42, tablet: -28),
              child: IgnorePointer(
                child: SizedBox(
                  width: r.scale(190, tablet: 180),
                  height: r.scale(190, tablet: 180),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withValues(
                              alpha: isDark ? 0.14 : 0.08,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: r.scale(46, tablet: 32),
                        bottom: r.scale(26, tablet: 28),
                        child: _CalorieWheel(
                          size: r.scale(68, tablet: 79),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      topPadding,
                      horizontal,
                      r.scale(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: _BrandHeader(
                            logoSize: logoSize,
                            compact: compact,
                            isDark: isDark,
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.symmetric(
                                vertical: r.scale(18),
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: r.scale(420, tablet: 460),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Welcome back!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: r.scale(
                                          compact ? 30 : 34,
                                          tablet: 36,
                                        ),
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimaryOf(context),
                                        height: 1.12,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    SizedBox(height: r.scale(10)),
                                    Text(
                                      'Enter your mobile number to continue',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: r.scale(14, tablet: 15),
                                        color: AppColors.textSecondaryOf(
                                          context,
                                        ),
                                        height: 1.4,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: sectionGap),
                                    _PhoneNumberField(
                                      height: buttonHeight,
                                      isDark: isDark,
                                    ),
                                    SizedBox(height: buttonGap),
                                    Obx(() {
                                      final sending =
                                          controller.isSendingPhoneOtp.value;
                                      final anyLoading = controller.isSigningIn;
                                      return _PrimaryContinueButton(
                                        height: buttonHeight,
                                        label: sending
                                            ? 'Sending code...'
                                            : 'Continue',
                                        isLoading: anyLoading,
                                        onPressed: controller.sendPhoneOtp,
                                      );
                                    }),
                                    SizedBox(height: sectionGap),
                                    _OrDivider(compact: compact),
                                    SizedBox(height: sectionGap),
                                    Obx(() {
                                      final googleLoading =
                                          controller.isSigningInWithGoogle.value;
                                      final anyLoading = controller.isSigningIn;
                                      return _SocialLoginButton(
                                        height: buttonHeight,
                                        isDark: isDark,
                                        label: googleLoading
                                            ? 'Signing in...'
                                            : 'Continue with Google',
                                        icon: googleLoading
                                            ? SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.3,
                                                  color: AppColors.primary,
                                                ),
                                              )
                                            : _SocialIcon(
                                                asset: _googleAsset,
                                                size: r.scale(
                                                  compact ? 22 : 24,
                                                ),
                                              ),
                                        isLoading: anyLoading,
                                        onPressed: controller.loginWithGoogle,
                                      );
                                    }),
                                    if (Platform.isIOS) ...[
                                      SizedBox(height: buttonGap),
                                      Obx(() {
                                        final appleLoading = controller
                                            .isSigningInWithApple
                                            .value;
                                        final anyLoading =
                                            controller.isSigningIn;
                                        return _SocialLoginButton(
                                          height: buttonHeight,
                                          isDark: isDark,
                                          label: appleLoading
                                              ? 'Signing in...'
                                              : 'Continue with Apple',
                                          icon: appleLoading
                                              ? SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.3,
                                                    color: AppColors.primary,
                                                  ),
                                                )
                                              : _SocialIcon(
                                                  asset: _appleAsset,
                                                  size: r.scale(
                                                    compact ? 22 : 24,
                                                  ),
                                                  tintForDarkMode: true,
                                                ),
                                          isLoading: anyLoading,
                                          onPressed: controller.loginWithApple,
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    0,
                    horizontal,
                    r.scale(compact ? 8 : 12),
                  ),
                  child: _TermsFooter(
                    compact: compact,
                    onTermsTap: openTermsOfService,
                    onPrivacyTap: openPrivacyPolicy,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneNumberField extends StatelessWidget {
  const _PhoneNumberField({
    required this.height,
    required this.isDark,
  });

  final double height;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AuthController>();
    final background = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE8E8ED);
    final radius = height / 2;
    final muted = AppColors.textSecondaryOf(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor),
        ),
        alignment: Alignment.center,
        child: TextField(
          controller: controller.phoneController,
          enabled: !controller.isSigningIn,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          textAlignVertical: TextAlignVertical.center,
          maxLength: 10,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          onSubmitted: (_) => controller.sendPhoneOtp(),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            height: 1.2,
            color: AppColors.textPrimaryOf(context),
          ),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: 'Mobile number',
            hintStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: muted.withValues(alpha: 0.85),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 18, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🇮🇳',
                    style: TextStyle(fontSize: height < 54 ? 17 : 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+91',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      width: 1,
                      height: 18,
                      color: muted.withValues(alpha: isDark ? 0.35 : 0.28),
                    ),
                  ),
                ],
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            counterText: '',
            filled: false,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: const EdgeInsets.only(right: 18),
            isDense: true,
          ),
        ),
      ),
    );
  }
}

class _PrimaryContinueButton extends StatelessWidget {
  const _PrimaryContinueButton({
    required this.label,
    required this.onPressed,
    this.height = 52,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final double height;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final radius = height / 2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: isLoading && label.contains('...')
                    ? Row(
                        key: ValueKey(label),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: height < 54 ? 15 : 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        label,
                        key: ValueKey(label),
                        style: TextStyle(
                          fontSize: height < 54 ? 15 : 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.1,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lineColor = AppColors.isDark(context)
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.lightBorder;

    return Row(
      children: [
        Expanded(child: Divider(color: lineColor, thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
          child: Text(
            'or',
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ),
        Expanded(child: Divider(color: lineColor, thickness: 1)),
      ],
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.logoSize,
    required this.isDark,
    this.compact = false,
  });

  final double logoSize;
  final bool isDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final heroOverlap = r.scale(88, tablet: 100);

    return Padding(
      padding: EdgeInsets.only(right: heroOverlap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: r.scale(compact ? 24 : 28)),
          _AppLogo(size: logoSize, isDark: isDark),
          SizedBox(height: r.scale(compact ? 14 : 16)),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: r.scale(compact ? 22 : 24, tablet: 26),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryOf(context),
                height: 1.15,
                letterSpacing: -0.2,
              ),
              children: const [
                TextSpan(text: 'MyCalorie'),
                TextSpan(
                  text: 'Pal',
                  style: TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
          SizedBox(height: r.scale(compact ? 4 : 6)),
          Text(
            'Smarter tracking. Healthier you.',
            style: TextStyle(
              fontSize: r.scale(compact ? 13 : 14),
              color: AppColors.textSecondaryOf(context),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo({required this.size, required this.isDark});

  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.84;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: isDark ? 10 : 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: SvgPicture.asset(
          _LoginScaffold._logoAsset,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.isDark,
    this.height = 52,
    this.isLoading = false,
  });

  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  final bool isDark;
  final double height;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final radius = height / 2;
    final background = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE8E8ED);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: icon,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: height < 54 ? 15 : 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryOf(context),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  const _SocialIcon({
    required this.asset,
    this.size = 26,
    this.tintForDarkMode = false,
  });

  final String asset;
  final double size;
  final bool tintForDarkMode;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final tint = tintForDarkMode && isDark ? AppColors.darkTextPrimary : null;

    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        asset,
        fit: BoxFit.contain,
        colorFilter: tint != null
            ? ColorFilter.mode(tint, BlendMode.srcIn)
            : null,
      ),
    );
  }
}

class _CalorieWheel extends StatelessWidget {
  const _CalorieWheel({required this.size, required this.isDark});

  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ringWidth = size * 0.085;
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.lightBorder;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: ringWidth,
              color: trackColor,
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 0.78,
              strokeWidth: ringWidth,
              strokeCap: StrokeCap.round,
              color: AppColors.primary,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '2546',
                style: TextStyle(
                  fontSize: size * 0.2,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              SizedBox(height: size * 0.03),
              Text(
                'kcal',
                style: TextStyle(
                  fontSize: size * 0.11,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TermsFooter extends StatelessWidget {
  const _TermsFooter({
    required this.onTermsTap,
    required this.onPrivacyTap,
    this.compact = false,
  });

  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: compact ? 11 : 12,
      color: AppColors.textSecondaryOf(context).withValues(alpha: 0.9),
      height: 1.55,
    );

    final linkStyle = TextStyle(
      fontSize: compact ? 11 : 12,
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
      height: 1.55,
      decoration: TextDecoration.none,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'By continuing, you agree to our',
          textAlign: TextAlign.center,
          style: baseStyle,
        ),
        Text.rich(
          TextSpan(
            style: baseStyle,
            children: [
              TextSpan(
                text: 'Terms of Service',
                style: linkStyle,
                recognizer: TapGestureRecognizer()..onTap = onTermsTap,
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy.',
                style: linkStyle,
                recognizer: TapGestureRecognizer()..onTap = onPrivacyTap,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
