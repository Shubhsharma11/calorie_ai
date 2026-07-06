import 'package:firebase_messaging/firebase_messaging.dart';

import 'notification_type.dart';

class NotificationModel {
  const NotificationModel({
    required this.type,
    this.title,
    this.body,
    this.data = const {},
    this.messageId,
  });

  final NotificationType type;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
  final String? messageId;

  factory NotificationModel.fromRemoteMessage(RemoteMessage message) {
    final notification = message.notification;
    return NotificationModel(
      type: NotificationType.fromData(message.data),
      title: notification?.title ?? message.data['title'] as String?,
      body: notification?.body ?? message.data['body'] as String?,
      data: Map<String, dynamic>.from(message.data),
      messageId: message.messageId,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      type: NotificationType.fromValue(json['type'] as String?),
      title: json['title'] as String?,
      body: json['body'] as String?,
      data: json['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
      messageId: json['messageId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.value,
    'title': title,
    'body': body,
    'data': data,
    'messageId': messageId,
  };

  String get route => type.route;
}

class NotificationTokenRequest {
  const NotificationTokenRequest({required this.fcmToken});

  final String fcmToken;

  Map<String, dynamic> toJson() => {'fcmToken': fcmToken};
}

class NotificationTokenResponse {
  const NotificationTokenResponse({
    required this.success,
    this.message,
  });

  final bool success;
  final String? message;

  factory NotificationTokenResponse.fromJson(Map<String, dynamic> json) {
    final success = json['success'];
    return NotificationTokenResponse(
      success: success is bool
          ? success
          : json['status'] == 'ok' || json['status'] == 'success',
      message: json['message'] as String?,
    );
  }
}
