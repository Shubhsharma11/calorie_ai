/// Meal-style plan the user is interested in (onboarding after medications).
enum DietPlanInterest { heartHealthy, highProtein, healthyNatural }

extension DietPlanInterestX on DietPlanInterest {
  String get title => switch (this) {
    DietPlanInterest.heartHealthy => 'Heart-Healthy',
    DietPlanInterest.highProtein => 'High-Protein',
    DietPlanInterest.healthyNatural => 'Healthy & Natural',
  };

  String get apiValue => switch (this) {
    DietPlanInterest.heartHealthy => 'heartHealthy',
    DietPlanInterest.highProtein => 'highProtein',
    DietPlanInterest.healthyNatural => 'healthyNatural',
  };

  static DietPlanInterest? tryParse(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[\s\-_&]+'),
      '',
    );
    return switch (normalized) {
      'hearthealthy' || 'heart' => DietPlanInterest.heartHealthy,
      'highprotein' || 'protein' => DietPlanInterest.highProtein,
      'healthynatural' ||
      'healthyandnatural' ||
      'natural' => DietPlanInterest.healthyNatural,
      _ => null,
    };
  }
}
