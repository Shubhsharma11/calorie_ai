import 'activity_level.dart';
import 'diet_plan_interest.dart';
import 'diet_type.dart';
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
    required this.dietPlanInterest,
    required this.foodPreferences,
    required this.meatPreferences,
    required this.cookingSkills,
    required this.medications,
    required this.eatingHabits,
    required this.livingArea,
    required this.livingState,
    required this.dietType,
    required this.foodAllergies,
    required this.foodsToAvoid,
    required this.mealsPerDay,
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
  final DietPlanInterest? dietPlanInterest;
  final List<String> foodPreferences;
  final List<String> meatPreferences;
  final String? cookingSkills;
  final List<String> medications;
  final String? eatingHabits;
  final String? livingArea;
  final String? livingState;
  final DietType? dietType;
  final List<String> foodAllergies;
  final String foodsToAvoid;
  final int? mealsPerDay;

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
      dietPlanInterest: user.dietPlanInterest,
      foodPreferences: List<String>.from(user.foodPreferences),
      meatPreferences: List<String>.from(user.meatPreferences),
      cookingSkills: user.cookingSkills,
      medications: List<String>.from(user.medications),
      eatingHabits: user.eatingHabits,
      livingArea: user.livingArea,
      livingState: user.livingState,
      dietType: user.dietType,
      foodAllergies: List<String>.from(user.foodAllergies),
      foodsToAvoid: user.foodsToAvoid,
      mealsPerDay: user.mealsPerDay,
    );
  }

  static bool stringListsEqual(List<String> left, List<String> right) {
    final a = List<String>.from(left)..sort();
    final b = List<String>.from(right)..sort();
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool foodAllergiesEqual(List<String> left, List<String> right) =>
      stringListsEqual(left, right);

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

  /// Fields that affect nutrition-plan generation (Profile “Update plan” banner).
  static bool planInputsEqual(ProfileSyncSnapshot a, ProfileSyncSnapshot b) {
    return a.age == b.age &&
        a.gender == b.gender &&
        a.heightCm == b.heightCm &&
        a.weightKg == b.weightKg &&
        a.goal == b.goal &&
        (a.goalWeightKg - b.goalWeightKg).abs() < 0.05 &&
        a.targetDate.year == b.targetDate.year &&
        a.targetDate.month == b.targetDate.month &&
        a.targetDate.day == b.targetDate.day &&
        a.activityLevel == b.activityLevel &&
        a.dietPlanInterest == b.dietPlanInterest &&
        a.cookingSkills == b.cookingSkills &&
        a.eatingHabits == b.eatingHabits &&
        a.livingArea == b.livingArea &&
        a.livingState == b.livingState &&
        a.dietType == b.dietType &&
        a.mealsPerDay == b.mealsPerDay &&
        a.foodsToAvoid.trim() == b.foodsToAvoid.trim() &&
        stringListsEqual(a.foodPreferences, b.foodPreferences) &&
        stringListsEqual(a.meatPreferences, b.meatPreferences) &&
        stringListsEqual(a.medications, b.medications) &&
        foodAllergiesEqual(a.foodAllergies, b.foodAllergies) &&
        healthConcernsEqual(a.healthConcerns, b.healthConcerns);
  }

  static List<HealthConcern> _normalizedConcerns(List<HealthConcern> concerns) {
    final copy = List<HealthConcern>.from(concerns)
      ..sort((a, b) => a.category.compareTo(b.category));
    return copy;
  }
}
