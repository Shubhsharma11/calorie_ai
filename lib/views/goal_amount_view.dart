import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/settings_controller.dart';
import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/body_measurement_units.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/goal_type.dart';
import '../models/onboarding_request_model.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_page.dart';


class GoalAmountView extends StatefulWidget {
  const GoalAmountView({super.key});

  static const _loseAsset = 'assets/image/right-down.svg';
  static const _gainAsset = 'assets/image/upgain.svg';

  @override
  State<GoalAmountView> createState() => _GoalAmountViewState();
}

class _GoalAmountViewState extends State<GoalAmountView> {
  final UserController _user = Get.find<UserController>();
  final SettingsController _settings = Get.find<SettingsController>();
  final GlobalKey _weeklyRateKey = GlobalKey(debugLabel: 'weekly_rate_focus');
  Timer? _focusTimer;

  late bool _useKg;
  late double _amountDisplay;
  /// Null until the user picks a preset, slider value, or custom date.
  int? _weeks;
  DateTime? _pickedTargetDate;
  bool _customTimeframe = false;
  String? _errorText;
  bool _isSaving = false;

  static const double _minChangeKg = 0.5;
  static const double _maxChangeKg = 50;
  static const double _defaultChangeKg = 5;
  static const double _minWeightKg = 40;
  static const double _maxWeightKg = 200;
  static const int _minWeeks = 1;
  static const int _maxWeeks = 52;
  /// Model default is today + 90 days; treat that as "not chosen yet".
  static const int _unsetDefaultDays = 90;

  static const List<double> _amountPresetsKg = [2, 5, 8, 12];

  GoalType get _goal => _user.user.goal ?? GoalType.loseWeight;

  bool get _isLose => _goal == GoalType.loseWeight;

  double get _currentKg => _user.resolvedCurrentWeightKg();

  @override
  void initState() {
    super.initState();
    _useKg = _settings.useMetricUnits.value;
    if (RouteArgs.isEditingFromProfile) {
      _user.beginGoalEditFromProfile();
    }
    _bootstrapFromUser();

    final goal = _user.user.goal;
    if (goal == null || goal == GoalType.maintainWeight) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!RouteArgs.isEditingFromProfile) {
          Get.offNamed(AppRoutes.goalSetup);
        } else {
          Get.back<void>();
        }
      });
    }
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    super.dispose();
  }

  void _bootstrapFromUser() {
    final u = _user.user;
    final currentKg = _currentKg;
    final diffKg = (u.goalWeightKg - currentKg).abs();
    _amountDisplay = diffKg >= _minChangeKg
        ? _fromKg(diffKg.clamp(_minChangeKg, _maxChangeKg))
        : _fromKg(_defaultChangeKg);

    _weeks = null;
    _pickedTargetDate = null;
    _customTimeframe = false;

    final today = _today;
    final savedDate = DateTime(
      u.targetDate.year,
      u.targetDate.month,
      u.targetDate.day,
    );
    final days = savedDate.difference(today).inDays;
    if (days < _minWeeks * 7) return;

    // Skip the stock +90 day default so onboarding starts with no selection.
    // Restore when editing from profile, or when the user already picked a date.
    final looksUnset = (days - _unsetDefaultDays).abs() <= 1;
    if (!RouteArgs.isEditingFromProfile && looksUnset) return;

    _weeks = (days / 7).round().clamp(_minWeeks, _maxWeeks);
    final weekBasedDate = today.add(Duration(days: _weeks! * 7));
    if (_isSameDay(savedDate, weekBasedDate)) {
      _pickedTargetDate = null;
      _customTimeframe = ![1, 2, 4].contains(_weeks);
    } else {
      _pickedTargetDate = savedDate;
      _customTimeframe = true;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? get _targetDate {
    if (_pickedTargetDate != null) return _pickedTargetDate;
    final weeks = _weeks;
    if (weeks == null) return null;
    return _today.add(Duration(days: weeks * 7));
  }

  double get _amountKg => _toKg(_amountDisplay);

  double get _paceKgPerWeek {
    final weeks = _weeks;
    if (weeks == null || weeks <= 0) return 0;
    return (_amountKg / weeks).clamp(0, 5);
  }

  double get _minChangeDisplay =>
      _useKg ? _minChangeKg : _minChangeKg * BodyMeasurementUnits.kgToLb;

  double get _maxChangeDisplay =>
      _useKg ? _maxChangeKg : _maxChangeKg * BodyMeasurementUnits.kgToLb;

  double get _stepDisplay => _useKg ? 0.5 : 1;

  String get _unitShort => _useKg ? 'kg' : 'lb';

  String get _unitLong => _unitShort;

  String _formatAmount(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  double _toKg(double display) =>
      _useKg ? display : display / BodyMeasurementUnits.kgToLb;

  double _fromKg(double kg) =>
      _useKg ? kg : kg * BodyMeasurementUnits.kgToLb;

  void _persistDraft() {
    if (RouteArgs.isEditingFromProfile) return;

    final amountKg = _amountKg;
    final current = _currentKg;
    final target = _isLose ? current - amountKg : current + amountKg;
    _user.user.pinGoalWeight(target.clamp(_minWeightKg, _maxWeightKg));
    final targetDate = _targetDate;
    if (targetDate != null) {
      _user.user.targetDate = targetDate;
    }
    _user.scheduleOnboardingDraftSave();
  }

  void _setAmount(double display) {
    setState(() {
      _amountDisplay = display.clamp(_minChangeDisplay, _maxChangeDisplay);
      _errorText = null;
    });
    _persistDraft();
  }

  void _stepAmount(double delta) => _setAmount(_amountDisplay + delta);

  void _scheduleFocusWeeklyRate() {
    _focusTimer?.cancel();
    // Debounce so preset + slider-end don't stack scrolls.
    _focusTimer = Timer(const Duration(milliseconds: 40), () async {
      if (!mounted) return;
      final first = _weeklyRateKey.currentContext;
      if (first == null || !first.mounted) return;

      // Scroll in parallel with the expand for a continuous feel.
      unawaited(
        Scrollable.ensureVisible(
          first,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
          alignment: 0.18,
        ),
      );

      // Soft settle once the block has mostly finished expanding.
      await Future<void>.delayed(const Duration(milliseconds: 520));
      if (!mounted) return;
      final settled = _weeklyRateKey.currentContext;
      if (settled == null || !settled.mounted) return;
      await Scrollable.ensureVisible(
        settled,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
        alignment: 0.18,
      );
    });
  }

  void _setWeeks(int weeks, {bool focusScreen = false}) {
    final firstReveal = _weeks == null;
    setState(() {
      _weeks = weeks.clamp(_minWeeks, _maxWeeks);
      _pickedTargetDate = null;
      _customTimeframe = false;
      _errorText = null;
    });
    _persistDraft();
    if (firstReveal || focusScreen) {
      _scheduleFocusWeeklyRate();
    }
  }

  Future<void> _pickCustomDate() async {
    final minDate = _today.add(Duration(days: _minWeeks * 7));
    final maxDate = _today.add(Duration(days: _maxWeeks * 7));
    var initial = _pickedTargetDate ?? _targetDate ?? minDate;
    if (initial.isBefore(minDate)) initial = minDate;
    if (initial.isAfter(maxDate)) initial = maxDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minDate,
      lastDate: maxDate,
      helpText: 'Choose your target date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: AppColors.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;

    final date = DateTime(picked.year, picked.month, picked.day);
    final days = date.difference(_today).inDays;
    setState(() {
      _pickedTargetDate = date;
      _weeks = (days / 7).round().clamp(_minWeeks, _maxWeeks);
      _customTimeframe = true;
      _errorText = null;
    });
    _persistDraft();
    _scheduleFocusWeeklyRate();
  }

  String? _validate() {
    if (_weeks == null || _targetDate == null) {
      return 'Choose a timeframe for your goal';
    }

    if (_amountDisplay < _minChangeDisplay || _amountDisplay > _maxChangeDisplay) {
      return 'Use a value between ${_formatAmount(_minChangeDisplay)} and '
          '${_formatAmount(_maxChangeDisplay)} $_unitShort';
    }

    final amountKg = _amountKg;
    final current = _currentKg;
    if (_isLose) {
      final maxLossKg = current - _minWeightKg;
      if (maxLossKg < _minChangeKg) {
        return 'Current weight is already at the minimum';
      }
      if (amountKg > maxLossKg) {
        return 'You can lose up to '
            '${_formatAmount(_fromKg(maxLossKg))} $_unitShort';
      }
    } else {
      final maxGainKg = _maxWeightKg - current;
      if (maxGainKg < _minChangeKg) {
        return 'Current weight is already at the maximum';
      }
      if (amountKg > maxGainKg) {
        return 'You can gain up to '
            '${_formatAmount(_fromKg(maxGainKg))} $_unitShort';
      }
    }
    return null;
  }

  Future<void> _onBack({required bool fromProfile}) async {
    if (fromProfile) {
      // Back to Goal Setup keeps the edit journey; cancel only when Amount
      // was opened directly from My Goals.
      if (Get.previousRoute != AppRoutes.goalSetup) {
        _user.cancelGoalEditFromProfile();
      }
      Get.back<void>();
      return;
    }
    _persistDraft();
    await _user.goToPreviousOnboardingStep(AppRoutes.goalAmount);
  }

  Future<void> _onContinue({required bool fromProfile}) async {
    if (_isSaving) return;

    final error = _validate();
    setState(() => _errorText = error);
    if (error != null) return;

    final current = _currentKg;
    final target = _isLose ? current - _amountKg : current + _amountKg;
    _user.setGoalWeight(target, manual: true);
    _user.user.targetDate = _targetDate!;
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
    Get.toNamed(AppRoutes.activityLevel);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final compact = r.height < 720;
    final fromProfile = RouteArgs.isEditingFromProfile;

    return PopScope(
      canPop: fromProfile,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_onBack(fromProfile: fromProfile));
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppAppBar.backOnly(
          onBack: () => unawaited(_onBack(fromProfile: fromProfile)),
        ),
        body: SetupScreenLayout(
          scrollable: true,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: r.scale(compact ? 4 : 8)),
              _GoalAmountHero(
                r: r,
                compact: compact,
                isLose: _isLose,
              ),
              SizedBox(height: r.scale(compact ? 16 : 20)),
              _SectionHeader(
                label: _isLose ? 'How much to lose' : 'How much to gain',
              ),
              SizedBox(height: r.scale(10)),
              _AmountStepperCard(
                value: _formatAmount(_amountDisplay),
                unitLabel: _unitLong,
                onDecrease: () => _stepAmount(-_stepDisplay),
                onIncrease: () => _stepAmount(_stepDisplay),
              ),
              SizedBox(height: r.scale(12)),
              _PresetRow(
                options: _amountPresetsKg
                    .map((kg) => _PresetOption(
                          label: _useKg
                              ? '${kg.toStringAsFixed(0)} kg'
                              : '${(kg * BodyMeasurementUnits.kgToLb).round()} lb',
                          selected: (_amountKg - kg).abs() < 0.25,
                          onTap: () => _setAmount(_fromKg(kg)),
                        ))
                    .toList(),
              ),
              SizedBox(height: r.scale(compact ? 18 : 22)),
              const _SectionHeader(label: 'Timeframe'),
              SizedBox(height: r.scale(10)),
              _TimeframeCard(
                weeks: _weeks,
                targetDate: _targetDate,
                minWeeks: _minWeeks,
                maxWeeks: _maxWeeks,
                onWeeksChanged: _setWeeks,
                onWeeksChangeEnd: (_) => _scheduleFocusWeeklyRate(),
              ),
              SizedBox(height: r.scale(12)),
              _PresetRow(
                options: [
                  _PresetOption(
                    label: '1 wk',
                    selected: !_customTimeframe && _weeks == 1,
                    onTap: () => _setWeeks(1, focusScreen: true),
                  ),
                  _PresetOption(
                    label: '2 wk',
                    selected: !_customTimeframe && _weeks == 2,
                    onTap: () => _setWeeks(2, focusScreen: true),
                  ),
                  _PresetOption(
                    label: '1 mo',
                    selected: !_customTimeframe && _weeks == 4,
                    onTap: () => _setWeeks(4, focusScreen: true),
                  ),
                  _PresetOption(
                    label: _customTimeframe && _targetDate != null
                        ? DateFormat('MMM d').format(_targetDate!)
                        : 'Custom',
                    selected: _customTimeframe,
                    onTap: _pickCustomDate,
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 560),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: _weeks == null
                    ? const SizedBox.shrink()
                    : KeyedSubtree(
                        key: _weeklyRateKey,
                        child: _AnimatedWeeklyRateSection(
                          key: const ValueKey('weekly-rate'),
                          compact: compact,
                          paceKgPerWeek: _paceKgPerWeek,
                          weeks: _weeks!,
                          useKg: _useKg,
                          isLose: _isLose,
                        ),
                      ),
              ),
              if (_errorText != null) ...[
                SizedBox(height: r.scale(12)),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: r.scale(14),
                    vertical: r.scale(12),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: r.scale(18),
                        color: AppColors.error,
                      ),
                      SizedBox(width: r.scale(10)),
                      Expanded(
                        child: Text(
                          _errorText!,
                          style: TextStyle(
                            fontSize: r.scale(12),
                            fontWeight: FontWeight.w500,
                            color: AppColors.error,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          action: PrimaryButton(
            label: fromProfile ? 'Save' : 'Continue',
            isLoading: _isSaving,
            onPressed: _isSaving
                ? null
                : () => _onContinue(fromProfile: fromProfile),
          ),
        ),
      ),
    );
  }
}

class _GoalAmountHero extends StatelessWidget {
  const _GoalAmountHero({
    required this.r,
    required this.compact,
    required this.isLose,
  });

  final Responsive r;
  final bool compact;
  final bool isLose;

  @override
  Widget build(BuildContext context) {
    final heroAsset = isLose
        ? GoalAmountView._loseAsset
        : GoalAmountView._gainAsset;
    final highlight = isLose ? 'lose' : 'gain';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: r.scale(compact ? 26 : 28, tablet: 30),
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.16,
                    letterSpacing: -0.4,
                  ),
                  children: [
                    TextSpan(text: 'Weight to '),
                    TextSpan(
                      text: highlight,
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.scale(compact ? 6 : 8)),
              Text(
                'Set your target and when you want to reach it.',
                style: TextStyle(
                  fontSize: r.scale(compact ? 15 : 16, tablet: 17),
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: r.scale(8)),
        SizedBox(
          width: r.scale(compact ? 80 : 88, tablet: 96),
          height: r.scale(compact ? 80 : 88, tablet: 96),
          child: SvgPicture.asset(
            heroAsset,
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Text(
      label,
      style: TextStyle(
        fontSize: r.scale(18, tablet: 20, desktop: 21),
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

BoxDecoration _goalCardDecoration({Color? borderColor}) {
  return BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: borderColor ?? AppColors.border.withValues(alpha: 0.7),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

class _AmountStepperCard extends StatelessWidget {
  const _AmountStepperCard({
    required this.value,
    required this.unitLabel,
    required this.onDecrease,                                                                         
    required this.onIncrease,
  });

  final String value;
  final String unitLabel;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(18),
        vertical: r.scale(22),
      ),
      decoration: _goalCardDecoration(),
      child: Row(
        children: [
          _CircleStepButton(icon: Icons.remove_rounded, onPressed: onDecrease),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: r.scale(40, tablet: 44),
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1,
                    letterSpacing: -1,
                  ),
                ),
                SizedBox(height: r.scale(6)),
                Text(
                  unitLabel,
                  style: TextStyle(
                    fontSize: r.scale(13),
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          _CircleStepButton(icon: Icons.add_rounded, onPressed: onIncrease),
        ],
      ),
    );
  }
}

class _CircleStepButton extends StatelessWidget {
  const _CircleStepButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 22, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({required this.options});

  final List<_PresetOption> options;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: options[i]),
        ],
      ],
    );
  }
}

class _PresetOption extends StatelessWidget {
  const _PresetOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: selected ? AppColors.primary : AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: r.scale(11)),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.scale(12, tablet: 13),
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeframeCard extends StatelessWidget {
  const _TimeframeCard({
    required this.weeks,
    required this.targetDate,
    required this.minWeeks,
    required this.maxWeeks,
    required this.onWeeksChanged,
    this.onWeeksChangeEnd,
  });

  final int? weeks;
  final DateTime? targetDate;
  final int minWeeks;
  final int maxWeeks;
  final ValueChanged<int> onWeeksChanged;
  final ValueChanged<int>? onWeeksChangeEnd;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final selectedWeeks = weeks;
    final selectedDate = targetDate;

    if (selectedWeeks == null || selectedDate == null) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.scale(16),
          vertical: r.scale(20),
        ),
        decoration: _goalCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose a timeframe',
              style: TextStyle(
                fontSize: r.scale(16, tablet: 17),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: r.scale(6)),
            Text(
              'Pick a preset below, drag the slider, or set a custom date.',
              style: TextStyle(
                fontSize: r.scale(13),
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            SizedBox(height: r.scale(8)),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: AppColors.border,
                inactiveTrackColor: AppColors.border,
                thumbColor: AppColors.card,
                overlayColor: AppColors.primary.withValues(alpha: 0.12),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              ),
              child: Slider(
                value: minWeeks.toDouble(),
                min: minWeeks.toDouble(),
                max: maxWeeks.toDouble(),
                divisions: maxWeeks - minWeeks,
                onChanged: (v) => onWeeksChanged(v.round()),
                onChangeEnd: (v) => onWeeksChangeEnd?.call(v.round()),
              ),
            ),
          ],
        ),
      );
    }

    final dateLabel = DateFormat('MMM d, yyyy').format(selectedDate);

    return Container(
      padding: EdgeInsets.fromLTRB(
        r.scale(16),
        r.scale(16),
        r.scale(16),
        r.scale(8),
      ),
      decoration: _goalCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$selectedWeeks wk',
                style: TextStyle(
                  fontSize: r.scale(18, tablet: 19),
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'By',
                    style: TextStyle(
                      fontSize: r.scale(11),
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: r.scale(13),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.35),
              inactiveTrackColor: AppColors.border,
              thumbColor: AppColors.card,
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: selectedWeeks.toDouble(),
              min: minWeeks.toDouble(),
              max: maxWeeks.toDouble(),
              divisions: maxWeeks - minWeeks,
              onChanged: (v) => onWeeksChanged(v.round()),
              onChangeEnd: (v) => onWeeksChangeEnd?.call(v.round()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Staggered entrance for the weekly-rate block after a timeframe is chosen.
class _AnimatedWeeklyRateSection extends StatefulWidget {
  const _AnimatedWeeklyRateSection({
    super.key,
    required this.compact,
    required this.paceKgPerWeek,
    required this.weeks,
    required this.useKg,
    required this.isLose,
  });

  final bool compact;
  final double paceKgPerWeek;
  final int weeks;
  final bool useKg;
  final bool isLose;

  @override
  State<_AnimatedWeeklyRateSection> createState() =>
      _AnimatedWeeklyRateSectionState();
}

class _AnimatedWeeklyRateSectionState extends State<_AnimatedWeeklyRateSection>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _pulse;

  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _cardFade;
  late final Animation<double> _cardScale;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _glow;
  late final Animation<double> _iconPop;
  late final Animation<double> _copyFade;
  late final Animation<Offset> _copySlide;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _headerFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _cardFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.1, 0.65, curve: Curves.easeOutCubic),
    );
    _cardScale = Tween<double>(begin: 0.97, end: 1).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.1, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.1, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _glow = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 0.7).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.7, end: 0).chain(
          CurveTween(curve: Curves.easeInOutCubic),
        ),
        weight: 55,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.15, 1.0),
      ),
    );

    _iconPop = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.86, end: 1.05).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1).chain(
          CurveTween(curve: Curves.easeInOutCubic),
        ),
        weight: 45,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.22, 0.8),
      ),
    );

    _copyFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.32, 0.9, curve: Curves.easeOutCubic),
    );
    _copySlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.32, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    _entrance.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedWeeklyRateSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weeks != widget.weeks ||
        oldWidget.paceKgPerWeek != widget.paceKgPerWeek) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return AnimatedBuilder(
      animation: Listenable.merge([_entrance, _pulse]),
      builder: (context, _) {
        // Soft scale when rate changes: 1 → 1.02 → 1
        final updateScale = _pulse.value == 0 || _pulse.value == 1
            ? 1.0
            : 1.0 + 0.02 * math.sin(_pulse.value * math.pi);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: r.scale(widget.compact ? 18 : 22)),
            FadeTransition(
              opacity: _headerFade,
              child: SlideTransition(
                position: _headerSlide,
                child: const _SectionHeader(label: 'Weekly rate'),
              ),
            ),
            SizedBox(height: r.scale(10)),
            FadeTransition(
              opacity: _cardFade,
              child: SlideTransition(
                position: _cardSlide,
                child: ScaleTransition(
                  scale: _cardScale,
                  alignment: Alignment.topCenter,
                  child: Transform.scale(
                    scale: updateScale,
                    alignment: Alignment.center,
                    child: _PaceCard(
                      paceKgPerWeek: widget.paceKgPerWeek,
                      weeks: widget.weeks,
                      useKg: widget.useKg,
                      isLose: widget.isLose,
                      glowStrength: _glow.value,
                      iconScale: _iconPop.value *
                          (1 + 0.04 * math.sin(_pulse.value * math.pi)),
                      copyFade: _copyFade.value,
                      copySlide: _copySlide.value,
                      contentKey: ValueKey(
                        '${widget.weeks}_${widget.paceKgPerWeek.toStringAsFixed(3)}',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PaceCard extends StatelessWidget {
  const _PaceCard({
    required this.paceKgPerWeek,
    required this.weeks,
    required this.useKg,
    required this.isLose,
    this.glowStrength = 0,
    this.iconScale = 1,
    this.copyFade = 1,
    this.copySlide = Offset.zero,
    this.contentKey,
  });

  static const _starIconAsset = 'assets/image/star.svg';

  final double paceKgPerWeek;
  final int weeks;
  final bool useKg;
  final bool isLose;
  final double glowStrength;
  final double iconScale;
  final double copyFade;
  final Offset copySlide;
  final Key? contentKey;

  String _timeframeLabel() {
    if (weeks <= 1) return '1 week';
    if (weeks == 2) return '2 weeks';
    if (weeks <= 4) return '1 month';
    if (weeks <= 8) return '2 months';
    if (weeks <= 17) return '4 months';
    if (weeks <= 26) return '6 months';
    return '$weeks weeks';
  }

  ({String title, String description}) _paceCopy() {
    final displayPace = useKg
        ? paceKgPerWeek
        : paceKgPerWeek * BodyMeasurementUnits.kgToLb;
    final unit = useKg ? 'kg' : 'lb';
    final formatted = displayPace == displayPace.roundToDouble()
        ? displayPace.toStringAsFixed(2)
        : displayPace.toStringAsFixed(2);
    final timeframe = _timeframeLabel();

    if (paceKgPerWeek < 0.25) {
      return (
        title: '$formatted $unit/wk',
        description: 'A calm pace — a great start for your $timeframe goal.',
      );
    }
    if (paceKgPerWeek <= 0.5) {
      return (
        title: '$formatted $unit/wk',
        description: 'Solid pace over $timeframe — keep showing up.',
      );
    }
    if (paceKgPerWeek <= 0.75) {
      return (
        title: '$formatted $unit/wk',
        description: 'Strong effort for $timeframe — consistency wins.',
      );
    }
    if (paceKgPerWeek <= 1.0) {
      return (
        title: '$formatted $unit/wk',
        description: 'Bold target for $timeframe — listen to your body.',
      );
    }
    if (weeks <= 1) {
      return (
        title: '$formatted $unit/wk',
        description:
            'Big goal in 1 week — you can do it. A little more time helps it stick.',
      );
    }
    if (weeks <= 2) {
      return (
        title: '$formatted $unit/wk',
        description:
            'Strong push for 2 weeks — adding time makes progress easier to keep.',
      );
    }
    if (weeks <= 4) {
      return (
        title: '$formatted $unit/wk',
        description:
            'Ambitious 1-month plan — stay focused and trust the process.',
      );
    }
    if (weeks <= 8) {
      return (
        title: '$formatted $unit/wk',
        description:
            "You're aiming high in $timeframe — small steps add up fast.",
      );
    }
    return (
      title: '$formatted $unit/wk',
      description:
          'Big $timeframe goal — stay patient, stay consistent, and celebrate progress.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final copy = _paceCopy();
    final glow = glowStrength.clamp(0.0, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
      padding: EdgeInsets.all(r.scale(16)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color.lerp(
                AppColors.border.withValues(alpha: 0.7),
                AppColors.primary,
                glow * 0.4,
              ) ??
              AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          if (glow > 0.01)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1 * glow),
              blurRadius: 16 + 8 * glow,
              offset: const Offset(0, 6),
              spreadRadius: -2,
            ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.scale(
            scale: iconScale,
            child: Container(
              width: 44,
              height: 44,
              padding: EdgeInsets.all(r.scale(7)),
              decoration: BoxDecoration(
                color: Color.lerp(
                  AppColors.surface,
                  AppColors.primary.withValues(alpha: 0.1),
                  glow,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SvgPicture.asset(
                _starIconAsset,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(width: r.scale(14)),
          Expanded(
            child: Opacity(
              opacity: copyFade.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(
                  copySlide.dx * r.scale(12),
                  copySlide.dy * r.scale(12),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(curved),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    key: contentKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.title,
                        style: TextStyle(
                          fontSize: r.scale(15, tablet: 16),
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      SizedBox(height: r.scale(4)),
                      Text(
                        copy.description,
                        style: TextStyle(
                          fontSize: r.scale(12),
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
