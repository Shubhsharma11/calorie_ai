import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../core/api_errors.dart';
import '../core/app_snackbar.dart';
import '../core/goal_progress_message.dart';
import '../core/meal_log_group.dart';
import '../models/custom_meal_preset.dart';
import '../models/custom_food_preset.dart';
import '../models/daily_nutrition.dart';
import '../models/food_item.dart';
import '../models/meal_entry.dart';
import '../models/meal_suggestion.dart';
import '../models/meal_summary.dart';
import '../models/meal_type.dart';
import '../models/saved_meal_item.dart';
import '../repositories/custom_meals_repository.dart';
import '../repositories/favourite_meals_repository.dart';
import '../repositories/meals_repository.dart';
import '../repositories/my_foods_repository.dart';
import '../services/food_api_service.dart';
import '../services/api_endpoints.dart';
import '../services/custom_meals_api_service.dart';
import '../services/favourite_meals_api_service.dart';
import '../services/meals_api_service.dart';
import '../services/my_foods_api_service.dart';
import '../widgets/calorie_goal_success_dialog.dart';
import 'dashboard_controller.dart';
// import 'streak_controller.dart';
import 'user_controller.dart';

class FoodController extends GetxController {
  FoodController({
    FoodApiService? api,
    MealsRepository? mealsRepository,
    CustomMealsRepository? customMealsRepository,
    MyFoodsRepository? myFoodsRepository,
    FavouriteMealsRepository? favouriteMealsRepository,
  }) : _api = api ?? FoodApiService(),
       _mealsRepository = mealsRepository ?? MealsRepository(),
       _customMealsRepository =
           customMealsRepository ?? CustomMealsRepository(),
       _myFoodsRepository = myFoodsRepository ?? MyFoodsRepository(),
       _favouriteMealsRepository =
           favouriteMealsRepository ?? FavouriteMealsRepository();

  final FoodApiService _api;
  final MealsRepository _mealsRepository;
  final CustomMealsRepository _customMealsRepository;
  final MyFoodsRepository _myFoodsRepository;
  final FavouriteMealsRepository _favouriteMealsRepository;

  static const int maxMealHistory = 15;
  static const int maxQuickMealsPerSection = 5;

  /// All logged meals keyed by day via [MealEntry.date].
  final RxList<MealEntry> entries = <MealEntry>[].obs;

  /// Meals returned by `GET /api/v1/meals` — source of truth for quick pickers.
  final RxList<MealEntry> apiMeals = <MealEntry>[].obs;

  /// Bumps on any add, update, or remove so UIs refresh beyond length changes.
  final RxInt entriesRevision = 0.obs;

  final RxString searchQuery = ''.obs;
  final RxString selectedMeal = MealType.breakfast.obs;
  final RxInt selectedGrams = 100.obs;
  final RxList<FoodItem> searchResults = <FoodItem>[].obs;
  final showRepeatYesterdayCard = true.obs;
  final RxList<SavedMealItem> favoriteMeals = <SavedMealItem>[].obs;
  final RxList<CustomMealPreset> customMealPresets = <CustomMealPreset>[].obs;
  final RxList<CustomFoodPreset> customFoodPresets = <CustomFoodPreset>[].obs;
  final RxMap<String, bool> expandedMeals = <String, bool>{}.obs;
  final RxList<MealEntry> repeatedYesterdayEntries = <MealEntry>[].obs;
  final RxSet<String> selectedYesterdayMeals = <String>{}.obs;

  /// Meal entry ids currently showing Delete_message.json on their card.
  final RxSet<String> deletingMealIds = <String>{}.obs;
  final RxList<MealLogGroup> _deletingGroups = <MealLogGroup>[].obs;
  final Set<String> _deleteCommitInFlight = <String>{};

  final RxBool isSearching = false.obs; 
  final RxBool isLoadingMealsApi = false.obs;
  final RxnString searchErrorMessage = RxnString();
  final RxnString mealsApiErrorMessage = RxnString();
  final Rx<DateTime> selectedLogDate = MealEntry.normalizeDate(
    DateTime.now(),
  ).obs;

  Timer? _debounce;
  final Set<String> _goalCelebratedDates = <String>{};
  Future<void>? _refreshMealsFuture;
  Future<void>? _refreshCustomMealsFuture;
  Future<void>? _refreshMyFoodsFuture;
  Future<void>? _refreshFavouritesFuture;
  DateTime? _lastCustomMealsFetchAt;
  DateTime? _lastMyFoodsFetchAt;
  DateTime? _lastFavouritesFetchAt;
  List<CustomMealPreset> _lastRemoteCustomMeals = const [];
  List<CustomFoodPreset> _lastRemoteMyFoods = const [];
  List<SavedMealItem> _lastRemoteFavourites = const [];
  String? _dismissedBreakfastSuggestionDate;
  static const Duration _listRefreshCooldown = Duration(seconds: 20);

  @override
  void onInit() {
    super.onInit();

    debugPrint("🔥 FoodController onInit called");

    unawaited(_bootstrapFromServer());
    unawaited(loadRepeatYesterdayCardState());
  }

  /// Wipe in-memory meals so logout never leaves the previous user's diary.
  void clearSessionData() {
    entries.clear();
    apiMeals.clear();
    favoriteMeals.clear();
    customMealPresets.clear();
    customFoodPresets.clear();
    searchResults.clear();
    repeatedYesterdayEntries.clear();
    selectedYesterdayMeals.clear();
    deletingMealIds.clear();
    _deletingGroups.clear();
    _deleteCommitInFlight.clear();
    _lastRemoteCustomMeals = const [];
    _lastRemoteMyFoods = const [];
    _lastRemoteFavourites = const [];
    _lastCustomMealsFetchAt = null;
    _lastMyFoodsFetchAt = null;
    _lastFavouritesFetchAt = null;
    searchErrorMessage.value = null;
    mealsApiErrorMessage.value = null;
    entriesRevision.value++;
    debugPrint('FoodController: session data cleared');
  }

  /// Pull fresh meals/catalog from the API after a new login.
  Future<void> reloadAfterLogin() => _bootstrapFromServer();

  /// Always start empty and pull meals/catalog from the API (no disk cache).
  Future<void> _bootstrapFromServer() async {
    entries.clear();
    favoriteMeals.clear();
    customMealPresets.clear();
    customFoodPresets.clear();
    entriesRevision.value++;

    await refreshMealsFromApi();
    await ensureLastLoggedMealsLoaded();
    await Future.wait([
      refreshFavouritesFromApi(force: true),
      refreshMyFoodsFromApi(force: true),
      refreshCustomMealsFromApi(force: true),
    ]);
  }

  Future<void> refreshFavouritesFromApi({bool force = false}) {
    if (_refreshFavouritesFuture != null) {
      return _refreshFavouritesFuture!;
    }
    if (!force &&
        _lastFavouritesFetchAt != null &&
        DateTime.now().difference(_lastFavouritesFetchAt!) <
            _listRefreshCooldown) {
      debugPrint(
        'FoodController: skipping GET ${ApiEndpoints.favouriteMeals} '
        '(recent fetch within ${_listRefreshCooldown.inSeconds}s)',
      );
      return Future<void>.value();
    }

    _refreshFavouritesFuture = _refreshFavouritesFromApi().whenComplete(() {
      _refreshFavouritesFuture = null;
    });
    return _refreshFavouritesFuture!;
  }

  Future<void> _refreshFavouritesFromApi() async {
    final accessToken = await _mealAccessToken();
    if (accessToken == null) {
      debugPrint(
        'FoodController: skipping GET ${ApiEndpoints.favouriteMeals} '
        '(no access token)',
      );
      return;
    }

    try {
      debugPrint(
        'FoodController: calling GET favourite-meals API at '
        '${ApiEndpoints.favouriteMealsUrl}',
      );
      final fetched = await _favouriteMealsRepository.fetchFavourites(
        accessToken: accessToken,
      );

      debugPrint(
        'FoodController: favourite-meals API returned ${fetched.length} items',
      );

      // Prefer server list; keep unsynced local favourites without a server id.
      final remoteKeys = {
        for (final item in fetched) item.storageKey,
      };
      final remoteNameMeals = {
        for (final item in fetched)
          '${item.food.name.trim().toLowerCase()}|${item.meal}',
      };
      final localOnly = favoriteMeals.where((local) {
        if (local.hasServerId) return false;
        final nameMeal =
            '${local.food.name.trim().toLowerCase()}|${local.meal}';
        return !remoteKeys.contains(local.storageKey) &&
            !remoteNameMeals.contains(nameMeal);
      });

      favoriteMeals.assignAll([...fetched, ...localOnly]);
      _lastRemoteFavourites = List<SavedMealItem>.unmodifiable(fetched);
      _lastFavouritesFetchAt = DateTime.now();
    } on FavouriteMealsApiException catch (error) {
      debugPrint('FoodController: favourite-meals GET failed: $error');
    } catch (error) {
      debugPrint('FoodController: favourite-meals GET failed: $error');
    }
  }

  Future<void> refreshMyFoodsFromApi({bool force = false}) {
    if (_refreshMyFoodsFuture != null) {
      return _refreshMyFoodsFuture!;
    }
    if (!force &&
        _lastMyFoodsFetchAt != null &&
        DateTime.now().difference(_lastMyFoodsFetchAt!) < _listRefreshCooldown) {
      debugPrint(
        'FoodController: skipping GET ${ApiEndpoints.myFoods} '
        '(recent fetch within ${_listRefreshCooldown.inSeconds}s)',
      );
      return Future<void>.value();
    }

    _refreshMyFoodsFuture = _refreshMyFoodsFromApi().whenComplete(() {
      _refreshMyFoodsFuture = null;
    });
    return _refreshMyFoodsFuture!;
  }

  Future<void> _refreshMyFoodsFromApi() async {
    final accessToken = await _mealAccessToken();
    if (accessToken == null) {
      debugPrint(
        'FoodController: skipping GET ${ApiEndpoints.myFoods} '
        '(no access token)',
      );
      return;
    }

    try {
      debugPrint(
        'FoodController: calling GET my-foods API at '
        '${ApiEndpoints.myFoodsUrl}',
      );
      final fetched = await _myFoodsRepository.fetchMyFoods(
        accessToken: accessToken,
      );

      debugPrint(
        'FoodController: my-foods API returned ${fetched.length} foods',
      );

      final localById = {
        for (final food in customFoodPresets) food.id: food,
      };
      final localByName = {
        for (final food in customFoodPresets)
          food.food.name.trim().toLowerCase(): food,
      };

      final merged = fetched.map((remote) {
        final local = localById[remote.id];
        if (local == null) {
          final byName = localByName[remote.food.name.trim().toLowerCase()];
          if (byName == null) return remote;
          return remote.copyWith(imageBytes: byName.imageBytes);
        }

        final remoteMacroCalories = (remote.food.carbs * 4 +
                remote.food.protein * 4 +
                remote.food.fat * 9)
            .round();
        final preferLocalCalories = local.food.caloriesPer100g > 0 &&
            (remote.food.caloriesPer100g <= 0 ||
                remote.food.caloriesPer100g == remoteMacroCalories);

        // Same id: keep local name/calories when the list payload lags behind
        // a successful PATCH (name rename + user-entered calories).
        return remote.copyWith(
          food: FoodItem(
            name: local.food.name.trim().isNotEmpty
                ? local.food.name
                : remote.food.name,
            caloriesPer100g: preferLocalCalories
                ? local.food.caloriesPer100g
                : remote.food.caloriesPer100g,
            protein: remote.food.protein,
            carbs: remote.food.carbs,
            fat: remote.food.fat,
            emoji: local.food.emoji.isNotEmpty
                ? local.food.emoji
                : remote.food.emoji,
            imageUrl: local.food.imageUrl ?? remote.food.imageUrl,
          ),
          servingQuantity: local.servingQuantity ?? remote.servingQuantity,
          servingUnit: local.servingUnit.isNotEmpty
              ? local.servingUnit
              : remote.servingUnit,
          nutritionBasisQuantity:
              local.nutritionBasisQuantity ?? remote.nutritionBasisQuantity,
          imageBytes: local.imageBytes,
        );
      }).toList();

      // Keep unsynced local foods that the server does not know about yet.
      final remoteIds = {for (final food in merged) food.id};
      final remoteNames = {
        for (final food in merged) food.food.name.trim().toLowerCase(),
      };
      for (final local in customFoodPresets) {
        final nameKey = local.food.name.trim().toLowerCase();
        if (remoteIds.contains(local.id) || remoteNames.contains(nameKey)) {
          continue;
        }
        merged.add(local);
      }

      customFoodPresets.assignAll(merged);
      _lastRemoteMyFoods = List<CustomFoodPreset>.unmodifiable(fetched);
      _lastMyFoodsFetchAt = DateTime.now();
    } on MyFoodsApiException catch (error) {
      debugPrint('FoodController: my-foods API fetch failed: $error');
    } catch (error) {
      debugPrint('FoodController: my-foods API fetch failed: $error');
    }
  }

  Future<void> refreshCustomMealsFromApi({bool force = false}) {
    if (_refreshCustomMealsFuture != null) {
      debugPrint(
        'FoodController: reusing in-flight GET my-meals '
        '(no new network call)',
      );
      return _refreshCustomMealsFuture!;
    }
    if (!force &&
        _lastCustomMealsFetchAt != null &&
        DateTime.now().difference(_lastCustomMealsFetchAt!) <
            _listRefreshCooldown) {
      debugPrint(
        'FoodController: skipping GET my-meals '
        '(cooldown ${_listRefreshCooldown.inSeconds}s, last fetch '
        '${DateTime.now().difference(_lastCustomMealsFetchAt!).inSeconds}s ago)',
      );
      return Future<void>.value();
    }

    debugPrint(
      'FoodController: scheduling GET my-meals '
      '(force=$force onInitOrCaller)',
    );
    _refreshCustomMealsFuture = _refreshCustomMealsFromApi().whenComplete(() {
      _refreshCustomMealsFuture = null;
    });
    return _refreshCustomMealsFuture!;
  }

  Future<void> _refreshCustomMealsFromApi() async {
    final accessToken = await _mealAccessToken();
    if (accessToken == null) {
      debugPrint(
        'FoodController: skipping GET ${ApiEndpoints.myMeals} '
        '(no access token)',
      );
      return;
    }

    try {
      final fetched = await _customMealsRepository.fetchCustomMeals(
        accessToken: accessToken,
      );

      debugPrint(
        'FoodController: my-meals list applied '
        '(${fetched.length} templates from network)',
      );

      final localById = {for (final meal in customMealPresets) meal.id: meal};
      final localByNameAndSlot = {
        for (final meal in customMealPresets)
          '${meal.meal.toLowerCase()}|${meal.name.trim().toLowerCase()}': meal,
      };
      final merged = fetched.map((remote) {
        final local =
            localById[remote.id] ??
            localByNameAndSlot['${remote.meal.toLowerCase()}|${remote.name.trim().toLowerCase()}'];
        if (local == null) return remote;

        final items = remote.items.map((remoteItem) {
          SavedMealItem? localItem;
          for (final candidate in local.items) {
            if (candidate.food.name.trim().toLowerCase() ==
                remoteItem.food.name.trim().toLowerCase()) {
              localItem = candidate;
              break;
            }
          }
          if (localItem == null) return remoteItem;
          return remoteItem.copyWith(
            servingQuantity: localItem.servingQuantity,
            servingUnit: localItem.servingUnit,
            nutritionBasisQuantity: localItem.nutritionBasisQuantity,
            basisCarbs: localItem.basisCarbs,
            basisProtein: localItem.basisProtein,
            basisFat: localItem.basisFat,
          );
        }).toList();

        return remote.copyWith(items: items, imageBytes: local.imageBytes);
      }).toList();

      // Keep unsynced local meals the server does not know about yet.
      final remoteIds = {for (final meal in merged) meal.id};
      final remoteKeys = {
        for (final meal in merged)
          '${meal.meal.toLowerCase()}|${meal.name.trim().toLowerCase()}',
      };
      for (final local in customMealPresets) {
        final key =
            '${local.meal.toLowerCase()}|${local.name.trim().toLowerCase()}';
        if (remoteIds.contains(local.id) || remoteKeys.contains(key)) {
          continue;
        }
        merged.add(local);
      }

      customMealPresets.assignAll(merged);
      _lastRemoteCustomMeals = List<CustomMealPreset>.unmodifiable(fetched);
      _lastCustomMealsFetchAt = DateTime.now();
    } on CustomMealsApiException catch (error) {
      debugPrint('FoodController: custom meals API fetch failed: $error');
    } catch (error) {
      debugPrint('FoodController: custom meals API fetch failed: $error');
    }
  }

  /// Unique meals from past logs, most recent first.
  List<SavedMealItem> get mealHistory {
    entriesRevision.value;
    return SavedMealItem.historyFromEntries(
      entries.toList(),
      limit: maxMealHistory,
    );
  }

  List<SavedMealItem> mealHistoryFor(String meal) {
    entriesRevision.value;
    return SavedMealItem.historyFromEntries(
      entries.toList(),
      limit: maxMealHistory,
      meal: meal,
    );
  }

  int get lastLoggedMealCount => getLastLoggedMeals().length;

  int get lastLoggedCalories {
    return getLastLoggedMeals().fold(0, (sum, meal) => sum + meal.calories);
  }

  bool get canRepeatYesterday => getLastLoggedMeals().isNotEmpty;

  bool get hasRepeatedYesterdayMeals => repeatedYesterdayEntries.isNotEmpty;

  bool get isBreakfastSuggestionDismissed {
    final todayKey = MealEntry.dateToKey(DateTime.now());
    return _dismissedBreakfastSuggestionDate == todayKey;
  }

  MealSuggestion? get breakfastSuggestion {
    entriesRevision.value;
    if (!_isToday(selectedLogDate.value)) return null;
    if (mealsForSelectedDate(MealType.breakfast).isNotEmpty) return null;
    if (isBreakfastSuggestionDismissed) return null;

    final yesterday = selectedLogDate.value.subtract(const Duration(days: 1));
    final yesterdayBreakfast = mealsForDate(yesterday, MealType.breakfast);
    if (yesterdayBreakfast.isNotEmpty) {
      final items = yesterdayBreakfast
          .map(SavedMealItem.fromMealEntry)
          .toList();
      return MealSuggestion(
        meal: MealType.breakfast,
        title: items.map((item) => item.food.name).join(' + '),
        calories: items.fold(0, (sum, item) => sum + item.calories),
        items: items,
        subtitle: 'You usually have this for breakfast',
      );
    }

    final history = mealHistoryFor(MealType.breakfast);
    if (history.isEmpty) return null;

    final item = history.first;
    return MealSuggestion(
      meal: MealType.breakfast,
      title: item.food.name,
      calories: item.calories,
      items: [item],
      subtitle: 'You usually have this for breakfast',
    );
  }

  List<SavedMealItem> quickMealsFor(String meal) {
    entriesRevision.value;
    apiMeals.length;
    favoriteMeals.length;
    isLoadingMealsApi.value;

    final seen = <String>{};
    final result = <SavedMealItem>[];

    for (final favorite in favoriteMeals.where((item) => item.meal == meal)) {
      if (seen.add(favorite.storageKey)) {
        result.add(favorite);
      }
    }

    for (final item in _apiMealHistoryFor(meal)) {
      if (seen.add(item.storageKey)) {
        result.add(item);
      }
    }

    if (result.length > maxQuickMealsPerSection) {
      return result.sublist(0, maxQuickMealsPerSection);
    }
    return result;
  }

  List<SavedMealItem> _apiMealHistoryFor(String meal) {
    return SavedMealItem.historyFromEntries(
      apiMeals.toList(),
      limit: maxMealHistory,
      meal: meal,
    );
  }

  /// Loads meal history from `GET /api/v1/meals` for quick-item pickers.
  Future<void> refreshQuickItemsFromApi() => refreshMealsFromApi();

  /// Last [maxQuickMealsPerSection] unique meals from `GET /api/v1/meals`.
  List<SavedMealItem> get recentQuickMeals {
    apiMeals.length;
    isLoadingMealsApi.value;
    return SavedMealItem.historyFromEntries(
      apiMeals.toList(),
      limit: maxQuickMealsPerSection,
    );
  }

  /// Most recently logged unique meals for a meal slot (from API history).
  List<SavedMealItem> recentMealsFor(
    String meal, {
    int limit = maxQuickMealsPerSection,
  }) {
    apiMeals.length;
    isLoadingMealsApi.value;
    final history = _apiMealHistoryFor(meal);
    if (history.length <= limit) return history;
    return history.sublist(0, limit);
  }

  bool isFavorite(SavedMealItem item) {
    return favoriteMeals.any((favorite) => favorite.matchesFavorite(item));
  }

  bool isFavoriteFood(FoodItem food, String meal) {
    return favoriteMeals.any((item) => item.matchesFoodAndMeal(food, meal));
  }

  Future<void> toggleFavorite(SavedMealItem item) async {
    final index = favoriteMeals.indexWhere(
      (favorite) => favorite.matchesFavorite(item),
    );

    if (index >= 0) {
      final existing = favoriteMeals[index];
      favoriteMeals.removeAt(index);
      unawaited(_syncDeleteFavourite(existing));
      return;
    }

    favoriteMeals.insert(0, item);
    unawaited(_syncAddFavourite(item));
  }

  Future<void> toggleFavoriteFood({
    required FoodItem food,
    required int grams,
    required String meal,
  }) async {
    await toggleFavorite(SavedMealItem(food: food, grams: grams, meal: meal));
  }

  Future<void> removeFavorite(SavedMealItem item) async {
    SavedMealItem existing = item;
    for (final favorite in favoriteMeals) {
      if (favorite.matchesFavorite(item)) {
        existing = favorite;
        break;
      }
    }
    favoriteMeals.removeWhere((favorite) => favorite.matchesFavorite(item));
    unawaited(_syncDeleteFavourite(existing));
  }

  Future<void> _syncAddFavourite(SavedMealItem item) async {
    final accessToken = await _mealAccessToken();
    if (accessToken == null) {
      debugPrint(
        'FoodController: skipping POST ${ApiEndpoints.favouriteMeals} '
        '(no access token)',
      );
      return;
    }

    try {
      debugPrint(
        'FoodController: calling POST favourite-meals API at '
        '${ApiEndpoints.favouriteMealsUrl}',
      );
      final synced = await _favouriteMealsRepository.addFavourite(
        accessToken: accessToken,
        item: item,
      );

      final index = favoriteMeals.indexWhere(
        (favorite) =>
            favorite.matchesFavorite(item) || favorite.matchesFavorite(synced),
      );
      if (index >= 0) {
        favoriteMeals[index] = synced;
      } else {
        favoriteMeals.insert(0, synced);
      }
      _lastFavouritesFetchAt = DateTime.now();
    } on FavouriteMealsApiException catch (error) {
      debugPrint('FoodController: favourite-meals POST failed: $error');
      AppSnackbar.error(
        error.message.isNotEmpty
            ? error.message
            : 'Could not save ${item.food.name} to favourites.',
        title: 'Save failed',
      );
    } catch (error) {
      debugPrint('FoodController: favourite-meals POST failed: $error');
    }
  }

  Future<void> _syncDeleteFavourite(SavedMealItem item) async {
    final favouriteId = item.hasServerId
        ? item.id!.trim()
        : await _resolveServerFavouriteId(item);
    if (favouriteId == null) return;

    final accessToken = await _mealAccessToken();
    if (accessToken == null) {
      debugPrint(
        'FoodController: skipping DELETE '
        '${ApiEndpoints.favouriteMeals}/$favouriteId (no access token)',
      );
      return;
    }

    try {
      await _favouriteMealsRepository.deleteFavourite(
        accessToken: accessToken,
        favouriteMealId: favouriteId,
      );
      _lastFavouritesFetchAt = DateTime.now();
    } on FavouriteMealsApiException catch (error) {
      debugPrint('FoodController: favourite-meals DELETE failed: $error');
    } catch (error) {
      debugPrint('FoodController: favourite-meals DELETE failed: $error');
    }
  }

  Future<String?> _resolveServerFavouriteId(SavedMealItem item) async {
    if (item.hasServerId) return item.id!.trim();

    SavedMealItem? matchIn(Iterable<SavedMealItem> items) {
      for (final candidate in items) {
        if (!candidate.hasServerId) continue;
        if (candidate.matchesFavorite(item) ||
            (candidate.food.name.trim().toLowerCase() ==
                    item.food.name.trim().toLowerCase() &&
                candidate.meal == item.meal)) {
          return candidate;
        }
      }
      return null;
    }

    final cached = matchIn(_lastRemoteFavourites) ?? matchIn(favoriteMeals);
    if (cached != null) return cached.id!.trim();

    final accessToken = await _mealAccessToken();
    if (accessToken == null) return null;

    try {
      final remote = await _favouriteMealsRepository.fetchFavourites(
        accessToken: accessToken,
      );
      _lastRemoteFavourites = List<SavedMealItem>.unmodifiable(remote);
      _lastFavouritesFetchAt = DateTime.now();
      return matchIn(remote)?.id?.trim();
    } catch (_) {
      return null;
    }
  }

  /// Logs a favourite locally and via `POST .../favourite-meals/:id/log`.
  void logFavouriteMeal(
    SavedMealItem item, {
    String? meal,
    DateTime? date,
  }) {
    final mealSlot = meal ?? item.meal;
    final day = MealEntry.normalizeDate(date ?? selectedLogDate.value);
    final entry = item.copyWith(meal: mealSlot).toMealEntry(date: day);
    _insertEntry(entry, syncToServer: false);
    unawaited(_syncLogFavourite(item.copyWith(meal: mealSlot), entry: entry));
  }

  Future<void> _syncLogFavourite(
    SavedMealItem item, {
    required MealEntry entry,
  }) async {
    final favouriteId = item.hasServerId
        ? item.id!.trim()
        : await _resolveServerFavouriteId(item);

    final accessToken = await _mealAccessToken();
    if (accessToken == null || favouriteId == null) {
      await _syncCreateMeal(entry);
      return;
    }

    try {
      await _favouriteMealsRepository.logFavourite(
        accessToken: accessToken,
        favouriteMealId: favouriteId,
        item: item,
        date: entry.date,
        mealtime: entry.meal,
      );
      // Local entry already mirrors the log; skip full GET /meals refresh.
    } on FavouriteMealsApiException catch (error) {
      debugPrint('FoodController: favourite-meals log failed: $error');
      await _syncCreateMeal(entry);
    } catch (error) {
      debugPrint('FoodController: favourite-meals log failed: $error');
      await _syncCreateMeal(entry);
    }
  }

  Future<CustomMealPreset> saveCustomMealPreset(
    CustomMealPreset preset, {
    bool awaitSync = true,
    bool? isUpdate,
  }) async {
    final index = customMealPresets.indexWhere((meal) => meal.id == preset.id);
    final previous = index >= 0 ? customMealPresets[index] : null;
    final updating = isUpdate ?? previous != null;

    if (index >= 0) {
      customMealPresets[index] = preset;
    } else {
      customMealPresets.insert(0, preset);
    }

    for (final item in preset.items) {
      if (!isFavorite(item)) {
        favoriteMeals.insert(0, item);
      }
    }


    if (awaitSync) {
      return _syncCustomMealPreset(
        preset,
        previous: previous,
        isUpdate: updating,
      );
    }

    unawaited(
      _syncCustomMealPreset(
        preset,
        previous: previous,
        isUpdate: updating,
      ),
    );
    return preset;
  }

  Future<CustomFoodPreset> saveCustomFoodPreset(
    CustomFoodPreset preset, {
    String? mealtime,
    bool awaitSync = true,
    bool? isUpdate,
  }) async {
    final index = customFoodPresets.indexWhere((food) => food.id == preset.id);
    final previous = index >= 0 ? customFoodPresets[index] : null;
    final updating = isUpdate ?? previous != null;

    if (index >= 0) {
      customFoodPresets[index] = preset;
    } else {
      customFoodPresets.insert(0, preset);
    }

    final mealSlot = mealtime ?? selectedMeal.value;
    if (awaitSync) {
      return _syncCustomFoodPreset(
        preset,
        mealtime: mealSlot,
        previous: previous,
        isUpdate: updating,
      );
    }

    unawaited(
      _syncCustomFoodPreset(
        preset,
        mealtime: mealSlot,
        previous: previous,
        isUpdate: updating,
      ),
    );
    return preset;
  }

  Future<void> removeCustomFoodPreset(String id) async {
    CustomFoodPreset? removed;
    for (final food in customFoodPresets) {
      if (food.id == id) {
        removed = food;
        break;
      }
    }

    customFoodPresets.removeWhere((food) => food.id == id);

    final synced = await _syncDeleteMyFood(
      id,
      name: removed?.food.name,
    );
    if (!synced) {
      if (removed != null &&
          customFoodPresets.every((food) => food.id != removed!.id)) {
        customFoodPresets.insert(0, removed);
      }
      throw MyFoodsApiException(
        'Could not delete "${removed?.food.name ?? 'food'}" on the server.',
      );
    }
  }

  /// Logs a My Food item locally and via `POST /api/v1/my-foods/:id/log`.
  void logMyFood(
    CustomFoodPreset preset, {
    String? meal,
    DateTime? date,
  }) {
    final mealSlot = meal ?? selectedMeal.value;
    final day = MealEntry.normalizeDate(date ?? selectedLogDate.value);
    final entry = SavedMealItem(
      food: preset.food,
      grams: preset.defaultGrams,
      meal: mealSlot,
      servingQuantity: preset.servingQuantity,
      servingUnit: preset.servingUnit,
      nutritionBasisQuantity: preset.nutritionBasisQuantity,
      basisCarbs: preset.food.carbs,
      basisProtein: preset.food.protein,
      basisFat: preset.food.fat,
    ).toMealEntry(date: day);

    _insertEntry(entry, syncToServer: false);
    unawaited(_syncLogMyFood(preset, entry: entry));
  }

  Future<CustomFoodPreset> _syncCustomFoodPreset(
    CustomFoodPreset preset, {
    required String mealtime,
    CustomFoodPreset? previous,
    bool isUpdate = false,
  }) async {
    final accessToken = await _mealAccessToken();
    if (accessToken == null) {
      debugPrint(
        'FoodController: skipping my-foods sync '
        '(no access token — sign in required)',
      );
      AppSnackbar.info(
        '${preset.food.name} was saved on this device. '
        'Sign in to sync to the server.',
        title: 'Saved locally',
      );
      return preset;
    }

    try {
      final serverId = await _serverMyFoodIdForSync(
        accessToken: accessToken,
        preset: preset,
        previous: previous,
      );
      late final CustomFoodPreset synced;

      if (serverId != null) {
        debugPrint(
          'FoodController: calling PATCH my-foods API at '
          '${ApiEndpoints.myFoodByIdUrl(serverId)} '
          '(isUpdate=$isUpdate localId=${preset.id})',
        );
        synced = await _myFoodsRepository.updateMyFood(
          accessToken: accessToken,
          myFoodId: serverId,
          preset: preset.copyWith(id: serverId),
          mealtime: mealtime,
        );
      } else if (isUpdate) {
        debugPrint(
          'FoodController: edit sync skipped POST for "${preset.food.name}" '
          '(no server my-food id resolved for localId=${preset.id})',
        );
        AppSnackbar.error(
          'Could not update ${preset.food.name} on the server.',
          title: 'Save failed',
        );
        return preset;
      } else {
        debugPrint(
          'FoodController: calling POST my-foods API at '
          '${ApiEndpoints.myFoodsUrl}',
        );
        synced = await _myFoodsRepository.saveMyFood(
          accessToken: accessToken,
          preset: preset,
          mealtime: mealtime,
        );
      }

      final index = customFoodPresets.indexWhere(
        (food) => food.id == preset.id || food.id == synced.id,
      );
      if (index >= 0) {
        customFoodPresets[index] = synced;
      } else {
        customFoodPresets.insert(0, synced);
      }

      _lastRemoteMyFoods = [
        for (final food in _lastRemoteMyFoods)
          if (food.id != synced.id) food,
        synced,
      ];
      return synced;
    } on MyFoodsApiException catch (error) {
      debugPrint('FoodController: my-foods API failed: $error');
      AppSnackbar.error(
        error.message.isNotEmpty
            ? error.message
            : 'Could not save ${preset.food.name} on the server.',
        title: 'Save failed',
      );
      return preset;
    } catch (error) {
      debugPrint('FoodController: my-foods API failed: $error');
      AppSnackbar.error(
        'Could not save ${preset.food.name} on the server.',
        title: 'Save failed',
      );
      return preset;
    }
  }

  Future<String?> _serverMyFoodIdForSync({
    required String accessToken,
    required CustomFoodPreset preset,
    CustomFoodPreset? previous,
  }) async {
    if (!_looksLikeLocalMealId(preset.id)) {
      return preset.id.trim();
    }

    final resolveName = previous?.food.name ?? preset.food.name;
    var serverId = await _resolveServerMyFoodId(
      accessToken: accessToken,
      localId: preset.id,
      name: resolveName,
    );
    if (serverId != null) return serverId;

    if (previous != null &&
        previous.food.name.trim().toLowerCase() !=
            preset.food.name.trim().toLowerCase()) {
      return _resolveServerMyFoodId(
        accessToken: accessToken,
        localId: preset.id,
        name: preset.food.name,
      );
    }

    return null;
  }

  Future<void> _syncLogMyFood(
    CustomFoodPreset preset, {
    required MealEntry entry,
  }) async {
    final accessToken = await _mealAccessToken();
    if (accessToken == null) {
      // No auth — fall back to standard meals create sync.
      await _syncCreateMeal(entry);
      return;
    }

    var serverId = preset.id;
    if (_looksLikeLocalMealId(serverId)) {
      final resolved = await _resolveServerMyFoodId(
        accessToken: accessToken,
        localId: preset.id,
        name: preset.food.name,
      );
      if (resolved != null) {
        serverId = resolved;
        final index = customFoodPresets.indexWhere(
          (food) => food.id == preset.id,
        );
        if (index >= 0) {
          customFoodPresets[index] = customFoodPresets[index].copyWith(
            id: resolved,
          );
        }
      }
    }

    try {
      debugPrint(
        'FoodController: calling POST my-foods log API at '
        '${ApiEndpoints.myFoodLogUrl(serverId)}',
      );
      await _myFoodsRepository.logMyFood(
        accessToken: accessToken,
        myFoodId: serverId,
        preset: preset,
        date: entry.date,
        mealtime: entry.meal,
      );
      // Local entry already mirrors the log; skip full GET /meals refresh.
    } on MyFoodsApiException catch (error) {
      debugPrint('FoodController: my-foods log API failed: $error');
      // Fall back to logging via the regular meals endpoint.
      await _syncCreateMeal(entry);
    } catch (error) {
      debugPrint('FoodController: my-foods log API failed: $error');
      await _syncCreateMeal(entry);
    }
  }

  /// Returns `true` when the server delete succeeded (or food was already gone).
  Future<bool> _syncDeleteMyFood(
    String myFoodId, {
    String? name,
  }) async {
    final accessToken = await _mealAccessToken();
    if (accessToken == null) {
      debugPrint(
        'FoodController: skipping DELETE ${ApiEndpoints.myFoods}/$myFoodId '
        '(no access token — removed locally only)',
      );
      return true;
    }

    var serverId = myFoodId;
    if (_looksLikeLocalMealId(myFoodId)) {
      final resolved = await _resolveServerMyFoodId(
        accessToken: accessToken,
        localId: myFoodId,
        name: name,
      );
      if (resolved == null) {
        debugPrint(
          'FoodController: no server my-food id for local id=$myFoodId '
          'name=$name — treating as local-only delete',
        );
        return true;
      }
      serverId = resolved;
    }

    try {
      debugPrint(
        'FoodController: calling DELETE my-foods API at '
        '${ApiEndpoints.myFoodByIdUrl(serverId)}',
      );
      await _myFoodsRepository.deleteMyFood(
        accessToken: accessToken,
        myFoodId: serverId,
      );
      _lastMyFoodsFetchAt = DateTime.now();
      return true;
    } on MyFoodsApiException catch (error) {
      if (error.statusCode == 404) {
        debugPrint(
          'FoodController: my-foods delete returned 404 for $serverId '
          '(already deleted)',
        );
        return true;
      }

      // Invalid/local id — resolve via list and retry once.
      if (error.statusCode == 400 && name != null && name.trim().isNotEmpty) {
        final resolved = await _resolveServerMyFoodId(
          accessToken: accessToken,
          localId: myFoodId,
          name: name,
        );
        if (resolved != null && resolved != serverId) {
          debugPrint(
            'FoodController: retrying DELETE my-foods with resolved id '
            '$resolved (was $serverId)',
          );
          try {
            await _myFoodsRepository.deleteMyFood(
              accessToken: accessToken,
              myFoodId: resolved,
            );
            return true;
          } on MyFoodsApiException catch (retryError) {
            if (retryError.statusCode == 404) return true;
            debugPrint(
              'FoodController: my-foods delete retry failed: $retryError',
            );
            return false;
          }
        }
      }

      debugPrint('FoodController: my-foods delete API failed: $error');
      return false;
    } catch (error) {
      debugPrint('FoodController: my-foods delete API failed: $error');
      return false;
    }
  }

  Future<String?> _resolveServerMyFoodId({
    required String accessToken,
    required String localId,
    String? name,
  }) async {
    String? matchIn(List<CustomFoodPreset> foods) {
      final nameKey = name?.trim().toLowerCase();

      for (final food in foods) {
        if (food.id == localId) return food.id;
      }
      if (nameKey == null || nameKey.isEmpty) return null;

      for (final food in foods) {
        if (_looksLikeLocalMealId(food.id)) continue;
        if (food.food.name.trim().toLowerCase() == nameKey) {
          return food.id;
        }
      }
      return null;
    }

    final cached = matchIn(_lastRemoteMyFoods);
    if (cached != null) return cached;

    try {
      final remote = await _myFoodsRepository.fetchMyFoods(
        accessToken: accessToken,
      );
      _lastRemoteMyFoods = List<CustomFoodPreset>.unmodifiable(remote);
      _lastMyFoodsFetchAt = DateTime.now();
      return matchIn(remote);
    } catch (error) {
      debugPrint(
        'FoodController: failed resolving server my-food id: $error',
      );
    }
    return null;
  }

  Future<CustomMealPreset> _syncCustomMealPreset(
    CustomMealPreset preset, {
    CustomMealPreset? previous,
    bool isUpdate = false,
  }) async {
    final accessToken = await _mealAccessToken();
    if (accessToken == null) {
      debugPrint(
        'FoodController: skipping my-meals sync '
        '(no access token — sign in required)',
      );
      AppSnackbar.info(
        '${preset.name} was saved on this device. Sign in to sync to the server.',
        title: 'Saved locally',
      );
      return preset;
    }

    try {
      final serverId = await _serverMyMealIdForSync(
        accessToken: accessToken,
        preset: preset,
        previous: previous,
      );
      late final CustomMealPreset synced;

      if (serverId != null) {
        debugPrint(
          'FoodController: calling PATCH my-meals API at '
          '${ApiEndpoints.myMealByIdUrl(serverId)} '
          '(isUpdate=$isUpdate localId=${preset.id})',
        );
        synced = await _customMealsRepository.updateCustomMeal(
          accessToken: accessToken,
          myMealId: serverId,
          preset: preset.copyWith(id: serverId),
        );
      } else if (isUpdate) {
        // Editing an existing meal — never POST a duplicate.
        debugPrint(
          'FoodController: edit sync skipped POST for "${preset.name}" '
          '(no server my-meal id resolved for localId=${preset.id})',
        );
        AppSnackbar.error(
          'Could not update ${preset.name} on the server.',
          title: 'Save failed',
        );
        return preset;
      } else {
        debugPrint(
          'FoodController: calling POST my-meals API at '
          '${ApiEndpoints.myMealsUrl} '
          '(isUpdate=$isUpdate localId=${preset.id})',
        );
        synced = await _customMealsRepository.createCustomMeal(
          accessToken: accessToken,
          preset: preset,
        );
      }

      final index = customMealPresets.indexWhere(
        (meal) => meal.id == preset.id || meal.id == synced.id,
      );
      if (index >= 0) {
        customMealPresets[index] = synced;
      } else {
        customMealPresets.insert(0, synced);
      }

      _lastCustomMealsFetchAt = DateTime.now();
      _rememberRemoteCustomMeal(synced);
      return synced;
    } on CustomMealsApiException catch (error) {
      debugPrint('FoodController: custom meal API failed: $error');
      AppSnackbar.error(
        'Could not save ${preset.name} on the server.',
        title: 'Save failed',
      );
      return preset;
    } catch (error) {
      debugPrint('FoodController: custom meal API failed: $error');
      AppSnackbar.error(
        'Could not save ${preset.name} on the server.',
        title: 'Save failed',
      );
      return preset;
    }
  }

  /// Resolves the server my-meal id for create-vs-update sync.
  ///
  /// Uses the pre-edit name/slot when present so renames still PATCH.
  Future<String?> _serverMyMealIdForSync({
    required String accessToken,
    required CustomMealPreset preset,
    CustomMealPreset? previous,
  }) async {
    if (!_looksLikeLocalMealId(preset.id)) {
      return preset.id.trim();
    }

    final resolveName = previous?.name ?? preset.name;
    final resolveMeal = previous?.meal;

    var serverId = await _resolveServerMyMealId(
      accessToken: accessToken,
      localId: preset.id,
      name: resolveName,
      mealTime: resolveMeal,
    );
    if (serverId != null) return serverId;

    // Meal slot may have changed during edit — match by name only.
    if (resolveMeal != null && resolveMeal.trim().isNotEmpty) {
      serverId = await _resolveServerMyMealId(
        accessToken: accessToken,
        localId: preset.id,
        name: resolveName,
        mealTime: null,
      );
      if (serverId != null) return serverId;
    }

    // Last try: new name after rename (in case previous name was never synced).
    if (previous != null &&
        previous.name.trim().toLowerCase() !=
            preset.name.trim().toLowerCase()) {
      return _resolveServerMyMealId(
        accessToken: accessToken,
        localId: preset.id,
        name: preset.name,
        mealTime: null,
      );
    }

    return null;
  }

  void _rememberRemoteCustomMeal(CustomMealPreset meal) {
    if (_looksLikeLocalMealId(meal.id)) return;
    final next = <CustomMealPreset>[
      for (final existing in _lastRemoteCustomMeals)
        if (existing.id != meal.id) existing,
      meal,
    ];
    _lastRemoteCustomMeals = List<CustomMealPreset>.unmodifiable(next);
  }

  Future<void> removeCustomMealPreset(String id) async {
    CustomMealPreset? removed;
    for (final meal in customMealPresets) {
      if (meal.id == id) {
        removed = meal;
        break;
      }
    }

    customMealPresets.removeWhere((meal) => meal.id == id);

    final synced = await _syncDeleteMyMeal(
      id,
      name: removed?.name,
      mealTime: removed?.meal,
    );
    if (!synced) {
      // Put it back if the server delete failed so the UI stays truthful.
      if (removed != null &&
          customMealPresets.every((meal) => meal.id != removed!.id)) {
        customMealPresets.insert(0, removed);
      }
      throw CustomMealsApiException(
        'Could not delete "${removed?.name ?? 'meal'}" on the server.',
      );
    }
  }

  /// Returns `true` when the server delete succeeded (or meal was already gone).
  Future<bool> _syncDeleteMyMeal(
    String myMealId, {
    String? name,
    String? mealTime,
  }) async {
    final accessToken = await _mealAccessToken();
    if (accessToken == null) {
      debugPrint(
        'FoodController: skipping DELETE ${ApiEndpoints.myMeals}/$myMealId '
        '(no access token — removed locally only)',
      );
      return true;
    }

    var serverId = myMealId;
    if (_looksLikeLocalMealId(myMealId)) {
      final resolved = await _resolveServerMyMealId(
        accessToken: accessToken,
        localId: myMealId,
        name: name,
        mealTime: mealTime,
      );
      if (resolved == null) {
        debugPrint(
          'FoodController: no server my-meal id for local id=$myMealId '
          'name=$name — treating as local-only delete',
        );
        // Never synced to server; local remove is enough.
        return true;
      }
      serverId = resolved;
    }

    try {
      debugPrint(
        'FoodController: calling DELETE my-meals API at '
        '${ApiEndpoints.myMealByIdUrl(serverId)}',
      );
      await _customMealsRepository.deleteCustomMeal(
        accessToken: accessToken,
        myMealId: serverId,
      );
      _lastCustomMealsFetchAt = DateTime.now();
      return true;
    } on CustomMealsApiException catch (error) {
      // Already gone on the server — treat as success.
      if (error.statusCode == 404) {
        debugPrint(
          'FoodController: my-meals delete returned 404 for $serverId '
          '(already deleted)',
        );
        return true;
      }
      debugPrint('FoodController: my-meals delete API failed: $error');
      return false;
    } catch (error) {
      debugPrint('FoodController: my-meals delete API failed: $error');
      return false;
    }
  }

  Future<String?> _resolveServerMyMealId({
    required String accessToken,
    required String localId,
    String? name,
    String? mealTime,
  }) async {
    String? matchIn(List<CustomMealPreset> meals) {
      final nameKey = name?.trim().toLowerCase();
      final mealKey = mealTime?.trim().toLowerCase();

      for (final meal in meals) {
        if (meal.id == localId) return meal.id;
      }
      if (nameKey == null || nameKey.isEmpty) return null;

      for (final meal in meals) {
        if (_looksLikeLocalMealId(meal.id)) continue;
        final sameName = meal.name.trim().toLowerCase() == nameKey;
        final sameMeal = mealKey == null ||
            mealKey.isEmpty ||
            meal.meal.trim().toLowerCase() == mealKey;
        if (sameName && sameMeal) return meal.id;
      }
      return null;
    }

    // Prefer the last successful list response — avoids another GET.
    final cached = matchIn(_lastRemoteCustomMeals);
    if (cached != null) return cached;

    try {
      final remote = await _customMealsRepository.fetchCustomMeals(
        accessToken: accessToken,
      );
      _lastRemoteCustomMeals = List<CustomMealPreset>.unmodifiable(remote);
      _lastCustomMealsFetchAt = DateTime.now();
      return matchIn(remote);
    } catch (error) {
      debugPrint(
        'FoodController: failed resolving server my-meal id: $error',
      );
    }
    return null;
  }

  bool _looksLikeLocalMealId(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return true;
    final value = int.tryParse(trimmed);
    if (value == null) return false;
    // Local ids use DateTime epoch millis (~1e12) or micros (~1e15).
    return value >= 1000000000000;
  }

  void logCustomMealPreset(
    CustomMealPreset preset, {
    String? meal,
    DateTime? date,
  }) {
    final targetMeal = meal ?? preset.meal;
    for (final item in preset.items) {
      logFromHistory(
        item.copyWith(meal: targetMeal),
        meal: targetMeal,
        date: date,
      );
    }
  }

  void toggleMealExpanded(String meal) {
    expandedMeals[meal] = !isMealExpanded(meal);
  }

  bool isMealExpanded(String meal) {
    return expandedMeals[meal] ?? true;
  }

  Future<void> dismissBreakfastSuggestion() async {
    final todayKey = MealEntry.dateToKey(DateTime.now());
    _dismissedBreakfastSuggestionDate = todayKey;
    entriesRevision.value++;
  }

  void logItems(List<SavedMealItem> items, {DateTime? date}) {
    final target = date ?? selectedLogDate.value;
    for (final item in items) {
      _insertEntry(item.toMealEntry(date: target));
    }
  }

  void logSuggestion(MealSuggestion suggestion) {
    logItems(suggestion.items);
  }

  Future<void> refreshMealsFromApi({
    DateTime? date,
    String? period,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    // Never coalesce onto an in-flight GET with different args — that can
    // restore a stale list and wipe an optimistic create/delete.
    final inFlight = _refreshMealsFuture;
    if (inFlight != null) {
      return inFlight.then(
        (_) => refreshMealsFromApi(
          date: date,
          period: period,
          fromDate: fromDate,
          toDate: toDate,
        ),
      );
    }

    _refreshMealsFuture = _refreshMealsFromApi(
      date: date,
      period: period,
      fromDate: fromDate,
      toDate: toDate,
    ).whenComplete(() {
      _refreshMealsFuture = null;
    });

    return _refreshMealsFuture!;
  }

  /// Loads meals for [start]..[end] in one request (`period=custom`).
  Future<void> refreshMealsForDateRange(DateTime start, DateTime end) async {
    var from = MealEntry.normalizeDate(start);
    var to = MealEntry.normalizeDate(end);
    if (to.isBefore(from)) {
      final swap = from;
      from = to;
      to = swap;
    }

    await refreshMealsFromApi(
      period: 'custom',
      fromDate: from,
      toDate: to,
    );
  }

  Future<void> _refreshMealsFromApi({
    DateTime? date,
    String? period,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (!Get.isRegistered<UserController>()) return;

    final userController = Get.find<UserController>();
    await userController.localProfileReady;
    await userController.loadAuthSession();

    if (!userController.isLoggedIn || userController.accessToken.isEmpty) {
      mealsApiErrorMessage.value = null;
      isLoadingMealsApi.value = false;
      debugPrint('FoodController: skipping meals API (not signed in)');
      return;
    }

    isLoadingMealsApi.value = true;
    mealsApiErrorMessage.value = null;

    final endpoint = ApiEndpoints.mealsWithQuery(
      date: date,
      period: period,
      fromDate: fromDate,
      toDate: toDate,
    );

    try {
      debugPrint(
        'FoodController: calling GET meals API at ${ApiEndpoints.url(endpoint)}',
      );
      final fetched = await _mealsRepository.fetchMeals(
        accessToken: userController.accessToken,
        date: date,
        period: period,
        fromDate: fromDate,
        toDate: toDate,
      );

      debugPrint('FoodController: meals API returned ${fetched.length} meals');
      for (final meal in fetched.take(8)) {
        debugPrint(
          'FoodController:   id=${meal.id} '
          'local=${_looksLikeLocalMealId(meal.id)} '
          'name=${meal.food.name} meal=${meal.meal} g=${meal.grams}',
        );
      }

      apiMeals.assignAll(fetched);

      if (date != null) {
        final normalized = MealEntry.normalizeDate(date);
        // API is source of truth for that day — do not keep local-only ghosts.
        entries.assignAll([
          ...entries.where((e) => e.date != normalized),
          ...fetched,
        ]);
        _markEntriesDirty();
      } else if (fetched.isNotEmpty) {
        // Full meals payload replaces in-memory diary (API source of truth).
        entries.assignAll(fetched);
        _markEntriesDirty();
      }

      _notifyStreakController();
    } on MealsApiException catch (error) {
      debugPrint('FoodController: meals API failed: $error');
      mealsApiErrorMessage.value = error.message;
    } catch (error) {
      debugPrint('FoodController: meals API failed: $error');
      mealsApiErrorMessage.value =
          'Unable to load meals. Please check your connection.';
    } finally {
      isLoadingMealsApi.value = false;
      pruneDeletingAnimations();
      entriesRevision.value++;
    }
  }

  List<MealEntry> get todayMeals =>
      entries.where((e) => _isToday(e.date)).toList();

  List<MealEntry> get selectedDateMeals =>
      entries.where((e) => e.date == selectedLogDate.value).toList();

  void setSelectedLogDate(DateTime date) {
    selectedLogDate.value = MealEntry.normalizeDate(date);
    entriesRevision.value++;

    unawaited(refreshMealsFromApi(date: selectedLogDate.value));
  }

  List<MealEntry> mealsForDate(DateTime day, String meal) {
    final normalized = MealEntry.normalizeDate(day);
    return entries
        .where((e) => e.date == normalized && e.meal == meal)
        .toList();
  }

  List<MealEntry> getLastLoggedMeals() {
    final today = MealEntry.normalizeDate(selectedLogDate.value);
    final yesterday = today.subtract(const Duration(days: 1));

    // Prefer the previous calendar day when it has any meals.
    final yesterdayMeals =
        entries.where((e) => e.date == yesterday).toList();
    if (yesterdayMeals.isNotEmpty) return yesterdayMeals;

    final previousDays = entries
        .where((e) => e.date.isBefore(today))
        .map((e) => e.date)
        .toSet()
        .toList();

    if (previousDays.isEmpty) {
      return [];
    }

    previousDays.sort((a, b) => b.compareTo(a));

    final lastLoggedDay = previousDays.first;

    return entries.where((e) => e.date == lastLoggedDay).toList();
  }

  /// Loads Breakfast / Lunch / Dinner / Snacks for the last logged day from API.
  /// Local cache often only has a partial day (e.g. Breakfast) until this runs.
  Future<List<MealEntry>> ensureLastLoggedMealsLoaded() async {
    if (_refreshMealsFuture != null) {
      await _refreshMealsFuture;
    }

    final today = MealEntry.normalizeDate(selectedLogDate.value);
    final yesterday = today.subtract(const Duration(days: 1));

    // Undated GET /meals may already include yesterday — skip a second fetch.
    var yesterdayMeals = entries.where((e) => e.date == yesterday).toList();
    if (yesterdayMeals.isNotEmpty) return yesterdayMeals;

    await _refreshMealsFromApi(date: yesterday);
    yesterdayMeals = entries.where((e) => e.date == yesterday).toList();
    if (yesterdayMeals.isNotEmpty) return yesterdayMeals;

    final previousDays = entries
        .where((e) => e.date.isBefore(today))
        .map((e) => e.date)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (previousDays.isEmpty) return [];

    final lastLoggedDay = previousDays.first;
    if (lastLoggedDay != yesterday) {
      await _refreshMealsFromApi(date: lastLoggedDay);
    }

    return entries.where((e) => e.date == lastLoggedDay).toList();
  }

  DateTime? get lastLoggedDate {
    final today = MealEntry.normalizeDate(selectedLogDate.value);
    final yesterday = today.subtract(const Duration(days: 1));
    if (entries.any((e) => e.date == yesterday)) return yesterday;

    final previousDays = entries
        .where((e) => e.date.isBefore(today))
        .map((e) => e.date)
        .toSet()
        .toList();

    if (previousDays.isEmpty) return null;

    previousDays.sort((a, b) => b.compareTo(a));

    return previousDays.first;
  }

  String get lastLoggedDayLabel {
    final date = lastLoggedDate;
    if (date == null) return '';

    final today = MealEntry.normalizeDate(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final weekday = DateFormat('EEEE').format(date);

    if (date == yesterday) return 'Yesterday';
    if (date == today) return 'Today';
    return weekday;
  }

  List<MealEntry> mealsForSelectedDate(String meal) =>
      mealsForDate(selectedLogDate.value, meal);

  int caloriesForMealOnDate(DateTime day, String meal) =>
      mealsForDate(day, meal).fold(0, (sum, e) => sum + e.calories);

  int caloriesForMealOnSelectedDate(String meal) =>
      caloriesForMealOnDate(selectedLogDate.value, meal);

  int get selectedDateCalories =>
      selectedDateMeals.fold(0, (sum, e) => sum + e.calories);

  List<DailyNutrition> get last7Days => nutritionForLastDays(7);

  List<DailyNutrition> nutritionForLastDays(int dayCount) {
    return nutritionForLastDaysEnding(dayCount, endDate: DateTime.now());
  }

  List<DailyNutrition> nutritionForLastDaysEnding(
    int dayCount, {
    required DateTime endDate,
  }) {
    final end = MealEntry.normalizeDate(endDate);
    return List.generate(dayCount, (index) {
      final day = end.subtract(Duration(days: dayCount - 1 - index));
      final dayEntries = entries.where((e) => e.date == day);
      return DailyNutrition.fromEntries(day, dayEntries);
    });
  }

  DailyNutrition nutritionForDate(DateTime date) {
    final day = MealEntry.normalizeDate(date);
    final dayEntries = entries.where((e) => e.date == day);
    return DailyNutrition.fromEntries(day, dayEntries);
  }

  void setSelectedMeal(String meal) {
    if (MealType.all.contains(meal)) selectedMeal.value = meal;
  }

  Future<void> searchFoods(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      searchResults.clear();
      searchErrorMessage.value = null;
      return;
    }

    isSearching.value = true;
    searchErrorMessage.value = null;
    try {
      searchResults.value = await searchFoodsEphemeral(trimmed);
    } on FoodApiException catch (error) {
      searchResults.clear();
      searchErrorMessage.value = error.message;
      debugPrint('FoodController: search failed: $error');
    } catch (error) {
      searchResults.clear();
      searchErrorMessage.value = 'Unable to search foods. Please try again.';
      debugPrint('FoodController: search failed: $error');
    } finally {
      isSearching.value = false;
    }
  }

  /// Search without updating [searchQuery] / [searchResults] — for pickers.
  Future<List<FoodItem>> searchFoodsEphemeral(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final accessToken = await _mealAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const FoodApiException('Sign in to search foods.');
    }
    return _api.searchFoods(
      trimmed,
      accessToken: accessToken,
      page: 1,
      limit: 20,
    );
  }

  void onSearchChanged(String value) {
    searchQuery.value = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      searchFoods(value);
    });
  }

  /// Clears Add Food search so reopening the screen starts empty.
  void clearSearch() {
    _debounce?.cancel();
    searchQuery.value = '';
    searchResults.clear();
    searchErrorMessage.value = null;
    isSearching.value = false;
  }

  void logFromHistory(SavedMealItem item, {DateTime? date, String? meal}) {
    if (item.hasServerId || isFavorite(item)) {
      logFavouriteMeal(item, meal: meal, date: date);
      return;
    }
    _insertEntry(
      item
          .copyWith(meal: meal ?? item.meal)
          .toMealEntry(date: date ?? selectedLogDate.value),
    );
  }

  // int copyYesterdayToDate({DateTime? date}) {
  //   final target = MealEntry.normalizeDate(date ?? selectedLogDate.value);
  //   final yesterday = target.subtract(const Duration(days: 1));
  //   final sourceMeals =
  //       entries.where((entry) => entry.date == yesterday).toList();
  //   if (sourceMeals.isEmpty) return 0;

  //   for (final entry in sourceMeals) {
  //     _insertEntry(
  //       MealEntry(
  //         food: entry.food,
  //         grams: entry.grams,
  //         meal: entry.meal,
  //         date: target,
  //       ),
  //     );
  //   }
  //   return sourceMeals.length;
  // }

  int copyYesterdayToDate({DateTime? date}) {
    final target = MealEntry.normalizeDate(date ?? selectedLogDate.value);
    final sourceMeals = getLastLoggedMeals();

    if (sourceMeals.isEmpty) return 0;

    repeatedYesterdayEntries.clear();

    for (final entry in sourceMeals) {
      final copied = MealEntry(
        food: entry.food,
        grams: entry.grams,
        meal: entry.meal,
        date: target,
      );

      repeatedYesterdayEntries.add(copied);
      _insertEntry(copied);
    }

    return sourceMeals.length;
  }

  int copySelectedYesterdayMeals({DateTime? date}) {
    final target = MealEntry.normalizeDate(date ?? selectedLogDate.value);
    final sourceMeals = getLastLoggedMeals()
        .where((entry) => selectedYesterdayMeals.contains(entry.id))
        .toList();

    if (sourceMeals.isEmpty) return 0;

    repeatedYesterdayEntries.clear();

    for (final entry in sourceMeals) {
      final copied = MealEntry(
        food: entry.food,
        grams: entry.grams,
        meal: entry.meal,
        date: target,
      );

      repeatedYesterdayEntries.add(copied);
      _insertEntry(copied);
    }

    selectedYesterdayMeals.clear();

    return sourceMeals.length;
  }

  void _insertEntry(MealEntry entry, {bool syncToServer = true}) {
    entries.add(entry);
    _markEntriesDirty(celebrationDay: entry.date);
    if (syncToServer) {
      unawaited(_syncCreateMeal(entry));
    }
  }

  List<FoodItem> get filteredFoods => searchResults;

  int get totalCaloriesEaten =>
      todayMeals.fold(0, (sum, e) => sum + e.calories);

  double get totalProtein => todayMeals.fold(0.0, (sum, e) => sum + e.protein);

  double get totalCarbs => todayMeals.fold(0.0, (sum, e) => sum + e.carbs);

  double get totalFat => todayMeals.fold(0.0, (sum, e) => sum + e.fat);

  void addToLog(FoodItem food, {String? meal, DateTime? date, int? grams}) {
    _insertEntry(
      MealEntry(
        food: food,
        grams: grams ?? selectedGrams.value,
        meal: meal ?? selectedMeal.value,
        date: MealEntry.normalizeDate(date ?? selectedLogDate.value),
      ),
    );
    selectedGrams.value = 100;
  }

  Future<String?> _mealAccessToken() async {
    if (!Get.isRegistered<UserController>()) {
      debugPrint(
        'FoodController: MISSING token — UserController not registered '
        '(lib/controllers/food_controller.dart _mealAccessToken)',
      );
      return null;
    }

    final userController = Get.find<UserController>();
    final resolution = await userController.resolveAccessTokenWithDiagnostics();
    if (!resolution.isResolved) {
      debugPrint(
        'FoodController: MISSING token — stage=${resolution.failureStage} '
        'at ${resolution.failureLocation}',
      );
      return null;
    }

    debugPrint(
      'FoodController: access token OK '
      'source=${resolution.source} length=${resolution.tokenLength}',
    );
    return resolution.token;
  }

  Future<void> _syncCreateMeal(MealEntry entry) async {
    final accessToken = await _mealAccessToken();
    if (accessToken == null) {
      entries.removeWhere((e) => e.id == entry.id);
      entriesRevision.value++;
      AppSnackbar.error(
        'Sign in to save meals to the server.',
        title: 'Not signed in',
      );
      return;
    }

    try {
      debugPrint(
        'FoodController: calling POST meals API at ${ApiEndpoints.mealsUrl}',
      );
      final created = await _mealsRepository.createMeal(
        accessToken: accessToken,
        entry: entry,
      );

      final index = entries.indexWhere((e) => e.id == entry.id);
      if (_looksLikeLocalMealId(created.id)) {
        // Response missing server id — drop draft and reload from API.
        if (index >= 0) entries.removeAt(index);
        await refreshMealsFromApi(date: entry.date);
        return;
      }

      if (index >= 0) {
        entries[index] = created;
      } else {
        entries.add(created);
      }

      apiMeals.removeWhere(
        (e) => e.id == entry.id || e.id == created.id,
      );
      apiMeals.add(created);

      _dropDuplicateEntriesById(created.id);
      _markEntriesDirty(celebrationDay: created.date);
    } on MealsApiException catch (error) {
      debugPrint('FoodController: create meal API failed: $error');
      mealsApiErrorMessage.value = error.message;
      entries.removeWhere((e) => e.id == entry.id);
      entriesRevision.value++;
      AppSnackbar.error(error.message, title: 'Could not save meal');
    } catch (error) {
      debugPrint('FoodController: create meal API failed: $error');
      mealsApiErrorMessage.value = apiNetworkErrorMessage(
        error,
        action: 'saving meal',
      );
      entries.removeWhere((e) => e.id == entry.id);
      entriesRevision.value++;
      AppSnackbar.error(
        'Could not save ${entry.food.name} to the server.',
        title: 'Save failed',
      );
    }
  }

  void _dropDuplicateEntriesById(String id) {
    if (id.trim().isEmpty) return;
    var seen = false;
    entries.removeWhere((e) {
      if (e.id != id) return false;
      if (!seen) {
        seen = true;
        return false;
      }
      return true;
    });
  }

  void toggleYesterdayMeal(String id) {
    if (selectedYesterdayMeals.contains(id)) {
      selectedYesterdayMeals.remove(id);
    } else {
      selectedYesterdayMeals.add(id);
    }
  }

  bool isYesterdayMealSelected(String id) {
    return selectedYesterdayMeals.contains(id);
  }

  int get selectedYesterdayMealCount {
    return selectedYesterdayMeals.length;
  }

  void clearYesterdaySelection() {
    selectedYesterdayMeals.clear();
  }

  void selectAllYesterdayMeals() {
    selectedYesterdayMeals.clear();

    for (final meal in getLastLoggedMeals()) {
      selectedYesterdayMeals.add(meal.id);
    }
  }

  void unselectAllYesterdayMeals() {
    selectedYesterdayMeals.clear();
  }

  void _markEntriesDirty({DateTime? celebrationDay}) {
    entries.refresh();
    entriesRevision.value++;
    _notifyStreakController();
    _maybeCelebrateCalorieGoal(day: celebrationDay);
  }

  void _notifyStreakController() {
    // Streak unused — do not notify / refresh streak API.
    // debugPrint("🔥 _notifyStreakController called");
    // if (!Get.isRegistered<StreakController>()) return;
    // Get.find<StreakController>().onMealsChanged();
  }

  void _maybeCelebrateCalorieGoal({DateTime? day}) {
    if (!Get.isRegistered<DashboardController>()) return;

    final normalizedDay = MealEntry.normalizeDate(day ?? DateTime.now());
    final dateKey = MealEntry.dateToKey(normalizedDay);
    final goal = Get.find<DashboardController>().calorieGoal;
    if (goal <= 0) return;

    final consumed = caloriesForDate(normalizedDay);
    if (!GoalProgressMessage.isGoalReached(consumed: consumed, goal: goal)) {
      _goalCelebratedDates.remove(dateKey);
      return;
    }

    if (_goalCelebratedDates.contains(dateKey)) return;
    _goalCelebratedDates.add(dateKey);

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<DashboardController>()) return;
      CalorieGoalSuccessDialog.show(consumed: consumed, goal: goal);
    });
  }

  int caloriesForDate(DateTime day) {
    final normalized = MealEntry.normalizeDate(day);
    return entries
        .where((entry) => entry.date == normalized)
        .fold(0, (sum, entry) => sum + entry.calories);
  }

  List<MealEntry> mealsForToday(String meal) =>
      todayMeals.where((e) => e.meal == meal).toList();

  int caloriesForMeal(String meal) =>
      mealsForToday(meal).fold(0, (sum, e) => sum + e.calories);

  MealSummary summaryForMeal(String meal) {
    final items = mealsForToday(meal);
    if (items.isEmpty) {
      return MealSummary(
        meal: meal,
        calories: 0,
        itemCount: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
      );
    }
    return MealSummary(
      meal: meal,
      calories: items.fold(0, (sum, e) => sum + e.calories),
      itemCount: items.length,
      protein: items.fold(0.0, (sum, e) => sum + e.protein),
      carbs: items.fold(0.0, (sum, e) => sum + e.carbs),
      fat: items.fold(0.0, (sum, e) => sum + e.fat),
    );
  }

  List<MealSummary> get todayMealSummaries =>
      MealType.all.map(summaryForMeal).toList();

  /// Updates a diary meal on the server (`PATCH /meals/:id`).
  /// Falls back to delete + create if PATCH is unsupported.
  Future<bool> updateEntry(MealEntry entry, {int? grams, String? meal}) async {
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index < 0) return false;

    final updated = entry.copyWith(grams: grams, meal: meal);
    final previous = entries[index];

    // Optimistic UI — roll back if API fails.
    entries[index] = updated;
    _markEntriesDirty(celebrationDay: updated.date);

    final accessToken = await _mealAccessToken();
    if (accessToken == null) {
      entries[index] = previous;
      _markEntriesDirty(celebrationDay: previous.date);
      AppSnackbar.error(
        'Sign in to save meal changes to the server.',
        title: 'Not signed in',
      );
      return false;
    }

    try {
      if (_looksLikeLocalMealId(updated.id)) {
        // Never had a server id — create as new, drop draft.
        entries.removeAt(index);
        entries.add(updated);
        await _syncCreateMeal(updated);
        return true;
      }

      final saved = await _mealsRepository.updateMeal(
        accessToken: accessToken,
        entry: updated,
      );
      final i = entries.indexWhere((e) => e.id == entry.id || e.id == saved.id);
      if (i >= 0) {
        entries[i] = saved;
      }
      apiMeals.removeWhere((e) => e.id == entry.id || e.id == saved.id);
      apiMeals.add(saved);
      _markEntriesDirty(celebrationDay: saved.date);
      return true;
    } on MealsApiException catch (error) {
      // Backend may not support PATCH — replace via delete + create.
      if (error.statusCode == 404 ||
          error.statusCode == 405 ||
          error.statusCode == 501) {
        debugPrint(
          'FoodController: PATCH unsupported (${error.statusCode}); '
          'falling back to delete+create',
        );
        try {
          await _mealsRepository.deleteMeal(
            accessToken: accessToken,
            mealId: entry.id,
          );
          final created = await _mealsRepository.createMeal(
            accessToken: accessToken,
            entry: updated,
          );
          final i = entries.indexWhere(
            (e) => e.id == entry.id || e.id == updated.id,
          );
          if (i >= 0) {
            entries[i] = created;
          } else {
            entries.add(created);
          }
          apiMeals.removeWhere(
            (e) => e.id == entry.id || e.id == created.id,
          );
          apiMeals.add(created);
          _markEntriesDirty(celebrationDay: created.date);
          return true;
        } catch (fallbackError) {
          debugPrint('FoodController: update fallback failed: $fallbackError');
        }
      }

      entries[index] = previous;
      _markEntriesDirty(celebrationDay: previous.date);
      mealsApiErrorMessage.value = error.message;
      AppSnackbar.error(error.message, title: 'Could not update meal');
      return false;
    } catch (error) {
      final rollbackAt = entries.indexWhere(
        (e) => e.id == updated.id || e.id == entry.id,
      );
      if (rollbackAt >= 0) {
        entries[rollbackAt] = previous;
      }
      _markEntriesDirty(celebrationDay: previous.date);
      AppSnackbar.error(
        'Could not save changes for ${entry.food.name}.',
        title: 'Update failed',
      );
      return false;
    }
  }

  /// Removes a meal via `DELETE /meals/:id`, then reloads that day from the API.
  /// Never deletes with a local-only epoch id — that 404s and the meal comes back.
  Future<bool> deleteMealEntry(MealEntry entry) async {
    try {
      return await _deleteMealEntryBody(entry);
    } catch (error, stack) {
      debugPrint(
        'FoodController: deleteMealEntry unexpected error: $error\n$stack',
      );
      mealsApiErrorMessage.value = apiNetworkErrorMessage(
        error,
        action: 'deleting meal',
      );
      AppSnackbar.error(
        'Could not delete ${entry.food.name} on the server.',
        title: 'Delete failed',
      );
      return false;
    }
  }

  Future<bool> _deleteMealEntryBody(MealEntry entry) async {
    debugPrint(
      'FoodController: deleteMealEntry START food=${entry.food.name} '
      'id=${entry.id} meal=${entry.meal} grams=${entry.grams} '
      'date=${MealEntry.dateToKey(entry.date)} '
      'looksLocal=${_looksLikeLocalMealId(entry.id)}',
    );

    final accessToken = await _mealAccessToken().timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        debugPrint('FoodController: access token resolve timed out');
        return null;
      },
    );
    if (accessToken == null) {
      AppSnackbar.error(
        'Sign in to delete meals from the server.',
        title: 'Not signed in',
      );
      return false;
    }

    var mealIdForApi = entry.id.trim();
    var serverMeal = entry;

    if (_looksLikeLocalMealId(mealIdForApi)) {
      // Prefer in-memory resolve first — sync may have replaced the local id
      // while the confirm sheet was open (that also disposes the row State).
      var target = await _resolveServerMealForDelete(entry);
      if (target == null || _looksLikeLocalMealId(target.id)) {
        debugPrint(
          'FoodController: local id — GET meals for '
          '${MealEntry.dateToKey(entry.date)} before DELETE',
        );
        try {
          if (_refreshMealsFuture != null) {
            await _refreshMealsFuture!.timeout(const Duration(seconds: 6));
          }
          await refreshMealsFromApi(date: entry.date)
              .timeout(const Duration(seconds: 6));
        } on TimeoutException {
          debugPrint(
            'FoodController: meals refresh timed out during local delete',
          );
        }
        target = await _resolveServerMealForDelete(entry);
      }

      if (target == null || _looksLikeLocalMealId(target.id)) {
        debugPrint(
          'FoodController: meal never reached server — removing local draft '
          'id=${entry.id}',
        );
        entries.removeWhere(
          (e) => e.id == entry.id || _matchesLoggedMeal(e, entry),
        );
        apiMeals.removeWhere((e) => _matchesLoggedMeal(e, entry));
        entriesRevision.value++;
        return true;
      }

      serverMeal = target;
      mealIdForApi = serverMeal.id.trim();
      debugPrint(
        'FoodController: resolved local ${entry.id} → server $mealIdForApi',
      );
    }

    try {
      debugPrint(
        'FoodController: DELETE ${ApiEndpoints.mealsByIdUrl(mealIdForApi)}',
      );
      await _mealsRepository.deleteMeal(
        accessToken: accessToken,
        mealId: mealIdForApi,
      );
      debugPrint('FoodController: DELETE ok for $mealIdForApi');
    } on MealsApiException catch (error) {
      debugPrint(
        'FoodController: delete meal API failed status=${error.statusCode} '
        'msg=$error',
      );
      if (error.statusCode != 404) {
        mealsApiErrorMessage.value = error.message;
        AppSnackbar.error(error.message, title: 'Delete failed');
        return false;
      }
    } catch (error) {
      debugPrint('FoodController: delete meal API failed: $error');
      mealsApiErrorMessage.value = apiNetworkErrorMessage(
        error,
        action: 'deleting meal',
      );
      AppSnackbar.error(
        'Could not delete ${entry.food.name} on the server.',
        title: 'Delete failed',
      );
      return false;
    }

    entries.removeWhere(
      (e) =>
          e.id == entry.id ||
          e.id == mealIdForApi ||
          e.id == serverMeal.id ||
          _matchesLoggedMeal(e, entry) ||
          _matchesLoggedMeal(e, serverMeal),
    );
    apiMeals.removeWhere(
      (e) =>
          e.id == entry.id ||
          e.id == mealIdForApi ||
          e.id == serverMeal.id ||
          _matchesLoggedMeal(e, entry) ||
          _matchesLoggedMeal(e, serverMeal),
    );
    entriesRevision.value++;

    try {
      if (_refreshMealsFuture != null) {
        await _refreshMealsFuture!.timeout(const Duration(seconds: 6));
      }
      await refreshMealsFromApi(date: entry.date)
          .timeout(const Duration(seconds: 6));
    } on TimeoutException {
      debugPrint('FoodController: post-delete meals refresh timed out');
    }

    final stillThere = entries.any(
      (e) =>
          e.id == mealIdForApi ||
          _matchesLoggedMeal(e, serverMeal) ||
          _matchesLoggedMeal(e, entry),
    );
    if (stillThere) {
      debugPrint(
        'FoodController: meal still present after DELETE+GET — delete failed',
      );
      AppSnackbar.error(
        'Server still has “${entry.food.name}”. Delete did not stick.',
        title: 'Delete failed',
      );
      return false;
    }

    debugPrint('FoodController: deleteMealEntry DONE for $mealIdForApi');
    return true;
  }

  /// Finds the server-backed copy of [entry] (never a local epoch id).
  Future<MealEntry?> _resolveServerMealForDelete(MealEntry entry) async {
    final resolvedId = _resolveMealIdForApiDelete(entry);
    if (resolvedId != null &&
        resolvedId.isNotEmpty &&
        !_looksLikeLocalMealId(resolvedId)) {
      // Prefer the live entry object that carries this id.
      for (final e in apiMeals) {
        if (e.id == resolvedId) return e;
      }
      for (final e in entries) {
        if (e.id == resolvedId) return e;
      }
      return entry.copyWith(id: resolvedId);
    }

    // Content match against API-loaded meals that have real ids.
    for (final e in apiMeals) {
      if (_looksLikeLocalMealId(e.id)) continue;
      if (_matchesLoggedMeal(e, entry)) return e;
    }
    for (final e in entries) {
      if (_looksLikeLocalMealId(e.id)) continue;
      if (_matchesLoggedMeal(e, entry)) return e;
    }

    // Looser match: same day + meal slot + name (ignore grams drift).
    for (final e in [...apiMeals, ...entries]) {
      if (_looksLikeLocalMealId(e.id)) continue;
      if (MealEntry.normalizeDate(e.date) !=
          MealEntry.normalizeDate(entry.date)) {
        continue;
      }
      if (e.meal != entry.meal) continue;
      if (e.food.name.toLowerCase() != entry.food.name.toLowerCase()) continue;
      return e;
    }

    return null;
  }

  /// Prefer [deleteMealEntry]. Kept for call sites that fire-and-forget.
  void removeEntry(MealEntry entry) {
    unawaited(deleteMealEntry(entry));
  }

  /// Deletes every entry in [group], then clears the in-row delete animation.
  /// Safe to call from Lottie `onCompleted` after [beginDeletingGroup].
  Future<bool> commitDeletingGroup(MealLogGroup group) async {
    final id = group.representative.id;
    if (_deleteCommitInFlight.contains(id)) {
      debugPrint(
        'FoodController: commitDeletingGroup skipped — already in flight id=$id',
      );
      return false;
    }
    _deleteCommitInFlight.add(id);

    final entriesToDelete = List<MealEntry>.of(group.entries);
    if (entriesToDelete.isEmpty) {
      entriesToDelete.add(group.representative);
    }

    var allOk = true;
    try {
      for (final entry in entriesToDelete) {
        debugPrint(
          'FoodController: commitDeletingGroup → deleteMealEntry '
          'id=${entry.id} name=${entry.food.name}',
        );
        final ok = await deleteMealEntry(entry);
        if (!ok) {
          allOk = false;
          break;
        }
      }
    } catch (error, stack) {
      debugPrint(
        'FoodController: commitDeletingGroup failed: $error\n$stack',
      );
      allOk = false;
      AppSnackbar.error(
        'Could not delete “${group.representative.food.name}”.',
        title: 'Delete failed',
      );
    } finally {
      _deleteCommitInFlight.remove(id);
      // UI clear is owned by [deleteMealGroupWithFeedback] so the trash
      // animation can finish (API often completes in milliseconds).
    }
    return allOk;
  }

  void beginDeletingGroup(MealLogGroup group) {
    final id = group.representative.id;
    if (deletingMealIds.contains(id)) return;
    deletingMealIds.add(id);
    _deletingGroups.removeWhere((g) => g.representative.id == id);
    _deletingGroups.add(group);
    deletingMealIds.refresh();
    _deletingGroups.refresh();

    // Safety net for abandoned deletes.
    Future<void>.delayed(const Duration(seconds: 12), () {
      if (!deletingMealIds.contains(id)) return;
      debugPrint(
        'FoodController: force-clear stuck delete animation id=$id',
      );
      _deleteCommitInFlight.remove(id);
      finishDeletingGroup(group);
    });
  }

  /// Confirm-sheet-safe delete: owned by the controller so row dispose
  /// (`mounted=false` after local→server id sync) cannot abort the request.
  Future<bool> deleteMealGroupWithFeedback(MealLogGroup group) async {
    beginDeletingGroup(group);
    final started = DateTime.now();
    final allOk = await commitDeletingGroup(group);

    // Keep the trash Lottie on screen long enough to be readable.
    const minVisible = Duration(milliseconds: 1100);
    final elapsed = DateTime.now().difference(started);
    if (elapsed < minVisible) {
      await Future<void>.delayed(minVisible - elapsed);
    }
    finishDeletingGroup(group);

    if (allOk) {
      AppSnackbar.success(
        'Removed from your diary.',
        title: 'Deleted',
      );
    }
    return allOk;
  }

  void finishDeletingGroup(MealLogGroup group) {
    final id = group.representative.id;
    deletingMealIds.remove(id);
    _deletingGroups.removeWhere((g) => g.representative.id == id);
    deletingMealIds.refresh();
    _deletingGroups.refresh();
  }

  /// Clears any in-progress delete UI (e.g. after refresh or leaving diary).
  void clearDeletingAnimations() {
    if (deletingMealIds.isEmpty && _deletingGroups.isEmpty) return;
    deletingMealIds.clear();
    _deletingGroups.clear();
    _deleteCommitInFlight.clear();
    deletingMealIds.refresh();
    _deletingGroups.refresh();
  }

  /// Active delete animations are owned by begin/finishDeletingGroup.
  /// Do not clear them when a meal leaves memory after DELETE — that made the
  /// trash Lottie disappear in milliseconds.
  void pruneDeletingAnimations() {}

  List<MealLogGroup> deletingGroupsForMeal(String meal) {
    return _deletingGroups
        .where((g) => g.representative.meal == meal)
        .toList();
  }

  Future<void> cancelRepeatedYesterdayMeals() async {
    if (repeatedYesterdayEntries.isEmpty) return;

    final meals = List<MealEntry>.from(repeatedYesterdayEntries);

    repeatedYesterdayEntries.clear();

    for (final meal in meals) {
      await deleteMealEntry(meal);
    }

    entriesRevision.value++;
  }

  String? _resolveMealIdForApiDelete(MealEntry entry) {
    final entryId = entry.id.trim();

    for (final apiEntry in apiMeals) {
      if (apiEntry.id == entryId && entryId.isNotEmpty) {
        return apiEntry.id;
      }
    }

    for (final apiEntry in apiMeals) {
      if (_matchesLoggedMeal(apiEntry, entry) &&
          apiEntry.id.trim().isNotEmpty) {
        return apiEntry.id;
      }
    }

    // Also search in-memory diary entries (API-loaded) for a better id.
    for (final logged in entries) {
      if (logged.id == entryId && entryId.isNotEmpty) {
        // Prefer non-local-looking ids when duplicates exist.
        if (!_looksLikeLocalMealId(logged.id)) return logged.id;
      }
    }

    for (final logged in entries) {
      if (_matchesLoggedMeal(logged, entry) &&
          logged.id.trim().isNotEmpty &&
          !_looksLikeLocalMealId(logged.id)) {
        return logged.id;
      }
    }

    if (entryId.isNotEmpty) return entryId;
    return null;
  }

  bool _matchesLoggedMeal(MealEntry a, MealEntry b) {
    return a.meal == b.meal &&
        MealEntry.normalizeDate(a.date) == MealEntry.normalizeDate(b.date) &&
        a.food.name.toLowerCase() == b.food.name.toLowerCase() &&
        a.grams == b.grams;
  }

  MealEntry? findEntry(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<void> loadRepeatYesterdayCardState() async {
    // Session-only — no local persistence; diary data comes from the API.
    showRepeatYesterdayCard.value = true;
  }

  Future<void> dismissRepeatYesterdayCard() async {
    showRepeatYesterdayCard.value = false;
  }

  bool get isViewingToday => _isToday(selectedLogDate.value);
  bool _isToday(DateTime date) =>
      date == MealEntry.normalizeDate(DateTime.now());

  void prepareForNewMeal() {
    final today = MealEntry.normalizeDate(DateTime.now());

    // Immediately switch the diary back to today.
    selectedLogDate.value = today;

    entriesRevision.value++;

    unawaited(refreshMealsFromApi(date: today));
  }

  void showReadOnlyMessage() {
    AppSnackbar.info(
      "Past meals can't be edited.",
      title: 'Read only',
    );
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}
