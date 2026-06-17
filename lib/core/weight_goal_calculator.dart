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
      GoalType.loseWeight =>
        _roundKg((current - _defaultLossKg).clamp(40.0, current - 0.5)),
      GoalType.gainWeight =>
        _roundKg((current + _defaultGainKg).clamp(current + 0.5, 200.0)),
    };
  }

  static double _roundKg(double kg) => (kg * 10).round() / 10;
}
