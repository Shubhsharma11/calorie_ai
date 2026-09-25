import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../core/onboarding_nav.dart';
import '../core/responsive.dart';
import '../models/lifestyle_habits.dart';
import '../theme/app_colors.dart';
import 'onboarding_question_transition.dart';
import 'onboarding_step_scaffold.dart';

/// Multi-select onboarding screen — soft rows with + / check (Cupertino).
class OnboardingMultiChoicePage extends StatelessWidget {
  const OnboardingMultiChoicePage({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
    required this.title,
    required this.options,
    required this.selectedValues,
    required this.onToggle,
    required this.onBack,
    required this.onContinue,
    this.subtitle,
    this.showProgress = true,
    this.continueLabel = 'Continue',
    this.continueEnabled = true,
    this.onSelectAll,
    this.selectAllSelected = false,
  });

  final int stepIndex;
  final int totalSteps;
  final String title;
  final String? subtitle;
  final List<HabitOption> options;
  final Set<String> selectedValues;
  final ValueChanged<String> onToggle;
  final VoidCallback onBack;
  final VoidCallback? onContinue;
  final VoidCallback? onSelectAll;
  final bool selectAllSelected;
  final bool showProgress;
  final String continueLabel;
  final bool continueEnabled;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final canContinue = continueEnabled && selectedValues.isNotEmpty;

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
                showProgress: showProgress,
                onBack: () {
                  OnboardingNav.markBackward();
                  onBack();
                },
                sectionLabel: showProgress
                    ? OnboardingJourney.labelForStep(stepIndex)
                    : null,
              ),
              SizedBox(height: r.scale(28)),
              Expanded(
                child: OnboardingQuestionTransition(
                  stepKey: stepIndex,
                  question: OnboardingQuestionHeader(title: title),
                  description: subtitle == null || subtitle!.trim().isEmpty
                      ? null
                      : OnboardingQuestionDescription(subtitle!),
                  answer: ListView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    children: [
                      if (onSelectAll != null) ...[
                        OnboardingOptionCard(
                          title: 'Select all',
                          selected: false,
                          trailing: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: r.scale(22),
                            height: r.scale(22),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selectAllSelected
                                  ? AppColors.primary
                                  : CupertinoColors.transparent,
                              border: Border.all(
                                color: selectAllSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondaryOf(context),
                                width: 1.5,
                              ),
                            ),
                            child: selectAllSelected
                                ? Icon(
                                    CupertinoIcons.check_mark,
                                    size: r.scale(13),
                                    color: CupertinoColors.white,
                                  )
                                : null,
                          ),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onSelectAll!();
                          },
                        ),
                        SizedBox(height: r.scale(10)),
                      ],

                      for (final option in options) ...[
                        OnboardingOptionCard(
                          title: option.label,
                          leading: option.emoji == null
                              ? null
                              : Text(
                                  option.emoji!,
                                  style: TextStyle(fontSize: r.scale(20)),
                                ),
                          selected: selectedValues.contains(option.value),
                          trailing: selectedValues.contains(option.value)
                              ? Icon(
                                  CupertinoIcons.check_mark,
                                  size: r.scale(20),
                                  color: AppColors.primary,
                                )
                              : null,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onToggle(option.value);
                          },
                        ),
                        SizedBox(height: r.scale(10)),
                      ],
                    ],
                  ),
                ),
              ),
              OnboardingContinueButton(
                label: continueLabel,
                onPressed: canContinue
                    ? () {
                        OnboardingNav.markForward();
                        onContinue?.call();
                      }
                    : null,
              ),
              SizedBox(height: r.scale(12)),
            ],
          ),
        ),
      ),
    );
  }
}
