import '../core/api_errors.dart';
import '../models/image_upload_result.dart';
import '../services/uploads_api_service.dart';

class UploadsRepository {
  UploadsRepository({UploadsApiService? apiService})
      : _apiService = apiService ?? UploadsApiService();

  final UploadsApiService _apiService;

  Future<ImageUploadResult> uploadImage({
    required String accessToken,
    required List<int> imageBytes,
    String filename = 'image.jpg',
  }) async {
    try {
      return await _apiService.uploadImage(
        accessToken: accessToken,
        imageBytes: imageBytes,
        filename: filename,
      );
    } on UploadsApiException {
      rethrow;
    } catch (error) {
      throw UploadsApiException(
        apiNetworkErrorMessage(error, action: 'uploading image'),
      );
    }
  }
}
