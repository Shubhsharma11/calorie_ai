import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../core/responsive.dart';
import '../core/signed_out_navigation.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/privacy_policy_dialog.dart';
import '../widgets/terms_of_service_dialog.dart';

class LoginView extends GetView<AuthController> {
  const LoginView({super.key});

  static const _logoAsset = 'assets/image/logo1.21.svg';
  static const _googleAsset = 'assets/image/google.svg';
  static const _appleAsset = 'assets/image/apple.svg';

  @override
  Widget build(BuildContext context) {
    // After logout, never allow system Back / swipe to reveal Main/Home.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(SignedOutNavigation.onSignedOutRootBack());
      },
      child: _LoginPhoneHintBootstrap(
        child: _LoginScaffold(controller: controller),
      ),
    );
  }
}

/// Shared corner radius for phone field, Continue, and social buttons.
abstract final class _LoginControlStyle {
  static const double fieldRadius = 16;
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

class _LoginScaffold extends StatefulWidget {
  const _LoginScaffold({required this.controller});

  final AuthController controller;

  static const _logoAsset = LoginView._logoAsset;
  static const _googleAsset = LoginView._googleAsset;
  static const _appleAsset = LoginView._appleAsset;

  @override
  State<_LoginScaffold> createState() => _LoginScaffoldState();
}

class _LoginScaffoldState extends State<_LoginScaffold> {
  AuthController get controller => widget.controller;

  static const _anim = Duration(milliseconds: 280);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final isDark = AppColors.isDark(context);
    final r = context.responsive;
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = keyboard > 0;
    final compact = size.height < 740;

    final sidePad = r.scale(18, tablet: 28);
    final logoSize = r.scale(
      keyboardOpen ? (compact ? 44 : 48) : (compact ? 52 : 58),
      tablet: 64,
    );
    final controlHeight = r.scale(56, tablet: 60);
    const loginMint = Color(0xFFF1F8F1);
    final pageBg = isDark ? AppColors.darkBackground : loginMint;
    final sheetRadius = r.scale(28, tablet: 32);
    final cardPadH = r.scale(22, tablet: 28);
    final cardPadV = r.scale(compact ? 22 : 26);
    final brandGap = r.scale(keyboardOpen ? 18 : 22);
    final overlay = AppTheme.systemOverlayStyleFor(
      isDark ? Brightness.dark : Brightness.light,
    ).copyWith(
      statusBarColor: pageBg,
      systemNavigationBarColor: pageBg,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: pageBg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: AnimatedPadding(
            duration: _anim,
            curve: _curve,
            padding: EdgeInsets.fromLTRB(
              sidePad,
              r.scale(compact ? 18 : 24),
              sidePad,
              keyboardOpen ? r.scale(8) : padding.bottom + r.scale(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSize(
                  duration: _anim,
                  curve: _curve,
                  alignment: Alignment.topLeft,
                  child: _BrandHeader(
                    logoSize: logoSize,
                    compact: true,
                    isDark: isDark,
                    dense: keyboardOpen,
                  ),
                ),
                AnimatedContainer(
                  duration: _anim,
                  curve: _curve,
                  height: brandGap,
                ),
                Expanded(
                  child: AnimatedAlign(
                    duration: _anim,
                    curve: _curve,
                    alignment: keyboardOpen
                        ? Alignment.topCenter
                        : Alignment.center,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(sheetRadius),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.28 : 0.07,
                              ),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            cardPadH,
                            cardPadV,
                            cardPadH,
                            cardPadV,
                          ),
                          child: _LoginForm(
                            controller: controller,
                            controlHeight: controlHeight,
                            compact: compact,
                            isDark: isDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: _anim,
                  curve: _curve,
                  child: keyboardOpen
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: EdgeInsets.only(top: r.scale(14)),
                          child: _TermsFooter(
                            compact: compact,
                            onTermsTap: openTermsOfService,
                            onPrivacyTap: openPrivacyPolicy,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.controller,
    required this.controlHeight,
    required this.compact,
    required this.isDark,
  });

  final AuthController controller;
  final double controlHeight;
  final bool compact;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final labelColor = AppColors.textSecondaryOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Welcome back!',
          style: TextStyle(
            fontSize: r.scale(compact ? 24 : 28, tablet: 32),
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimaryOf(context),
            height: 1.15,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: r.scale(8)),
        Text(
          'Enter your mobile number to continue',
          style: TextStyle(
            fontSize: r.scale(14, tablet: 15),
            color: labelColor,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: r.scale(compact ? 20 : 24)),
        Text(
          'Mobile number',
          style: TextStyle(
            fontSize: r.scale(13),
            fontWeight: FontWeight.w500,
            color: labelColor,
            height: 1.2,
          ),
        ),
        SizedBox(height: r.scale(10)),
        _PhoneNumberField(
          height: controlHeight,
          isDark: isDark,
        ),
        SizedBox(height: r.scale(14)),
        Obx(() {
          final sending = controller.isSendingPhoneOtp.value;
          final anyLoading = controller.isSigningIn;
          return _PrimaryContinueButton(
            height: controlHeight,
            label: sending ? 'Sending code...' : 'Continue',
            isLoading: anyLoading,
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              controller.sendPhoneOtp();
            },
          );
        }),
        SizedBox(height: r.scale(compact ? 18 : 20)),
        _OrDivider(compact: compact),
        SizedBox(height: r.scale(compact ? 18 : 20)),
        Obx(() {
          final googleLoading = controller.isSigningInWithGoogle.value;
          final anyLoading = controller.isSigningIn;
          return _SocialLoginButton(
            height: controlHeight,
            isDark: isDark,
            label: googleLoading ? 'Signing in...' : 'Continue with Google',
            icon: googleLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.primary,
                    ),
                  )
                : _SocialIcon(
                    asset: _LoginScaffold._googleAsset,
                    size: r.scale(22),
                  ),
            isLoading: anyLoading,
            onPressed: controller.loginWithGoogle,
          );
        }),
        if (Platform.isIOS) ...[
          SizedBox(height: r.scale(12)),
          Obx(() {
            final appleLoading = controller.isSigningInWithApple.value;
            final anyLoading = controller.isSigningIn;
            return _SocialLoginButton(
              height: controlHeight,
              isDark: isDark,
              label: appleLoading ? 'Signing in...' : 'Continue with Apple',
              icon: appleLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.primary,
                      ),
                    )
                  : _SocialIcon(
                      asset: _LoginScaffold._appleAsset,
                      size: r.scale(22),
                      tintForDarkMode: true,
                    ),
              isLoading: anyLoading,
              onPressed: controller.loginWithApple,
            );
          }),
        ],
      ],
    );
  }
}

class _PhoneNumberField extends StatefulWidget {
  const _PhoneNumberField({
    required this.height,
    required this.isDark,
  });

  final double height;
  final bool isDark;

  @override
  State<_PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<_PhoneNumberField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AuthController>();
    final idleBorder = widget.isDark
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFFD5DAD6);
    final focused = _focusNode.hasFocus;
    final borderColor = focused ? AppColors.primary : idleBorder;
    final muted = AppColors.textSecondaryOf(context);

    return Obx(() {
      final enabled = !controller.isSigningIn;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: widget.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_LoginControlStyle.fieldRadius),
          border: Border.all(
            color: borderColor,
            width: focused ? 1.5 : 1.1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? () => _focusNode.requestFocus() : null,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🇮🇳',
                      style: TextStyle(
                        fontSize: widget.height < 56 ? 18 : 20,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+91',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        width: 1,
                        height: 20,
                        color: muted.withValues(
                          alpha: widget.isDark ? 0.35 : 0.30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller.phoneController,
                focusNode: _focusNode,
                enabled: enabled,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [
                  AutofillHints.telephoneNumberNational,
                ],
                autocorrect: false,
                enableSuggestions: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                textAlignVertical: TextAlignVertical.center,
                maxLength: 10,
                onTapOutside: (_) => _focusNode.unfocus(),
                onSubmitted: (_) {
                  _focusNode.unfocus();
                  controller.sendPhoneOtp();
                },
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.35,
                  height: 1.15,
                  color: AppColors.textPrimaryOf(context),
                ),
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: '98765 43210',
                  hintStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.15,
                    color: muted.withValues(alpha: 0.55),
                  ),
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.only(right: 16),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _PrimaryContinueButton extends StatelessWidget {
  const _PrimaryContinueButton({
    required this.label,
    required this.onPressed,
    this.height = 56,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final double height;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    const radius = _LoginControlStyle.fieldRadius;

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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      label,
                      key: ValueKey(label),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.1,
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
        ? Colors.white.withValues(alpha: 0.14)
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
    this.dense = false,
  });

  final double logoSize;
  final bool isDark;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final titleSize = dense
        ? r.scale(compact ? 22 : 24, tablet: 28)
        : r.scale(compact ? 26 : 28, tablet: 32);
    final tagSize = dense
        ? r.scale(compact ? 13 : 13.5)
        : r.scale(compact ? 14 : 15);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: logoSize,
          height: logoSize,
          child: _AppLogo(size: logoSize, isDark: isDark),
        ),
        SizedBox(height: r.scale(dense ? 8 : (compact ? 10 : 12))),
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryOf(context),
              height: 1.15,
              letterSpacing: -0.4,
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
        SizedBox(height: r.scale(dense ? 4 : 6)),
        Text(
          'Smarter tracking. Healthier you.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: tagSize,
            color: AppColors.textSecondaryOf(context),
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
    this.height = 56,
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
    const radius = _LoginControlStyle.fieldRadius;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFFD5DAD6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor, width: 1.1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Center(child: icon),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryOf(context),
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 22),
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
    final size = compact ? 11.5 : 12.0;
    final muted = AppColors.textSecondaryOf(context).withValues(alpha: 0.8);
    final baseStyle = TextStyle(
      fontSize: size,
      color: muted,
      height: 1.5,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.1,
    );
    final linkStyle = TextStyle(
      fontSize: size,
      color: AppColors.primary,
      height: 1.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'By continuing, you agree to our',
          textAlign: TextAlign.center,
          style: baseStyle,
        ),
        const SizedBox(height: 2),
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
                text: 'Privacy Policy',
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
