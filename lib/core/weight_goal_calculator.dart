import '../models/goal_type.dart';
import '../models/user_model.dart';

/// Simple goal-based target weight suggestions (no BMI).
abstract final class WeightGoalCalculator {
  static const double _defaultLossKg = 5.0;
  static const double _defaultGainKg = 5.0;
  static const double atGoalToleranceKg = 0.05;
  static const double maintainToleranceKg = 0.15;

  static double recommendedGoalWeight({
    required GoalType? goal,
    required double currentWeightKg,
    int? heightCm,
    int? age,
    String? gender,
  }) {
    final current = currentWeightKg;

    return switch (goal) {
      null || GoalType.maintainWeight => _roundKg(current),
      GoalType.loseWeight => () {
          const minKg = 40.0;
          final ceiling = current - 0.5;
          if (ceiling < minKg) return _roundKg(current);
          final target = (current - _defaultLossKg).clamp(minKg, ceiling);
          return _roundKg(target);
        }(),
      GoalType.gainWeight => () {
          const maxKg = 200.0;
          final floor = current + 0.5;
          if (floor > maxKg) return _roundKg(current);
          final target = (current + _defaultGainKg).clamp(floor, maxKg);
          return _roundKg(target);
        }(),
    };
  }

  static bool targetMatchesGoal({
    required GoalType goal,
    required double currentKg,
    required double targetKg,
  }) {
    final diff = targetKg - currentKg;
    return switch (goal) {
      GoalType.maintainWeight => diff.abs() < maintainToleranceKg,
      GoalType.loseWeight => diff < -atGoalToleranceKg,
      GoalType.gainWeight => diff > atGoalToleranceKg,
    };
  }

  static bool isAtGoal({
    required double currentKg,
    required double targetKg,
  }) =>
      (currentKg - targetKg).abs() < atGoalToleranceKg;

  /// Progress from start → current toward [targetKg].
  ///
  /// [startWeightKg] should come from the API (`startWeight`) or the oldest
  /// weight log from the weight API — never from device storage.
  static double weightGoalProgress({
    required UserModel user,
    required double currentWeight,
    double? startWeightKg,
  }) {
    final goal = user.goal;
    if (goal == null) return 0.0;

    final start = startWeightKg ??
        user.goalStartWeightKg ??
        user.weightKg?.toDouble() ??
        currentWeight;
    final target = user.goalWeightKg;

    if (!targetMatchesGoal(
          goal: goal,
          currentKg: start,
          targetKg: target,
        ) &&
        !targetMatchesGoal(
          goal: goal,
          currentKg: currentWeight,
          targetKg: target,
        )) {
      return 0.0;
    }

    if (goal == GoalType.maintainWeight) {
      final diff = (currentWeight - target).abs();
      return (1 - (diff / 2).clamp(0.0, 1.0)).clamp(0.0, 1.0);
    }

    final totalChange = (target - start).abs();
    if (totalChange < atGoalToleranceKg) {
      return isAtGoal(currentKg: currentWeight, targetKg: target) ? 1.0 : 0.0;
    }

    if (goal == GoalType.loseWeight && currentWeight <= target) return 1.0;
    if (goal == GoalType.gainWeight && currentWeight >= target) return 1.0;

    // Direction-aware: how much of the start→target journey is closed.
    final traveled = goal == GoalType.loseWeight
        ? (start - currentWeight).clamp(0.0, totalChange)
        : (currentWeight - start).clamp(0.0, totalChange);
    return (traveled / totalChange).clamp(0.0, 1.0);
  }

  static double _roundKg(double kg) => (kg * 10).round() / 10;
}
