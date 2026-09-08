import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/responsive.dart';
import '../theme/app_colors.dart';

/// Unified progress: gender → age → goal → height → weight goal → activity → health.
abstract final class OnboardingFlowProgress {
  static const totalSteps = 7;
  static const gender = 0;
  static const age = 1;
  static const goalSetup = 2;
  static const height = 3;
  static const goalWeight = 4;
  static const activity = 5;
  static const health = 6;
}

/// Shared chrome for onboarding steps (personal details, goal, activity, …).
class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onContinue,
    required this.child,
    this.continueLabel = 'Continue',
    this.continueEnabled = true,
    this.errorText,
    this.showProgress = true,
    this.scrollable = false,
    this.footer,
  });

  final int stepIndex;
  final int totalSteps;
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback? onContinue;
  final Widget child;
  final String continueLabel;
  final bool continueEnabled;
  final String? errorText;
  final bool showProgress;
  final bool scrollable;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final pageBg = AppColors.backgroundOf(context);

    final body = Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: r.scale(28, tablet: 32),
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimaryOf(context),
            height: 1.15,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: r.scale(10)),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: r.scale(14, tablet: 15),
            color: AppColors.textSecondaryOf(context),
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (errorText != null) ...[
          SizedBox(height: r.scale(12)),
          Text(
            errorText!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        SizedBox(height: r.scale(8)),
        Expanded(
          child: scrollable
              ? SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: child,
                )
              : child,
        ),
      ],
    );

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: r.scale(20, tablet: 28)),
          child: Column(
            children: [
              SizedBox(height: r.scale(4)),
              OnboardingStepTopBar(
                stepIndex: stepIndex,
                totalSteps: totalSteps,
                onBack: onBack,
                showProgress: showProgress,
              ),
              SizedBox(height: r.scale(28)),
              Expanded(child: body),
              OnboardingContinueButton(
                label: continueLabel,
                onPressed: continueEnabled ? onContinue : null,
              ),
              if (footer != null) ...[
                SizedBox(height: r.scale(10)),
                footer!,
              ],
              SizedBox(height: r.scale(12)),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingStepTopBar extends StatelessWidget {
  const OnboardingStepTopBar({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
    required this.onBack,
    this.showProgress = true,
  });

  final int stepIndex;
  final int totalSteps;
  final VoidCallback onBack;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          OnboardingBackButton(onTap: onBack),
          const SizedBox(width: 14),
          Expanded(
            child: showProgress && totalSteps > 1
                ? OnboardingDotsProgress(
                    currentStep: stepIndex,
                    totalSteps: totalSteps,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class OnboardingBackButton extends StatelessWidget {
  const OnboardingBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Material(
      color: isDark ? AppColors.darkCard : Colors.white,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
      ),
    );
  }
}

class OnboardingCircleBackButton extends StatelessWidget {
  const OnboardingCircleBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OnboardingBackButton(onTap: onTap);
  }
}

/// Clean equal segments — clearer than tiny dots + hairlines.
class OnboardingDotsProgress extends StatelessWidget {
  const OnboardingDotsProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final track = isDark
        ? AppColors.darkBorder
        : Colors.white;
    final trackBorder = isDark
        ? Colors.transparent
        : Colors.black.withValues(alpha: 0.04);

    return SizedBox(
      height: 8,
      child: Row(
        children: List.generate(totalSteps, (i) {
          final active = i <= currentStep;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
              height: 6,
              margin: EdgeInsets.only(
                left: i == 0 ? 0 : 3,
                right: i == totalSteps - 1 ? 0 : 3,
              ),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : track,
                borderRadius: BorderRadius.circular(99),
                border: active
                    ? null
                    : Border.all(color: trackBorder, width: 1),
                boxShadow: active
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class OnboardingContinueButton extends StatelessWidget {
  const OnboardingContinueButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(28),
        color: AppColors.primary,
        disabledColor: AppColors.primary.withValues(alpha: 0.55),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class OnboardingUnitToggle extends StatelessWidget {
  const OnboardingUnitToggle({
    super.key,
    required this.left,
    required this.right,
    required this.leftSelected,
    required this.onLeft,
    required this.onRight,
  });

  final String left;
  final String right;
  final bool leftSelected;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final isDark = AppColors.isDark(context);
    return Padding(
      padding: EdgeInsets.only(top: r.scale(12), bottom: r.scale(8)),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorder
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chip(context, left, leftSelected, onLeft),
            _chip(context, right, !leftSelected, onRight),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    final r = context.responsive;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: r.scale(28, tablet: 34),
          vertical: r.scale(12, tablet: 14),
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: r.scale(16, tablet: 17),
            fontWeight: FontWeight.w800,
            color: selected
                ? Colors.white
                : AppColors.textPrimaryOf(context),
          ),
        ),
      ),
    );
  }
}

/// Cupertino wheel used on personal-details-style onboarding steps.
class OnboardingCupertinoValuePicker extends StatelessWidget {
  const OnboardingCupertinoValuePicker({
    super.key,
    required this.controller,
    required this.labels,
    required this.onSelectedItemChanged,
    this.unit,
    this.labelFontSize = 30,
  });

  final FixedExtentScrollController controller;
  final List<String> labels;
  final ValueChanged<int> onSelectedItemChanged;
  final String? unit;
  final double labelFontSize;

  static const _itemExtent = 52.0;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final primaryText = AppColors.textPrimaryOf(context);
    final secondaryText = AppColors.textSecondaryOf(context);
    final maxLen =
        labels.fold<int>(0, (m, s) => s.length > m ? s.length : m);

    // Tight highlight around the value (age "25" vs longer labels).
    final overlayWidth = maxLen <= 3
        ? r.scale(88, tablet: 96)
        : maxLen <= 6
            ? r.scale(128, tablet: 142)
            : maxLen <= 12
                ? r.scale(168, tablet: 190)
                : r.scale(210, tablet: 240);
    final pickerWidth = overlayWidth + r.scale(36, tablet: 44);

    final trailing = unit != null
        ? Padding(
            padding: EdgeInsets.only(left: r.scale(8)),
            child: Text(
              unit!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: secondaryText,
              ),
            ),
          )
        : Padding(
            padding: EdgeInsets.only(left: r.scale(6)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                OnboardingBoldChevron(
                  up: true,
                  onTap: () => _nudgePicker(controller, -1, labels.length),
                ),
                const SizedBox(height: 10),
                OnboardingBoldChevron(
                  up: false,
                  onTap: () => _nudgePicker(controller, 1, labels.length),
                ),
              ],
            ),
          );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: pickerWidth,
          child: CupertinoPicker.builder(
            scrollController: controller,
            itemExtent: _itemExtent,
            diameterRatio: 1.2,
            squeeze: 1.05,
            useMagnifier: true,
            magnification: 1.15,
            backgroundColor: Colors.transparent,
            selectionOverlay: Center(
              child: Container(
                width: overlayWidth,
                height: _itemExtent - 4,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.55),
                    width: 1.4,
                  ),
                ),
              ),
            ),
            onSelectedItemChanged: onSelectedItemChanged,
            childCount: labels.length,
            itemBuilder: (context, index) {
              return Center(
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.w700,
                    color: primaryText,
                    height: 1,
                  ),
                ),
              );
            },
          ),
        ),
        trailing,
      ],
    );
  }

  void _nudgePicker(
    FixedExtentScrollController controller,
    int delta,
    int itemCount,
  ) {
    if (!controller.hasClients || itemCount <= 0) return;
    final next = (controller.selectedItem + delta).clamp(0, itemCount - 1);
    if (next == controller.selectedItem) return;
    controller.animateToItem(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }
}

class OnboardingBoldChevron extends StatelessWidget {
  const OnboardingBoldChevron({
    super.key,
    required this.up,
    this.onTap,
  });

  final bool up;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: CustomPaint(
          size: const Size(20, 11),
          painter: _OnboardingChevronPainter(
            color: up
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.primary,
            up: up,
            strokeWidth: 3.4,
          ),
        ),
      ),
    );
  }
}

class _OnboardingChevronPainter extends CustomPainter {
  const _OnboardingChevronPainter({
    required this.color,
    required this.up,
    required this.strokeWidth,
  });

  final Color color;
  final bool up;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final inset = strokeWidth / 2;
    final path = Path();
    if (up) {
      path
        ..moveTo(inset, size.height - inset)
        ..lineTo(size.width / 2, inset)
        ..lineTo(size.width - inset, size.height - inset);
    } else {
      path
        ..moveTo(inset, inset)
        ..lineTo(size.width / 2, size.height - inset)
        ..lineTo(size.width - inset, inset);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _OnboardingChevronPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.up != up ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// White option card with mint selected state (gender / activity / goal).
class OnboardingOptionCard extends StatelessWidget {
  const OnboardingOptionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final mintFill = AppColors.primary.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(18),
            vertical: r.scale(subtitle == null ? 18 : 16),
          ),
          decoration: BoxDecoration(
            color: selected ? mintFill : AppColors.cardOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1.6,
            ),
            boxShadow: selected
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                SizedBox(width: r.scale(14)),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: r.scale(16, tablet: 17),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: r.scale(13, tablet: 14),
                          color: AppColors.textSecondaryOf(context),
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
