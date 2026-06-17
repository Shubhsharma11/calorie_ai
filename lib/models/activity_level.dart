enum ActivityLevel {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
}

extension ActivityLevelLabel on ActivityLevel {
  String get title {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'Sedentary';
      case ActivityLevel.lightlyActive:
        return 'Lightly Active';
      case ActivityLevel.moderatelyActive:
        return 'Moderately Active';
      case ActivityLevel.veryActive:
        return 'Very Active';
    }
  }

  String get description {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'Little or no exercise. Desk job, minimal physical activity.';
      case ActivityLevel.lightlyActive:
        return 'Light exercise 1–3 days per week. Light walking, stretching, etc.';
      case ActivityLevel.moderatelyActive:
        return 'Moderate exercise 3–5 days per week. Brisk walking, cycling, gym, sports.';
      case ActivityLevel.veryActive:
        return 'Hard exercise 6–7 days per week. Intense training, heavy workouts.';
    }
  }

  String get imageAsset {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'assets/image/sofa.svg';
      case ActivityLevel.lightlyActive:
        return 'assets/image/exercising.svg';
      case ActivityLevel.moderatelyActive:
        return 'assets/image/bicycle.svg';
      case ActivityLevel.veryActive:
        return 'assets/image/weightlifting.svg';
    }
  }
}
