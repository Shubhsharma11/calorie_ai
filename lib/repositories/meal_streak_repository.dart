import '../models/meal_streak_model.dart';
import '../services/meal_streak_api_service.dart';

class MealStreakRepository {
  MealStreakRepository({MealStreakApiService? apiService})
    : _apiService = apiService ?? MealStreakApiService();

  final MealStreakApiService _apiService;

  Future<MealStreakModel> fetchStreak({required String accessToken}) async {
    try {
      return await _apiService.fetchStreak(accessToken: accessToken);
    } on MealStreakApiException {
      rethrow;
    } catch (error) {
      throw MealStreakApiException(
        'Network error while loading meal streak: $error',
      );
    }
  }
}
