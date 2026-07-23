import '../core/api_errors.dart';
import '../models/water_log_entry.dart';
import '../services/water_api_service.dart';

class WaterRepository {
  WaterRepository({WaterApiService? apiService})
      : _apiService = apiService ?? WaterApiService();

  final WaterApiService _apiService;

  Future<WaterFetchResult> fetchWaterByDate({
    required String accessToken,
    required DateTime date,
  }) async {
    try {
      return await _apiService.fetchWaterByDate(
        accessToken: accessToken,
        date: date,
      );
    } on WaterApiException {
      rethrow;
    } catch (error) {
      throw WaterApiException(
        apiNetworkErrorMessage(error, action: 'loading water'),
      );
    }
  }

  Future<WaterFetchResult> fetchWaterHistory({
    required String accessToken,
    int page = 1,
    int limit = WaterApiService.defaultPageLimit,
  }) async {
    try {
      return await _apiService.fetchWaterHistory(
        accessToken: accessToken,
        page: page,
        limit: limit,
      );
    } on WaterApiException {
      rethrow;
    } catch (error) {
      throw WaterApiException(
        apiNetworkErrorMessage(error, action: 'loading water history'),
      );
    }
  }

  Future<WaterLogResponse> logWater({
    required String accessToken,
    required int amountMl,
    DateTime? date,
  }) async {
    try {
      return await _apiService.logWater(
        accessToken: accessToken,
        amountMl: amountMl,
        date: date,
      );
    } on WaterApiException {
      rethrow;
    } catch (error) {
      throw WaterApiException(
        apiNetworkErrorMessage(error, action: 'saving water'),
      );
    }
  }

  Future<void> deleteWater({
    required String accessToken,
    required String waterId,
  }) async {
    try {
      await _apiService.deleteWater(
        accessToken: accessToken,
        waterId: waterId,
      );
    } on WaterApiException {
      rethrow;
    } catch (error) {
      throw WaterApiException(
        apiNetworkErrorMessage(error, action: 'deleting water'),
      );
    }
  }
}
