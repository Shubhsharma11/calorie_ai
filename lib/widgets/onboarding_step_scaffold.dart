import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/onboarding_nav.dart';
import '../core/responsive.dart';
import '../models/onboarding_journey.dart';
import '../theme/app_colors.dart';
import 'onboarding_cupertino_shell.dart';
import 'onboarding_question_transition.dart';

export '../models/onboarding_journey.dart'
    show OnboardingFlowProgress, OnboardingJourney, OnboardingSectionId;
export 'onboarding_cupertino_shell.dart' show OnboardingCupertinoShell;

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
    this.sectionLabel,
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

  /// Override section label; defaults from [OnboardingJourney].
  final String? sectionLabel;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final section =
        sectionLabel ??
        (showProgress ? OnboardingJourney.labelForStep(stepIndex) : null);

    return OnboardingCupertinoShell(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: r.scale(20, tablet: 28)),
          child: Column(
            children: [
              SizedBox(height: r.scale(4)),
              OnboardingStepTopBar(
                stepIndex: stepIndex,
                totalSteps: totalSteps,
                onBack: () {
                  OnboardingNav.markBackward();
                  onBack();
                },
                showProgress: showProgress,
                sectionLabel: section,
              ),
              SizedBox(height: r.scale(28)),
              Expanded(
                child: OnboardingQuestionTransition(
                  stepKey: stepIndex,
                  question: OnboardingQuestionHeader(
                    title: title,
                    errorText: errorText,
                  ),
                  description: subtitle.trim().isEmpty
                      ? null
                      : OnboardingQuestionDescription(subtitle),
                  answer: scrollable
                      ? SingleChildScrollView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          child: child,
                        )
                      : child,
                ),
              ),
              OnboardingContinueButton(
                label: continueLabel,
                onPressed: continueEnabled
                    ? () {
                        OnboardingNav.markForward();
                        onContinue?.call();
                      }
                    : null,
              ),
              if (footer != null) ...[SizedBox(height: r.scale(10)), footer!],
              SizedBox(height: r.scale(12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Question title (section label lives in the top bar).
/// Supporting copy is passed separately to [OnboardingQuestionTransition]
/// so it can reveal after the title.
class OnboardingQuestionHeader extends StatelessWidget {
  const OnboardingQuestionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.errorText,
  });

  final String title;

  /// Kept for call-site compatibility; prefer [OnboardingQuestionDescription]
  /// via [OnboardingQuestionTransition.description] for staggered reveal.
  final String? subtitle;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final theme = CupertinoTheme.of(context);
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.navLargeTitleTextStyle.copyWith(
            fontSize: r.scale(28, tablet: 32),
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),
        if (errorText != null) ...[
          SizedBox(height: r.scale(12)),
          Text(
            errorText!,
            textAlign: TextAlign.center,
            style: theme.textTheme.textStyle.copyWith(
              fontSize: 13,
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
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
    this.sectionLabel,
  });

  final int stepIndex;
  final int totalSteps;
  final VoidCallback onBack;
  final bool showProgress;

  /// When null and [showProgress], derived from [OnboardingJourney].
  final String? sectionLabel;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final rawLabel =
        sectionLabel ??
        (showProgress ? OnboardingJourney.labelForStep(stepIndex) : null);
    final label = rawLabel == null ? null : _titleCaseSection(rawLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: Align(
            alignment: Alignment.centerLeft,
            child: OnboardingBackButton(onTap: onBack),
          ),
        ),
        if (label != null) ...[
          SizedBox(height: r.scale(4)),
          AnimatedSwitcher(
            duration: OnboardingMotion.duration,
            switchInCurve: OnboardingMotion.inCurve,
            switchOutCurve: OnboardingMotion.outCurve,
            child: Text(
              label,
              key: ValueKey(label),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: r.scale(20, tablet: 22),
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: AppColors.primary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
        if (showProgress && totalSteps > 1) ...[
          SizedBox(height: r.scale(10)),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: r.scale(280, tablet: 340)),
              child: OnboardingSectionProgress(
                stepIndex: stepIndex,
                totalSteps: totalSteps,
              ),
            ),
          ),
          SizedBox(height: r.scale(4)),
        ],
      ],
    );
  }

  static String _titleCaseSection(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return trimmed;
    final lower = trimmed.toLowerCase();
    return '${lower[0].toUpperCase()}${lower.substring(1)}';
  }
}

/// Reference-style progress: **5 fixed milestones** + growing fill between them.
///
/// Personal → Goals → Lifestyle → Preferences → Create Plan.
/// Dots never move. Only the fill width animates across the 4 segments.
class OnboardingSectionProgress extends StatelessWidget {
  const OnboardingSectionProgress({
    super.key,
    required this.stepIndex,
    this.totalSteps = OnboardingFlowProgress.totalSteps,
  });

  final int stepIndex;
  final int totalSteps;

  static const _animDuration = Duration(milliseconds: 360);
  static const _milestoneCount = OnboardingMilestones.count;

  /// Legacy overall fraction (call sites). Prefer [_fillProgress] for the UI.
  static double progressForStep(int stepIndex, {int? totalSteps}) {
    final total = totalSteps ?? OnboardingFlowProgress.totalSteps;
    if (total <= 1) return 0.0;
    return (stepIndex / (total - 1)).clamp(0.0, 1.0);
  }

  /// Fill position 0..1 along the track (see [OnboardingJourney.fillProgressForStep]).
  static double _fillProgress(int stepIndex) {
    return OnboardingJourney.fillProgressForStep(stepIndex);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final isDark = AppColors.isDark(context);
    final fillProgress = _fillProgress(stepIndex);

    final trackColor = isDark
        ? CupertinoColors.systemGrey4.resolveFrom(context)
        : CupertinoColors.systemGrey5.resolveFrom(context);
    final activeColor = AppColors.primary;
    final holeColor = AppColors.backgroundOf(context);

    // Larger Cupertino-style track + milestones, centered by parent.
    final trackHeight = r.scale(5, tablet: 6);
    final dotSize = r.scale(18, tablet: 20);

    return SizedBox(
      width: double.infinity,
      height: dotSize,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final travel = (constraints.maxWidth - dotSize).clamp(
            0.0,
            double.infinity,
          );
          final fillWidth = (dotSize / 2) + (travel * fillProgress);

          return Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: (dotSize - trackHeight) / 2,
                child: Container(
                  height: trackHeight,
                  decoration: BoxDecoration(
                    color: trackColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: (dotSize - trackHeight) / 2,
                child: AnimatedContainer(
                  duration: _animDuration,
                  curve: Curves.easeOutCubic,
                  height: trackHeight,
                  width: fillWidth.clamp(0.0, constraints.maxWidth),
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              for (var i = 0; i < _milestoneCount; i++)
                Positioned(
                  left: (i / (_milestoneCount - 1)) * travel,
                  top: 0,
                  child: _FixedSectionDot(
                    size: dotSize,
                    completed: OnboardingJourney.isMilestoneCompleted(
                      i,
                      stepIndex,
                    ),
                    activeColor: activeColor,
                    trackColor: trackColor,
                    holeColor: holeColor,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FixedSectionDot extends StatelessWidget {
  const _FixedSectionDot({
    required this.size,
    required this.completed,
    required this.activeColor,
    required this.trackColor,
    required this.holeColor,
  });

  final double size;
  final bool completed;
  final Color activeColor;
  final Color trackColor;
  final Color holeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed ? activeColor : holeColor,
        border: Border.all(
          color: completed ? activeColor : trackColor,
          width: completed ? 0 : 1.5,
        ),
      ),
    );
  }
}

class OnboardingBackButton extends StatefulWidget {
  const OnboardingBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<OnboardingBackButton> createState() => _OnboardingBackButtonState();
}

class _OnboardingBackButtonState extends State<OnboardingBackButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
    reverseDuration: const Duration(milliseconds: 220),
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 1,
    end: 0.94,
  ).animate(CurvedAnimation(parent: _press, curve: Curves.easeOutCubic));

  late final Animation<double> _fade = Tween<double>(
    begin: 1,
    end: 0.78,
  ).animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final fontFamily = CupertinoTheme.of(
      context,
    ).textTheme.textStyle.fontFamily;
    final labelColor = AppColors.textPrimaryOf(context);
    final chevronColor = labelColor.withValues(alpha: 0.72);
    final fill = isDark
        ? CupertinoColors.systemGrey5.resolveFrom(context)
        : const Color(0xFFF4F4F6);
    final rim = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFE5E5EA);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press.forward(),
      onTapCancel: () => _press.reverse(),
      onTapUp: (_) async {
        await _press.reverse();
        if (!mounted) return;
        _handleTap();
      },
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, child) {
          return Opacity(
            opacity: _fade.value,
            child: Transform.scale(
              scale: _scale.value,
              alignment: Alignment.centerLeft,
              child: child,
            ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: rim, width: 0.8),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.035),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: const Offset(-1, 0.5),
                child: Icon(
                  CupertinoIcons.chevron_back,
                  size: 14,
                  color: chevronColor,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                'Prev',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.05,
                  letterSpacing: -0.15,
                  color: labelColor,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
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

/// Legacy flat bar — kept for any call sites still using step/total directly.
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
    return OnboardingSectionProgress(
      stepIndex: currentStep,
      totalSteps: totalSteps,
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
    final enabled = onPressed != null;
    final r = context.responsive;
    final height = r.scale(54, tablet: 56);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled ? 1 : 0.45,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(height / 2),
          color: AppColors.primary,
          disabledColor: AppColors.primary.withValues(alpha: 0.4),
          onPressed: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                }
              : null,
          child: Text(
            label,
            style: TextStyle(
              fontSize: r.scale(17, tablet: 18),
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white,
              letterSpacing: -0.2,
            ),
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
    return Padding(
      padding: EdgeInsets.only(top: r.scale(12), bottom: r.scale(8)),
      child: SizedBox(
        width: r.scale(160, tablet: 180),
        child: CupertinoSlidingSegmentedControl<bool>(
          groupValue: leftSelected,
          backgroundColor: AppColors.isDark(context)
              ? CupertinoColors.tertiarySystemFill.resolveFrom(context)
              : const Color(0xFFF2F2F7),
          thumbColor: AppColors.isDark(context)
              ? CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
                  context,
                )
              : CupertinoColors.white,
          children: {
            true: Padding(
              padding: EdgeInsets.symmetric(vertical: r.scale(8)),
              child: Text(
                left,
                style: TextStyle(
                  fontSize: r.scale(14),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ),
            false: Padding(
              padding: EdgeInsets.symmetric(vertical: r.scale(8)),
              child: Text(
                right,
                style: TextStyle(
                  fontSize: r.scale(14),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
            ),
          },
          onValueChanged: (value) {
            if (value == null) return;
            if (value) {
              onLeft();
            } else {
              onRight();
            }
          },
        ),
      ),
    );
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
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final theme = CupertinoTheme.of(context);
    final isDark = AppColors.isDark(context);
    final selectedFill = AppColors.primary.withValues(alpha: 0.12);
    final unselectedFill = isDark
        ? CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context)
        : AppColors.cardOf(context);
    final unselectedBorder = isDark
        ? CupertinoColors.separator.resolveFrom(context)
        : const Color(0xFFE5E5EA);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: r.scale(18),
          vertical: r.scale(subtitle == null ? 16 : 14),
        ),
        decoration: BoxDecoration(
          color: selected ? selectedFill : unselectedFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : unselectedBorder,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, SizedBox(width: r.scale(14))],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: r.scale(17, tablet: 18),
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: theme.textTheme.tabLabelTextStyle.copyWith(
                        fontSize: r.scale(13, tablet: 14),
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 140),
                child: Icon(
                  CupertinoIcons.check_mark_circled_solid,
                  size: r.scale(22),
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
    final maxLen = labels.fold<int>(0, (m, s) => s.length > m ? s.length : m);

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
  const OnboardingBoldChevron({super.key, required this.up, this.onTap});

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
