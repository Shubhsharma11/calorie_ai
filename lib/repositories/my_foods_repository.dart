import '../core/api_errors.dart';
import '../models/custom_food_preset.dart';
import '../services/my_foods_api_service.dart';

class MyFoodsRepository {
  MyFoodsRepository({MyFoodsApiService? apiService})
      : _apiService = apiService ?? MyFoodsApiService();

  final MyFoodsApiService _apiService;

  Future<List<CustomFoodPreset>> fetchMyFoods({
    required String accessToken,
  }) async {
    try {
      return await _apiService.fetchMyFoods(accessToken: accessToken);
    } on MyFoodsApiException {
      rethrow;
    } catch (error) {
      throw MyFoodsApiException(
        apiNetworkErrorMessage(error, action: 'loading my foods'),
      );
    }
  }

  Future<CustomFoodPreset> fetchMyFood({
    required String accessToken,
    required String myFoodId,
  }) async {
    try {
      return await _apiService.fetchMyFood(
        accessToken: accessToken,
        myFoodId: myFoodId,
      );
    } on MyFoodsApiException {
      rethrow;
    } catch (error) {
      throw MyFoodsApiException(
        apiNetworkErrorMessage(error, action: 'loading my food'),
      );
    }
  }

  Future<CustomFoodPreset> saveMyFood({
    required String accessToken,
    required CustomFoodPreset preset,
    required String mealtime,
    String? imageUrl,
  }) async {
    try {
      return await _apiService.saveMyFood(
        accessToken: accessToken,
        preset: preset,
        mealtime: mealtime,
        imageUrl: imageUrl,
      );
    } on MyFoodsApiException {
      rethrow;
    } catch (error) {
      throw MyFoodsApiException(
        apiNetworkErrorMessage(error, action: 'saving my food'),
      );
    }
  }

  Future<CustomFoodPreset> updateMyFood({
    required String accessToken,
    required String myFoodId,
    required CustomFoodPreset preset,
    required String mealtime,
    String? imageUrl,
  }) async {
    try {
      return await _apiService.updateMyFood(
        accessToken: accessToken,
        myFoodId: myFoodId,
        preset: preset,
        mealtime: mealtime,
        imageUrl: imageUrl,
      );
    } on MyFoodsApiException {
      rethrow;
    } catch (error) {
      throw MyFoodsApiException(
        apiNetworkErrorMessage(error, action: 'updating my food'),
      );
    }
  }

  Future<void> logMyFood({
    required String accessToken,
    required String myFoodId,
    required CustomFoodPreset preset,
    required DateTime date,
    required String mealtime,
  }) async {
    try {
      await _apiService.logMyFood(
        accessToken: accessToken,
        myFoodId: myFoodId,
        preset: preset,
        date: date,
        mealtime: mealtime,
      );
    } on MyFoodsApiException {
      rethrow;
    } catch (error) {
      throw MyFoodsApiException(
        apiNetworkErrorMessage(error, action: 'logging my food'),
      );
    }
  }

  Future<void> deleteMyFood({
    required String accessToken,
    required String myFoodId,
  }) async {
    try {
      await _apiService.deleteMyFood(
        accessToken: accessToken,
        myFoodId: myFoodId,
      );
    } on MyFoodsApiException {
      rethrow;
    } catch (error) {
      throw MyFoodsApiException(
        apiNetworkErrorMessage(error, action: 'deleting my food'),
      );
    }
  }
}
