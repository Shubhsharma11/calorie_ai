import 'package:calorie_ai/models/activity_level.dart';
import 'package:calorie_ai/models/goal_type.dart';
import 'package:calorie_ai/models/health_concern.dart';
import 'package:calorie_ai/models/onboarding_request_model.dart';
import 'package:calorie_ai/models/profile_sync_snapshot.dart';
import 'package:calorie_ai/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OnboardingRequestModel.fromUser maps live user data', () {
    final user = UserModel()
      ..age = 25
      ..gender = 'Male'
      ..heightCm = 170
      ..weightKg = 70
      ..goal = GoalType.loseWeight
      ..manualGoalWeightKg = 65
      ..targetDate = DateTime(2026, 9, 23)
      ..activityLevel = ActivityLevel.moderatelyActive
      ..healthConcerns = [
        const HealthConcern(
          category: 'Diabetes',
          description: 'Type 2, controlled with diet',
          duration: '1-6 months',
          severity: 'Mild',
          medication: 'Yes',
        ),
      ];

    final request = OnboardingRequestModel.fromUser(user);
    final json = request.toJson();

    expect(json['personalDetails'], {
      'age': 25,
      'gender': 'Male',
      'heightCm': 170,
      'weight': 70,
      'weightUnit': 'kg',
    });
    expect(json['goal'], 'loseWeight');
    expect(json['activityLevel'], 'moderatelyActive');
    expect(json['healthProblems'], [
      {
        'category': 'diabetes',
        'description': 'Type 2, controlled with diet',
        'duration': 'oneToSixMonths',
        'severity': 'mild',
        'medication': 'yes',
      },
    ]);
    expect(json.containsKey('healthProblem'), isFalse);
  });

  test('OnboardingRequestModel.fromUser maps multiple health concerns', () {
    final user = UserModel()
      ..age = 45
      ..gender = 'Male'
      ..heightCm = 175
      ..weightKg = 82
      ..goal = GoalType.maintainWeight
      ..targetDate = DateTime(2026, 6, 30)
      ..activityLevel = ActivityLevel.lightlyActive
      ..healthConcerns = [
        const HealthConcern(
          category: 'High Cholesterol',
          description: 'Borderline high LDL',
          duration: '1-6 months',
          severity: 'Moderate',
          medication: 'No',
        ),
        const HealthConcern(
          category: 'Stress / Anxiety',
          description: 'Work-related, affecting sleep',
          duration: '1-4 weeks',
          severity: 'Mild',
          medication: 'No',
        ),
      ];

    final json = OnboardingRequestModel.fromUser(user).toJson();

    expect(json['healthProblems'], [
      {
        'category': 'highCholesterol',
        'description': 'Borderline high LDL',
        'duration': 'oneToSixMonths',
        'severity': 'moderate',
        'medication': 'no',
      },
      {
        'category': 'stress',
        'description': 'Work-related, affecting sleep',
        'duration': 'oneToFourWeeks',
        'severity': 'mild',
        'medication': 'no',
      },
    ]);
    expect(json.containsKey('healthProblem'), isFalse);
  });

  test('OnboardingRequestModel.fromUser sends empty healthProblems for none', () {
    final user = UserModel()
      ..age = 30
      ..gender = 'Female'
      ..heightCm = 165
      ..weightKg = 60
      ..goal = GoalType.maintainWeight
      ..targetDate = DateTime(2026, 12, 31)
      ..activityLevel = ActivityLevel.sedentary
      ..healthConcerns = [HealthConcern.none()];

    final json = OnboardingRequestModel.fromUser(user).toJson();

    expect(json['goal'], 'maintainWeight');
    expect(json['healthProblems'], isEmpty);
    expect(json.containsKey('healthProblem'), isFalse);
  });

  test('OnboardingRequestModel.fromUser maps each goal to backend value', () {
    const mappings = {
      GoalType.loseWeight: 'loseWeight',
      GoalType.gainWeight: 'gainWeight',
      GoalType.maintainWeight: 'maintainWeight',
    };

    for (final entry in mappings.entries) {
      final user = UserModel()
        ..age = 30
        ..gender = 'Female'
        ..heightCm = 165
        ..weightKg = 60
        ..goal = entry.key
        ..targetDate = DateTime(2026, 12, 31)
        ..activityLevel = ActivityLevel.sedentary
        ..healthConcerns = [HealthConcern.none()];

      final json = OnboardingRequestModel.fromUser(user).toJson();
      expect(json['goal'], entry.value);
      expect(json['healthProblems'], isEmpty);
    }
  });

  test('OnboardingPatchModel sends partial personal details for weight', () {
    final user = UserModel()..weightKg = 68;

    final json = OnboardingPatchModel.weightOnly(user).toJson();

    expect(json, {
      'personalDetails': {
        'weight': 68,
        'weightUnit': 'kg',
      },
    });
  });

  test('OnboardingPatchModel sends goal and activity level together', () {
    final user = UserModel()
      ..goal = GoalType.maintainWeight
      ..activityLevel = ActivityLevel.veryActive;

    final json = OnboardingPatchModel.goalAndActivity(user).toJson();

    expect(json, {
      'goal': 'maintainWeight',
      'activityLevel': 'veryActive',
    });
  });

  test('OnboardingPatchModel sends health concerns patch payload', () {
    final json = OnboardingPatchModel.healthConcerns([
      const HealthConcern(
        category: 'Diabetes',
        description: 'Type 2',
        duration: '1-6 months',
        severity: 'Mild',
        medication: 'No',
      ),
    ]).toJson();

    expect(json['healthProblems'], [
      {
        'category': 'diabetes',
        'description': 'Type 2',
        'duration': 'oneToSixMonths',
        'severity': 'mild',
        'medication': 'no',
      },
    ]);
    expect(json.containsKey('healthProblem'), isFalse);
  });

  test('OnboardingPatchModel sends empty healthProblems when none selected', () {
    final json = OnboardingPatchModel.healthConcerns([
      HealthConcern.none(),
    ]).toJson();

    expect(json['healthProblems'], isEmpty);
  });

  test('OnboardingPatchModel.profileDiff sends personal and activity together', () {
    final user = UserModel()
      ..age = 25
      ..gender = 'Male'
      ..heightCm = 170
      ..weightKg = 68
      ..goal = GoalType.loseWeight
      ..activityLevel = ActivityLevel.veryActive;
    final baseline = ProfileSyncSnapshot.fromUser(
      UserModel()
        ..age = 25
        ..gender = 'Male'
        ..heightCm = 170
        ..weightKg = 70
        ..goal = GoalType.loseWeight
        ..activityLevel = ActivityLevel.moderatelyActive,
    );

    final json = OnboardingPatchModel.profileDiff(user, baseline).toJson();

    expect(json, {
      'personalDetails': {
        'weight': 68,
        'weightUnit': 'kg',
      },
      'activityLevel': 'veryActive',
    });
  });

  test('OnboardingPatchModel.profileDiff is empty when nothing changed', () {
    final user = UserModel()
      ..age = 25
      ..gender = 'Male'
      ..heightCm = 170
      ..weightKg = 70
      ..goal = GoalType.loseWeight
      ..activityLevel = ActivityLevel.moderatelyActive;
    final baseline = ProfileSyncSnapshot.fromUser(user);

    expect(OnboardingPatchModel.profileDiff(user, baseline).isEmpty, isTrue);
  });

  test('OnboardingPatchModel.personalDetailsDiff sends only changed fields', () {
    final user = UserModel()
      ..age = 25
      ..gender = 'Male'
      ..heightCm = 170
      ..weightKg = 68
      ..goal = GoalType.loseWeight
      ..activityLevel = ActivityLevel.moderatelyActive;
    final baseline = ProfileSyncSnapshot.fromUser(
      UserModel()
        ..age = 25
        ..gender = 'Male'
        ..heightCm = 170
        ..weightKg = 70
        ..goal = GoalType.loseWeight
        ..activityLevel = ActivityLevel.moderatelyActive,
    );

    final json =
        OnboardingPatchModel.personalDetailsDiff(user, baseline).toJson();

    expect(json, {
      'personalDetails': {
        'weight': 68,
        'weightUnit': 'kg',
      },
    });
  });

  test('OnboardingPatchModel.goalProfileDiff sends goal weight changes', () {
    final user = UserModel()
      ..goal = GoalType.loseWeight
      ..manualGoalWeightKg = 62
      ..targetDate = DateTime(2026, 9, 23);
    final baseline = ProfileSyncSnapshot.fromUser(
      UserModel()
        ..goal = GoalType.loseWeight
        ..manualGoalWeightKg = 65
        ..targetDate = DateTime(2026, 6, 30),
    );

    final json = OnboardingPatchModel.goalProfileDiff(user, baseline).toJson();

    expect(json['goalWeight'], 62);
    expect(json['goalWeightUnit'], 'kg');
    expect(json['targetDate'], '2026-09-23');
    expect(json.containsKey('goal'), isFalse);
  });

  test('OnboardingPatchModel.goalDiff skips unchanged goal', () {
    final user = UserModel()
      ..goal = GoalType.maintainWeight
      ..activityLevel = ActivityLevel.sedentary;
    final baseline = ProfileSyncSnapshot.fromUser(user);

    expect(
      OnboardingPatchModel.goalDiff(
        GoalType.maintainWeight,
        baseline,
      ).toJson(),
      isEmpty,
    );
  });

  test('OnboardingPatchModel.healthConcernsDiff skips unchanged concerns', () {
    const concerns = [
      HealthConcern(
        category: 'Diabetes',
        description: 'Type 2',
        duration: '1-6 months',
        severity: 'Mild',
        medication: 'No',
      ),
    ];
    final user = UserModel()
      ..goal = GoalType.loseWeight
      ..activityLevel = ActivityLevel.moderatelyActive
      ..healthConcerns = concerns;
    final baseline = ProfileSyncSnapshot.fromUser(user);

    expect(
      OnboardingPatchModel.healthConcernsDiff(concerns, baseline).toJson(),
      isEmpty,
    );
  });
}
