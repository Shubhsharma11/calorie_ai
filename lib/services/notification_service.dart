import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../controllers/user_controller.dart';
import '../models/notification_model.dart';
import '../models/notification_type.dart';
import '../repositories/notification_repository.dart';
import 'notification_api_service.dart';

/// Handles FCM, local notifications, token sync, and notification navigation.
class NotificationService {
  NotificationService._({
    NotificationRepository? repository,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _repository = repository ?? NotificationRepository(),
       _messagingOverride = messaging,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  static final NotificationService instance = NotificationService._();

  final NotificationRepository _repository;
  final FirebaseMessaging? _messagingOverride;
  String? _lastSyncedFcmToken;
  DateTime? _lastSyncedFcmAt;
  Future<void>? _syncTokenInFlight;
  static const Duration _fcmSyncCooldown = Duration(hours: 12);
  final FlutterLocalNotificationsPlugin _localNotifications;

  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;

  bool get isInitialized => _initialized;

  static const _androidLauncherIcon = '@mipmap/ic_launcher';

  bool _initialized = false;
  String? _currentToken;
  RemoteMessage? _pendingInitialMessage;
  NotificationModel? _pendingTapNotification;

  final Map<String, AndroidNotificationChannel> _androidChannels = {};

  Future<void> initialize() async {
    if (_initialized) return;

    await _initLocalNotifications();
    await _createAndroidNotificationChannels();
    await _requestPermissions();
    await _configureFirebaseMessaging();

    _currentToken = await _messaging.getToken();
    logFcmToken();

    _messaging.onTokenRefresh.listen(_handleTokenRefresh);
    _pendingInitialMessage = await _messaging.getInitialMessage();

    _initialized = true;
  }

  Future<String?> logFcmToken() async {
    final token = _currentToken ?? await _messaging.getToken();
    _currentToken = token;
    if (kDebugMode) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('FCM TOKEN: $token');
      debugPrint('═══════════════════════════════════════');
    }
    return token;
  }

  Future<void> handlePendingLaunchNavigation() async {
    if (_pendingInitialMessage != null) {
      final message = _pendingInitialMessage!;
      _pendingInitialMessage = null;
      await _navigateFromMessage(message);
      return;
    }

    if (_pendingTapNotification != null) {
      final notification = _pendingTapNotification!;
      _pendingTapNotification = null;
      await _navigateFromModel(notification);
    }
  }

  Future<void> syncTokenWithBackend({String? accessToken}) {
    if (_syncTokenInFlight != null) {
      return _syncTokenInFlight!;
    }

    _syncTokenInFlight = _syncTokenWithBackend(accessToken: accessToken)
        .whenComplete(() {
      _syncTokenInFlight = null;
    });
    return _syncTokenInFlight!;
  }

  Future<void> _syncTokenWithBackend({String? accessToken}) async {
    final token = _currentToken ?? await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    _currentToken = token;

    final authToken = accessToken ?? _readAccessToken();
    if (authToken == null || authToken.isEmpty) return;

    final now = DateTime.now();
    if (_lastSyncedFcmToken == token &&
        _lastSyncedFcmAt != null &&
        now.difference(_lastSyncedFcmAt!) < _fcmSyncCooldown) {
      if (kDebugMode) {
        debugPrint('FCM token upload skipped (already synced recently)');
      }
      return;
    }

    try {
      final response = await _repository.uploadFcmToken(
        accessToken: authToken,
        request: NotificationTokenRequest(fcmToken: token),
      );
      _lastSyncedFcmToken = token;
      _lastSyncedFcmAt = DateTime.now();
      if (kDebugMode) {
        debugPrint(
          'FCM token uploaded: success=${response.success} '
          'message=${response.message}',
        );
      }
    } on NotificationApiException catch (error) {
      if (kDebugMode) {
        debugPrint('FCM token upload failed (non-fatal): $error');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('FCM token upload unexpected error: $error');
      }
    }
  }

  Future<void> clearBackendToken({String? accessToken}) async {
    _lastSyncedFcmToken = null;
    _lastSyncedFcmAt = null;
    final authToken = accessToken ?? _readAccessToken();
    if (authToken == null || authToken.isEmpty) return;

    try {
      await _repository.uploadFcmToken(
        accessToken: authToken,
        request: const NotificationTokenRequest(fcmToken: ''),
      );
    } catch (_) {
      // Best-effort clear on logout.
    }
  }

  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    if (!_initialized) {
      await _initLocalNotifications();
      await _createAndroidNotificationChannels();
    }
    await _showLocalNotification(NotificationModel.fromRemoteMessage(message));
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(_androidLauncherIcon);
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
      onDidReceiveBackgroundNotificationResponse:
          notificationTapBackgroundHandler,
    );
  }

  Future<void> _createAndroidNotificationChannels() async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return;

    final seenChannelIds = <String>{};
    for (final type in NotificationType.values) {
      if (type == NotificationType.unknown) continue;
      if (!seenChannelIds.add(type.channelId)) continue;

      final channel = AndroidNotificationChannel(
        type.channelId,
        type.channelName,
        description: type.channelDescription,
        importance: Importance.high,
      );
      _androidChannels[type.channelId] = channel;
      await androidPlugin.createNotificationChannel(channel);
    }

    final generalChannel = AndroidNotificationChannel(
      NotificationType.unknown.channelId,
      NotificationType.unknown.channelName,
      description: NotificationType.unknown.channelDescription,
      importance: Importance.defaultImportance,
    );
    _androidChannels[generalChannel.id] = generalChannel;
    await androidPlugin.createNotificationChannel(generalChannel);
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (kDebugMode) {
        debugPrint('FCM iOS permission: ${settings.authorizationStatus}');
      }
      return;
    }

    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      if (kDebugMode) {
        debugPrint('Android notification permission: $status');
      }
    }
  }

  Future<void> _configureFirebaseMessaging() async {
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpenedApp);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint(
        'FCM foreground message: ${message.messageId} data=${message.data}',
      );
    }
    await _showLocalNotification(NotificationModel.fromRemoteMessage(message));
  }

  Future<void> _handleNotificationOpenedApp(RemoteMessage message) async {
    if (kDebugMode) {
      debugPrint('FCM opened from background: ${message.messageId}');
    }
    await _navigateFromMessage(message);
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final model = _decodePayload(payload);
    if (model == null) return;

    unawaited(_navigateFromModel(model));
  }

  Future<void> _handleTokenRefresh(String token) async {
    if (token.isEmpty) return;
    if (_currentToken == token && _lastSyncedFcmToken == token) {
      return;
    }
    _currentToken = token;
    if (kDebugMode) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('FCM TOKEN REFRESHED: $token');
      debugPrint('═══════════════════════════════════════');
    }
    // Force upload when FCM rotates the token.
    _lastSyncedFcmAt = null;
    await syncTokenWithBackend();
  }

  Future<void> _showLocalNotification(NotificationModel model) async {
    final title = model.title ?? _defaultTitle(model.type);
    final body = model.body ?? _defaultBody(model.type);
    final notificationId = _notificationIdFor(model);
    final channel = _androidChannels[model.type.channelId];

    final androidDetails = AndroidNotificationDetails(
      channel?.id ?? model.type.channelId,
      channel?.name ?? model.type.channelName,
      channelDescription: channel?.description ?? model.type.channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: _androidLauncherIcon,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notificationId,
      title,
      body,
      details,
      payload: _encodePayload(model),
    );
  }

  Future<void> _navigateFromMessage(RemoteMessage message) async {
    await _navigateFromModel(NotificationModel.fromRemoteMessage(message));
  }

  Future<void> _navigateFromModel(NotificationModel model) async {
    final route = model.route;
    if (route.isEmpty) return;

    void navigate() {
      if (Get.currentRoute != route) {
        Get.toNamed(route, arguments: model.data);
      }
    }

    if (Get.key.currentContext == null) {
      _pendingTapNotification = model;
      return;
    }

    navigate();
  }

  String? _readAccessToken() {
    try {
      final userController = Get.find<UserController>();
      if (!userController.isLoggedIn || userController.accessToken.isEmpty) {
        return null;
      }
      return userController.accessToken;
    } catch (_) {
      return null;
    }
  }

  int _notificationIdFor(NotificationModel model) {
    final seed = model.messageId ?? '${model.type.value}_${model.title}';
    return seed.hashCode & 0x7fffffff;
  }

  String _defaultTitle(NotificationType type) {
    switch (type) {
      case NotificationType.breakfastReminder:
        return 'Breakfast time';
      case NotificationType.lunchReminder:
        return 'Lunch time';
      case NotificationType.dinnerReminder:
        return 'Dinner time';
      case NotificationType.waterReminder:
        return 'Stay hydrated';
      case NotificationType.workoutReminder:
        return 'Workout reminder';
      case NotificationType.dailyStreakReminder:
        return 'Keep your streak alive';
      case NotificationType.goalAchieved:
        return 'Goal achieved!';
      case NotificationType.weeklyReport:
        return 'Your weekly report';
      case NotificationType.weightReminder:
        return 'Log your weight';
      case NotificationType.aiNutritionTips:
        return 'AI nutrition tip';
      case NotificationType.motivational:
        return 'Fit Buddy AI';
      case NotificationType.unknown:
        return 'Fit Buddy AI';
    }
  }

  String _defaultBody(NotificationType type) {
    switch (type) {
      case NotificationType.breakfastReminder:
        return 'Log your breakfast to stay on track.';
      case NotificationType.lunchReminder:
        return 'Log your lunch and keep your calories balanced.';
      case NotificationType.dinnerReminder:
        return 'Log your dinner before the day ends.';
      case NotificationType.waterReminder:
        return 'Drink some water and log your intake.';
      case NotificationType.workoutReminder:
        return 'Time to move — log your activity.';
      case NotificationType.dailyStreakReminder:
        return 'Log today to maintain your streak.';
      case NotificationType.goalAchieved:
        return 'You hit a goal. Great work!';
      case NotificationType.weeklyReport:
        return 'See how you did this week.';
      case NotificationType.weightReminder:
        return 'Update your weight to track progress.';
      case NotificationType.aiNutritionTips:
        return 'Open your personalized nutrition tip.';
      case NotificationType.motivational:
        return 'Small steps lead to big results.';
      case NotificationType.unknown:
        return 'You have a new notification.';
    }
  }

  String _encodePayload(NotificationModel model) {
    return '${model.type.value}|${model.title ?? ''}|${model.body ?? ''}';
  }

  NotificationModel? _decodePayload(String payload) {
    final parts = payload.split('|');
    if (parts.isEmpty) return null;
    return NotificationModel(
      type: NotificationType.fromValue(parts.first),
      title: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
      body: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
    );
  }
}

@pragma('vm:entry-point')
void notificationTapBackgroundHandler(NotificationResponse response) {
  if (kDebugMode) {
    debugPrint('Local notification tapped in background: ${response.payload}');
  }
}
