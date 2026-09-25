import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/onboarding_nav.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/lifestyle_habits.dart';
import '../models/onboarding_request_model.dart';
import '../models/profile_sync_snapshot.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/onboarding_question_transition.dart';
import '../widgets/onboarding_step_scaffold.dart';

enum _LivingStep { region, state }

/// Region → state picker for preferred Indian food culture (not residence).
class LivingAreaView extends StatefulWidget {
  const LivingAreaView({super.key});

  @override
  State<LivingAreaView> createState() => _LivingAreaViewState();
}

class _LivingAreaViewState extends State<LivingAreaView> {
  late final UserController _user = Get.find<UserController>();
  late final ProfileSyncSnapshot _baseline;
  _LivingStep _step = _LivingStep.region;
  String? _region;
  String? _state;
  bool _forward = true;
  bool _transitioning = false;
  bool _saving = false;

  bool get _fromProfile => RouteArgs.isEditingFromProfile;

  IndiaLivingRegion? get _selectedRegion =>
      LifestyleHabitOptions.livingRegionByValue(_region);

  @override
  void initState() {
    super.initState();
    _baseline = _user.captureProfileSyncSnapshot();
    _region = _user.user.livingArea;
    _state = _user.user.livingState;
    // Resume on state step when both are already chosen.
    if (_region != null &&
        _state != null &&
        LifestyleHabitOptions.livingRegionByValue(_region) != null) {
      _step = _LivingStep.state;
    }
  }

  void _persistDraft() {
    if (_fromProfile) return;
    _user.user.livingArea = _region;
    _user.user.livingState = _state;
    _user.scheduleOnboardingDraftSave();
  }

  Future<void> _goTo(_LivingStep next, {required bool forward}) async {
    if (_transitioning || next == _step) return;
    _transitioning = true;
    if (forward) {
      OnboardingNav.markForward();
    } else {
      OnboardingNav.markBackward();
    }
    setState(() {
      _forward = forward;
      _step = next;
    });
    await Future<void>.delayed(OnboardingMotion.duration);
    if (!mounted) return;
    _transitioning = false;
  }

  Future<void> _onBack() async {
    if (_transitioning || _saving) return;
    if (_step == _LivingStep.state) {
      await _goTo(_LivingStep.region, forward: false);
      return;
    }
    if (_fromProfile) {
      Get.back<void>();
      return;
    }
    await _user.goToPreviousOnboardingStep(AppRoutes.livingArea);
  }

  Future<void> _onContinue() async {
    if (_transitioning || _saving) return;

    if (_step == _LivingStep.region) {
      if (_region == null) {
        AppSnackbar.error('Please choose a food region to continue.');
        return;
      }
      // Clear state if region changed.
      if (_selectedRegion == null ||
          !(_selectedRegion!.states.any((s) => s.value == _state))) {
        _state = null;
      }
      _persistDraft();
      await _goTo(_LivingStep.state, forward: true);
      return;
    }

    if (_state == null) {
      AppSnackbar.error('Please choose a state food style to continue.');
      return;
    }

    _user.user.livingArea = _region;
    _user.user.livingState = _state;
    if (_fromProfile) {
      if (_region == _baseline.livingArea &&
          _state == _baseline.livingState) {
        AppSnackbar.info('No changes to save.', title: 'Nothing changed');
        Get.back<void>();
        return;
      }
      setState(() => _saving = true);
      try {
        final error = await _user.patchOnboarding(
          OnboardingPatchModel.livingArea(area: _region!, state: _state),
        );
        if (!mounted) return;
        if (error != null) {
          AppSnackbar.error(error, title: 'Save failed');
          return;
        }
        Get.back<void>();
        AppSnackbar.success('Food region updated.');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }
    await _user.persistOnboardingStep(AppRoutes.dietPreferences);
    await OnboardingNav.offNamed(
      AppRoutes.dietPreferences,
      arguments: RouteArgs.dietLifestyleMap,
    );
  }

  void _selectRegion(String value) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_region != value) {
        _region = value;
        _state = null;
      } else {
        _region = value;
      }
    });
    _persistDraft();
  }

  void _selectState(String value) {
    HapticFeedback.selectionClick();
    setState(() => _state = value);
    _persistDraft();
  }

  String get _title => switch (_step) {
    _LivingStep.region => 'Which region’s food do you usually eat?',
    _LivingStep.state => 'Which state’s food feels most like home?',
  };

  String? get _subtitle => switch (_step) {
    _LivingStep.region =>
      'We’ll match your meals to the food you like to eat.',
    _LivingStep.state => _selectedRegion == null
        ? null
        : 'Pick the ${_selectedRegion!.label} food you enjoy most.',
  };

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final canContinue = _step == _LivingStep.region
        ? _region != null
        : _state != null;

    final options = _step == _LivingStep.region
        ? LifestyleHabitOptions.livingRegions
              .map((region) => region.asOption)
              .toList(growable: false)
        : (_selectedRegion?.states ?? const <HabitOption>[]);

    final selected = _step == _LivingStep.region ? _region : _state;

    final continueLabel = _saving
        ? 'Saving...'
        : (_fromProfile && _step == _LivingStep.state ? 'Save' : 'Continue');

    return PopScope(
      canPop: _fromProfile && _step == _LivingStep.region && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_onBack());
      },
      child: OnboardingCupertinoShell(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: r.scale(20, tablet: 28)),
            child: Column(
              children: [
                SizedBox(height: r.scale(4)),
                OnboardingStepTopBar(
                  stepIndex: _fromProfile
                      ? 0
                      : OnboardingFlowProgress.livingArea,
                  totalSteps: _fromProfile
                      ? 1
                      : OnboardingFlowProgress.totalSteps,
                  showProgress: !_fromProfile,
                  onBack: () => unawaited(_onBack()),
                  sectionLabel: _fromProfile
                      ? null
                      : OnboardingJourney.labelForStep(
                          OnboardingFlowProgress.livingArea,
                        ),
                ),
                SizedBox(height: r.scale(28)),
                Expanded(
                  child: OnboardingQuestionTransition(
                    stepKey: _step,
                    forward: _forward,
                    question: OnboardingQuestionHeader(title: _title),
                    description: _subtitle == null
                        ? null
                        : OnboardingQuestionDescription(_subtitle!),
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
                            selected: selected == option.value,
                            onTap: () {
                              if (_saving) return;
                              if (_step == _LivingStep.region) {
                                _selectRegion(option.value);
                              } else {
                                _selectState(option.value);
                              }
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
                  onPressed: canContinue && !_saving
                      ? () => unawaited(_onContinue())
                      : null,
                ),
                SizedBox(height: r.scale(12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
