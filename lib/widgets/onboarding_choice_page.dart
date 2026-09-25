import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../core/onboarding_nav.dart';
import '../core/responsive.dart';
import '../models/lifestyle_habits.dart';
import '../theme/app_colors.dart';
import 'onboarding_question_transition.dart';
import 'onboarding_step_scaffold.dart';

/// Shared single-choice onboarding screen (Cupertino).
class OnboardingChoicePage extends StatelessWidget {
  const OnboardingChoicePage({
    super.key,
    required this.stepIndex,
    required this.totalSteps,
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onSelect,
    required this.onBack,
    required this.onContinue,
    this.subtitle,
    this.showProgress = true,
    this.continueLabel = 'Continue',
    this.continueEnabled = true,
  });

  final int stepIndex;
  final int totalSteps;
  final String title;
  final String? subtitle;
  final List<HabitOption> options;
  final String? selectedValue;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;
  final VoidCallback? onContinue;
  final bool showProgress;
  final String continueLabel;
  final bool continueEnabled;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final canContinue = continueEnabled && selectedValue != null;

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
                      for (final option in options) ...[
                        OnboardingOptionCard(
                          title: option.label,
                          leading: option.emoji == null
                              ? null
                              : Text(
                                  option.emoji!,
                                  style: TextStyle(fontSize: r.scale(20)),
                                ),
                          selected: selectedValue == option.value,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onSelect(option.value);
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
