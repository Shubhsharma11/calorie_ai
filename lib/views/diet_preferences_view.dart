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
import '../models/diet_type.dart';
import '../models/lifestyle_habits.dart';
import '../models/onboarding_request_model.dart';
import '../models/profile_sync_snapshot.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/onboarding_question_transition.dart';
import '../widgets/onboarding_step_scaffold.dart';

enum _DietStep { dietType, avoid, meals }

class DietPreferencesView extends StatefulWidget {
  const DietPreferencesView({super.key});

  @override
  State<DietPreferencesView> createState() => _DietPreferencesViewState();
}

class _DietPreferencesViewState extends State<DietPreferencesView> {
  late final UserController _user = Get.find<UserController>();
  late final ProfileSyncSnapshot _baseline;

  _DietStep _step = _DietStep.dietType;
  DietType? _dietType;
  int? _mealsPerDay;
  final Set<String> _avoidSelected = {};
  bool _saving = false;
  bool _transitioning = false;
  bool _forward = true;

  bool get _fromProfile => RouteArgs.isEditingFromProfile;

  /// Lifestyle segment: diet type → meals → cooking.
  bool get _isLifestylePhase {
    if (_fromProfile && _isAvoidOnlyEdit) return false;
    if (_fromProfile) return false;
    final phase = RouteArgs.dietPreferencesPhase;
    return phase == null ||
        phase == RouteArgs.dietPhaseLifestyle ||
        phase == RouteArgs.dietPhaseDietType;
  }

  /// Preferences tail: foods to avoid → plan loading.
  bool get _isAvoidPhase {
    return RouteArgs.dietPreferencesPhase == RouteArgs.dietPhaseAvoid;
  }

  /// Profile edit: only “Don’t eat” (skip diet type / meals).
  bool get _isAvoidOnlyEdit => _fromProfile && _isAvoidPhase;

  int get _progressIndex => switch (_step) {
    _DietStep.dietType => OnboardingFlowProgress.dietType,
    _DietStep.avoid => OnboardingFlowProgress.foodsToAvoid,
    _DietStep.meals => OnboardingFlowProgress.mealsPerDay,
  };

  String get _title => switch (_step) {
    _DietStep.dietType => 'What type of diet do you follow?',
    _DietStep.avoid => 'Anything you don’t eat?',
    _DietStep.meals => 'How many meals do you prefer?',
  };

  String get _description => switch (_step) {
    _DietStep.dietType =>
      'Vegetarian, vegan, non-veg — we’ll match meals to your diet.',
    _DietStep.avoid => 'Select all that apply — or choose nothing.',
    _DietStep.meals =>
      'This helps us size portions and daily calories for your routine.',
  };

  String get _continueLabel {
    if (_saving) return 'Saving...';
    if (_fromProfile && (_step == _DietStep.meals || _isAvoidOnlyEdit)) {
      return 'Save';
    }
    return 'Continue';
  }

  @override
  void initState() {
    super.initState();
    _baseline = _user.captureProfileSyncSnapshot();
    final profile = _user.user;
    _dietType = profile.dietType;
    _mealsPerDay = profile.mealsPerDay;
    _hydrateAvoidFromSaved(profile.foodsToAvoid);

    if (_isAvoidPhase) {
      _step = _DietStep.avoid;
      final allowed = LifestyleHabitOptions.foodsToAvoidFor(
        _dietType ?? profile.dietType,
      ).map((o) => o.value).toSet();
      _avoidSelected.removeWhere((v) => !allowed.contains(v));
    } else if (_isLifestylePhase &&
        RouteArgs.onboardingStartStep == RouteArgs.stepMeals) {
      _step = _DietStep.meals;
    } else {
      _step = _DietStep.dietType;
    }
  }

  void _hydrateAvoidFromSaved(String saved) {
    final text = saved.trim();
    if (text.isEmpty) return;
    final lower = text.toLowerCase();
    if (lower.contains('nothing') || lower == 'none') {
      _avoidSelected.add('none');
      return;
    }
    for (final option in LifestyleHabitOptions.foodsToAvoid) {
      if (option.value == 'none') continue;
      if (lower.contains(option.label.toLowerCase()) ||
          lower.contains(option.value.replaceAll('_', ' '))) {
        _avoidSelected.add(option.value);
      }
    }
  }

  String _avoidToSave() {
    if (_avoidSelected.isEmpty || _avoidSelected.contains('none')) {
      return '';
    }
    return LifestyleHabitOptions.foodsToAvoid
        .where((o) => _avoidSelected.contains(o.value) && o.value != 'none')
        .map((o) => o.label)
        .join(', ');
  }

  void _persistDraft() {
    if (_fromProfile) return;
    unawaited(
      _user.saveDietPreferences(
        dietType: _dietType,
        foodAllergies: List<String>.from(_user.user.foodAllergies),
        foodsToAvoid: _avoidToSave(),
        mealsPerDay: _mealsPerDay,
      ),
    );
  }

  void _toggleAvoid(String value) {
    HapticFeedback.selectionClick();
    setState(() {
      if (value == 'none') {
        _avoidSelected
          ..clear()
          ..add('none');
      } else {
        _avoidSelected.remove('none');
        if (!_avoidSelected.remove(value)) _avoidSelected.add(value);
      }
    });
    _persistDraft();
  }

  Future<void> _animateTo(_DietStep next, {required bool forward}) async {
    if (_transitioning || next == _step) return;
    if (forward) {
      OnboardingNav.markForward();
    } else {
      OnboardingNav.markBackward();
    }
    setState(() {
      _transitioning = true;
      _forward = forward;
      _step = next;
    });
    await Future<void>.delayed(OnboardingMotion.duration);
    if (!mounted) return;
    setState(() => _transitioning = false);
  }

  Future<void> _onBack() async {
    if (_saving || _transitioning) return;

    if (_isAvoidPhase) {
      if (_fromProfile) {
        Get.back<void>();
        return;
      }
      OnboardingNav.markBackward();
      _persistDraft();
      await _user.goToPreviousOnboardingStep(AppRoutes.dietPreferences);
      return;
    }

    if (_isLifestylePhase) {
      if (_step == _DietStep.meals) {
        await _animateTo(_DietStep.dietType, forward: false);
        return;
      }
      OnboardingNav.markBackward();
      _persistDraft();
      await _user.goToPreviousOnboardingStep(AppRoutes.dietPreferences);
      return;
    }

    // Profile: dietType ← avoid ← meals
    if (_step == _DietStep.meals) {
      await _animateTo(_DietStep.avoid, forward: false);
      return;
    }
    if (_step == _DietStep.avoid) {
      await _animateTo(_DietStep.dietType, forward: false);
      return;
    }
    Get.back<void>();
  }

  void _selectDiet(DietType type) {
    HapticFeedback.selectionClick();
    setState(() => _dietType = type);
    _user.user.dietType = type;
    _user.user.applyDietTypeConstraints();
    // Drop avoid chips that no longer apply (e.g. red meat after going veg).
    final allowed = LifestyleHabitOptions.foodsToAvoidFor(type)
        .map((o) => o.value)
        .toSet();
    _avoidSelected.removeWhere((v) => !allowed.contains(v));
    _persistDraft();
  }

  void _selectMeals(int count) {
    HapticFeedback.selectionClick();
    setState(() => _mealsPerDay = count);
    _persistDraft();
  }

  Future<void> _continue() async {
    if (_saving || _transitioning) return;

    if (_isAvoidPhase) {
      if (_avoidSelected.isEmpty) {
        AppSnackbar.error('Select at least one option to continue.');
        return;
      }
      if (_fromProfile) {
        await _finishAvoidOnlyProfile();
        return;
      }
      _persistDraft();
      await _finishToLoading();
      return;
    }

    if (_isLifestylePhase) {
      switch (_step) {
        case _DietStep.dietType:
          if (_dietType == null) {
            AppSnackbar.error('Select the type of diet you follow.');
            return;
          }
          await _animateTo(_DietStep.meals, forward: true);
          return;
        case _DietStep.meals:
          if (_mealsPerDay == null) {
            AppSnackbar.error('Select how many meals you prefer per day.');
            return;
          }
          await _user.saveDietPreferences(
            dietType: _dietType,
            foodAllergies: List<String>.from(_user.user.foodAllergies),
            foodsToAvoid: _user.user.foodsToAvoid,
            mealsPerDay: _mealsPerDay,
          );
          await _user.persistOnboardingStep(AppRoutes.cookingSkills);
          await OnboardingNav.offNamed(AppRoutes.cookingSkills);
          return;
        case _DietStep.avoid:
          break;
      }
      return;
    }

    // Profile: dietType → avoid → meals → save
    switch (_step) {
      case _DietStep.dietType:
        if (_dietType == null) {
          AppSnackbar.error('Select the type of diet you follow.');
          return;
        }
        await _animateTo(_DietStep.avoid, forward: true);
        return;
      case _DietStep.avoid:
        if (_avoidSelected.isEmpty) {
          AppSnackbar.error('Select at least one option to continue.');
          return;
        }
        _persistDraft();
        await _animateTo(_DietStep.meals, forward: true);
        return;
      case _DietStep.meals:
        break;
    }

    if (_mealsPerDay == null) {
      AppSnackbar.error('Select how many meals you prefer per day.');
      return;
    }

    await _finishProfile();
  }

  Future<void> _finishAvoidOnlyProfile() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    final avoid = _avoidToSave();
    await _user.saveDietPreferences(
      dietType: _user.user.dietType ?? _dietType,
      foodAllergies: List<String>.from(_user.user.foodAllergies),
      foodsToAvoid: avoid,
      mealsPerDay: _user.user.mealsPerDay ?? _mealsPerDay,
    );
    if (!mounted) return;

    final patch = OnboardingPatchModel.dietPreferencesDiff(
      _user.user,
      _baseline,
    );
    if (patch.isEmpty) {
      AppSnackbar.info('No changes to save.', title: 'Nothing changed');
      Get.back();
      return;
    }

    setState(() => _saving = true);
    try {
      final error = await _user.patchOnboarding(patch);
      if (!mounted) return;
      if (error != null) {
        AppSnackbar.error(error, title: 'Save failed');
        return;
      }
      Get.back();
      AppSnackbar.success('Don’t-eat list updated.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finishToLoading() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    await _user.saveDietPreferences(
      dietType: _user.user.dietType ?? _dietType,
      foodAllergies: List<String>.from(_user.user.foodAllergies),
      foodsToAvoid: _avoidToSave(),
      mealsPerDay: _user.user.mealsPerDay ?? _mealsPerDay,
    );
    if (!mounted) return;

    await _user.persistOnboardingStep(AppRoutes.nutritionPlanLoading);
    await OnboardingNav.offNamed(AppRoutes.nutritionPlanLoading);
  }

  Future<void> _finishProfile() async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    await _user.saveDietPreferences(
      dietType: _dietType,
      foodAllergies: List<String>.from(_user.user.foodAllergies),
      foodsToAvoid: _avoidToSave(),
      mealsPerDay: _mealsPerDay,
    );
    if (!mounted) return;

    final patch = OnboardingPatchModel.dietPreferencesDiff(
      _user.user,
      _baseline,
    );
    if (patch.isEmpty) {
      AppSnackbar.info('No changes to save.', title: 'Nothing changed');
      Get.back();
      return;
    }

    setState(() => _saving = true);
    try {
      final error = await _user.patchOnboarding(patch);
      if (!mounted) return;
      if (error != null) {
        AppSnackbar.error(error, title: 'Save failed');
        return;
      }
      Get.back();
      AppSnackbar.success('Diet preferences updated.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return PopScope(
      canPop: _fromProfile &&
          (_step == _DietStep.dietType || _isAvoidOnlyEdit) &&
          !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_onBack());
      },
      child: OnboardingCupertinoShell(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: r.scale(20, tablet: 28),
              right: r.scale(20, tablet: 28),
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              children: [
                SizedBox(height: r.scale(4)),
                OnboardingStepTopBar(
                  stepIndex: _fromProfile ? _step.index : _progressIndex,
                  totalSteps: _fromProfile
                      ? _DietStep.values.length
                      : OnboardingFlowProgress.totalSteps,
                  showProgress: true,
                  onBack: () => unawaited(_onBack()),
                  sectionLabel: _fromProfile
                      ? null  
                      : OnboardingJourney.labelForStep(_progressIndex),
                ),
                SizedBox(height: r.scale(28)),
                Expanded(
                  child: OnboardingQuestionTransition(
                    stepKey: _step, 
                    forward: _forward,
                    question: OnboardingQuestionHeader(title: _title),
                    description: OnboardingQuestionDescription(_description),
                    answer: _buildStepBody(context),
                  ),
                ),
                OnboardingContinueButton(
                  label: _continueLabel,
                  onPressed: !_saving && !_transitioning
                      ? () {
                          OnboardingNav.markForward();
                          unawaited(_continue());
                        }
                      : null,
                ),
                if (!_fromProfile &&
                    _isLifestylePhase &&
                    _step == _DietStep.meals) ...[
                  SizedBox(height: r.scale(10)),
                ],
                SizedBox(height: r.scale(12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody(BuildContext context) {
    final r = context.responsive;
    return switch (_step) {
      _DietStep.dietType => ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.only(bottom: r.scale(8)),
        children: [
          for (final type in DietType.values) ...[
            OnboardingOptionCard(
              title: type.choiceTitle,
              subtitle: type.choiceSubtitle,
              leading: Text(
                type.emoji,
                style: TextStyle(fontSize: r.scale(22)),
              ),
              selected: _dietType == type,
              onTap: () => _selectDiet(type),
            ),
            SizedBox(height: r.scale(10)),
          ],
        ],
      ),
      _DietStep.avoid => ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.only(bottom: r.scale(8)),
        children: [
          for (final option in LifestyleHabitOptions.foodsToAvoidFor(
            _dietType ?? _user.user.dietType,
          )) ...[
            OnboardingOptionCard(
              title: option.label,
              leading: option.emoji == null
                  ? null
                  : Text(
                      option.emoji!,
                      style: TextStyle(fontSize: r.scale(20)),
                    ),
              selected: _avoidSelected.contains(option.value),
              onTap: () => _toggleAvoid(option.value),
            ),
            SizedBox(height: r.scale(10)),
          ],
        ],
      ),
      _DietStep.meals => ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          for (final count in MealsPerDayOptions.values) ...[
            OnboardingOptionCard(
              title: MealsPerDayOptions.countLabel(count),
              subtitle: MealsPerDayOptions.structureLabel(count),
              selected: _mealsPerDay == count,
              onTap: () => _selectMeals(count),
            ),
            SizedBox(height: r.scale(12)),
          ],
        ],
      ),
    };
  }
}
