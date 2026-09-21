import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// TEMPORARY — HOME_STUCK_DEBUG — remove this file after investigation.
///
/// Verifies silent 401/403 → clearInvalidSession → shellReady=false stuck Home.
/// Safe: never logs tokens, JWTs, PII, or request bodies.
abstract final class HomeStuckDebug {
  static const tag = 'HOME_STUCK_DEBUG';

  /// Always print (debug/profile) so device Logcat captures the hypothesis.
  static void log(String event, [Map<String, Object?> fields = const {}]) {
    final ts = DateTime.now().toIso8601String();
    final buf = StringBuffer('[$tag] $ts $event');
    if (fields.isNotEmpty) {
      buf.write(' | ');
      buf.write(
        fields.entries.map((e) => '${e.key}=${e.value}').join(' '),
      );
    }
    // ignore: avoid_print — temporary investigation; must survive debugPrint filters
    print(buf.toString());
  }

  static void logHttpStatus({
    required String method,
    required String path,
    required int statusCode,
  }) {
    if (statusCode != 401 && statusCode != 403 && statusCode != 429) return;
    log(
      'HTTP_STATUS',
      {
        'method': method,
        'endpoint': path,
        'status': statusCode,
      },
    );
  }

  static void logTimeout({
    required String method,
    required String path,
  }) {
    log('HTTP_TIMEOUT', {'method': method, 'endpoint': path});
  }

  static Map<String, Object?> snapshotAuthShell({
    required bool isLoggedIn,
    required bool shellReady,
    required int userSessionEpoch,
    required int homeHydrateGeneration,
  }) {
    return {
      'isLoggedIn': isLoggedIn,
      'shellReady': shellReady,
      'userSessionEpoch': userSessionEpoch,
      'homeHydrateGen': homeHydrateGeneration,
      'route': Get.currentRoute,
    };
  }

  static void logNavigation(String phase) {
    log(
      'NAVIGATION',
      {
        'phase': phase,
        'currentRoute': Get.currentRoute,
        'previousRoute': Get.previousRoute,
      },
    );
  }
}

/// TEMPORARY — HOME_STUCK_DEBUG — remove after investigation.
class HomeStuckNavObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    HomeStuckDebug.log(
      'NAV_PUSH',
      {
        'route': route.settings.name ?? route.runtimeType.toString(),
        'previous': previousRoute?.settings.name ??
            previousRoute?.runtimeType.toString() ??
            'none',
      },
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    HomeStuckDebug.log(
      'NAV_REPLACE',
      {
        'route': newRoute?.settings.name ?? newRoute?.runtimeType.toString(),
        'old': oldRoute?.settings.name ?? oldRoute?.runtimeType.toString(),
      },
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    HomeStuckDebug.log(
      'NAV_POP',
      {
        'popped': route.settings.name ?? route.runtimeType.toString(),
        'now': previousRoute?.settings.name ??
            previousRoute?.runtimeType.toString() ??
            'none',
      },
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    HomeStuckDebug.log(
      'NAV_REMOVE',
      {
        'removed': route.settings.name ?? route.runtimeType.toString(),
        'now': previousRoute?.settings.name ??
            previousRoute?.runtimeType.toString() ??
            'none',
      },
    );
  }
}
