import '../models/notification_model.dart';
import '../services/notification_api_service.dart';

class NotificationRepository {
  NotificationRepository({NotificationApiService? apiService})
    : _apiService = apiService ?? NotificationApiService();

  final NotificationApiService _apiService;

  Future<NotificationTokenResponse> uploadFcmToken({
    required String accessToken,
    required NotificationTokenRequest request,
  }) async {
    try {
      return await _apiService.uploadFcmToken(
        accessToken: accessToken,
        request: request,
      );
    } on NotificationApiException {
      rethrow;
    } catch (error) {
      throw NotificationApiException(
        'Network error while uploading FCM token: $error',
      );
    }
  }

  Future<NotificationListResult> fetchNotifications({
    required String accessToken,
    int page = 1,
    int limit = 20,
    bool? unreadOnly,
  }) async {
    try {
      return await _apiService.fetchNotifications(
        accessToken: accessToken,
        page: page,
        limit: limit,
        unreadOnly: unreadOnly,
      );
    } on NotificationApiException {
      rethrow;
    } catch (error) {
      throw NotificationApiException(
        'Network error while loading notifications: $error',
      );
    }
  }

  Future<int> fetchUnreadCount({required String accessToken}) async {
    try {
      return await _apiService.fetchUnreadCount(accessToken: accessToken);
    } on NotificationApiException {
      rethrow;
    } catch (error) {
      throw NotificationApiException(
        'Network error while loading unread count: $error',
      );
    }
  }

  Future<void> markAsRead({
    required String accessToken,
    required String notificationId,
  }) async {
    try {
      await _apiService.markAsRead(
        accessToken: accessToken,
        notificationId: notificationId,
      );
    } on NotificationApiException {
      rethrow;
    } catch (error) {
      throw NotificationApiException(
        'Network error while marking notification read: $error',
      );
    }
  }

  Future<void> markAllAsRead({required String accessToken}) async {
    try {
      await _apiService.markAllAsRead(accessToken: accessToken);
    } on NotificationApiException {
      rethrow;
    } catch (error) {
      throw NotificationApiException(
        'Network error while marking all notifications read: $error',
      );
    }
  }
}
