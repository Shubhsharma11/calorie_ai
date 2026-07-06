import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';

class LoginView extends GetView<AuthController> {
  const LoginView({super.key});

  static const _logoAsset = 'assets/image/login.png';
  static const _googleAsset = 'assets/image/google.svg';
  static const _appleAsset = 'assets/image/apple.svg';

  void _continue() => controller.login();

  void _showTerms(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'By using Calorie AI, you agree to track nutrition and health '
            'data responsibly. Do not use this app as a substitute for '
            'professional medical advice. You are responsible for the '
            'accuracy of the information you enter.',
            style: TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Calorie AI stores your profile, goals, and food logs on your '
            'device to personalize your experience. We do not sell your '
            'personal data. You can update or clear your information from '
            'the app settings at any time.',
            style: TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final horizontal = r.scale(24, tablet: 32);
    final compact = r.height < 720;
    final logoSize = r.scale(compact ? 52 : 58, tablet: 64);
    final buttonHeight = r.scale(compact ? 48 : 52, tablet: 54);
    final buttonGap = r.scale(compact ? 8 : 10);
    final sectionGap = r.scale(compact ? 18 : 22);
    final topPadding = r.scale(compact ? 36 : 44);

    return Scaffold(
      backgroundColor: AppColors.background,
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
                        child: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(
                            alpha:
                                Theme.of(context).brightness == Brightness.dark
                                ? 0.13
                                : 0.07,
                          ),
                        ),
                      ),
                      Positioned(
                        left: r.scale(46, tablet: 32),
                        bottom: r.scale(26, tablet: 28),
                        child: _CalorieWheel(size: r.scale(68, tablet: 79)),
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
                                      'Welcome back',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: r.scale(
                                          compact ? 30 : 34,
                                          tablet: 36,
                                        ),
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                        height: 1.12,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    SizedBox(height: r.scale(10)),
                                    Text(
                                      'Login to continue your health journey',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: r.scale(14, tablet: 15),
                                        color: AppColors.textSecondary,
                                        height: 1.4,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: sectionGap),
                                    _SocialLoginButton(
                                      height: buttonHeight,
                                      label: 'Continue with Google',
                                      icon: _SocialIcon(
                                        asset: _googleAsset,
                                        size: r.scale(compact ? 24 : 26),
                                      ),
                                      onPressed: controller.loginWithGoogle,
                                    ),
                                    SizedBox(height: buttonGap),
                                    _SocialLoginButton(
                                      height: buttonHeight,
                                      label: 'Continue with Apple',
                                      icon: _SocialIcon(
                                        asset: _appleAsset,
                                        size: r.scale(compact ? 24 : 26),
                                      ),
                                      onPressed: _continue,
                                    ),
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
                    onTermsTap: () => _showTerms(context),
                    onPrivacyTap: () => _showPrivacyPolicy(context),
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.logoSize, this.compact = false});

  final double logoSize;
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
          _AppLogo(size: logoSize),
          SizedBox(height: r.scale(compact ? 14 : 16)),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: r.scale(compact ? 22 : 24, tablet: 26),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                height: 1.15,
                letterSpacing: -0.2,
              ),
              children: const [
                TextSpan(text: 'Calorie '),
                TextSpan(
                  text: 'AI',
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
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// App logo from [login.png] — green mark on transparent background.
class _AppLogo extends StatelessWidget {
  const _AppLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Image.asset(
          LoginView._logoAsset,
          width: size,
          height: size,
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
    this.height = 52,
  });

  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                icon,
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: height < 50 ? 15 : 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.1,
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
  const _SocialIcon({required this.asset, this.size = 26});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(asset, fit: BoxFit.contain),
    );
  }
}

class _CalorieWheel extends StatelessWidget {
  const _CalorieWheel({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final ringWidth = size * 0.08;

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
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: size * 0.03),
              Text(
                'kcal',
                style: TextStyle(
                  fontSize: size * 0.11,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
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
      color: AppColors.textSecondary.withValues(alpha: 0.9),
      height: 1.55,
    );

    final linkStyle = TextStyle(
      fontSize: compact ? 11 : 12,
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
      height: 1.55,
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
