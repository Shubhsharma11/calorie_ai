import '../core/api_errors.dart';
import '../models/meal_entry.dart';
import '../services/meals_api_service.dart';

class MealsRepository {
  MealsRepository({MealsApiService? apiService})
    : _apiService = apiService ?? MealsApiService();

  final MealsApiService _apiService;

  Future<List<MealEntry>> fetchMeals({
    required String accessToken,
    DateTime? date,
    String? period,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      return await _apiService.fetchMeals(
        accessToken: accessToken,
        date: date,
        period: period,
        fromDate: fromDate,
        toDate: toDate,
      );
    } on MealsApiException {
      rethrow;
    } catch (error) {
      throw MealsApiException(
        apiNetworkErrorMessage(error, action: 'loading meals'),
      );
    }
  }

  Future<MealEntry> createMeal({
    required String accessToken,
    required MealEntry entry,
  }) async {
    try {
      return await _apiService.createMeal(
        accessToken: accessToken,
        entry: entry,
      );
    } on MealsApiException {
      rethrow;
    } catch (error) {
      throw MealsApiException(
        apiNetworkErrorMessage(error, action: 'saving meal'),
      );
    }
  }

  Future<MealEntry> updateMeal({
    required String accessToken,
    required MealEntry entry,
  }) async {
    try {
      return await _apiService.updateMeal(
        accessToken: accessToken,
        entry: entry,
      );
    } on MealsApiException {
      rethrow;
    } catch (error) {
      throw MealsApiException(
        apiNetworkErrorMessage(error, action: 'updating meal'),
      );
    }
  }

  Future<void> deleteMeal({
    required String accessToken,
    required String mealId,
  }) async {
    try {
      await _apiService.deleteMeal(
        accessToken: accessToken,
        mealId: mealId,
      );
    } on MealsApiException {
      rethrow;
    } catch (error) {
      throw MealsApiException(
        apiNetworkErrorMessage(error, action: 'deleting meal'),
      );
    }
  }
}
