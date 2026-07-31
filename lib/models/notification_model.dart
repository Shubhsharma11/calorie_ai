import 'package:firebase_messaging/firebase_messaging.dart';

import 'notification_type.dart';

class NotificationModel {
  const NotificationModel({
    required this.type,
    this.id,
    this.title,
    this.body,
    this.data = const {},
    this.messageId,
    this.isRead = false,
    this.createdAt,
  });

  final String? id;
  final NotificationType type;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
  final String? messageId;
  final bool isRead;
  final DateTime? createdAt;

  factory NotificationModel.fromRemoteMessage(RemoteMessage message) {
    final notification = message.notification;
    return NotificationModel(
      id: message.messageId,
      type: NotificationType.fromData(message.data),
      title: notification?.title ?? message.data['title'] as String?,
      body: notification?.body ?? message.data['body'] as String?,
      data: Map<String, dynamic>.from(message.data),
      messageId: message.messageId,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? json['messageId'] as String?,
      type: NotificationType.fromValue(json['type'] as String?),
      title: json['title'] as String?,
      body: json['body'] as String?,
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
      messageId: json['messageId'] as String?,
      isRead: json['isRead'] == true,
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'type': type.value,
        'title': title,
        'body': body,
        'data': data,
        if (messageId != null) 'messageId': messageId,
        'isRead': isRead,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  NotificationModel copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    String? messageId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      messageId: messageId ?? this.messageId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get route {
    if (type == NotificationType.mealReminder) {
      return NotificationType.routeForMealTime(data['mealTime'] as String?);
    }
    return type.route;
  }

  static DateTime? _parseDateTime(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }
}

class NotificationCounts {
  const NotificationCounts({this.total = 0, this.unread = 0});

  final int total;
  final int unread;

  factory NotificationCounts.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NotificationCounts();
    return NotificationCounts(
      total: _asInt(json['total']),
      unread: _asInt(json['unread']),
    );
  }
}

class NotificationListMeta {
  const NotificationListMeta({
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.totalPages = 1,
    this.unreadCount = 0,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final int unreadCount;

  factory NotificationListMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NotificationListMeta();
    return NotificationListMeta(
      page: _asInt(json['page'], fallback: 1),
      limit: _asInt(json['limit'], fallback: 20),
      total: _asInt(json['total']),
      totalPages: _asInt(json['totalPages'], fallback: 1),
      unreadCount: _asInt(json['unreadCount']),
    );
  }
}

class NotificationListResult {
  const NotificationListResult({
    required this.notifications,
    this.count = const NotificationCounts(),
    this.meta = const NotificationListMeta(),
    this.success = true,
  });

  final List<NotificationModel> notifications;
  final NotificationCounts count;
  final NotificationListMeta meta;
  final bool success;

  factory NotificationListResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final payload = data is Map<String, dynamic> ? data : json;
    final rawList = payload['notifications'];
    final notifications = rawList is List
        ? rawList
            .whereType<Map>()
            .map(
              (item) => NotificationModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : const <NotificationModel>[];

    return NotificationListResult(
      success: json['success'] != false,
      notifications: notifications,
      count: NotificationCounts.fromJson(
        payload['count'] is Map
            ? Map<String, dynamic>.from(payload['count'] as Map)
            : null,
      ),
      meta: NotificationListMeta.fromJson(
        payload['meta'] is Map
            ? Map<String, dynamic>.from(payload['meta'] as Map)
            : null,
      ),
    );
  }
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

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
