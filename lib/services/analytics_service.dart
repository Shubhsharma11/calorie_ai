import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/widgets.dart';

/// Central Firebase Analytics / Crashlytics / Performance helpers.
///
/// Automatic Analytics metrics (no custom events needed):
/// total users, DAU, session duration, retention (D1/D7/D30), drop-off.
/// Those appear once Analytics is enabled and screen views are logged.
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static final FirebaseCrashlytics crashlytics = FirebaseCrashlytics.instance;
  static final FirebasePerformance performance = FirebasePerformance.instance;

  static String? _currentScreen;
  static String? get currentScreen => _currentScreen;

  /// Navigator observers for screen_view + Crashlytics screen context.
  static List<NavigatorObserver> get navigatorObservers => [
        FirebaseAnalyticsObserver(
          analytics: analytics,
          nameExtractor: _screenNameFromRoute,
          routeFilter: (route) => route is PageRoute,
        ),
        _AnalyticsScreenObserver(),
      ];

  static String? _screenNameFromRoute(RouteSettings settings) {
    final name = settings.name;
    if (name == null || name.isEmpty || name == '/') return null;
    return name.startsWith('/') ? name.substring(1) : name;
  }

  // ─── Init / identity ─────────────────────────────────────────────────────

  static Future<void> initialize() async {
    await analytics.setAnalyticsCollectionEnabled(true);
    await crashlytics.setCrashlyticsCollectionEnabled(true);
    await performance.setPerformanceCollectionEnabled(true);
  }

  static Future<void> setUser({
    required String? userId,
    String? email,
    String? name,
    String? provider,
  }) async {
    final id = (userId == null || userId.isEmpty) ? null : userId;
    await analytics.setUserId(id: id);
    await crashlytics.setUserIdentifier(id ?? '');

    if (email != null && email.isNotEmpty) {
      await analytics.setUserProperty(name: 'email_domain', value: _emailDomain(email));
      await crashlytics.setCustomKey('user_email', email);
    }
    if (name != null && name.isNotEmpty) {
      await crashlytics.setCustomKey('user_name', name);
    }
    if (provider != null && provider.isNotEmpty) {
      await analytics.setUserProperty(name: 'auth_provider', value: provider);
      await crashlytics.setCustomKey('auth_provider', provider);
    }
    if (_currentScreen != null) {
      await crashlytics.setCustomKey('current_screen', _currentScreen!);
    }
  }

  static Future<void> clearUser() async {
    await analytics.setUserId(id: null);
    await crashlytics.setUserIdentifier('');
  }

  static String _emailDomain(String email) {
    final at = email.indexOf('@');
    if (at < 0 || at == email.length - 1) return 'unknown';
    return email.substring(at + 1).toLowerCase();
  }

  // ─── Screen tracking ─────────────────────────────────────────────────────

  static Future<void> logScreenView(String screenName) async {
    final cleaned = screenName.startsWith('/')
        ? screenName.substring(1)
        : screenName;
    if (cleaned.isEmpty) return;

    _currentScreen = cleaned;
    await analytics.logScreenView(screenName: cleaned);
    await crashlytics.setCustomKey('current_screen', cleaned);
  }

  // ─── Built-in / requested events ─────────────────────────────────────────

  static Future<void> logAppOpen() async {
    await analytics.logAppOpen();
  }

  static Future<void> logSignup({String? method}) async {
    await analytics.logEvent(
      name: 'signup',
      parameters: {
        if (method != null && method.isNotEmpty) 'method': method,
      },
    );
  }

  static Future<void> logLogin({String? method}) async {
    await analytics.logLogin(loginMethod: method);
  }

  static Future<void> logFoodSearch(String food) async {
    await analytics.logEvent(
      name: 'food_search',
      parameters: {
        'food_name': _truncate(food),
      },
    );
  }

  static Future<void> logMealAdded(String mealType) async {
    await analytics.logEvent(
      name: 'meal_added',
      parameters: {
        'meal_type': mealType,
      },
    );
  }

  static Future<void> logWaterLogged(int glasses) async {
    await analytics.logEvent(
      name: 'water_logged',
      parameters: {
        'glasses': glasses,
      },
    );
  }

  static Future<void> logWeightUpdated(double weight) async {
    await analytics.logEvent(
      name: 'weight_updated',
      parameters: {
        'weight': weight,
      },
    );
  }

  static Future<void> logWaterReminderCompleted({String? source}) async {
    await analytics.logEvent(
      name: 'water_reminder_completed',
      parameters: {
        if (source != null && source.isNotEmpty) 'source': source,
      },
    );
  }

  static Future<void> logGoalCompleted({
    required String goalType,
    Map<String, Object>? extra,
  }) async {
    await analytics.logEvent(
      name: 'goal_completed',
      parameters: {
        'goal_type': goalType,
        ...?extra,
      },
    );
  }

  /// Call this when an in-app purchase / subscription succeeds.
  static Future<void> logSubscriptionPurchased({
    String? planId,
    String? currency,
    double? price,
  }) async {
    await analytics.logEvent(
      name: 'subscription_purchased',
      parameters: {
        if (planId != null && planId.isNotEmpty) 'plan_id': planId,
        if (currency != null && currency.isNotEmpty) 'currency': currency,
        'price': ?price,
      },
    );
  }

  // ─── Crashlytics helpers ─────────────────────────────────────────────────

  static Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    await crashlytics.recordError(
      error,
      stackTrace,
      reason: reason,
      fatal: fatal,
      information: [
        if (_currentScreen != null) 'screen=$_currentScreen',
      ],
    );
  }

  static Future<void> log(String message) => crashlytics.log(message);

  // ─── Performance helpers ─────────────────────────────────────────────────

  static Trace newTrace(String name) => performance.newTrace(name);

  static HttpMetric newHttpMetric(String url, HttpMethod method) =>
      performance.newHttpMetric(url, method);

  static String _truncate(String value, [int max = 100]) {
    final trimmed = value.trim();
    if (trimmed.length <= max) return trimmed;
    return trimmed.substring(0, max);
  }
}

/// Keeps Crashlytics + custom screen_view in sync with navigator changes.
class _AnalyticsScreenObserver extends NavigatorObserver {
  Trace? _screenTrace;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onScreen(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _onScreen(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stopScreenTrace();
    if (previousRoute != null) _onScreen(previousRoute);
  }

  void _onScreen(Route<dynamic> route) {
    if (route is! PageRoute) return;
    final name = AnalyticsService._screenNameFromRoute(route.settings);
    if (name == null) return;

    _stopScreenTrace();
    _screenTrace = AnalyticsService.newTrace('screen_$name');
    _screenTrace!.start();

    // Fire-and-forget; observer callbacks are sync.
    AnalyticsService.logScreenView(name);
  }

  void _stopScreenTrace() {
    final trace = _screenTrace;
    _screenTrace = null;
    if (trace != null) {
      // ignore: discarded_futures
      trace.stop();
    }
  }
}
