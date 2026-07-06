import 'package:flutter/material.dart';

enum ExerciseCategory {
  cardio('Cardio'),
  strength('Strength & gym'),
  flexibility('Mind & body');

  const ExerciseCategory(this.label);

  final String label;
}

enum ExerciseIntensity {
  low('Low', 0.85),
  normal('Normal', 1.0),
  high('High', 1.15);

  const ExerciseIntensity(this.label, this.multiplier);

  final String label;
  final double multiplier;
}

enum ExerciseType {
  walking('Walking', 3.5, Icons.directions_walk_rounded, ExerciseCategory.cardio),
  running('Running', 9.8, Icons.directions_run_rounded, ExerciseCategory.cardio),
  cycling('Cycling', 7.5, Icons.directions_bike_rounded, ExerciseCategory.cardio),
  swimming('Swimming', 8.0, Icons.pool_rounded, ExerciseCategory.cardio),
  elliptical('Elliptical', 6.0, Icons.monitor_heart_outlined, ExerciseCategory.cardio),
  rowing('Rowing', 7.0, Icons.rowing_rounded, ExerciseCategory.cardio),
  gymLight(
    'Light weights',
    3.5,
    Icons.fitness_center_outlined,
    ExerciseCategory.strength,
  ),
  gymModerate(
    'Moderate weights',
    5.0,
    Icons.fitness_center_rounded,
    ExerciseCategory.strength,
  ),
  gymHeavy(
    'Heavy lifting',
    6.5,
    Icons.sports_gymnastics_rounded,
    ExerciseCategory.strength,
  ),
  gymHiit(
    'HIIT / Circuit',
    9.0,
    Icons.bolt_rounded,
    ExerciseCategory.strength,
  ),
  yoga('Yoga', 3.0, Icons.self_improvement_rounded, ExerciseCategory.flexibility);

  const ExerciseType(this.label, this.met, this.icon, this.category);

  final String label;
  final double met;
  final IconData icon;
  final ExerciseCategory category;

  String get intensityHint => switch (this) {
    gymLight => 'Machines, light dumbbells, high rest',
    gymModerate => 'Typical gym session, mixed exercises',
    gymHeavy => 'Compound lifts, low rest, high effort',
    gymHiit => 'Circuits, intervals, minimal rest',
    running => 'Steady or tempo pace',
    walking => 'Brisk walk',
    _ => 'Standard pace',
  };

  static List<ExerciseType> forCategory(ExerciseCategory category) =>
      values.where((type) => type.category == category).toList();

  static ExerciseType? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final type in values) {
      if (type.name == id) return type;
    }
    return null;
  }

  static ExerciseType? fromLabel(String label) {
    for (final type in values) {
      if (type.label == label) return type;
    }
    if (label == 'Gym') return ExerciseType.gymModerate;
    return null;
  }

  static int estimateCalories({
    required ExerciseType type,
    required double weightKg,
    required int durationMinutes,
    ExerciseIntensity intensity = ExerciseIntensity.normal,
  }) {
    if (durationMinutes <= 0 || weightKg <= 0) return 0;
    final met = type.met * intensity.multiplier;
    return (met * weightKg * (durationMinutes / 60)).round();
  }
}
