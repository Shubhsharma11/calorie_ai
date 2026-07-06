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
}
