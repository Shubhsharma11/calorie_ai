import '../core/api_errors.dart';
import '../models/step_log_entry.dart';
import '../services/steps_api_service.dart';

class StepsRepository {
  StepsRepository({StepsApiService? apiService})
      : _apiService = apiService ?? StepsApiService();

  final StepsApiService _apiService;

  Future<StepsFetchResult> fetchStepsByDate({
    required String accessToken,
    required DateTime date,
  }) async {
    try {
      return await _apiService.fetchStepsByDate(
        accessToken: accessToken,
        date: date,
      );
    } on StepsApiException {
      rethrow;
    } catch (error) {
      throw StepsApiException(
        apiNetworkErrorMessage(error, action: 'loading steps'),
      );
    }
  }

  Future<StepsFetchResult> fetchStepsHistory({
    required String accessToken,
    int page = 1,
    int limit = StepsApiService.defaultPageLimit,
  }) async {
    try {
      return await _apiService.fetchStepsHistory(
        accessToken: accessToken,
        page: page,
        limit: limit,
      );
    } on StepsApiException {
      rethrow;
    } catch (error) {
      throw StepsApiException(
        apiNetworkErrorMessage(error, action: 'loading steps history'),
      );
    }
  }

  Future<StepLogResponse> syncSteps({
    required String accessToken,
    required int steps,
    required int caloriesBurned,
    DateTime? date,
  }) async {
    try {
      return await _apiService.syncSteps(
        accessToken: accessToken,
        steps: steps,
        caloriesBurned: caloriesBurned,
        date: date,
      );
    } on StepsApiException {
      rethrow;
    } catch (error) {
      throw StepsApiException(
        apiNetworkErrorMessage(error, action: 'saving steps'),
      );
    }
  }
}
