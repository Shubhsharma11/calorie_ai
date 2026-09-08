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

class _LoginScaffold extends StatefulWidget {
  const _LoginScaffold({required this.controller});

  final AuthController controller;

  static const _logoAsset = LoginView._logoAsset;
  static const _googleAsset = LoginView._googleAsset;
  static const _appleAsset = LoginView._appleAsset;
  static const _buddyAsset = 'assets/image/buddy/buddy_wave_hello.png';

  @override
  State<_LoginScaffold> createState() => _LoginScaffoldState();
}

class _LoginScaffoldState extends State<_LoginScaffold> {
  AuthController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final isDark = AppColors.isDark(context);
    final r = context.responsive;
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = keyboard > 0;
    final headerPad = r.scale(20, tablet: 28);
    final formPad = (size.width * 0.132).clamp(26.0, 40.0);
    final compact = size.height < 740;

    final logoSize = r.scale(compact ? 48 : 54, tablet: 60);
    final buttonHeight = r.scale(compact ? 48 : 52, tablet: 56);
    final buttonGap = r.scale(compact ? 8 : 10);
    final sectionGap = r.scale(compact ? 10 : 12);
    final pageBg =
        isDark ? AppColors.darkBackground : const Color(0xFFF1F8F1);

    final restingSheetTop = size.height * 0.463;
    final buddyHeight = size.height * 0.36;
    // Buddy sits ~halfway onto the white sheet (same as before).
    final visualInside = buddyHeight * 0.10;
    final imageBottomPad = buddyHeight * 0.10;
    final overlap = visualInside + imageBottomPad;
    final sheetRadius = r.scale(44, tablet: 48);
    final formTopPad = keyboardOpen
        ? r.scale(16)
        : (size.height * 0.074).clamp(
            visualInside + r.scale(16),
            visualInside + r.scale(36),
          );
    // Sheet sits above the keyboard; content scrolls if space is tight.
    final focusedBlockHeight = formTopPad +
        r.scale(compact ? 26 : 30) +
        r.scale(8) +
        r.scale(14) +
        sectionGap +
        buttonHeight +
        buttonGap +
        buttonHeight +
        r.scale(12);
    final availableAboveKeyboard = size.height - keyboard;
    final raisedSheetTop =
        (availableAboveKeyboard - focusedBlockHeight).clamp(
      padding.top + r.scale(44),
      restingSheetTop,
    );
    final sheetTop = keyboardOpen ? raisedSheetTop : restingSheetTop;
    final buddyTop = sheetTop - buddyHeight + overlap;

    return Scaffold(
      backgroundColor: pageBg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            top: sheetTop,
            bottom: keyboard,
            child: Material(
              color: isDark ? AppColors.darkCard : Colors.white,
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(sheetRadius),
                topRight: Radius.circular(sheetRadius),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        formPad,
                        formTopPad,
                        formPad,
                        r.scale(8),
                      ),
                      child: _LoginForm(
                        controller: controller,
                        buttonHeight: buttonHeight,
                        buttonGap: buttonGap,
                        sectionGap: sectionGap,
                        compact: compact,
                        isDark: isDark,
                        keyboardOpen: keyboardOpen,
                      ),
                    ),
                  ),
                  if (!keyboardOpen)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        formPad + 4,
                        r.scale(8),
                        formPad + 4,
                        padding.bottom + r.scale(12),
                      ),
                      child: _TermsFooter(
                        compact: compact,
                        onTermsTap: openTermsOfService,
                        onPrivacyTap: openPrivacyPolicy,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Buddy on top of the sheet so it sits half on the box.
          if (!keyboardOpen)
            Positioned(
              top: buddyTop,
              left: 0,
              right: 0,
              height: buddyHeight,
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: buddyHeight,
                    width: size.width * 0.72,
                    child: Image.asset(
                      _LoginScaffold._buddyAsset,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            top: padding.top + r.scale(compact ? 4 : 8),
            left: headerPad,
            right: headerPad,
            child: _BrandHeader(
              logoSize: logoSize,
              compact: compact,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.controller,
    required this.buttonHeight,
    required this.buttonGap,
    required this.sectionGap,
    required this.compact,
    required this.isDark,
    required this.keyboardOpen,
  });

  final AuthController controller;
  final double buttonHeight;
  final double buttonGap;
  final double sectionGap;
  final bool compact;
  final bool isDark;
  final bool keyboardOpen;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Welcome back!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: r.scale(compact ? 26 : 30, tablet: 34),
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimaryOf(context),
            height: 1.12,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: r.scale(8)),
        Text(
          'Enter your mobile number to continue',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: r.scale(14, tablet: 15),
            color: AppColors.textSecondaryOf(context),
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
          final sending = controller.isSendingPhoneOtp.value;
          final anyLoading = controller.isSigningIn;
          return _PrimaryContinueButton(
            height: buttonHeight,
            label: sending ? 'Sending code...' : 'Continue',
            isLoading: anyLoading,
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              controller.sendPhoneOtp();
            },
          );
        }),
        if (!keyboardOpen) ...[
          SizedBox(height: sectionGap),
          _OrDivider(compact: compact),
          SizedBox(height: sectionGap),
          Obx(() {
            final googleLoading = controller.isSigningInWithGoogle.value;
            final anyLoading = controller.isSigningIn;
            return _SocialLoginButton(
              height: buttonHeight,
              isDark: isDark,
              label: googleLoading ? 'Signing in...' : 'Continue with Google',
              icon: googleLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: AppColors.primary,
                      ),
                    )
                  : _SocialIcon(
                      asset: _LoginScaffold._googleAsset,
                      size: r.scale(compact ? 22 : 24),
                    ),
              isLoading: anyLoading,
              onPressed: controller.loginWithGoogle,
            );
          }),
          if (Platform.isIOS) ...[
            SizedBox(height: buttonGap),
            Obx(() {
              final appleLoading = controller.isSigningInWithApple.value;
              final anyLoading = controller.isSigningIn;
              return _SocialLoginButton(
                height: buttonHeight,
                isDark: isDark,
                label: appleLoading ? 'Signing in...' : 'Continue with Apple',
                icon: appleLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: AppColors.primary,
                        ),
                      )
                    : _SocialIcon(
                        asset: _LoginScaffold._appleAsset,
                        size: r.scale(compact ? 22 : 24),
                        tintForDarkMode: true,
                      ),
                isLoading: anyLoading,
                onPressed: controller.loginWithApple,
              );
            }),
          ],
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
    final sheetColor = widget.isDark ? AppColors.darkCard : Colors.white;
    final idleBorder = widget.isDark
        ? Colors.white.withValues(alpha: 0.14)
        : const Color(0xFFD9DCE3);
    final focused = _focusNode.hasFocus;
    final borderColor = focused ? AppColors.primary : idleBorder;
    final radius = widget.height / 2;
    final muted = AppColors.textSecondaryOf(context);

    return Obx(() {
      final enabled = !controller.isSigningIn;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                _focusNode.requestFocus();
                SystemChannels.textInput.invokeMethod('TextInput.show');
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: widget.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor,
              width: focused ? 1.5 : 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🇮🇳',
                      style: TextStyle(
                        fontSize: widget.height < 54 ? 17 : 18,
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
                        height: 18,
                        color: muted.withValues(
                          alpha: widget.isDark ? 0.35 : 0.28,
                        ),
                      ),
                    ),
                  ],
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
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  onSubmitted: (_) {
                    _focusNode.unfocus();
                    controller.sendPhoneOtp();
                  },
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.35,
                    height: 1.15,
                    color: AppColors.textPrimaryOf(context),
                  ),
                  cursorColor: AppColors.primary,
                  decoration: InputDecoration(
                    hintText: 'Mobile number',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.15,
                      color: muted.withValues(alpha: 0.8),
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
        ),
      );
    });
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _AppLogo(size: logoSize, isDark: isDark),
        SizedBox(height: r.scale(compact ? 8 : 10)),
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: TextStyle(
              fontSize: r.scale(compact ? 21 : 24, tablet: 26),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryOf(context),
              height: 1.15,
              letterSpacing: -0.3,
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
        SizedBox(height: r.scale(3)),
        Text(
          'Smarter tracking. Healthier you.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: r.scale(compact ? 12 : 13.5),
            color: AppColors.textSecondaryOf(context),
            height: 1.3,
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
