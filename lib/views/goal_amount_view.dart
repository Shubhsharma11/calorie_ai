import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/settings_controller.dart';
import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/body_measurement_units.dart';
import '../core/onboarding_nav.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/goal_type.dart';
import '../models/onboarding_request_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/onboarding_question_transition.dart';
import '../widgets/onboarding_step_scaffold.dart';

class GoalAmountView extends StatefulWidget {
  const GoalAmountView({super.key});

  @override
  State<GoalAmountView> createState() => _GoalAmountViewState();
}

class _GoalAmountViewState extends State<GoalAmountView> {
  final UserController _user = Get.find<UserController>();
  final SettingsController _settings = Get.find<SettingsController>();

  static const double _minWeightKg = 30;
  static const double _maxWeightKg = 300;
  static const double _defaultPickerKg = 50;
  static const int _defaultWeeks = 12;
  static const int _minWeeks = 1;
  static const int _maxWeeks = 52;

  late bool _useKg;
  late double _currentDisplay;
  late double _goalDisplay;
  late FixedExtentScrollController _currentCtrl;
  late FixedExtentScrollController _goalCtrl;
  String? _errorText;
  bool _isSaving = false;

  /// True only when a real saved goal exists or the user scrolled Goal.
  bool _goalChosen = false;

  /// Ignore picker noise during first layout (do not treat as a user choice).
  bool _pickersReady = false;

  List<double> get _weightValues {
    if (_useKg) {
      return [
        for (
          var i = (_minWeightKg * 10).round();
          i <= (_maxWeightKg * 10).round();
          i++
        )
          i / 10.0,
      ];
    }
    final minLb = BodyMeasurementUnits.lbsFromKg(
      _minWeightKg.round(),
    ).toDouble();
    final maxLb = BodyMeasurementUnits.lbsFromKg(
      _maxWeightKg.round(),
    ).toDouble();
    return [
      for (var i = (minLb * 10).round(); i <= (maxLb * 10).round(); i++)
        i / 10.0,
    ];
  }

  @override
  void initState() {
    super.initState();
    _useKg = _settings.useMetricUnits.value;
    if (RouteArgs.isEditingFromProfile) {
      _user.beginGoalEditFromProfile();
    }
    _bootstrap();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _pickersReady = true);
    });

    final goal = _user.user.goal;
    if (goal == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!RouteArgs.isEditingFromProfile) {
          unawaited(
            OnboardingNav.offNamed(AppRoutes.goalSetup, animate: false),
          );
        } else {
          Get.back<void>();
        }
      });
    }
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  void _bootstrap() {
    final values = _weightValues;
    final defaultIdx = _nearestIndex(_fromKg(_defaultPickerKg));

    // Prefer the weight the user just set in Personal → Current Weight.
    // Tracker/history can lag or differ during onboarding.
    final profileKg = _user.user.weightKg?.toDouble() ?? 0;
    final resolved = profileKg >= _minWeightKg && profileKg <= _maxWeightKg
        ? profileKg
        : _user.resolvedCurrentWeightKg();
    final hasCurrent = resolved >= _minWeightKg && resolved <= _maxWeightKg;

    final rawGoal = _user.user.goalWeightKg;
    final hasGoal =
        hasCurrent && rawGoal >= _minWeightKg && rawGoal <= _maxWeightKg;

    // Default selection is 50 kg when the user has not saved a weight yet.
    _goalChosen = true;

    final currentIdx = hasCurrent
        ? _nearestIndex(_fromKg(resolved))
        : defaultIdx;
    final goalIdx = hasGoal ? _nearestIndex(_fromKg(rawGoal)) : currentIdx;

    _currentDisplay = values[currentIdx];
    _goalDisplay = values[goalIdx];
    _currentCtrl = FixedExtentScrollController(initialItem: currentIdx);
    _goalCtrl = FixedExtentScrollController(initialItem: goalIdx);
  }

  int _nearestIndex(double display) {
    final values = _weightValues;
    var best = 0;
    var bestDiff = (values[0] - display).abs();
    for (var i = 1; i < values.length; i++) {
      final d = (values[i] - display).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = i;
      }
    }
    return best;
  }

  double _toKg(double display) =>
      _useKg ? display : display / BodyMeasurementUnits.kgToLb;

  double _fromKg(double kg) => _useKg ? kg : kg * BodyMeasurementUnits.kgToLb;

  String _format(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(1)
        : value.toStringAsFixed(1);
  }

  String get _unit => _useKg ? 'kg' : 'lb';

  double get _deltaKg => _toKg(_goalDisplay) - _toKg(_currentDisplay);

  (String, IconData?) get _badge {
    final delta = _deltaKg;
    final absDisplay = _fromKg(delta.abs());
    if (delta.abs() < 0.05) {
      return ('Maintain 0.0 $_unit', Icons.remove);
    }
    if (delta < 0) {
      return ('Lose ${_format(absDisplay)} $_unit', Icons.remove);
    }
    return ('Gain ${_format(absDisplay)} $_unit', Icons.add);
  }

  void _toggleUnit(bool useKg) {
    if (_useKg == useKg) return;
    final currentKg = _toKg(_currentDisplay);
    final goalKg = _toKg(_goalDisplay);
    setState(() {
      _useKg = useKg;
      _currentDisplay = _fromKg(currentKg);
      _goalDisplay = _fromKg(goalKg);
      final cIdx = _nearestIndex(_currentDisplay);
      final gIdx = _nearestIndex(_goalDisplay);
      _currentDisplay = _weightValues[cIdx];
      _goalDisplay = _weightValues[gIdx];
      _currentCtrl.dispose();
      _goalCtrl.dispose();
      _currentCtrl = FixedExtentScrollController(initialItem: cIdx);
      _goalCtrl = FixedExtentScrollController(initialItem: gIdx);
      _errorText = null;
    });
  }

  void _nudgeGoal(int delta) {
    if (!_goalCtrl.hasClients) return;
    final next = (_goalCtrl.selectedItem + delta).clamp(
      0,
      _weightValues.length - 1,
    );
    setState(() {
      _goalChosen = true;
      _goalDisplay = _weightValues[next];
      _errorText = null;
    });
    _goalCtrl.animateToItem(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    _persistDraft();
  }

  void _applyWeight({required bool isCurrent, required double displayValue}) {
    final idx = _nearestIndex(displayValue);
    final snapped = _weightValues[idx];
    setState(() {
      _errorText = null;
      if (isCurrent) {
        _currentDisplay = snapped;
      } else {
        _goalChosen = true;
        _goalDisplay = snapped;
      }
    });

    final ctrl = isCurrent ? _currentCtrl : _goalCtrl;
    void jump() {
      if (!ctrl.hasClients) return;
      ctrl.animateToItem(
        idx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }

    if (ctrl.hasClients) {
      jump();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        jump();
      });
    }
    _persistDraft();
  }

  Future<void> _editWeight({required bool isCurrent}) async {
    final initial = isCurrent ? _currentDisplay : _goalDisplay;
    final label = isCurrent ? 'Current weight' : 'Goal weight';
    final textCtrl = TextEditingController(text: _format(initial));
    final entered = await showCupertinoDialog<double>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: Text(label),
          content: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              children: [
                Text(
                  'Enter a value in $_unit',
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(ctx),
                  ),
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: textCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  placeholder: _format(initial),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.tertiarySystemFill.resolveFrom(ctx),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSubmitted: (raw) {
                    final parsed = _parseDisplayWeight(raw);
                    Navigator.of(ctx).pop(parsed);
                  },
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                final parsed = _parseDisplayWeight(textCtrl.text);
                Navigator.of(ctx).pop(parsed);
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
    textCtrl.dispose();
    if (!mounted || entered == null) return;

    final minDisplay = _weightValues.first;
    final maxDisplay = _weightValues.last;
    if (entered < minDisplay || entered > maxDisplay) {
      AppSnackbar.error(
        'Enter a weight between ${_format(minDisplay)} and ${_format(maxDisplay)} $_unit.',
      );
      return;
    }
    _applyWeight(isCurrent: isCurrent, displayValue: entered);
  }

  double? _parseDisplayWeight(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  void _persistDraft() {
    if (RouteArgs.isEditingFromProfile) return;
    if (!_goalChosen) return;

    final currentKg = _toKg(_currentDisplay);
    final goalKg = _toKg(_goalDisplay);
    // Keep Current in sync with Personal → Current Weight (and any edits here).
    _user.user.weightKg = currentKg.round();
    _user.user.pinGoalWeight(goalKg);
    _inferAndSelectGoal(goalKg - currentKg);
    _user.scheduleOnboardingDraftSave();
  }

  void _inferAndSelectGoal(double deltaKg) {
    final GoalType type;
    if (deltaKg.abs() < 0.05) {
      type = GoalType.maintainWeight;
    } else if (deltaKg < 0) {
      type = GoalType.loseWeight;
    } else {
      type = GoalType.gainWeight;
    }
    if (_user.user.goal != type) {
      _user.selectGoal(type, persistDraft: !RouteArgs.isEditingFromProfile);
    }
  }

  String? _validate() {
    final currentKg = _toKg(_currentDisplay);
    final goalKg = _toKg(_goalDisplay);
    if (currentKg < _minWeightKg || currentKg > _maxWeightKg) {
      return 'Current weight must be between $_minWeightKg and $_maxWeightKg kg';
    }
    if (goalKg < _minWeightKg || goalKg > _maxWeightKg) {
      return 'Target weight must be between $_minWeightKg and $_maxWeightKg kg';
    }
    return null;
  }

  Future<void> _onBack({required bool fromProfile}) async {
    if (fromProfile) {
      if (Get.previousRoute != AppRoutes.goalSetup) {
        _user.cancelGoalEditFromProfile();
      }
      Get.back<void>();
      return;
    }
    _persistDraft();
    OnboardingNav.markBackward();
    await _user.goToPreviousOnboardingStep(AppRoutes.goalAmount);
  }

  Future<void> _onContinue({required bool fromProfile}) async {
    if (_isSaving) return;
    final error = _validate();
    setState(() => _errorText = error);
    if (error != null) return;

    final currentKg = _toKg(_currentDisplay);
    final goalKg = _toKg(_goalDisplay);
    final delta = goalKg - currentKg;
    _inferAndSelectGoal(delta);

    _user.user.weightKg = currentKg.round();
    _user.setGoalWeight(goalKg, manual: true);

    // API still expects a date — default silently (no Target Date question).
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final weeks = _defaultWeeks.clamp(_minWeeks, _maxWeeks);
    _user.user.targetDate = start.add(Duration(days: weeks * 7));
    _user.update();

    if (fromProfile) {
      final patch = OnboardingPatchModel.goalProfileDiff(
        _user.user,
        _user.baselineForGoalProfileSave(),
      );
      if (patch.isEmpty) {
        _user.commitGoalEditFromProfile();
        AppSnackbar.info('No changes to save.', title: 'Nothing changed');
        _user.popToMyGoals();
        return;
      }
      setState(() => _isSaving = true);
      final saveError = await _user.patchOnboarding(patch);
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (saveError != null) {
        AppSnackbar.error(saveError, title: 'Save failed');
        return;
      }
      _user.commitGoalEditFromProfile();
      _user.popToMyGoals();
      AppSnackbar.success('Goal updated.');
      return;
    }

    await _user.persistOnboardingStep(AppRoutes.activityLevel);
    await OnboardingNav.offNamed(AppRoutes.activityLevel);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final fromProfile = RouteArgs.isEditingFromProfile;
    final (badgeLabel, badgeIcon) = _badge;

    return PopScope(
      canPop: fromProfile,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_onBack(fromProfile: fromProfile));
      },
      child: OnboardingCupertinoShell(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: r.scale(20, tablet: 28)),
            child: Column(
              children: [
                SizedBox(height: r.scale(4)),
                OnboardingStepTopBar(
                  stepIndex: fromProfile
                      ? 1
                      : OnboardingFlowProgress.targetWeight,
                  totalSteps: fromProfile
                      ? 2
                      : OnboardingFlowProgress.totalSteps,
                  onBack: () {
                    OnboardingNav.markBackward();
                    unawaited(_onBack(fromProfile: fromProfile));
                  },
                  sectionLabel: fromProfile
                      ? 'GOALS'
                      : OnboardingJourney.labelForStep(
                          OnboardingFlowProgress.targetWeight,
                        ),
                ),
                SizedBox(height: r.scale(28)),
                Expanded(
                  child: OnboardingQuestionTransition(
                    stepKey: OnboardingFlowProgress.targetWeight,
                    question: OnboardingQuestionHeader(
                      title: fromProfile
                          ? 'What’s your weight goal?'
                          : 'What’s your target weight?',
                      errorText: _errorText,
                    ),
                    description: OnboardingQuestionDescription(
                      fromProfile
                          ? 'Set your current weight and where you want to be.'
                          : 'Confirm your current weight and set your target.',
                    ),
                    answer: _buildDualWeightAnswer(r, badgeLabel, badgeIcon),
                  ),
                ),
                OnboardingContinueButton(
                  label: _isSaving
                      ? 'Please wait...'
                      : (fromProfile ? 'Save' : 'Continue'),
                  onPressed: _isSaving
                      ? null
                      : () {
                          OnboardingNav.markForward();
                          _onContinue(fromProfile: fromProfile);
                        },
                ),
                SizedBox(height: r.scale(12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDualWeightAnswer(
    Responsive r,
    String badgeLabel,
    IconData? badgeIcon,
  ) {
    return Column(
      children: [
        OnboardingUnitToggle(
          left: 'lbs',
          right: 'kg',
          leftSelected: !_useKg,
          onLeft: () => _toggleUnit(false),
          onRight: () => _toggleUnit(true),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _WeightColumn(
                  label: 'Current',
                  controller: _currentCtrl,
                  values: _weightValues,
                  format: _format,
                  onSelected: (i) {
                    if (!_pickersReady) return;
                    setState(() {
                      _currentDisplay = _weightValues[i];
                      _errorText = null;
                    });
                    _persistDraft();
                  },
                  onTapValue: () => unawaited(_editWeight(isCurrent: true)),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: r.scale(28)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OnboardingBoldChevron(
                      up: true,
                      onTap: () => _nudgeGoal(-1),
                    ),
                    const SizedBox(height: 12),
                    OnboardingBoldChevron(
                      up: false,
                      onTap: () => _nudgeGoal(1),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _WeightColumn(
                  label: 'Goal',
                  controller: _goalCtrl,
                  values: _weightValues,
                  format: _format,
                  onSelected: (i) {
                    if (!_pickersReady) return;
                    setState(() {
                      _goalChosen = true;
                      _goalDisplay = _weightValues[i];
                      _errorText = null;
                    });
                    _persistDraft();
                  },
                  onTapValue: () => unawaited(_editWeight(isCurrent: false)),
                ),
              ),
            ],
          ),
        ),
        _buildBadge(r, badgeLabel, badgeIcon),
      ],
    );
  }

  Widget _buildBadge(Responsive r, String badgeLabel, IconData? badgeIcon) {
    return Transform.translate(
      offset: const Offset(0, -8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.scale(14),
          vertical: r.scale(8),
        ),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeIcon != null) ...[
              Icon(badgeIcon, size: 16, color: AppColors.primaryDark),
              const SizedBox(width: 4),
            ],
            Text(
              badgeLabel,
              style: TextStyle(
                fontSize: r.scale(15),
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightColumn extends StatelessWidget {
  const _WeightColumn({
    required this.label,
    required this.controller,
    required this.values,
    required this.format,
    required this.onSelected,
    required this.onTapValue,
  });

  final String label;
  final FixedExtentScrollController controller;
  final List<double> values;
  final String Function(double) format;
  final ValueChanged<int> onSelected;
  final VoidCallback onTapValue;

  static const _itemExtent = 48.0;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final primary = AppColors.textPrimaryOf(context);
    final secondary = AppColors.textSecondaryOf(context);

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: r.scale(16),
            fontWeight: FontWeight.w800,
            color: primary,
          ),
        ),
        SizedBox(height: r.scale(8)),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              CupertinoPicker.builder(
                scrollController: controller,
                itemExtent: _itemExtent,
                diameterRatio: 1.15,
                squeeze: 1.05,
                useMagnifier: true,
                magnification: 1.12,
                backgroundColor: Colors.transparent,
                selectionOverlay: const SizedBox.shrink(),
                onSelectedItemChanged: onSelected,
                childCount: values.length,
                itemBuilder: (context, index) {
                  return Center(
                    child: Text(
                      format(values[index]),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: primary,
                        height: 1,
                      ),
                    ),
                  );
                },
              ),
              // Translucent so vertical scroll still works on the center band.
              Align(
                alignment: Alignment.center,
                child: _TapToEditBand(
                  height: _itemExtent - 4,
                  horizontalMargin: r.scale(10),
                  onTap: onTapValue,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 1,
          child: ColoredBox(color: secondary.withValues(alpha: 0)),
        ),
      ],
    );
  }
}

/// Draws the green selection frame and detects taps without blocking scroll.
class _TapToEditBand extends StatefulWidget {
  const _TapToEditBand({
    required this.height,
    required this.horizontalMargin,
    required this.onTap,
  });

  final double height;
  final double horizontalMargin;
  final VoidCallback onTap;

  @override
  State<_TapToEditBand> createState() => _TapToEditBandState();
}

class _TapToEditBandState extends State<_TapToEditBand> {
  Offset? _downPosition;
  int? _downTimestamp;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _downPosition = event.localPosition;
        _downTimestamp = event.timeStamp.inMilliseconds;
      },
      onPointerUp: (event) {
        final start = _downPosition;
        final startedAt = _downTimestamp;
        _downPosition = null;
        _downTimestamp = null;
        if (start == null || startedAt == null) return;
        final elapsed = event.timeStamp.inMilliseconds - startedAt;
        final distance = (event.localPosition - start).distance;
        if (elapsed <= 350 && distance <= 18) {
          widget.onTap();
        }
      },
      onPointerCancel: (_) {
        _downPosition = null;
        _downTimestamp = null;
      },
      child: Container(
        height: widget.height,
        margin: EdgeInsets.symmetric(horizontal: widget.horizontalMargin),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.55),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
