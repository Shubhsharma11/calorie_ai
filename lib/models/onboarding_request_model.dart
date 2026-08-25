import 'activity_level.dart';
import 'goal_type.dart';
import 'health_concern.dart';
import 'health_problem_api_mapper.dart';
import 'profile_sync_snapshot.dart';
import 'user_model.dart';

class OnboardingPersonalDetails {
  const OnboardingPersonalDetails({
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weight,
    required this.weightUnit,
  });

  final int age;
  final String gender;
  final int heightCm;
  final num weight;
  final String weightUnit;

  Map<String, dynamic> toJson() => {
    'age': age,
    'gender': gender,
    'heightCm': heightCm,
    'weight': weight,
    'weightUnit': weightUnit,
  };
}

class OnboardingGoal {
  const OnboardingGoal({
    required this.type,
    required this.isGoalWeightManual,
    required this.targetDate,
    required this.goalWeight,
    required this.goalWeightUnit,
    required this.goalTimeline,
    this.goalTimelineCustomDate,
  });

  final String type;
  final bool isGoalWeightManual;
  final String targetDate;
  final num goalWeight;
  final String goalWeightUnit;
  final String goalTimeline;
  final String? goalTimelineCustomDate;




  Map<String, dynamic> toJson() => {
    'type': type,
    'isGoalWeightManual': isGoalWeightManual,
    'targetDate': targetDate,
    'goalWeight': goalWeight,
    'goalWeightUnit': goalWeightUnit,
    'goalTimeline': goalTimeline,
    if (goalTimelineCustomDate != null)
      'goalTimelineCustomDate': goalTimelineCustomDate,
  };
}

class OnboardingHealthProblem {
  const OnboardingHealthProblem({
    required this.category,
    required this.description,
    this.duration,
    this.severity,
    this.medication,
  });

  final String category;
  final String description;
  final String? duration;
  final String? severity;
  final String? medication;

  factory OnboardingHealthProblem.fromConcern(HealthConcern concern) {
    if (concern.isNone) {
      throw const OnboardingPayloadException(
        'Cannot map a "none" health concern to the API.',
      );
    }

    return OnboardingHealthProblem(
      category: HealthProblemApiMapper.category(concern.category),
      description: concern.description,
      duration: HealthProblemApiMapper.duration(concern.duration),
      severity: HealthProblemApiMapper.severity(concern.severity),
      medication: HealthProblemApiMapper.medication(concern.medication),
    );
  }



  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'category': category,
      'description': description,
    };
    if (duration != null) json['duration'] = duration;
    if (severity != null) json['severity'] = severity;
    if (medication != null) json['medication'] = medication;
    return json;
  }
}

class OnboardingRequestModel {
  const OnboardingRequestModel({
    required this.personalDetails,
    required this.activityLevel,
    required this.goalType,
    required this.healthProblems,
    required this.goalWeight,
    required this.goalWeightUnit,
    required this.goalTimeline,
    this.goalTimelineCustomDate,
    this.startWeight,
    this.startWeightUnit,
  });

  final OnboardingPersonalDetails personalDetails;
  final String activityLevel;
  final List<OnboardingHealthProblem> healthProblems;
  final String goalType;
  final num goalWeight;
  final String goalWeightUnit;
  final String goalTimeline;
  final String? goalTimelineCustomDate;
  final num? startWeight;
  final String? startWeightUnit;

  OnboardingHealthProblem? get primaryHealthProblem =>
      healthProblems.isEmpty ? null : healthProblems.first;

  Map<String, dynamic> toJson() {
    return {
      'personalDetails': personalDetails.toJson(),
      'goal': goalType,
      'activityLevel': activityLevel,
      'healthProblems': healthProblems.map((problem) => problem.toJson()).toList(),
      'goalWeight': goalWeight,
      'goalWeightUnit': goalWeightUnit,
      'goalTimeline': goalTimeline,
      if (goalTimelineCustomDate != null)
        'goalTimelineCustomDate': goalTimelineCustomDate,
      if (startWeight != null) 'startWeight': startWeight,
      if (startWeightUnit != null) 'startWeightUnit': startWeightUnit,
    };
  }

  static List<HealthConcern> _apiConcerns(UserModel user) {
    return user.healthConcerns.where((concern) => !concern.isNone).toList();
  }

  /// Builds the API payload from live [UserModel] data — no hardcoded demo values.
  factory OnboardingRequestModel.fromUser(UserModel user) {
    final goal = user.goal;
    if (goal == null) {
      throw const OnboardingPayloadException('Fitness goal is not set.');
    }

    final concerns = _apiConcerns(user); 

    final activity = user.activityLevel;
    if (activity == null) {
      throw const OnboardingPayloadException('Activity level is not set.');
    } 

    final age = user.age;
    final gender = user.gender;
    final heightCm = user.heightCm;
    final weightKg = user.weightKg;
    if (age == null ||
        gender == null ||
        gender.trim().isEmpty ||
        heightCm == null ||
        weightKg == null) {
      throw const OnboardingPayloadException(
        'Personal details are incomplete.',
      );
    }

    return OnboardingRequestModel(
      personalDetails: OnboardingPersonalDetails(
        age: age,
        gender: gender,
        heightCm: heightCm,
        weight: weightKg,
        weightUnit: 'kg',
      ),
      goalType: goal.apiValue,
      activityLevel: activity.name,
      healthProblems: concerns
          .map(OnboardingHealthProblem.fromConcern)
          .toList(growable: false),
      goalWeight: _roundGoalWeight(user.goalWeightKg),
      goalWeightUnit: 'kg',
      goalTimeline: user.goalTimeline,
      goalTimelineCustomDate: user.goalTimelineCustomDate,
      startWeight: user.goalStartWeightKg != null
          ? _roundGoalWeight(user.goalStartWeightKg!)
          : _roundGoalWeight(weightKg.toDouble()),
      startWeightUnit: 'kg',
    );
  }

  static num _roundGoalWeight(double kg) {
    final rounded = double.parse(kg.toStringAsFixed(1));
    return rounded == rounded.roundToDouble() ? rounded.round() : rounded;
  }
}

class OnboardingPatchModel {
  const OnboardingPatchModel._({
    this.personalDetails,
    this.goal,
    this.activityLevel,
    this.healthProblems,
    this.extraFields,
  });

  final Map<String, dynamic>? personalDetails;
  final String? goal;
  final String? activityLevel;
  final List<OnboardingHealthProblem>? healthProblems;
  final Map<String, dynamic>? extraFields;

  bool get isEmpty => toJson().isEmpty;

  /// True when this patch changes goal type / target weight / timeline.
  bool get touchesGoalFields {
    if (goal != null) return true;
    final extras = extraFields;
    if (extras == null || extras.isEmpty) return false;
    const goalKeys = {
      'goalWeight',
      'targetWeight',
      'goal_weight',
      'target_weight',
      'isGoalWeightManual',
      'is_goal_weight_manual',
      'targetDate',
      'target_date',
      'goalTimeline',
      'goal_timeline',
      'goalTimelineCustomDate',
      'startWeight',
      'goalStartWeight',
    };
    return extras.keys.any(goalKeys.contains);
  }

  /// True when calories/macros may need a new nutrition plan after this patch.
  bool get shouldRefreshNutritionPlan {
    if (touchesGoalFields) return true;
    if (activityLevel != null) return true;
    final personal = personalDetails;
    if (personal == null || personal.isEmpty) return false;
    const planKeys = {
      'age',
      'gender',
      'heightCm',
      'height_cm',
      'weight',
      'weightKg',
      'weight_kg',
    };
    return personal.keys.any(planKeys.contains);
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    if (personalDetails != null && personalDetails!.isNotEmpty) {
      json['personalDetails'] = personalDetails;
    }
    if (goal != null) {
      json['goal'] = goal;
    }
    if (activityLevel != null) {
      json['activityLevel'] = activityLevel;
    }
    if (healthProblems != null) {
      json['healthProblems'] =
          healthProblems!.map((problem) => problem.toJson()).toList();
    }
    if (extraFields != null && extraFields!.isNotEmpty) {
      json.addAll(extraFields!);
    }

    return json;
  }

  OnboardingPatchModel merge(OnboardingPatchModel other) {
    final mergedPersonal = <String, dynamic>{};
    if (personalDetails != null) mergedPersonal.addAll(personalDetails!);
    if (other.personalDetails != null) {
      mergedPersonal.addAll(other.personalDetails!);
    }

    final mergedExtras = <String, dynamic>{};
    if (extraFields != null) mergedExtras.addAll(extraFields!);
    if (other.extraFields != null) mergedExtras.addAll(other.extraFields!);

    return OnboardingPatchModel._(
      personalDetails: mergedPersonal.isEmpty ? null : mergedPersonal,
      goal: other.goal ?? goal,
      activityLevel: other.activityLevel ?? activityLevel,
      healthProblems: other.healthProblems ?? healthProblems,
      extraFields: mergedExtras.isEmpty ? null : mergedExtras,
    );
  }

  factory OnboardingPatchModel.personalDetails(UserModel user) {
    final age = user.age;
    final gender = user.gender;
    final heightCm = user.heightCm;
    final weightKg = user.weightKg;
    if (age == null ||
        gender == null ||
        gender.trim().isEmpty ||
        heightCm == null ||
        weightKg == null) {
      return const OnboardingPatchModel._();
    }

    return OnboardingPatchModel._(
      personalDetails: OnboardingPersonalDetails(
        age: age,
        gender: gender,
        heightCm: heightCm,
        weight: weightKg,
        weightUnit: 'kg',
      ).toJson(),
    );
  }

  factory OnboardingPatchModel.personalDetailsDiff(
    UserModel user,
    ProfileSyncSnapshot baseline,
  ) {
    final details = <String, dynamic>{};

    if (user.age != baseline.age) {
      details['age'] = user.age;
    }
    if (user.gender != baseline.gender) {
      details['gender'] = user.gender;
    }
    if (user.heightCm != baseline.heightCm) {
      details['heightCm'] = user.heightCm;
    }
    if (user.weightKg != baseline.weightKg) {
      details['weight'] = user.weightKg;
      details['weightUnit'] = 'kg';
    }

    return OnboardingPatchModel._(
      personalDetails: details.isEmpty ? null : details,
    );
  }

  factory OnboardingPatchModel.weightOnly(UserModel user) {
    return OnboardingPatchModel._(
      personalDetails: {
        'weight': user.weightKg,
        'weightUnit': 'kg',
      },
    );
  }

  factory OnboardingPatchModel.goalWeightOnly(
    double goalWeightKg, {
    String? goalTimeline,
    String? goalTimelineCustomDate,
    double? startWeightKg,
    GoalType? goalType,
  }) {
    return OnboardingPatchModel._(
      goal: goalType?.apiValue,
      extraFields: {
        'goalWeight': goalWeightKg,
        'goalWeightUnit': 'kg',
        'isGoalWeightManual': true,
        if (startWeightKg != null) ...{
          'startWeight': startWeightKg,
          'startWeightUnit': 'kg',
        },
        if (goalTimeline != null && goalTimeline.isNotEmpty)
          'goalTimeline': goalTimeline,
        if (goalTimelineCustomDate != null && goalTimelineCustomDate.isNotEmpty)
          'goalTimelineCustomDate': goalTimelineCustomDate,
      },
    );
  }

  factory OnboardingPatchModel.goal(GoalType goal) {
    return OnboardingPatchModel._(goal: goal.apiValue);
  }

  factory OnboardingPatchModel.goalDiff(
    GoalType goal,
    ProfileSyncSnapshot baseline,
  ) {
    if (baseline.goal == goal) {
      return const OnboardingPatchModel._();
    }

    return OnboardingPatchModel._(goal: goal.apiValue);
  }

  factory OnboardingPatchModel.goalProfileDiff(
    UserModel user,
    ProfileSyncSnapshot baseline,
  ) {
    String? goal;
    if (user.goal != null && user.goal != baseline.goal) {
      goal = user.goal!.apiValue;
    }

    final extras = <String, dynamic>{};
    final goalWeightChanged =
        (user.goalWeightKg - baseline.goalWeightKg).abs() > 0.01;
    if (goalWeightChanged) {
      extras['goalWeight'] = user.goalWeightKg;
      extras['goalWeightUnit'] = 'kg';
    }
    // Always send startWeight when goal type or target changes so the API
    // owns the progress baseline (no local storage).
    if ((goal != null || goalWeightChanged) &&
        user.goalStartWeightKg != null) {
      extras['startWeight'] = user.goalStartWeightKg;
      extras['startWeightUnit'] = 'kg';
    }
    if (user.isGoalWeightManual != baseline.isGoalWeightManual) {
      extras['isGoalWeightManual'] = user.isGoalWeightManual;
    }
    if (!_isSameDate(user.targetDate, baseline.targetDate)) {
      extras['targetDate'] = _formatApiDate(user.targetDate);
      extras['goalTimeline'] = user.goalTimeline;
      final customDate = user.goalTimelineCustomDate;
      if (customDate != null) {
        extras['goalTimelineCustomDate'] = customDate;
      }
    } else if (goalWeightChanged || goal != null) {
      extras['goalTimeline'] = user.goalTimeline;
      final customDate = user.goalTimelineCustomDate;
      if (customDate != null) {
        extras['goalTimelineCustomDate'] = customDate;
      }
    }

    return OnboardingPatchModel._(
      goal: goal,
      extraFields: extras.isEmpty ? null : extras,
    );
  }

  static bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static String _formatApiDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  factory OnboardingPatchModel.activityLevel(ActivityLevel level) {
    return OnboardingPatchModel._(activityLevel: level.name);
  }

  factory OnboardingPatchModel.activityLevelDiff(
    ActivityLevel? level,
    ProfileSyncSnapshot baseline,
  ) {
    if (level == null || baseline.activityLevel == level) {
      return const OnboardingPatchModel._();
    }

    return OnboardingPatchModel._(activityLevel: level.name);
  }

  /// Personal information screen — sends only changed personal + activity fields
  /// in a single PATCH request.
  factory OnboardingPatchModel.profileDiff(
    UserModel user,
    ProfileSyncSnapshot baseline,
  ) {
    return OnboardingPatchModel.personalDetailsDiff(user, baseline).merge(
      OnboardingPatchModel.activityLevelDiff(user.activityLevel, baseline),
    );
  }

  factory OnboardingPatchModel.goalAndActivity(UserModel user) {
    return OnboardingPatchModel._(
      goal: user.goal?.apiValue,
      activityLevel: user.activityLevel?.name,
    );
  }

  factory OnboardingPatchModel.healthConcerns(List<HealthConcern> concerns) {
    final resolved = concerns.where((concern) => !concern.isNone).toList();

    return OnboardingPatchModel._(
      healthProblems: resolved
          .map(OnboardingHealthProblem.fromConcern)
          .toList(growable: false),
    );
  }

  factory OnboardingPatchModel.healthConcernsDiff(
    List<HealthConcern> concerns,
    ProfileSyncSnapshot baseline,
  ) {
    if (ProfileSyncSnapshot.healthConcernsEqual(
      concerns,
      baseline.healthConcerns,
    )) {
      return const OnboardingPatchModel._();
    }

    return OnboardingPatchModel.healthConcerns(concerns);
  }
}

class OnboardingPayloadException implements Exception {
  const OnboardingPayloadException(this.message);

  final String message;

  @override
  String toString() => message;
}
