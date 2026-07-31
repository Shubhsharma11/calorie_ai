import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/tracker_controller.dart';
import '../controllers/user_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../core/route_args.dart';
import '../core/weight_goal_calculator.dart';
import '../models/goal_type.dart';
import '../models/onboarding_request_model.dart';
import '../models/profile_sync_snapshot.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/responsive_page.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/weight_ruler_slider.dart';

class GoalWeightView extends StatefulWidget {
  const GoalWeightView({super.key});

  @override
  State<GoalWeightView> createState() => _GoalWeightViewState();
}

class _GoalWeightViewState extends State<GoalWeightView> {
  late final UserController _user = Get.find<UserController>();
  late double _goalWeight;
  late bool _isManual;
  late DateTime _targetDate;
  late ProfileSyncSnapshot _baseline;
  bool _isSaving = false;

  static const double _weightMinKg = 40;
  static const double _weightMaxKg = 200;

  @override
  void initState() {
    super.initState();
    final u = _user.user;
    _isManual = u.isGoalWeightManual;
    _goalWeight = u.goalWeightKg.clamp(_weightMinKg, _weightMaxKg);
    _targetDate = u.targetDate;
    _baseline = _user.captureProfileSyncSnapshot();

    if (u.goal == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!RouteArgs.isEditingFromProfile) {
          Get.offNamed(AppRoutes.goalSetup);
        }
      });
    }
  }

  GoalType get _goal => _user.user.goal ?? GoalType.maintainWeight;

  double get _currentKg {
    if (Get.isRegistered<TrackerController>()) {
      final kg = Get.find<TrackerController>().currentWeight.value;
      if (kg > 0) return kg;
    }
    return _user.user.weightKg?.toDouble() ?? 0;
  }

  bool _weightMatchesGoal(double targetKg, double currentKg, GoalType goal) =>
      WeightGoalCalculator.targetMatchesGoal(
        goal: goal,
        currentKg: currentKg,
        targetKg: targetKg,
      );

  int _previewCalories() {
    final u = _user.user;
    final savedGoal = u.goal;
    final savedPinned = u.pinnedGoalWeightKg;
    final savedManual = u.manualGoalWeightKg;
    final savedDate = u.targetDate;

    u.goal = _goal;
    if (_goal == GoalType.maintainWeight) {
      u.clearPinnedGoalWeight();
    } else if (_isManual) {
      u.pinGoalWeight(_goalWeight);
    } else {
      u.clearPinnedGoalWeight();
      u.pinGoalWeight(u.recommendedGoalWeightKg);
    }
    u.targetDate = _targetDate;
    final calories = u.dailyCalorieGoal;

    u.goal = savedGoal;
    u.pinnedGoalWeightKg = savedPinned;
    u.manualGoalWeightKg = savedManual;
    u.targetDate = savedDate;
    return calories;
  }

  Future<void> _pickTargetDate() async {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate.isBefore(today) ? today : _targetDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
      helpText: 'Select target date',
    );
    if (picked == null) return;
    setState(() {
      _targetDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _onWeightChanged(double value) {
    setState(() {
      _isManual = true;
      _goalWeight = value.clamp(_weightMinKg, _weightMaxKg);
    });
  }

  void _stepWeight(double delta) {
    _onWeightChanged(_goalWeight + delta);
  }

  void _showCalorieInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Estimated daily calories'),
        content: const SingleChildScrollView(
          child: Text(
            'This number is calculated from your age, height, weight, '
            'activity level, and goal type. You can fine-tune it later on '
            'the daily calorie goal screen.',
            style: TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final u = _user.user;
    final currentKg = _currentKg;

    if (!_weightMatchesGoal(_goalWeight, currentKg, _goal)) {
      final message = switch (_goal) {
        GoalType.loseWeight =>
          'For weight loss, set a target below your current weight.',
        GoalType.maintainWeight =>
          'For maintenance, your target should match your current weight.',
        GoalType.gainWeight =>
          'For weight gain, set a target above your current weight.',
      };
      AppSnackbar.error(message, title: 'Invalid target');
      return;
    }

    setState(() => _isSaving = true);

    try {
      u.targetDate = _targetDate;

      if (_goal == GoalType.maintainWeight) {
        _user.useRecommendedGoalWeight();
      } else if (_isManual) {
        _user.setGoalWeight(_goalWeight, manual: true);
      } else {
        _user.setGoalWeight(_goalWeight, manual: false);
      }
      _user.update();
      // Don't overwrite logged weights — only seed empty history.

      if (RouteArgs.isEditingFromProfile || RouteArgs.shouldReturnToDailyGoal) {
        var didSaveProfile = false;
        if (RouteArgs.isEditingFromProfile && u.goal != null) {
          final patch = OnboardingPatchModel.goalProfileDiff(u, _baseline);
          if (patch.isEmpty) {
            AppSnackbar.info('No changes to save.', title: 'Nothing changed');
            return;
          }

          final error = await _user.patchOnboarding(patch);
          if (!mounted) return;
          if (error != null) {
            AppSnackbar.error(error, title: 'Save failed');
            return;
          }
          _baseline = _user.captureProfileSyncSnapshot();
          didSaveProfile = true;
        }
        Get.back();
        if (didSaveProfile) {
          AppSnackbar.success('Goal weight updated.');
        }
      } else {
        Get.toNamed(AppRoutes.activityLevel);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final currentKg = _currentKg;
    final calories = _previewCalories();
    final fromProfile = RouteArgs.isEditingFromProfile;
    final showDatePicker = _goal != GoalType.maintainWeight;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar.backOnly(),
      body: SetupScreenLayout(
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What\'s your goal weight?',
              style: TextStyle(
                fontSize: r.scale(24, tablet: 26),
                fontWeight: FontWeight.bold,
                height: 1.25,
              ),
            ),
            SizedBox(height: r.scale(8)),
            Text(
              'We\'ll use this to estimate your daily calorie target.',
              style: TextStyle(
                fontSize: r.scale(15),
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            SizedBox(height: r.scale(20)),
            Center(child: _GoalStatusBadge(goal: _goal)),
            SizedBox(height: r.scale(20)),
            _WeightCompareRow(
              currentKg: currentKg,
              targetKg: _goalWeight,
            ),
            SizedBox(height: r.scale(28)),
            _WeightPickerRow(
              weight: _goalWeight,
              onDecrease: () => _stepWeight(-0.5),
              onIncrease: () => _stepWeight(0.5),
            ),
            SizedBox(height: r.scale(24)),
            WeightRulerSlider(
              value: _goalWeight,
              min: _weightMinKg,
              max: _weightMaxKg,
              onChanged: _onWeightChanged,
            ),
            if (showDatePicker) ...[
              SizedBox(height: r.scale(20)),
              Center(
                child: InkWell(
                  onTap: _pickTargetDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 15,
                          color: AppColors.textSecondary.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd MMM yyyy').format(_targetDate),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(height: r.scale(24)),
            _GoalSummaryCard(
              calories: calories,
              onCaloriesTap: _showCalorieInfo,
            ),
          ],
        ),
        action: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(fromProfile ? 'Save' : 'Next'),
                          if (!fromProfile) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalStatusBadge extends StatelessWidget {
  const _GoalStatusBadge({required this.goal});

  final GoalType goal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _goalIcon(goal),
            size: 16,
            color: AppColors.primary.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 6),
          Text(
            goal.statusLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  IconData _goalIcon(GoalType goal) {
    return switch (goal) {
      GoalType.loseWeight => Icons.trending_down_rounded,
      GoalType.maintainWeight => Icons.balance_rounded,
      GoalType.gainWeight => Icons.trending_up_rounded,
    };
  }
}

class _WeightCompareRow extends StatelessWidget {
  const _WeightCompareRow({
    required this.currentKg,
    required this.targetKg,
  });

  final double currentKg;
  final double targetKg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CompareColumn(
              label: 'Current weight',
              value: '${currentKg.toStringAsFixed(1)} kg',
              icon: Icons.monitor_weight_outlined,
              highlight: false,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: AppColors.textSecondary.withValues(alpha: 0.45),
            ),
          ),
          Expanded(
            child: _CompareColumn(
              label: 'Target weight',
              value: '${targetKg.toStringAsFixed(1)} kg',
              icon: Icons.adjust_rounded,
              highlight: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareColumn extends StatelessWidget {
  const _CompareColumn({
    required this.label,
    required this.value,
    required this.icon,
    required this.highlight,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: highlight ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _WeightPickerRow extends StatelessWidget {
  const _WeightPickerRow({
    required this.weight,
    required this.onDecrease,
    required this.onIncrease,
  });

  final double weight;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Row(
      children: [
        _CircleStepButton(icon: Icons.remove, onPressed: onDecrease),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                weight.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: r.scale(52, tablet: 56),
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'kg',
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        _CircleStepButton(icon: Icons.add, onPressed: onIncrease),
      ],
    );
  }
}

class _CircleStepButton extends StatelessWidget {
  const _CircleStepButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

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

class _GoalSummaryCard extends StatelessWidget {
  const _GoalSummaryCard({
    required this.calories,
    required this.onCaloriesTap,
  });

  final int calories;
  final VoidCallback onCaloriesTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: _SummaryRow(
        icon: Icons.local_fire_department_rounded,
        title: 'Estimated daily calories',
        value: '$calories kcal',
        valueColor: AppColors.primary,
        valueFontSize: 18,
        onTap: onCaloriesTap,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
    this.valueFontSize,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;
  final double? valueFontSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: valueFontSize ?? 16,
                        fontWeight: FontWeight.w700,
                        color: valueColor ?? AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.textSecondary.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
