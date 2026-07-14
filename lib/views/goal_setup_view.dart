import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/body_measurement_units.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../models/goal_type.dart';
import '../models/onboarding_request_model.dart';
import '../models/profile_sync_snapshot.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/responsive_page.dart';

class GoalSetupView extends StatefulWidget {
  const GoalSetupView({super.key});

  static const _targetAsset = 'assets/image/target.svg';
  static const _loseWeightAsset = 'assets/image/right-down.svg';
  static const _gainWeightAsset = 'assets/image/upgain.svg';
  static const _maintainWeightAsset = 'assets/image/balance.svg';

  @override
  State<GoalSetupView> createState() => _GoalSetupViewState();
}

class _GoalSetupViewState extends State<GoalSetupView> {
  final UserController controller = Get.find<UserController>();
  late final ProfileSyncSnapshot _baseline;
  late final TextEditingController _amountCtrl;
  String? _amountError;
  bool _useKg = true;

  static const double _minChangeKg = 0.5;
  static const double _maxChangeKg = 50;
  static const double _defaultChangeKg = 5;
  static const double _minWeightKg = 40;
  static const double _maxWeightKg = 200;

  double get _minChangeDisplay =>
      _useKg ? _minChangeKg : _minChangeKg * BodyMeasurementUnits.kgToLb;

  double get _maxChangeDisplay =>
      _useKg ? _maxChangeKg : _maxChangeKg * BodyMeasurementUnits.kgToLb;

  String get _unitLabel => _useKg ? 'kg' : 'lbs';

  @override
  void initState() {
    super.initState();
    _baseline = controller.captureProfileSyncSnapshot();
    _amountCtrl = TextEditingController(text: _initialAmountText());
    _amountCtrl.addListener(_clearAmountError);
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_clearAmountError);
    _amountCtrl.dispose();
    super.dispose();
  }

  void _clearAmountError() {
    if (_amountError != null) setState(() => _amountError = null);
  }

  String _initialAmountText() {
    final u = controller.user;
    final goal = u.goal;
    if (goal == null || goal == GoalType.maintainWeight) {
      return _formatAmount(_defaultChangeKg);
    }
    final diff = (u.goalWeightKg - u.weightKg).abs();
    if (diff < _minChangeKg) return _formatAmount(_defaultChangeKg);
    return _formatAmount(diff.clamp(_minChangeKg, _maxChangeKg));
  }

  String _formatAmount(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  double _toKg(double displayAmount) {
    if (_useKg) return displayAmount;
    return displayAmount / BodyMeasurementUnits.kgToLb;
  }

  double _fromKg(double kg) {
    if (_useKg) return kg;
    return kg * BodyMeasurementUnits.kgToLb;
  }

  double? _parseDisplayAmount() {
    final raw = _amountCtrl.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  /// Always returns kg for calculations / saving.
  double? _parseAmountKg() {
    final display = _parseDisplayAmount();
    if (display == null) return null;
    return _toKg(display);
  }

  void _toggleUnit() {
    final nextUseKg = !_useKg;
    final display = _parseDisplayAmount();
    if (display != null) {
      final asKg = _useKg ? display : display / BodyMeasurementUnits.kgToLb;
      final converted = nextUseKg
          ? asKg
          : asKg * BodyMeasurementUnits.kgToLb;
      _amountCtrl.text = _formatAmount(converted);
    }
    setState(() {
      _useKg = nextUseKg;
      _amountError = null;
    });
  }

  void _onSelectGoal(GoalType goal) {
    controller.selectGoal(goal);
    if (goal != GoalType.maintainWeight && _parseDisplayAmount() == null) {
      _amountCtrl.text = _formatAmount(_fromKg(_defaultChangeKg));
    }
    setState(() => _amountError = null);
  }

  String? _validateAmount(GoalType goal) {
    if (goal == GoalType.maintainWeight) return null;

    final raw = _amountCtrl.text.trim();
    if (raw.isEmpty) {
      return goal == GoalType.loseWeight
          ? 'Enter how much you want to lose'
          : 'Enter how much you want to gain';
    }

    final display = _parseDisplayAmount();
    if (display == null) {
      return 'Enter a valid number';
    }
    if (display < _minChangeDisplay || display > _maxChangeDisplay) {
      return 'Use a value between ${_formatAmount(_minChangeDisplay)} and '
          '${_formatAmount(_maxChangeDisplay)} $_unitLabel';
    }

    final amountKg = _toKg(display);
    final current = controller.user.weightKg.toDouble();
    if (goal == GoalType.loseWeight) {
      final maxLossKg = current - _minWeightKg;
      if (maxLossKg < _minChangeKg) {
        return 'Current weight is already at the minimum';
      }
      if (amountKg > maxLossKg) {
        return 'You can lose up to '
            '${_formatAmount(_fromKg(maxLossKg))} $_unitLabel';
      }
    } else {
      final maxGainKg = _maxWeightKg - current;
      if (maxGainKg < _minChangeKg) {
        return 'Current weight is already at the maximum';
      }
      if (amountKg > maxGainKg) {
        return 'You can gain up to '
            '${_formatAmount(_fromKg(maxGainKg))} $_unitLabel';
      }
    }

    return null;
  }

  double? _targetWeightFor(GoalType goal) {
    final current = controller.user.weightKg.toDouble();
    if (goal == GoalType.maintainWeight) return current;

    final amountKg = _parseAmountKg();
    if (amountKg == null) return null;

    return goal == GoalType.loseWeight
        ? current - amountKg
        : current + amountKg;
  }

  Future<void> _onContinue({required bool fromProfile}) async {
    final goal = controller.user.goal;
    if (goal == null) {
      AppSnackbar.error('Select your goal first.');
      return;
    }

    final amountError = _validateAmount(goal);
    setState(() => _amountError = amountError);
    if (amountError != null) return;

    final target = _targetWeightFor(goal);
    if (target == null) {
      setState(() => _amountError = 'Enter a valid amount');
      return;
    }

    if (goal == GoalType.maintainWeight) {
      controller.useRecommendedGoalWeight();
    } else {
      controller.setGoalWeight(target, manual: true);
    }

    if (fromProfile) {
      final patch = OnboardingPatchModel.goalProfileDiff(
        controller.user,
        _baseline,
      );
      if (patch.isEmpty) {
        AppSnackbar.info('No changes to save.', title: 'Nothing changed');
        return;
      }

      final error = await controller.patchOnboarding(patch);
      if (error != null) {
        AppSnackbar.error(error, title: 'Save failed');
        return;
      }
      Get.back();
      AppSnackbar.success('Goal updated.');
      return;
    }

    await controller.persistOnboardingStep(AppRoutes.activityLevel);
    Get.toNamed(AppRoutes.activityLevel);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final compact = r.height < 720;
    final fromProfile = RouteArgs.isEditingFromProfile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar.backOnly(),
      body: GetBuilder<UserController>(
        builder: (_) {
          final selected = controller.user.goal;
          final currentKg = controller.user.weightKg.toDouble();

          return SetupScreenLayout(
            scrollable: true,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: r.scale(compact ? 4 : 8)),
                _HeroSection(r: r, compact: compact),
                SizedBox(height: r.scale(compact ? 16 : 20)),
                ...GoalType.values.map(
                  (g) => Padding(
                    padding: EdgeInsets.only(bottom: r.scale(12)),
                    child: _GoalCard(
                      goal: g,
                      selected: selected == g,
                      onTap: () => _onSelectGoal(g),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: selected == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: EdgeInsets.only(top: r.scale(4)),
                          child: _GoalAmountPanel(
                            goal: selected,
                            currentKg: currentKg,
                            useKg: _useKg,
                            amountController: _amountCtrl,
                            errorText: _amountError,
                            onUnitTap: _toggleUnit,
                            onAmountChanged: () => setState(() {}),
                          ),
                        ),
                ),
              ],
            ),
            action: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: selected == null
                    ? null
                    : () => _onContinue(fromProfile: fromProfile),
                child: Text(fromProfile ? 'Save' : 'Next'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GoalAmountPanel extends StatelessWidget {
  const _GoalAmountPanel({
    required this.goal,
    required this.currentKg,
    required this.useKg,
    required this.amountController,
    required this.onAmountChanged,
    required this.onUnitTap,
    this.errorText,
  });

  final GoalType goal;
  final double currentKg;
  final bool useKg;
  final TextEditingController amountController;
  final VoidCallback onAmountChanged;
  final VoidCallback onUnitTap;
  final String? errorText;

  String _formatValue(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final isMaintain = goal == GoalType.maintainWeight;
    final hasError = errorText != null;
    final borderColor =
        hasError ? AppColors.error.withValues(alpha: 0.65) : AppColors.border;
    final unit = useKg ? 'kg' : 'lbs';
    final displayCurrent = useKg
        ? currentKg
        : currentKg * BodyMeasurementUnits.kgToLb;

    final rawAmount = double.tryParse(
      amountController.text.trim().replaceAll(',', '.'),
    );
    final displayAmount = rawAmount;
    final displayTarget = displayAmount == null
        ? null
        : goal == GoalType.loseWeight
            ? displayCurrent - displayAmount
            : goal == GoalType.gainWeight
                ? displayCurrent + displayAmount
                : displayCurrent;

    final changeLabel = switch (goal) {
      GoalType.loseWeight => 'Losing',
      GoalType.gainWeight => 'Gaining',
      GoalType.maintainWeight => 'Change',
    };

    final title = switch (goal) {
      GoalType.loseWeight => 'How much do you want to lose?',
      GoalType.gainWeight => 'How much do you want to gain?',
      GoalType.maintainWeight => 'You\'ll keep your current weight',
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.scale(14)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? AppColors.error.withValues(alpha: 0.45)
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: r.scale(15, tablet: 16),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: r.scale(12)),
          if (isMaintain)
            Text(
              'Target: ${_formatValue(displayCurrent)} $unit',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: r.scale(16, tablet: 17),
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            )
          else ...[
            Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: r.scale(96),
                    child: TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: r.scale(14, tablet: 15),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surface,
                        isDense: true,
                        hintText: useKg ? '5' : '11',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color:
                                hasError ? AppColors.error : AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: borderColor),
                        ),
                      ),
                      onChanged: (_) => onAmountChanged(),
                    ),
                  ),
                  SizedBox(width: r.scale(10)),
                  GestureDetector(
                    onTap: onUnitTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: r.scale(14),
                        vertical: r.scale(12),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(
                        unit,
                        style: TextStyle(
                          fontSize: r.scale(12, tablet: 13),
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.scale(12)),
            _WeightChangeSummary(
              currentText: '${_formatValue(displayCurrent)} $unit',
              changeText: displayAmount == null
                  ? '—'
                  : '${goal == GoalType.loseWeight ? '-' : '+'}'
                      '${_formatValue(displayAmount)} $unit',
              changeLabel: changeLabel,
              targetText: displayTarget == null
                  ? '—'
                  : '${_formatValue(displayTarget)} $unit',
            ),
          ],
          if (hasError) ...[
            SizedBox(height: r.scale(8)),
            Text(
              errorText!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: r.scale(12),
                fontWeight: FontWeight.w500,
                color: AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeightChangeSummary extends StatelessWidget {
  const _WeightChangeSummary({
    required this.currentText,
    required this.changeText,
    required this.changeLabel,
    required this.targetText,
  });

  final String currentText;
  final String changeText;
  final String changeLabel;
  final String targetText;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(10),
        vertical: r.scale(10),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCell(
              label: 'Current',
              value: currentText,
              emphasize: false,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
          ),
          Expanded(
            child: _SummaryCell(
              label: changeLabel,
              value: changeText,
              emphasize: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
          ),
          Expanded(
            child: _SummaryCell(
              label: 'New',
              value: targetText,
              emphasize: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    required this.emphasize,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: emphasize ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.r,
    required this.compact,
  });

  final Responsive r;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(2),
        vertical: r.scale(compact ? 0 : 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: r.scale(compact ? 25 : 28, tablet: 31),
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.16,
                      letterSpacing: -0.5,
                    ),
                    children: const [
                      TextSpan(text: 'What\'s your '),
                      TextSpan(
                        text: 'goal?',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.scale(compact ? 6 : 8)),
                Text(
                  'Choose what you want to work toward.',
                  style: TextStyle(
                    fontSize: r.scale(compact ? 13 : 14, tablet: 15),
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: r.scale(8)),
          SizedBox(
            width: r.scale(compact ? 88 : 96, tablet: 104),
            height: r.scale(compact ? 88 : 96, tablet: 104),
            child: SvgPicture.asset(
              GoalSetupView._targetAsset,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final GoalType goal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(14),
            vertical: r.scale(14),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _GoalLeadingIcon(goal: goal),
              SizedBox(width: r.scale(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: TextStyle(
                        fontSize: r.scale(15, tablet: 16),
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      goal.description,
                      style: TextStyle(
                        fontSize: r.scale(12, tablet: 13),
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: r.scale(8)),
              _SelectionIndicator(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalLeadingIcon extends StatelessWidget {
  const _GoalLeadingIcon({required this.goal});

  final GoalType goal;

  @override
  Widget build(BuildContext context) {
    if (goal == GoalType.loseWeight) {
      return SizedBox(
        width: 44,
        height: 44,
        child: SvgPicture.asset(
          GoalSetupView._loseWeightAsset,
          fit: BoxFit.contain,
        ),
      );
    }

    if (goal == GoalType.gainWeight) {
      return SizedBox(
        width: 44,
        height: 44,
        child: SvgPicture.asset(
          GoalSetupView._gainWeightAsset,
          fit: BoxFit.contain,
        ),
      );
    }

    return SizedBox(
      width: 44,
      height: 44,
      child: SvgPicture.asset(
        GoalSetupView._maintainWeightAsset,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_rounded,
          size: 16,
          color: AppColors.onPrimary,
        ),
      );
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.border,
          width: 1.5,
        ),
      ),
    );
  }
}
