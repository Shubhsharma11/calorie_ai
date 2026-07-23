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

  Future<CustomMealPreset> updateCustomMeal({
    required String accessToken,
    required String myMealId,
    required CustomMealPreset preset,
    String? imageUrl,
  }) async {
    try {
      return await _apiService.updateCustomMeal(
        accessToken: accessToken,
        myMealId: myMealId,
        preset: preset,
        imageUrl: imageUrl,
      );
    } on CustomMealsApiException {
      rethrow;
    } catch (error) {
      throw CustomMealsApiException(
        apiNetworkErrorMessage(error, action: 'updating custom meal'),
      );
    }
  }

  Future<void> deleteCustomMeal({
    required String accessToken,
    required String myMealId,
  }) async {
    try {
      await _apiService.deleteCustomMeal(
        accessToken: accessToken,
        myMealId: myMealId,
      );
    } on CustomMealsApiException {
      rethrow;
    } catch (error) {
      throw CustomMealsApiException(
        apiNetworkErrorMessage(error, action: 'deleting custom meal'),
      );
    }
  }
}
