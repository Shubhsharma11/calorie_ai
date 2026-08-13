enum ProblemCategory {
  foodSearch('Food Search', 'food_search'),
  mealTracking('Meal Tracking', 'meal_tracking'),
  waterTracking('Water Tracking', 'water_tracking'),
  weightAndGoals('Weight & Goals', 'weight_and_goals'),
  notifications('Notifications', 'notifications'),
  loginAccount('Login / Account', 'login_account'),
  appCrash('App Crash', 'app_crash'),
  other('Other', 'other');

  const ProblemCategory(this.label, this.apiValue);

  final String label;
  final String apiValue;
}

class AppDeviceInfo {
  const AppDeviceInfo({
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.osVersion,
    required this.deviceModel,
  });

  final String appVersion;
  final String buildNumber;
  final String platform;
  final String osVersion;
  final String deviceModel;

  String get footerLabel {
    final version = appVersion.trim();
    final build = buildNumber.trim();
    if (version.isEmpty) return 'FitBuddy AI';
    if (build.isEmpty) return 'FitBuddy AI • v$version';
    return 'FitBuddy AI • v$version (Build $build)';
  }

  Map<String, String> toApiFields() => {
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'platform': platform,
        'osVersion': osVersion,
        'deviceModel': deviceModel,
      };
}
