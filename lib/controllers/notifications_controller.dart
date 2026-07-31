import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import '../services/notification_api_service.dart';
import 'user_controller.dart';

class NotificationsController extends GetxController {
  NotificationsController({NotificationRepository? repository})
    : _repository = repository ?? NotificationRepository();

  final NotificationRepository _repository;

  final notifications = <NotificationModel>[].obs;
  final unreadCount = 0.obs;
  final isLoading = false.obs;
  final isMarkingAll = false.obs;
  final errorMessage = RxnString();

  bool get isLoggedIn {
    if (!Get.isRegistered<UserController>()) return false;
    final user = Get.find<UserController>();
    return user.isLoggedIn && user.accessToken.isNotEmpty;
  }

  String get _accessToken {
    if (!Get.isRegistered<UserController>()) return '';
    return Get.find<UserController>().accessToken;
  }

  @override
  void onInit() {
    super.onInit();
    refreshUnreadCount();
  }

  Future<void> loadNotifications({bool force = false}) async {
    if (!isLoggedIn) {
      notifications.clear();
      unreadCount.value = 0;
      errorMessage.value = 'Sign in to see notifications.';
      return;
    }
    if (isLoading.value && !force) return;

    isLoading.value = true;
    errorMessage.value = null;
    try {
      final result = await _repository.fetchNotifications(
        accessToken: _accessToken,
        page: 1,
        limit: 50,
      );
      notifications.assignAll(result.notifications);
      unreadCount.value = result.meta.unreadCount > 0
          ? result.meta.unreadCount
          : result.count.unread;
    } on NotificationApiException catch (error) {
      errorMessage.value = error.message;
      if (kDebugMode) {
        debugPrint('NotificationsController.loadNotifications: $error');
      }
    } catch (error) {
      errorMessage.value = 'Could not load notifications.';
      if (kDebugMode) {
        debugPrint('NotificationsController.loadNotifications: $error');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshUnreadCount() async {
    if (!isLoggedIn) {
      unreadCount.value = 0;
      return;
    }

    try {
      unreadCount.value = await _repository.fetchUnreadCount(
        accessToken: _accessToken,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('NotificationsController.refreshUnreadCount: $error');
      }
    }
  }

  void clearSessionData() {
    notifications.clear();
    unreadCount.value = 0;
    errorMessage.value = null;
    isLoading.value = false;
    isMarkingAll.value = false;
    debugPrint('NotificationsController: session data cleared');
  }

  Future<void> openNotification(NotificationModel notification) async {
    final id = notification.id;
    if (id == null || id.isEmpty || notification.isRead) return;

    final index = notifications.indexWhere((item) => item.id == id);
    if (index >= 0) {
      notifications[index] = notification.copyWith(isRead: true);
      if (unreadCount.value > 0) unreadCount.value -= 1;
    }

    try {
      await _repository.markAsRead(
        accessToken: _accessToken,
        notificationId: id,
      );
    } catch (error) {
      if (index >= 0) {
        notifications[index] = notification.copyWith(isRead: false);
        unreadCount.value += 1;
      }
      if (kDebugMode) {
        debugPrint('NotificationsController.openNotification: $error');
      }
    }
  }

  Future<void> markAllAsRead() async {
    if (!isLoggedIn || isMarkingAll.value) return;
    if (unreadCount.value == 0 &&
        notifications.every((item) => item.isRead)) {
      return;
    }

    isMarkingAll.value = true;
    final previous = List<NotificationModel>.from(notifications);
    final previousUnread = unreadCount.value;

    // Materialize first — assignAll clears the RxList before iterating a
    // lazy map over the same list, which would wipe all items.
    notifications.assignAll([
      for (final item in previous) item.copyWith(isRead: true),
    ]);
    unreadCount.value = 0;

    try {
      await _repository.markAllAsRead(accessToken: _accessToken);
    } catch (error) {
      notifications.assignAll(previous);
      unreadCount.value = previousUnread;
      if (kDebugMode) {
        debugPrint('NotificationsController.markAllAsRead: $error');
      }
    } finally {
      isMarkingAll.value = false;
    }
  }

  RemovedNotification? dismissNotification(NotificationModel notification) {
    final index = _indexFor(notification);
    if (index < 0) return null;
    final removed = notifications[index];
    notifications.removeAt(index);
    if (!removed.isRead && unreadCount.value > 0) {
      unreadCount.value -= 1;
    }
    return RemovedNotification(index: index, notification: removed);
  }

  void restoreDismissedNotification(RemovedNotification removed) {
    final insertAt = removed.index.clamp(0, notifications.length);
    notifications.insert(insertAt, removed.notification);
    if (!removed.notification.isRead) {
      unreadCount.value += 1;
    }
  }

  int _indexFor(NotificationModel notification) {
    final id = notification.id;
    if (id != null && id.isNotEmpty) {
      final byId = notifications.indexWhere((item) => item.id == id);
      if (byId >= 0) return byId;
    }
    final messageId = notification.messageId;
    if (messageId != null && messageId.isNotEmpty) {
      return notifications.indexWhere((item) => item.messageId == messageId);
    }
    return notifications.indexWhere(
      (item) =>
          item.createdAt == notification.createdAt &&
          item.title == notification.title &&
          item.body == notification.body,
    );
  }
}

class RemovedNotification {
  const RemovedNotification({
    required this.index,
    required this.notification,
  });

  final int index;
  final NotificationModel notification;
}
