import 'activity_level.dart';
import 'goal_type.dart';
import 'health_concern.dart';
import 'user_model.dart';

/// Last-known profile values synced with the backend.
class ProfileSyncSnapshot {
  const ProfileSyncSnapshot({
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.goal,
    required this.goalWeightKg,
    required this.isGoalWeightManual,
    required this.targetDate,
    required this.activityLevel,
    required this.healthConcerns,
  });

  final int age;
  final String gender;
  final int heightCm;
  final int weightKg;
  final GoalType? goal;
  final double goalWeightKg;
  final bool isGoalWeightManual;
  final DateTime targetDate;
  final ActivityLevel? activityLevel;
  final List<HealthConcern> healthConcerns;

  factory ProfileSyncSnapshot.fromUser(UserModel user) {
    return ProfileSyncSnapshot(
      age: user.age ?? 0,
      gender: user.gender ?? '',
      heightCm: user.heightCm ?? 0,
      weightKg: user.weightKg ?? 0,
      goal: user.goal,
      goalWeightKg: user.goalWeightKg,
      isGoalWeightManual: user.isGoalWeightManual,
      targetDate: DateTime(
        user.targetDate.year,
        user.targetDate.month,
        user.targetDate.day,
      ),
      activityLevel: user.activityLevel,
      healthConcerns: List<HealthConcern>.from(user.healthConcerns),
    );
  }

  static bool healthConcernsEqual(
    List<HealthConcern> left,
    List<HealthConcern> right,
  ) {
    final normalizedLeft = _normalizedConcerns(left);
    final normalizedRight = _normalizedConcerns(right);
    if (normalizedLeft.length != normalizedRight.length) return false;

    for (var i = 0; i < normalizedLeft.length; i++) {
      final a = normalizedLeft[i];
      final b = normalizedRight[i];
      if (a.category != b.category ||
          a.description != b.description ||
          a.duration != b.duration ||
          a.severity != b.severity ||
          a.medication != b.medication) {
        return false;
      }
    }

    return true;
  }

  static List<HealthConcern> _normalizedConcerns(List<HealthConcern> concerns) {
    final copy = List<HealthConcern>.from(concerns)
      ..sort((a, b) => a.category.compareTo(b.category));
    return copy;
  }
}
