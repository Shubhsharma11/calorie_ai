import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/settings_controller.dart';
import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/body_measurement_units.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/onboarding_request_model.dart';
import '../models/profile_sync_snapshot.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/onboarding_entrance.dart';
import '../widgets/onboarding_step_scaffold.dart';

enum _PersonalStep { gender, age, height }

class PersonalDetailsView extends StatefulWidget {
  const PersonalDetailsView({super.key});

  @override
  State<PersonalDetailsView> createState() => _PersonalDetailsViewState();
}

class _PersonalDetailsViewState extends State<PersonalDetailsView> {
  late final UserController _user = Get.find<UserController>();
  late final SettingsController _settings = Get.find<SettingsController>();
  late ProfileSyncSnapshot _baseline;

  static const _genders = ['Male', 'Female', 'Other'];
  static final _ages = [for (var i = 13; i <= 100; i++) i];
  static final _heightsCm = [for (var i = 100; i <= 275; i++) i];

  late final FixedExtentScrollController _ageCtrl;
  late final FixedExtentScrollController _heightCtrl;

  late _PersonalStep _step;
  bool _heightUseCm = true;
  String? _stepError;
  bool _saving = false;
  bool _transitioning = false;

  late String? _gender;
  late int _age;
  late int _heightCm;

  bool get _fromProfile => RouteArgs.isEditingFromProfile;

  @override
  void initState() {
    super.initState();
    _heightUseCm = _settings.useMetricUnits.value;

    if (!_fromProfile && !_user.personalDetailsComplete) {
      if (!_user.hasOnboardingDraft) {
        _user.resetPersonalDetailsForOnboarding();
      }
    }

    final u = _user.user;
    // New users start with no selection — don't auto-pick Male.
    _gender = _genders.contains(u.gender) ? u.gender : null;
    _age = (u.age != null && u.age! >= 13 && u.age! <= 100) ? u.age! : 25;
    _heightCm = (u.heightCm != null &&
            BodyMeasurementUnits.isValidCm(u.heightCm!))
        ? u.heightCm!
        : 170;

    _ageCtrl = FixedExtentScrollController(
      initialItem: _ages.indexOf(_age).clamp(0, _ages.length - 1),
    );
    _heightCtrl = FixedExtentScrollController(
      initialItem: _heightIndexForCm(_heightCm),
    );

    _step = switch (RouteArgs.onboardingStartStep) {
      RouteArgs.stepHeight => _PersonalStep.height,
      RouteArgs.stepAge => _PersonalStep.age,
      _ => _PersonalStep.gender,
    };

    _baseline = _user.captureProfileSyncSnapshot();
  }

  int get _progressIndex => switch (_step) {
        _PersonalStep.gender => OnboardingFlowProgress.gender,
        _PersonalStep.age => OnboardingFlowProgress.age,
        _PersonalStep.height => OnboardingFlowProgress.height,
      };

  int _heightIndexForCm(int cm) {
    if (_heightUseCm) {
      return _heightsCm.indexOf(cm).clamp(0, _heightsCm.length - 1);
    }
    final fi = BodyMeasurementUnits.feetInchesFromCm(cm);
    final labels = _heightFtLabels;
    final label = "${fi.feet}'${fi.inches}\"";
    final idx = labels.indexOf(label);
    return idx >= 0 ? idx : labels.length ~/ 2;
  }

  List<String> get _heightFtLabels {
    final out = <String>[];
    for (var feet = 3; feet <= 9; feet++) {
      for (var inches = 0; inches <= 11; inches++) {
        if (feet == 3 && inches < 3) continue;
        if (feet == 9 && inches > 0) continue;
        out.add("$feet'$inches\"");
      }
    }
    return out;
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  void _syncDraft() {
    if (_fromProfile) return;
    final u = _user.user;
    if (_gender != null) u.gender = _gender;
    u.age = _age;
    u.heightCm = _heightCm;
    _user.scheduleOnboardingDraftSave();
  }

  bool _validateCurrentStep() {
    String? error;
    switch (_step) {
      case _PersonalStep.gender:
        if (_gender == null || !_genders.contains(_gender)) {
          error = 'Select your gender';
        }
      case _PersonalStep.age:
        if (_age < 13 || _age > 100) {
          error = 'Use an age between 13 and 100';
        }
      case _PersonalStep.height:
        if (!BodyMeasurementUnits.isValidCm(_heightCm)) {
          error = 'Use a height between 100 and 275 cm';
        }
    }
    setState(() => _stepError = error);
    return error == null;
  }

  Future<void> _onGenderSelected(String gender) async {
    if (_transitioning) return;
    setState(() {
      _gender = gender;
      _stepError = null;
    });
    _syncDraft();
  }

  Future<void> _onContinue() async {
    if (_transitioning) return;
    if (!_validateCurrentStep()) return;
    _syncDraft();

    if (_fromProfile) {
      if (_step != _PersonalStep.height) {
        await _transitionTo(
          _PersonalStep.values[_step.index + 1],
          forward: true,
        );
        return;
      }
      await _saveProfile();
      return;
    }

    // Onboarding: gender → age → goal → height → weight goal
    if (_step == _PersonalStep.gender) {
      await _transitionTo(_PersonalStep.age, forward: true);
      return;
    }
    if (_step == _PersonalStep.age) {
      await _user.persistOnboardingStep(AppRoutes.goalSetup);
      Get.offNamed(AppRoutes.goalSetup);
      return;
    }

    // Height → weight goal screen (Current / Goal).
    _user.markPersonalDetailsComplete();
    _user.onProfileUpdated();
    await _user.persistOnboardingStep(AppRoutes.goalAmount);
    Get.offNamed(AppRoutes.goalAmount);
  }

  Future<void> _onBack() async {
    if (_transitioning) return;

    if (_fromProfile) {
      if (_step == _PersonalStep.gender) {
        Get.back();
        return;
      }
      await _transitionTo(
        _PersonalStep.values[_step.index - 1],
        forward: false,
      );
      return;
    }

    if (_step == _PersonalStep.gender) {
      Get.back();
      return;
    }
    if (_step == _PersonalStep.age) {
      await _transitionTo(_PersonalStep.gender, forward: false);
      return;
    }
    // Height → goal
    await _user.persistOnboardingStep(AppRoutes.goalSetup);
    Get.offNamed(AppRoutes.goalSetup);
  }

  Future<void> _transitionTo(
    _PersonalStep next, {
    required bool forward,
  }) async {
    if (_transitioning || next == _step) return;
    _transitioning = true;
    setState(() {
      _step = next;
      _stepError = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    _transitioning = false;
  }

  Future<void> _saveProfile() async {
    if (_saving) return;
    setState(() => _saving = true);

    final u = _user.user;
    u.age = _age;
    if (_gender != null) u.gender = _gender;
    u.heightCm = _heightCm;

    try {
      final patch = OnboardingPatchModel.personalDetailsDiff(u, _baseline);
      if (patch.isEmpty) {
        AppSnackbar.info('No changes to save.', title: 'Nothing changed');
        return;
      }

      final error = await _user.patchOnboarding(patch);
      if (!mounted) return;
      if (error != null) {
        AppSnackbar.error(error);
        return;
      }

      _baseline = _user.captureProfileSyncSnapshot();
      _user.onProfileUpdated();
      Get.back();
      AppSnackbar.success('Personal details updated.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleHeightUnit(bool useCm) {
    if (useCm == _heightUseCm) return;
    setState(() {
      _heightUseCm = useCm;
      _stepError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final idx = _heightIndexForCm(_heightCm);
      if (_heightCtrl.hasClients) {
        _heightCtrl.jumpToItem(idx);
      }
    });
  }

  (String, String?) get _copy {
    switch (_step) {
      case _PersonalStep.gender:
        return ('Select Your Gender', null);
      case _PersonalStep.age:
        return (
          'How old are you?',
          'This helps us personalize your calorie and health goals',
        );
      case _PersonalStep.height:
        return (
          "What's your height?",
          'This helps us personalize your calorie and health goals',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final isLast = _step == _PersonalStep.height;
    final pageBg = AppColors.backgroundOf(context);
    final (title, subtitle) = _copy;

    return PopScope(
      canPop: _fromProfile && _step == _PersonalStep.gender,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        backgroundColor: pageBg,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: r.scale(20, tablet: 28)),
            child: Column(
              children: [
                SizedBox(height: r.scale(4)),
                OnboardingStepTopBar(
                  stepIndex: _progressIndex,
                  totalSteps: OnboardingFlowProgress.totalSteps,
                  onBack: _onBack,
                ),
                SizedBox(height: r.scale(28)),
                Expanded(
                  child: OnboardingEntrance(
                    replayToken: _step,
                    builder: (context, entrance) {
                      return Column(
                        children: [
                          entrance.item(
                            index: 0,
                            child: Text(
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
                          ),
                          if (subtitle != null) ...[
                            SizedBox(height: r.scale(10)),
                            entrance.item(
                              index: 1,
                              child: Text(
                                subtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: r.scale(14, tablet: 15),
                                  color: AppColors.textSecondaryOf(context),
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          if (_stepError != null) ...[
                            SizedBox(height: r.scale(12)),
                            Text(
                              _stepError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          Expanded(
                            child: entrance.item(
                              index: 2,
                              child: _buildStepBody(r),
                            ),
                          ),
                          entrance.item(
                            index: 3,
                            child: OnboardingContinueButton(
                              label: _fromProfile && isLast
                                  ? (_saving ? 'Saving...' : 'Save')
                                  : (_saving ? 'Please wait...' : 'Continue'),
                              onPressed: () {
                                if (_saving || _transitioning) return;
                                _onContinue();
                              },
                            ),
                          ),
                          SizedBox(height: r.scale(12)),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody(Responsive r) {
    switch (_step) {
      case _PersonalStep.gender:
        return Padding(
          padding: EdgeInsets.only(top: r.scale(28)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final g in _genders) ...[
                OnboardingOptionCard(
                  title: g,
                  selected: _gender == g,
                  onTap: () => _onGenderSelected(g),
                ),
                if (g != _genders.last) SizedBox(height: r.scale(12)),
              ],
            ],
          ),
        );
      case _PersonalStep.age:
        return OnboardingCupertinoValuePicker(
          controller: _ageCtrl,
          labels: _ages.map((e) => '$e').toList(growable: false),
          onSelectedItemChanged: (i) {
            setState(() {
              _age = _ages[i];
              _stepError = null;
            });
            _syncDraft();
          },
        );
      case _PersonalStep.height:
        final labels = _heightUseCm
            ? _heightsCm.map((e) => '$e').toList(growable: false)
            : _heightFtLabels;
        return Column(
          children: [
            OnboardingUnitToggle(
              left: 'cm',
              right: 'ft',
              leftSelected: _heightUseCm,
              onLeft: () => _toggleHeightUnit(true),
              onRight: () => _toggleHeightUnit(false),
            ),
            Expanded(
              child: OnboardingCupertinoValuePicker(
                key: ValueKey('h-$_heightUseCm'),
                controller: _heightCtrl,
                labels: labels,
                unit: _heightUseCm ? 'cm' : null,
                onSelectedItemChanged: (i) {
                  setState(() {
                    if (_heightUseCm) {
                      _heightCm = _heightsCm[i];
                    } else {
                      final parts = labels[i].split("'");
                      if (parts.length == 2) {
                        final feet = int.tryParse(parts[0]) ?? 5;
                        final inches =
                            int.tryParse(parts[1].replaceAll('"', '')) ?? 0;
                        _heightCm = BodyMeasurementUnits.cmFromFeetInches(
                          feet,
                          inches,
                        );
                      }
                    }
                    _stepError = null;
                  });
                  _syncDraft();
                },
              ),
            ),
          ],
        );
    }
  }
}
