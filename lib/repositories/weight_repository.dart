import '../core/api_errors.dart';
import '../models/api_weight_mapper.dart';
import '../models/weight_entry.dart';
import '../services/weight_api_service.dart';

class WeightRepository {
  WeightRepository({WeightApiService? apiService})
    : _apiService = apiService ?? WeightApiService();

  final WeightApiService _apiService;

  Future<List<WeightEntry>> fetchWeights({
    required String accessToken,
    DateTime? date,
    int page = 1,
    int limit = 30,
  }) async {
    try {
      return await _apiService.fetchWeights(
        accessToken: accessToken,
        date: date,
        page: page,
        limit: limit,
      );
    } on WeightApiException {
      rethrow;
    } catch (error) {
      throw WeightApiException(
        apiNetworkErrorMessage(error, action: 'loading weight'),
      );
    }
  }

  Future<WeightLogResponse> logWeight({
    required String accessToken,
    required double weight,
    String weightUnit = 'kg',
    DateTime? recordedAt,
  }) async {
    try {
      return await _apiService.logWeight(
        accessToken: accessToken,
        weight: weight,
        weightUnit: weightUnit,
        recordedAt: recordedAt,
      );
    } on WeightApiException {
      rethrow;
    } catch (error) {
      throw WeightApiException(
        apiNetworkErrorMessage(error, action: 'saving weight'),
      );
    }
  }

  Future<void> deleteWeight({
    required String accessToken,
    required String weightId,
  }) async {
    try {
      await _apiService.deleteWeight(
        accessToken: accessToken,
        weightId: weightId,
      );
    } on WeightApiException {
      rethrow;
    } catch (error) {
      throw WeightApiException(
        apiNetworkErrorMessage(error, action: 'deleting weight'),
      );
    }
  }
}
