import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import '../core/responsive.dart';
import '../theme/app_colors.dart';

class OtpVerifyView extends GetView<AuthController> {
  const OtpVerifyView({super.key});

  static const _logoAsset = 'assets/image/logo1.21.svg';

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final isDark = AppColors.isDark(context);
    final r = context.responsive;
    final horizontal = r.scale(24, tablet: 32);
    final compact = r.height < 720;
    final buttonHeight = r.scale(compact ? 52 : 56, tablet: 58);
    final logoSize = r.scale(compact ? 64 : 72, tablet: 80);

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            r.scale(8),
            horizontal,
            r.scale(compact ? 16 : 20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IconButton(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: AppColors.textPrimaryOf(context),
                ),
                onPressed: () => Get.back(),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: r.scale(420, tablet: 460),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: _OtpLogo(size: logoSize, isDark: isDark),
                          ),
                          SizedBox(height: r.scale(compact ? 24 : 28)),
                          Text(
                            'Verify your number',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: r.scale(compact ? 26 : 30, tablet: 32),
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryOf(context),
                              height: 1.15,
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: r.scale(10)),
                          Text(
                            'We’ve sent a 6-digit OTP to',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: r.scale(14, tablet: 15),
                              color: AppColors.textSecondaryOf(context),
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: r.scale(8)),
                          Obx(
                            () => Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _formatPhone(controller.phoneNumber.value),
                                  style: TextStyle(
                                    fontSize: r.scale(16, tablet: 17),
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimaryOf(context),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                InkWell(
                                  onTap: () => Get.back(),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Edit',
                                          style: TextStyle(
                                            fontSize: r.scale(14),
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        const Icon(
                                          Icons.edit_rounded,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: r.scale(compact ? 32 : 36)),
                          _OtpBoxes(
                            controller: controller.otpController,
                            isDark: isDark,
                            onCompleted: controller.verifyPhoneOtp,
                          ),
                          SizedBox(height: r.scale(20)),
                          Obx(() {
                            final canResend = controller.canResendOtp.value;
                            final countdown = controller.resendCountdown.value;
                            final sending = controller.isSendingPhoneOtp.value;

                            if (!canResend) {
                              return Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondaryOf(context),
                                  ),
                                  children: [
                                    const TextSpan(text: 'Resend OTP in '),
                                    TextSpan(
                                      text: _formatCountdown(countdown),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              );
                            }

                            return TextButton(
                              onPressed: sending || controller.isSigningIn
                                  ? null
                                  : controller.resendPhoneOtp,
                              child: Text(
                                sending ? 'Sending...' : 'Resend OTP',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          }),
                          SizedBox(height: r.scale(compact ? 28 : 32)),
                          Obx(() {
                            final verifying =
                                controller.isVerifyingPhoneOtp.value;
                            final anyLoading = controller.isSigningIn;
                            return _VerifyButton(
                              height: buttonHeight,
                              isLoading: verifying,
                              enabled: !anyLoading,
                              onPressed: controller.verifyPhoneOtp,
                            );
                          }),
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
    );
  }

  static String _formatPhone(String e164) {
    final digits = e164.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      final local = digits.substring(2);
      return '+91 ${local.substring(0, 5)} ${local.substring(5)}';
    }
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return e164.isEmpty ? '+91' : e164;
  }

  static String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _OtpLogo extends StatelessWidget {
  const _OtpLogo({required this.size, required this.isDark});

  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
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
          OtpVerifyView._logoAsset,
          width: size * 0.84,
          height: size * 0.84,
        ),
      ),
    );
  }
}

class _VerifyButton extends StatelessWidget {
  const _VerifyButton({
    required this.height,
    required this.onPressed,
    required this.enabled,
    this.isLoading = false,
  });

  final double height;
  final VoidCallback onPressed;
  final bool enabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final radius = height / 2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled && !isLoading ? onPressed : null,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Verify & Continue',
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
    );
  }
}

class _OtpBoxes extends StatefulWidget {
  const _OtpBoxes({
    required this.controller,
    required this.isDark,
    required this.onCompleted,
  });

  final TextEditingController controller;
  final bool isDark;
  final VoidCallback onCompleted;

  @override
  State<_OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_OtpBoxes> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    if (widget.controller.text.length == 6) {
      widget.onCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    final activeIndex = code.length.clamp(0, 5);

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: List.generate(6, (index) {
              final digit = index < code.length ? code[index] : null;
              final isActive =
                  _focusNode.hasFocus && index == activeIndex && code.length < 6;
              final isFilled = digit != null;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 5,
                    right: index == 5 ? 0 : 5,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF1F1F1F)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isActive
                            ? AppColors.primary
                            : (widget.isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : const Color(0xFFE5E5EA)),
                        width: isActive ? 1.8 : 1.2,
                      ),
                    ),
                    child: Text(
                      digit ?? '-',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isFilled
                            ? AppColors.textPrimaryOf(context)
                            : AppColors.textSecondaryOf(context)
                                .withValues(alpha: 0.35),
                        height: 1,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onTapOutside: (_) => _focusNode.unfocus(),
              onSubmitted: (_) {
                if (widget.controller.text.length == 6) {
                  widget.onCompleted();
                }
              },
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
