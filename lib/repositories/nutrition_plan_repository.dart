import '../models/nutrition_plan_model.dart';
import '../services/nutrition_plan_api_service.dart';

class NutritionPlanRepository {
  NutritionPlanRepository({NutritionPlanApiService? apiService})
    : _apiService = apiService ?? NutritionPlanApiService();

  final NutritionPlanApiService _apiService;

  Future<NutritionPlanModel> createPlan({required String accessToken}) async {
    try {
      return await _apiService.createPlan(accessToken: accessToken);
    } on NutritionPlanApiException {
      rethrow;
    } catch (error) {
      throw NutritionPlanApiException(
        'Network error while creating nutrition plan: $error',
      );
    }
  }

  Future<NutritionPlanModel> fetchPlan({required String accessToken}) async {
    try {
      return await _apiService.fetchPlan(accessToken: accessToken);
    } on NutritionPlanApiException {
      rethrow;
    } catch (error) {
      throw NutritionPlanApiException(
        'Network error while loading nutrition plan: $error',
      );
    }
  }
}
