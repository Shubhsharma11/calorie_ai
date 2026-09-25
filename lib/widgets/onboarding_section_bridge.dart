import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/onboarding_journey.dart';
import '../theme/app_colors.dart';

/// Brief section handoff (Personal ✓ → Goals) — not a full splash page.
abstract final class OnboardingSectionBridge {
  /// Shows a soft handoff when moving into a later section.
  static Future<void> maybeShow({
    required int fromStepIndex,
    required int toStepIndex,
  }) async {
    final fromIdx = OnboardingJourney.sectionIndexForStep(fromStepIndex);
    final toIdx = OnboardingJourney.sectionIndexForStep(toStepIndex);
    if (toIdx <= fromIdx) return;

    final completed = OnboardingJourney.sectionForStep(fromStepIndex);
    final next = OnboardingJourney.sectionForStep(toStepIndex);
    final copy = OnboardingJourney.bridgeCopy(completed.id);
    if (copy == null) return;

    await Get.dialog<void>(
      _SectionBridgeDialog(
        completedLabel: OnboardingJourney.labelForSection(completed.id),
        nextLabel: OnboardingJourney.labelForSection(next.id),
        message: copy,
      ),
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.18),
    );
  }

  /// Convenience when leaving the last question of a section.
  static Future<void> maybeShowAfterStep(int completedStepIndex) async {
    final next = OnboardingJourney.nextSectionAfter(completedStepIndex);
    if (next == null) return;
    final completed = OnboardingJourney.sectionForStep(completedStepIndex);
    final copy = OnboardingJourney.bridgeCopy(completed.id);
    if (copy == null) return;

    await Get.dialog<void>(
      _SectionBridgeDialog(
        completedLabel: OnboardingJourney.labelForSection(completed.id),
        nextLabel: OnboardingJourney.labelForSection(next),
        message: copy,
      ),
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.18),
    );
  }
}

class _SectionBridgeDialog extends StatefulWidget {
  const _SectionBridgeDialog({
    required this.completedLabel,
    required this.nextLabel,
    required this.message,
  });

  final String completedLabel;
  final String nextLabel;
  final String message;

  @override
  State<_SectionBridgeDialog> createState() => _SectionBridgeDialogState();
}

class _SectionBridgeDialogState extends State<_SectionBridgeDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 360), () {
      if (mounted) Get.back<void>();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    return Center(
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: Material(
            color: AppColors.cardOf(context),
            elevation: 0,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.completedLabel}  ✓',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        letterSpacing: -0.2,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.nextLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
