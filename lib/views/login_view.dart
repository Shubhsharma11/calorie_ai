import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';

class LoginView extends GetView<AuthController> {
  const LoginView({super.key});

  static const _logoAsset = 'assets/image/login 1.png';
  static const _heroAsset = 'assets/image/login2.png';
  static const _facebookAsset = 'assets/image/facebook.svg';
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
    final heroSize = r.scale(compact ? 150 : 170, tablet: 190);
    final buttonHeight = r.scale(compact ? 48 : 52, tablet: 54);
    final buttonGap = r.scale(compact ? 8 : 10);
    final sectionGap = r.scale(compact ? 18 : 22);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: r.scale(-8),
              right: r.scale(-36, tablet: -24),
              child: IgnorePointer(
                child: Image.asset(
                  _heroAsset,
                  width: heroSize,
                  height: heroSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      r.scale(compact ? 28 : 36),
                      horizontal,
                      r.scale(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: _BrandHeader(
                            logoSize: logoSize,
                            compact: compact,
                          ),
                        ),
                        SizedBox(height: r.scale(compact ? 44 : 52)),
                        Text(
                          'Welcome back!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: r.scale(
                              compact ? 26 : 28,
                              tablet: 32,
                            ),
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1.15,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: r.scale(compact ? 8 : 10 )),
                        Text(
                          'Login to continue your health journey',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: r.scale(compact ? 14 : 15),
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        SizedBox(height: sectionGap),
                        _SocialLoginButton(
                          height: buttonHeight,
                          label: 'Continue with Facebook',
                          icon: _SocialIcon(
                            asset: _facebookAsset,
                            size: r.scale(compact ? 24 : 26),
                          ),
                          onPressed: _continue,
                        ),
                        SizedBox(height: buttonGap),
                        _SocialLoginButton(
                          height: buttonHeight,
                          label: 'Continue with Google',
                          icon: _SocialIcon(
                            asset: _googleAsset,
                            size: r.scale(compact ? 24 : 26),
                          ),
                          onPressed: _continue,
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
  const _BrandHeader({
    required this.logoSize,
    this.compact = false,
  });

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
          SizedBox(height: r.scale(compact ? 16 : 20)),
          _AppLogo(size: logoSize),
          SizedBox(height: r.scale(compact ? 10 : 12)),
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

/// Crops the black padding around [login 1.png] so only the white icon tile shows.
class _AppLogo extends StatelessWidget {
  const _AppLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: OverflowBox(
        maxWidth: size * 1.55,
        maxHeight: size * 1.55,
        child: Image.asset(
          LoginView._logoAsset,
          fit: BoxFit.cover,
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
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.9),
            ),
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
  const _SocialIcon({
    required this.asset,
    this.size = 26,
  });

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        asset,
        fit: BoxFit.contain,
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
