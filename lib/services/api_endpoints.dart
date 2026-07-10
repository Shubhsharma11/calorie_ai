abstract final class ApiEndpoints {
  static const String baseUrl =
      'https://calorie-ai-uzq1.onrender.com/';
 

  static const String apiVersion = '/api/v1';
  static const String googleAuth = '$apiVersion/auth/google';
  static const String logout = '$apiVersion/auth/logout';
  static const String deleteAccount = '$apiVersion/auth/account';
  static const String fcmToken = '$apiVersion/auth/fcm-token';
  static const String onboarding = '$apiVersion/onboarding';
  static const String nutritionPlan = '$apiVersion/nutrition/plan';
  static const String meals = '$apiVersion/meals';
  static const String mealsCustom = '$apiVersion/meals/custom';
  static const String mealsStreak = '$apiVersion/meals/streak';
  static const String weight = '$apiVersion/weight';
  static const String water = '$apiVersion/water';



  static String url(String path) => '$baseUrl$path';

  static String mealsWithQuery({DateTime? date}) {
    if (date == null) return meals;
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return '$meals?date=$key';
  }

  static String mealById(String mealId) => '$meals/$mealId';

  static String weightById(String weightId) => '$weight/$weightId';

  static String waterById(String waterId) => '$water/$waterId';

  static String waterWithQuery({
    DateTime? date,
    int? page,
    int? limit,
  }) {
    final params = <String, String>{};
    if (date != null) {
      params['date'] =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    }
    if (page != null) params['page'] = '$page';
    if (limit != null) params['limit'] = '$limit';
    if (params.isEmpty) return water;

    final query = params.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('&');
    return '$water?$query';
  }

  static String weightWithQuery({
    DateTime? date,
    String? period,
    DateTime? fromDate,
    DateTime? toDate,
    int? page,
    int? limit,
  }) {
    final params = <String, String>{};
    if (date != null) {
      params['date'] =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    }
    if (period != null && period.isNotEmpty) params['period'] = period;
    if (fromDate != null) {
      params['fromDate'] =
          '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-'
          '${fromDate.day.toString().padLeft(2, '0')}';
    }
    if (toDate != null) {
      params['toDate'] =
          '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-'
          '${toDate.day.toString().padLeft(2, '0')}';
    }
    if (page != null) params['page'] = '$page';
    if (limit != null) params['limit'] = '$limit';
    if (params.isEmpty) return weight;

    final query = params.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('&');
    return '$weight?$query';
  }

  static String get googleAuthUrl => url(googleAuth);
  static String get logoutUrl => url(logout);
  static String get deleteAccountUrl => url(deleteAccount);
  static String get fcmTokenUrl => url(fcmToken);
  static String get onboardingUrl => url(onboarding);
  static String get nutritionPlanUrl => url(nutritionPlan);
  static String get mealsUrl => url(meals);
  static String get mealsCustomUrl => url(mealsCustom);
  static String mealsByIdUrl(String mealId) => url(mealById(mealId));
  static String get mealsStreakUrl => url(mealsStreak);
  static String get weightUrl => url(weight);
  static String weightByIdUrl(String weightId) => url(weightById(weightId));
  static String get waterUrl => url(water);
  static String waterByIdUrl(String waterId) => url(waterById(waterId));

  static const String openFoodFactsBaseUrl = 'https://world.openfoodfacts.org';

  static String openFoodFactsProduct(String barcode) =>
      '/api/v2/product/$barcode.json';
}
