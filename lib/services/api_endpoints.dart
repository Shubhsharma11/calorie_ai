abstract final class ApiEndpoints {

  
    static const String baseUrl = 'https://fitbuddyai.srhsoftwares.com';

  /// Public S3 host for uploaded avatars (`avatars/<file>`).
  static const String s3PublicBaseUrl =
      'https://fitbuddyai.s3.ap-south-1.amazonaws.com';


// static const String baseUrl = 'https://pdt-state-secretary-manchester.trycloudflare.com';



  static const String apiVersion = '/api/v1';
  static const String googleAuth = '$apiVersion/auth/google';
  static const String appleAuth = '$apiVersion/auth/apple';
  static const String phoneAuth = '$apiVersion/auth/phone';
  static const String logout = '$apiVersion/auth/logout';
  static const String authMe = '$apiVersion/auth/me';
  static const String authMeAvatar = '$apiVersion/auth/me/avatar';
  static const String deleteAccount = '$apiVersion/auth/account';
  static const String fcmToken = '$apiVersion/auth/fcm-token';
  static const String notifications = '$apiVersion/notifications';
  static const String notificationsUnreadCount =
      '$apiVersion/notifications/unread-count';
  static const String notificationsReadAll =
      '$apiVersion/notifications/read-all';
  static const String onboarding = '$apiVersion/onboarding';
  static const String nutritionPlan = '$apiVersion/nutrition/plan';
  static const String meals = '$apiVersion/meals';
  static const String mealsCustom = '$apiVersion/meals/custom';
  static const String myMeals = '$apiVersion/my-meals';
  static const String mealsStreak = '$apiVersion/meals/streak';
  static const String weight = '$apiVersion/weight';
  static const String water = '$apiVersion/water';
  static const String myFoods = '$apiVersion/my-foods';
  static const String favouriteMeals = '$apiVersion/favourite-meals';
  static const String searchFoods = '$apiVersion/search/foods';       
  static const String supportReports = '$apiVersion/support/reports';
  static const String uploadsImage = '$apiVersion/uploads/image';




  static String url(String path) => '$baseUrl$path';

  /// `GET /api/v1/search/foods?search=apple&page=1&limit=20`
  static String searchFoodsWithQuery({
    required String search,
    int page = 1,
    int limit = 20,
  }) {
    final params = <String, String>{
      'search': search.trim(),
      'page': '$page',
      'limit': '$limit',
    };
    final query = params.entries
        .map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');
    return '$searchFoods?$query';
  }
  static String mealsWithQuery({
    DateTime? date,
    String? period,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    final params = <String, String>{};
    if (date != null) {
      params['date'] =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    }
    if (period != null && period.isNotEmpty) params['period'] = period;
    if (fromDate != null) {
      params['from_date'] =
          '${fromDate.year}-${fromDate.month.toString().padLeft(2, '0')}-'
          '${fromDate.day.toString().padLeft(2, '0')}';
    }
    if (toDate != null) {
      params['to_date'] =
          '${toDate.year}-${toDate.month.toString().padLeft(2, '0')}-'
          '${toDate.day.toString().padLeft(2, '0')}';
    }
    if (params.isEmpty) return meals;

    final query = params.entries
        .map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');
    return '$meals?$query';
  }

  static String mealById(String mealId) =>
      '$meals/${Uri.encodeComponent(mealId)}';

  static String myFoodById(String myFoodId) =>
      '$myFoods/${Uri.encodeComponent(myFoodId)}';

  static String myFoodLog(String myFoodId) =>
      '$myFoods/${Uri.encodeComponent(myFoodId)}/log';

  static String favouriteMealById(String favouriteMealId) =>
      '$favouriteMeals/${Uri.encodeComponent(favouriteMealId)}';

  static String favouriteMealLog(String favouriteMealId) =>
      '$favouriteMeals/${Uri.encodeComponent(favouriteMealId)}/log';

  static String myMealById(String myMealId) =>
      '$myMeals/${Uri.encodeComponent(myMealId)}';

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
  static String get appleAuthUrl => url(appleAuth);
  static String get phoneAuthUrl => url(phoneAuth);
  static String get logoutUrl => url(logout);
  static String get authMeUrl => url(authMe);
  static String get authMeAvatarUrl => url(authMeAvatar);
  static String get deleteAccountUrl => url(deleteAccount);
  static String get fcmTokenUrl => url(fcmToken);
  static String get notificationsUrl => url(notifications);
  static String get notificationsUnreadCountUrl =>
      url(notificationsUnreadCount);
  static String get notificationsReadAllUrl => url(notificationsReadAll);

  static String notificationsWithQuery({
    int? page,
    int? limit,
    bool? unreadOnly,
  }) {
    final params = <String, String>{};
    if (page != null) params['page'] = '$page';
    if (limit != null) params['limit'] = '$limit';
    if (unreadOnly != null) params['unreadOnly'] = '$unreadOnly';
    if (params.isEmpty) return notifications;

    final query = params.entries
        .map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');
    return '$notifications?$query';
  }

  static String notificationById(String notificationId) =>
      '$notifications/${Uri.encodeComponent(notificationId)}';

  static String notificationRead(String notificationId) =>
      '${notificationById(notificationId)}/read';

  static String notificationReadUrl(String notificationId) =>
      url(notificationRead(notificationId));

  static String notificationByIdUrl(String notificationId) =>
      url(notificationById(notificationId));

  static String get onboardingUrl => url(onboarding);
  static String get nutritionPlanUrl => url(nutritionPlan);
  static String get mealsUrl => url(meals);
  static String get mealsCustomUrl => url(mealsCustom);
  static String get myMealsUrl => url(myMeals);
  static String mealsByIdUrl(String mealId) => url(mealById(mealId));
  static String get mealsStreakUrl => url(mealsStreak);
  static String get weightUrl => url(weight);              
  static String weightByIdUrl(String weightId) => url(weightById(weightId));
  static String get waterUrl => url(water);
  static String waterByIdUrl(String waterId) => url(waterById(waterId));
  static String get myFoodsUrl => url(myFoods);
  static String myFoodByIdUrl(String myFoodId) => url(myFoodById(myFoodId));
  static String myFoodLogUrl(String myFoodId) => url(myFoodLog(myFoodId));
  static String get favouriteMealsUrl => url(favouriteMeals);
  static String favouriteMealByIdUrl(String favouriteMealId) =>
      url(favouriteMealById(favouriteMealId));
  static String favouriteMealLogUrl(String favouriteMealId) =>
      url(favouriteMealLog(favouriteMealId));
  static String myMealByIdUrl(String myMealId) => url(myMealById(myMealId));
  static String get searchFoodsUrl => url(searchFoods);
  static String get supportReportsUrl => url(supportReports);
  static String get uploadsImageUrl => url(uploadsImage);

  static const String openFoodFactsBaseUrl = 'https://world.openfoodfacts.org';

  static String openFoodFactsProduct(String barcode) =>
      '/api/v2/product/$barcode.json';
}
