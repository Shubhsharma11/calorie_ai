import '../core/api_errors.dart';
import '../models/custom_meal_preset.dart';
import '../services/custom_meals_api_service.dart';

class CustomMealsRepository {
  CustomMealsRepository({CustomMealsApiService? apiService})
      : _apiService = apiService ?? CustomMealsApiService();

  final CustomMealsApiService _apiService;

  Future<List<CustomMealPreset>> fetchCustomMeals({
    required String accessToken,
  }) async {
    try {
      return await _apiService.fetchCustomMeals(accessToken: accessToken);
    } on CustomMealsApiException {
      rethrow;
    } catch (error) {
      throw CustomMealsApiException(
        apiNetworkErrorMessage(error, action: 'loading custom meals'),
      );
    }
  }

  Future<CustomMealPreset> createCustomMeal({
    required String accessToken,
    required CustomMealPreset preset,
  }) async {
    try {
      return await _apiService.createCustomMeal(
        accessToken: accessToken,
        preset: preset,
      );
    } on CustomMealsApiException {
      rethrow;
    } catch (error) {
      throw CustomMealsApiException(
        apiNetworkErrorMessage(error, action: 'saving custom meal'),
      );
    }
  }
}
