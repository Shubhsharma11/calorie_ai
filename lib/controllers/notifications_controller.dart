import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import '../services/local_storage_service.dart';
import '../services/notification_api_service.dart';
import 'user_controller.dart';

class NotificationsController extends GetxController {
  NotificationsController({NotificationRepository? repository})
    : _repository = repository ?? NotificationRepository();

  final NotificationRepository _repository;
  final Set<String> _dismissedIds = <String>{};
  final Set<String> _dismissedUnreadIds = <String>{};
  final Map<String, Timer> _pendingDeletes = <String, Timer>{};
  Future<void>? _dismissedIdsLoad;
  String? _dismissedIdsUserId;

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
    unawaited(_loadDismissedIds().then((_) => refreshUnreadCount()));
  }

  @override
  void onClose() {
    for (final timer in _pendingDeletes.values) {
      timer.cancel();
    }
    _pendingDeletes.clear();
    super.onClose();
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
      await _loadDismissedIds();
      final result = await _repository.fetchNotifications(
        accessToken: _accessToken,
        page: 1,
        limit: 50,
      );
      final visible = result.notifications
          .where((item) => !_isDismissed(item))
          .toList();
      notifications.assignAll(visible);
      unreadCount.value = _unreadAfterDismissals(
        result.notifications,
        result.meta.unreadCount > 0
            ? result.meta.unreadCount
            : result.count.unread,
      );
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
      await _loadDismissedIds();
      final serverCount = await _repository.fetchUnreadCount(
        accessToken: _accessToken,
      );
      final adjusted = serverCount - _dismissedUnreadIds.length;
      unreadCount.value = adjusted < 0 ? 0 : adjusted;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('NotificationsController.refreshUnreadCount: $error');
      }
    }
  }

  void clearSessionData() {
    for (final timer in _pendingDeletes.values) {
      timer.cancel();
    }
    _pendingDeletes.clear();
    _dismissedIds.clear();
    _dismissedUnreadIds.clear();
    _dismissedIdsLoad = null;
    _dismissedIdsUserId = null;
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

    final id = _stableId(removed);
    if (id != null) {
      _dismissedIds.add(id);
      if (!removed.isRead) _dismissedUnreadIds.add(id);
      unawaited(_persistDismissedIds());
      _scheduleServerDelete(removed);
    }
    return RemovedNotification(index: index, notification: removed);
  }

  void restoreDismissedNotification(RemovedNotification removed) {
    final id = _stableId(removed.notification);
    if (id != null) {
      _dismissedIds.remove(id);
      _dismissedUnreadIds.remove(id);
      _pendingDeletes.remove(id)?.cancel();
      unawaited(_persistDismissedIds());
    }
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

  String? _stableId(NotificationModel notification) {
    final id = notification.id?.trim();
    if (id != null && id.isNotEmpty) return id;
    final messageId = notification.messageId?.trim();
    if (messageId != null && messageId.isNotEmpty) return messageId;
    final createdAt = notification.createdAt?.toIso8601String() ?? '';
    final title = notification.title?.trim() ?? '';
    final body = notification.body?.trim() ?? '';
    if (createdAt.isEmpty && title.isEmpty && body.isEmpty) return null;
    return 'fp:$createdAt|$title|$body';
  }

  bool _isDismissed(NotificationModel notification) {
    final id = _stableId(notification);
    return id != null && _dismissedIds.contains(id);
  }

  int _unreadAfterDismissals(List<NotificationModel> items, int apiUnread) {
    final hiddenUnread = items
        .where((item) => _isDismissed(item) && !item.isRead)
        .length;
    final adjusted = apiUnread - hiddenUnread;
    return adjusted < 0 ? 0 : adjusted;
  }

  String get _currentUserId {
    if (!Get.isRegistered<UserController>()) return '';
    return Get.find<UserController>().userId;
  }

  Future<void> _loadDismissedIds() async {
    final userId = _currentUserId;
    final existing = _dismissedIdsLoad;
    if (existing != null && _dismissedIdsUserId == userId) {
      await existing;
      return;
    }
    if (_dismissedIdsUserId != userId) {
      _dismissedIds.clear();
      _dismissedUnreadIds.clear();
    }
    _dismissedIdsUserId = userId;
    _dismissedIdsLoad = _readDismissedIds(userId);
    await _dismissedIdsLoad;
  }

  Future<void> _readDismissedIds(String userId) async {
    try {
      final stored =
          await LocalStorageService(null, userId).loadDismissedNotificationIds();
      if (_dismissedIdsUserId != userId) return;
      _dismissedIds.addAll(stored);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('NotificationsController._loadDismissedIds: $error');
      }
    }
  }

  Future<void> _persistDismissedIds() async {
    try {
      await LocalStorageService(
        null,
        _currentUserId,
      ).saveDismissedNotificationIds(_dismissedIds);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('NotificationsController._persistDismissedIds: $error');
      }
    }
  }

  void _scheduleServerDelete(NotificationModel notification) {
    final id = notification.id?.trim();
    if (id == null || id.isEmpty || !isLoggedIn) return;
    _pendingDeletes.remove(id)?.cancel();
    _pendingDeletes[id] = Timer(const Duration(seconds: 3), () {
      _pendingDeletes.remove(id);
      unawaited(_deleteOnServer(id));
    });
  }

  Future<void> _deleteOnServer(String notificationId) async {
    if (!isLoggedIn) return;
    try {
      await _repository.deleteNotification(
        accessToken: _accessToken,
        notificationId: notificationId,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('NotificationsController._deleteOnServer: $error');
      }
    }
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
