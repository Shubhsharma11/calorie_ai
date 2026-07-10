import '../models/goal_type.dart';

/// Simple goal-based target weight suggestions (no BMI).
abstract final class WeightGoalCalculator {
  static const double _defaultLossKg = 5.0;
  static const double _defaultGainKg = 5.0;

  static double recommendedGoalWeight({
    required GoalType? goal,
    required int weightKg,
    required int heightCm,
    required int age,
    required String gender,
  }) {
    final current = weightKg.toDouble();

    return switch (goal) {
      null || GoalType.maintainWeight => current,
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

  static double _roundKg(double kg) => (kg * 10).round() / 10;
}
