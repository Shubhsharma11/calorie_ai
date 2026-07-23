import '../core/api_errors.dart';
import '../models/saved_meal_item.dart';
import '../services/favourite_meals_api_service.dart';

class FavouriteMealsRepository {
  FavouriteMealsRepository({FavouriteMealsApiService? apiService})
      : _apiService = apiService ?? FavouriteMealsApiService();

  final FavouriteMealsApiService _apiService;

  Future<List<SavedMealItem>> fetchFavourites({
    required String accessToken,
  }) async {
    try {
      return await _apiService.fetchFavourites(accessToken: accessToken);
    } on FavouriteMealsApiException {
      rethrow;
    } catch (error) {
      throw FavouriteMealsApiException(
        apiNetworkErrorMessage(error, action: 'loading favourite meals'),
      );
    }
  }

  Future<SavedMealItem> fetchFavourite({
    required String accessToken,
    required String favouriteMealId,
  }) async {
    try {
      return await _apiService.fetchFavourite(
        accessToken: accessToken,
        favouriteMealId: favouriteMealId,
      );
    } on FavouriteMealsApiException {
      rethrow;
    } catch (error) {
      throw FavouriteMealsApiException(
        apiNetworkErrorMessage(error, action: 'loading favourite meal'),
      );
    }
  }

  Future<SavedMealItem> addFavourite({
    required String accessToken,
    required SavedMealItem item,
    String? imageUrl,
  }) async {
    try {
      return await _apiService.addFavourite(
        accessToken: accessToken,
        item: item,
        imageUrl: imageUrl,
      );
    } on FavouriteMealsApiException {
      rethrow;
    } catch (error) {
      throw FavouriteMealsApiException(
        apiNetworkErrorMessage(error, action: 'adding favourite meal'),
      );
    }
  }

  Future<void> logFavourite({
    required String accessToken,
    required String favouriteMealId,
    required SavedMealItem item,
    required DateTime date,
    required String mealtime,
  }) async {
    try {
      await _apiService.logFavourite(
        accessToken: accessToken,
        favouriteMealId: favouriteMealId,
        item: item,
        date: date,
        mealtime: mealtime,
      );
    } on FavouriteMealsApiException {
      rethrow;
    } catch (error) {
      throw FavouriteMealsApiException(
        apiNetworkErrorMessage(error, action: 'logging favourite meal'),
      );
    }
  }

  Future<void> deleteFavourite({
    required String accessToken,
    required String favouriteMealId,
  }) async {
    try {
      await _apiService.deleteFavourite(
        accessToken: accessToken,
        favouriteMealId: favouriteMealId,
      );
    } on FavouriteMealsApiException {
      rethrow;
    } catch (error) {
      throw FavouriteMealsApiException(
        apiNetworkErrorMessage(error, action: 'removing favourite meal'),
      );
    }
  }
}
