import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../core/api_errors.dart';
import '../core/app_snackbar.dart';
import '../core/goal_progress_message.dart';
import '../core/image_downscale.dart';
import '../core/meal_log_group.dart';
import '../core/media_url.dart';
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
import '../repositories/uploads_repository.dart';
import '../services/food_api_service.dart';
import '../services/api_endpoints.dart';
import '../services/custom_meals_api_service.dart';
import '../services/favourite_meals_api_service.dart';
import '../services/meals_api_service.dart';
import '../services/my_foods_api_service.dart';
import '../services/uploads_api_service.dart';
import '../widgets/calorie_goal_success_dialog.dart';
import 'dashboard_controller.dart';
// import 'streak_controller.dart';
import 'user_controller.dart';

import '../services/analytics_service.dart';

class FoodController extends GetxController {
  FoodController({
    FoodApiService? api,
    MealsRepository? mealsRepository,
    CustomMealsRepository? customMealsRepository,
    MyFoodsRepository? myFoodsRepository,
    FavouriteMealsRepository? favouriteMealsRepository,
    UploadsRepository? uploadsRepository,
  }) : _api = api ?? FoodApiService(),
       _mealsRepository = mealsRepository ?? MealsRepository(),
       _customMealsRepository =
           customMealsRepository ?? CustomMealsRepository(),
       _myFoodsRepository = myFoodsRepository ?? MyFoodsRepository(),
       _favouriteMealsRepository =
           favouriteMealsRepository ?? FavouriteMealsRepository(),
       _uploadsRepository = uploadsRepository ?? UploadsRepository();

  final FoodApiService _api;
  final MealsRepository _mealsRepository;
  final CustomMealsRepository _customMealsRepository;
  final MyFoodsRepository _myFoodsRepository;
  final FavouriteMealsRepository _favouriteMealsRepository;
  final UploadsRepository _uploadsRepository;

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
  final Set<String> _favoriteToggleKeys = <String>{};

  /// Food names removed from My Food / My Meals so they leave Quick Items.
  final Set<String> _suppressedQuickItemNames = <String>{};

  /// Catalog / search photos keyed by lowercase food name.
  final Map<String, String> _catalogPhotoByName = <String, String>{};
  final Map<String, FoodItem> _catalogFoodByName = <String, FoodItem>{};
  final Set<String> _catalogPhotoMisses = <String>{};
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
    _suppressedQuickItemNames.clear();
    _catalogPhotoByName.clear();
    _catalogFoodByName.clear();
    _catalogPhotoMisses.clear();
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

      _rememberKnownFoodPhotos();
      final previous = List<SavedMealItem>.from(favoriteMeals);

      // Prefer server list; keep unsynced local favourites without a server id.
      final hydrated = _uniqueFavorites([
        for (final item in fetched) _favouriteWithKnownPhoto(item, previous),
      ]);
      final localOnly = previous.where((local) {
        if (local.hasServerId) return false;
        return !hydrated.any(
          (remote) => remote.food.isSameFavoriteFood(local.food),
        );
      });

      favoriteMeals.assignAll([...hydrated, ...localOnly]);
      _lastRemoteFavourites = List<SavedMealItem>.unmodifiable(hydrated);
      _lastFavouritesFetchAt = DateTime.now();
      _rememberFoodPhotos(favoriteMeals.map((item) => item.food));
      unawaited(_hydrateFavouritePhotos());
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
        DateTime.now().difference(_lastMyFoodsFetchAt!) <
            _listRefreshCooldown) {
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

      final localById = {for (final food in customFoodPresets) food.id: food};
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

        final remoteMacroCalories =
            (remote.food.carbs * 4 +
                    remote.food.protein * 4 +
                    remote.food.fat * 9)
                .round();
        final preferLocalCalories =
            local.food.caloriesPer100g > 0 &&
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
            imageUrl: MediaUrl.preferLoadable([
              remote.food.imageUrl,
              local.food.imageUrl,
            ]),
            category: local.food.category ?? remote.food.category,
            servingQuantity: local.food.servingQuantity,
            servingUnit: local.food.servingUnit,
            gramsPerServing: local.food.gramsPerServing,
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

      // Keep unsynced local drafts the server does not know about yet.
      // Server-id foods missing from GET were deleted — do not resurrect them.
      final remoteIds = {for (final food in merged) food.id};
      final remoteNames = {
        for (final food in merged) food.food.name.trim().toLowerCase(),
      };
      for (final local in customFoodPresets) {
        if (!_looksLikeLocalMealId(local.id)) continue;
        final nameKey = local.food.name.trim().toLowerCase();
        if (remoteIds.contains(local.id) || remoteNames.contains(nameKey)) {
          continue;
        }
        merged.add(local);
      }

      final previousNames = _quickItemNamesForFoods(customFoodPresets);
      customFoodPresets.assignAll(merged);
      _lastRemoteMyFoods = List<CustomFoodPreset>.unmodifiable(fetched);
      _lastMyFoodsFetchAt = DateTime.now();
      _suppressDroppedQuickItemNames(previousNames);
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
        final items = remote.items.map((remoteItem) {
          SavedMealItem? localItem;
          if (local != null) {
            for (final candidate in local.items) {
              if (candidate.food.name.trim().toLowerCase() ==
                  remoteItem.food.name.trim().toLowerCase()) {
                localItem = candidate;
                break;
              }
            }
          }
          final imageUrl = MediaUrl.preferLoadable([
            remoteItem.food.imageUrl,
            localItem?.food.imageUrl,
            _imageUrlForFoodName(remoteItem.food.name),
          ]);
          var item = remoteItem;
          if (imageUrl != null && imageUrl != remoteItem.food.imageUrl) {
            item = item.copyWith(
              food: remoteItem.food.copyWith(imageUrl: imageUrl),
            );
          }
          if (localItem == null) return item;
          return item.copyWith(
            servingQuantity: localItem.servingQuantity,
            servingUnit: localItem.servingUnit,
            nutritionBasisQuantity: localItem.nutritionBasisQuantity,
            basisCarbs: localItem.basisCarbs,
            basisProtein: localItem.basisProtein,
            basisFat: localItem.basisFat,
          );
        }).toList();

        if (local == null) {
          return remote.copyWith(items: items);
        }

        return remote.copyWith(
          items: items,
          imageBytes: local.imageBytes,
          imageUrl: MediaUrl.preferLoadable([remote.imageUrl, local.imageUrl]),
        );
      }).toList();

      // Keep unsynced local drafts the server does not know about yet.
      // Server-id meals missing from GET were deleted — do not resurrect them.
      final remoteIds = {for (final meal in merged) meal.id};
      final remoteKeys = {
        for (final meal in merged)
          '${meal.meal.toLowerCase()}|${meal.name.trim().toLowerCase()}',
      };
      for (final local in customMealPresets) {
        if (!_looksLikeLocalMealId(local.id)) continue;
        final key =
            '${local.meal.toLowerCase()}|${local.name.trim().toLowerCase()}';
        if (remoteIds.contains(local.id) || remoteKeys.contains(key)) {
          continue;
        }
        merged.add(local);
      }

      final previousNames = _quickItemNamesForMeals(customMealPresets);
      customMealPresets.assignAll(merged);
      _lastRemoteCustomMeals = List<CustomMealPreset>.unmodifiable(fetched);
      _lastCustomMealsFetchAt = DateTime.now();
      _suppressDroppedQuickItemNames(previousNames);
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
      if (_isHiddenFromQuickItems(favorite)) continue;
      final collapsed = _quickItemForHistory(favorite);
      if (seen.add(collapsed.storageKey)) {
        result.add(collapsed);
      }
    }

    for (final item in _apiMealHistoryFor(meal)) {
      if (_isHiddenFromQuickItems(item)) continue;
      final collapsed = _quickItemForHistory(item);
      if (seen.add(collapsed.storageKey)) {
        result.add(collapsed);
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
      excludeFoodNames: _hiddenQuickItemNames,
    );
  }

  /// Loads meal history from `GET /api/v1/meals` for quick-item pickers.
  Future<void> refreshQuickItemsFromApi() => refreshMealsFromApi();

  /// Last [maxQuickMealsPerSection] unique meals from `GET /api/v1/meals`.
  /// My Meal templates appear by name (not as their individual foods).
  List<SavedMealItem> get recentQuickMeals {
    apiMeals.length;
    isLoadingMealsApi.value;
    customFoodPresets.length;
    customMealPresets.length;
    entriesRevision.value;
    final history = SavedMealItem.historyFromEntries(
      apiMeals.toList(),
      limit: maxMealHistory,
      excludeFoodNames: _hiddenQuickItemNames,
    );
    return _collapseCustomMeals(history);
  }

  /// Most recently logged unique meals for a meal slot (from API history).
  List<SavedMealItem> recentMealsFor(
    String meal, {
    int limit = maxQuickMealsPerSection,
  }) {
    apiMeals.length;
    isLoadingMealsApi.value;
    customFoodPresets.length;
    customMealPresets.length;
    entriesRevision.value;
    final history = _apiMealHistoryFor(meal);
    return _collapseCustomMeals(history, limit: limit);
  }

  /// Matching My Meal template for a Quick Items row, if this row is a meal.
  CustomMealPreset? customMealForQuickItem(SavedMealItem item) {
    return _liveCustomMealFor(item);
  }

  List<SavedMealItem> _collapseCustomMeals(
    List<SavedMealItem> history, {
    int? limit,
  }) {
    if (history.isEmpty) return history;
    final cap = limit ?? maxQuickMealsPerSection;
    final result = <SavedMealItem>[];
    final seen = <String>{};
    for (final item in history) {
      final collapsed = _quickItemForHistory(item);
      if (!seen.add(collapsed.storageKey)) continue;
      result.add(collapsed);
      if (result.length >= cap) break;
    }
    return result;
  }

  SavedMealItem _quickItemForHistory(SavedMealItem item) {
    return _liveCustomMealFor(item)?.toQuickItem() ?? item;
  }

  CustomMealPreset? _liveCustomMealFor(SavedMealItem item) {
    final name = item.food.name.trim().toLowerCase();
    if (name.isEmpty || customMealPresets.isEmpty) return null;
    for (final meal in customMealPresets) {
      if (meal.name.trim().toLowerCase() == name) return meal;
    }
    for (final meal in customMealPresets) {
      if (meal.containsFoodNamed(name)) return meal;
    }
    return null;
  }

  Set<String> get _liveCatalogNames => {
    ..._quickItemNamesForFoods(customFoodPresets),
    ..._quickItemNamesForMeals(customMealPresets),
  };

  Set<String> get _hiddenQuickItemNames {
    final live = _liveCatalogNames;
    return {
      for (final name in _suppressedQuickItemNames)
        if (!live.contains(name)) name,
    };
  }

  bool _isHiddenFromQuickItems(SavedMealItem item) {
    return _hiddenQuickItemNames.contains(item.food.name.trim().toLowerCase());
  }

  Set<String> _quickItemNamesForFoods(Iterable<CustomFoodPreset> foods) {
    return {
      for (final food in foods)
        if (food.food.name.trim().isNotEmpty)
          food.food.name.trim().toLowerCase(),
    };
  }

  Set<String> _quickItemNamesForMeals(Iterable<CustomMealPreset> meals) {
    return {
      for (final meal in meals) ...[
        if (meal.name.trim().isNotEmpty) meal.name.trim().toLowerCase(),
        for (final item in meal.items)
          if (item.food.name.trim().isNotEmpty)
            item.food.name.trim().toLowerCase(),
      ],
    };
  }

  /// Fills missing ingredient photos from cache, my-foods, favourites, logs, search.
  CustomMealPreset withItemPhotos(CustomMealPreset preset) {
    _rememberKnownFoodPhotos();
    final items = [
      for (final item in preset.items)
        if ((item.food.imageUrl ?? '').trim().isNotEmpty)
          item
        else
          _itemWithKnownPhoto(item),
    ];
    return preset.copyWith(items: items);
  }

  /// Looks up catalog photos for meal foods that the my-meals payload omitted.
  Future<CustomMealPreset> hydrateCustomMealPhotos(
    CustomMealPreset preset,
  ) async {
    var updated = withItemPhotos(preset);
    final missing = {
      for (final item in updated.items)
        if ((item.food.imageUrl ?? '').trim().isEmpty) item.food.name.trim(),
    }..removeWhere((name) => name.isEmpty);

    if (missing.isNotEmpty) {
      await Future.wait(missing.map(_lookupCatalogPhoto));
      updated = withItemPhotos(updated);
    }

    _storeHydratedMeal(updated);
    return updated;
  }

  SavedMealItem _itemWithKnownPhoto(SavedMealItem item) {
    final url = _imageUrlForFoodName(item.food.name);
    if (url == null) return item;
    return item.copyWith(food: item.food.copyWith(imageUrl: url));
  }

  SavedMealItem _favouriteWithKnownPhoto(
    SavedMealItem item,
    List<SavedMealItem> previous,
  ) {
    SavedMealItem? local;
    final itemName = item.food.name.trim().toLowerCase();
    for (final candidate in previous) {
      if (candidate.matchesFavorite(item) ||
          candidate.food.name.trim().toLowerCase() == itemName) {
        local = candidate;
        break;
      }
    }
    final imageUrl = MediaUrl.preferLoadable([
      item.food.imageUrl,
      local?.food.imageUrl,
      _imageUrlForFoodName(item.food.name),
    ]);
    if (imageUrl == null || imageUrl == item.food.imageUrl) return item;
    return item.copyWith(food: item.food.copyWith(imageUrl: imageUrl));
  }

  Future<void> _hydrateFavouritePhotos() async {
    _rememberKnownFoodPhotos();
    final missing = <String>{
      for (final item in favoriteMeals)
        if ((item.food.imageUrl ?? '').trim().isEmpty) item.food.name.trim(),
    }..removeWhere((name) => name.isEmpty);
    if (missing.isEmpty) return;

    await Future.wait(missing.map(_lookupCatalogPhoto));

    var changed = false;
    for (var i = 0; i < favoriteMeals.length; i++) {
      final item = favoriteMeals[i];
      if ((item.food.imageUrl ?? '').trim().isNotEmpty) continue;
      final url = _imageUrlForFoodName(item.food.name);
      if (url == null) continue;
      favoriteMeals[i] = item.copyWith(food: item.food.copyWith(imageUrl: url));
      changed = true;
    }
    if (changed) favoriteMeals.refresh();
  }

  String? _imageUrlForFoodName(String name) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return null;

    final cached = _catalogPhotoByName[key];
    if (cached != null && cached.isNotEmpty) return cached;

    String? fromFood(FoodItem food) {
      if (food.name.trim().toLowerCase() != key) return null;
      final url = food.imageUrl?.trim();
      return (url != null && url.isNotEmpty) ? url : null;
    }

    for (final preset in customFoodPresets) {
      final url = fromFood(preset.food);
      if (url != null) return url;
    }
    for (final fav in favoriteMeals) {
      final url = fromFood(fav.food);
      if (url != null) return url;
    }
    for (final entry in apiMeals) {
      final url = fromFood(entry.food);
      if (url != null) return url;
    }
    for (final food in searchResults) {
      final url = fromFood(food);
      if (url != null) return url;
    }
    return null;
  }

  void _rememberFoodPhotos(Iterable<FoodItem> foods) {
    for (final food in foods) {
      _rememberCatalogFood(food);
    }
  }

  void _rememberCatalogFood(FoodItem food) {
    final key = food.name.trim().toLowerCase();
    if (key.isEmpty) return;

    final url = food.imageUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      _catalogPhotoByName[key] = url;
      _catalogPhotoMisses.remove(key);
    }

    if (!food.hasDisplayServing && url.isEmpty) return;

    final existing = _catalogFoodByName[key];
    if (existing == null) {
      _catalogFoodByName[key] = food;
      return;
    }

    final keepServing = existing.hasDisplayServing || !food.hasDisplayServing;
    _catalogFoodByName[key] = existing.copyWith(
      imageUrl: MediaUrl.preferLoadable([existing.imageUrl, food.imageUrl]),
      category: existing.category ?? food.category,
      servingQuantity:
          keepServing ? existing.servingQuantity : food.servingQuantity,
      servingUnit: keepServing ? existing.servingUnit : food.servingUnit,
      gramsPerServing:
          keepServing ? existing.gramsPerServing : food.gramsPerServing,
      catalogId: existing.catalogId ?? food.catalogId,
    );
  }

  void _rememberKnownFoodPhotos() {
    _rememberFoodPhotos(customFoodPresets.map((preset) => preset.food));
    _rememberFoodPhotos(favoriteMeals.map((item) => item.food));
    _rememberFoodPhotos(apiMeals.map((entry) => entry.food));
    _rememberFoodPhotos(searchResults);
    for (final meal in customMealPresets) {
      _rememberFoodPhotos(meal.items.map((item) => item.food));
    }
  }

  Future<void> _lookupCatalogPhoto(String name) => _lookupCatalogFood(name);

  Future<void> _lookupCatalogFood(String name) async {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return;

    final cached = _catalogFoodByName[key];
    final hasServing = cached?.hasDisplayServing == true;
    final hasImage =
        ((cached?.imageUrl ?? _catalogPhotoByName[key]) ?? '').isNotEmpty;
    if (hasServing && hasImage) return;
    if (_catalogPhotoMisses.contains(key) && hasServing) return;

    try {
      final results = await searchFoodsEphemeral(name);
      final match = _catalogFoodMatch(name, results);
      if (match != null) {
        _rememberCatalogFood(match);
        debugPrint(
          'FoodController: catalog food for "$name" → '
          'unit=${match.servingUnit} image=${match.imageUrl}',
        );
      } else if (!hasImage) {
        _catalogPhotoMisses.add(key);
      }
    } catch (error) {
      debugPrint(
        'FoodController: catalog lookup failed for $name: $error',
      );
    }
  }

  FoodItem? _catalogFoodMatch(String name, List<FoodItem> results) {
    final key = name.trim().toLowerCase();
    FoodItem? loose;
    for (final food in results) {
      final foodKey = food.name.trim().toLowerCase();
      if (foodKey == key) return food;
      if (loose == null &&
          (foodKey.contains(key) || key.contains(foodKey))) {
        loose = food;
      }
    }
    return loose;
  }

  FoodItem _foodWithCatalog(FoodItem food, {int? grams}) {
    final catalog = _catalogFoodByName[food.name.trim().toLowerCase()];
    final cachedImage = _imageUrlForFoodName(food.name);
    if (catalog == null && cachedImage == null) return food;
    final source = catalog ?? food.copyWith(imageUrl: cachedImage);
    return food.withServingFrom(source, loggedGrams: grams);
  }

  /// Restores catalog serving (bowl/glass/ml) and photo for a logged food.
  Future<FoodItem> hydrateLoggedFood(FoodItem food, {int? grams}) async {
    var next = _foodWithCatalog(food, grams: grams);
    final needsServing = !next.hasDisplayServing;
    final needsImage = (next.imageUrl ?? '').trim().isEmpty;
    if (needsServing || needsImage) {
      await _lookupCatalogFood(food.name);
      next = _foodWithCatalog(next, grams: grams);
    }
    return next;
  }

  void _storeHydratedMeal(CustomMealPreset meal) {
    final index = customMealPresets.indexWhere((item) => item.id == meal.id);
    if (index < 0) return;
    customMealPresets[index] = meal;
  }

  void _suppressDroppedQuickItemNames(Set<String> previousNames) {
    final live = _liveCatalogNames;
    var changed = false;
    for (final name in previousNames) {
      if (name.isEmpty || live.contains(name)) continue;
      if (_suppressedQuickItemNames.add(name)) changed = true;
    }
    if (changed) entriesRevision.value++;
  }

  void _forgetRemoteMyFood(String id) {
    _lastRemoteMyFoods = [
      for (final food in _lastRemoteMyFoods)
        if (food.id != id) food,
    ];
  }

  void _forgetRemoteCustomMeal(String id) {
    _lastRemoteCustomMeals = [
      for (final meal in _lastRemoteCustomMeals)
        if (meal.id != id) meal,
    ];
  }

  bool isFavorite(SavedMealItem item) {
    return favoriteMeals.any(
      (favorite) => favorite.food.isSameFavoriteFood(item.food),
    );
  }

  bool isFavoriteFood(FoodItem food, [String? meal]) {
    return favoriteMeals.any((item) => item.food.isSameFavoriteFood(food));
  }

  String _favoriteFoodKey(FoodItem food) {
    final id = food.catalogId?.trim();
    if (id != null && id.isNotEmpty) return 'id|$id';
    return 'name|${food.name.trim().toLowerCase()}';
  }

  List<SavedMealItem> _favoritesForFood(FoodItem food) {
    return [
      for (final item in favoriteMeals)
        if (item.food.isSameFavoriteFood(food)) item,
    ];
  }

  List<SavedMealItem> _uniqueFavorites(Iterable<SavedMealItem> items) {
    final seen = <String>{};
    final unique = <SavedMealItem>[];
    for (final item in items) {
      if (seen.add(_favoriteFoodKey(item.food))) unique.add(item);
    }
    return unique;
  }

  /// Star toggle: one favourite per food. Second tap removes it.
  Future<bool?> toggleFavorite(SavedMealItem item) async {
    final key = _favoriteFoodKey(item.food);
    if (key == 'name|' || !_favoriteToggleKeys.add(key)) return null;

    try {
      final existing = _favoritesForFood(item.food);
      if (existing.isNotEmpty) {
        favoriteMeals.removeWhere(
          (favorite) => favorite.food.isSameFavoriteFood(item.food),
        );
        for (final favorite in existing) {
          unawaited(_syncDeleteFavourite(favorite));
        }
        return false;
      }

      favoriteMeals.insert(0, item);
      unawaited(_syncAddFavourite(item));
      return true;
    } finally {
      _favoriteToggleKeys.remove(key);
    }
  }

  Future<bool?> toggleFavoriteFood({
    required FoodItem food,
    required int grams,
    required String meal,
  }) async {
    return toggleFavorite(
      SavedMealItem(
        food: food,
        grams: grams,
        meal: meal,
        servingQuantity: food.servingCountForGrams(grams),
        servingUnit: food.servingUnit,
      ),
    );
  }

  Future<void> removeFavorite(SavedMealItem item) async {
    final existing = _favoritesForFood(item.food);
    if (existing.isEmpty) return;
    favoriteMeals.removeWhere(
      (favorite) => favorite.food.isSameFavoriteFood(item.food),
    );
    for (final favorite in existing) {
      unawaited(_syncDeleteFavourite(favorite));
    }
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
        imageUrl: item.food.imageUrl,
      );

      final merged = synced.copyWith(
        food: synced.food.copyWith(
          imageUrl: MediaUrl.preferLoadable([
            synced.food.imageUrl,
            item.food.imageUrl,
          ]),
          catalogId: synced.food.catalogId ?? item.food.catalogId,
        ),
      );
      favoriteMeals.removeWhere(
        (favorite) =>
            favorite.food.isSameFavoriteFood(item.food) ||
            favorite.food.isSameFavoriteFood(merged.food),
      );
      favoriteMeals.insert(0, merged);
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
        if (candidate.food.isSameFavoriteFood(item.food) ||
            candidate.matchesFavorite(item) ||
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
  void logFavouriteMeal(SavedMealItem item, {String? meal, DateTime? date}) {
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

    if (awaitSync) {
      return _syncCustomMealPreset(
        preset,
        previous: previous,
        isUpdate: updating,
      );
    }

    unawaited(
      _syncCustomMealPreset(preset, previous: previous, isUpdate: updating),
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

    final synced = await _syncDeleteMyFood(id, name: removed?.food.name);
    if (!synced) {
      if (removed != null &&
          customFoodPresets.every((food) => food.id != removed!.id)) {
        customFoodPresets.insert(0, removed);
      }
      throw MyFoodsApiException(
        'Could not delete "${removed?.food.name ?? 'food'}" on the server.',
      );
    }

    _forgetRemoteMyFood(id);
    if (removed != null) {
      _forgetRemoteMyFood(removed.id);
      _suppressDroppedQuickItemNames(_quickItemNamesForFoods([removed]));
    }
  }

  /// Logs a My Food item locally and via `POST /api/v1/my-foods/:id/log`.
  void logMyFood(
    CustomFoodPreset preset, {
    String? meal,
    DateTime? date,
    int? grams,
    double? servingQuantity,
  }) {
    final mealSlot = meal ?? selectedMeal.value;
    final day = MealEntry.normalizeDate(date ?? selectedLogDate.value);
    final entry = SavedMealItem(
      food: preset.food,
      grams: grams ?? preset.defaultGrams,
      meal: mealSlot,
      servingQuantity: servingQuantity ?? preset.servingQuantity,
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

      if (serverId == null && isUpdate) {
        debugPrint(
          'FoodController: edit sync skipped POST for "${preset.food.name}" '
          '(no server my-food id resolved for localId=${preset.id})',
        );
        AppSnackbar.error(
          'Could not update ${preset.food.name} on the server.',
          title: 'Save failed',
        );
        return preset;
      }

      final uploaded = await _imageForSync(
        accessToken: accessToken,
        imageBytes: preset.imageBytes,
        existingUrl: preset.food.imageUrl,
      );
      late final CustomFoodPreset synced;

      if (serverId != null) {
        debugPrint(
          'FoodController: calling PATCH my-foods API at '
          '${ApiEndpoints.myFoodByIdUrl(serverId)} '
          '(isUpdate=$isUpdate localId=${preset.id})',
        );
        final toSync = _foodPresetWithImage(
          preset.copyWith(id: serverId),
          imageKey: uploaded?.key,
          displayUrl: uploaded?.displayUrl,
        );
        synced = await _myFoodsRepository.updateMyFood(
          accessToken: accessToken,
          myFoodId: serverId,
          preset: toSync,
          mealtime: mealtime,
          imageUrl: uploaded?.key,
        );
      } else {
        debugPrint(
          'FoodController: calling POST my-foods API at '
          '${ApiEndpoints.myFoodsUrl}',
        );
        final toSync = _foodPresetWithImage(
          preset,
          imageKey: uploaded?.key,
          displayUrl: uploaded?.displayUrl,
        );
        synced = await _myFoodsRepository.saveMyFood(
          accessToken: accessToken,
          preset: toSync,
          mealtime: mealtime,
          imageUrl: uploaded?.key,
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
    } on UploadsApiException catch (error) {
      debugPrint('FoodController: my-foods image upload failed: $error');
      AppSnackbar.error(
        error.message.isNotEmpty
            ? error.message
            : 'Could not upload the photo for ${preset.food.name}.',
        title: 'Photo upload failed',
      );
      return preset;
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
  Future<bool> _syncDeleteMyFood(String myFoodId, {String? name}) async {
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
      debugPrint('FoodController: failed resolving server my-food id: $error');
    }
    return null;
  }

  /// Uploads a new photo and returns the object key plus a loadable URL.
  Future<({String key, String? displayUrl})?> _imageForSync({
    required String accessToken,
    Uint8List? imageBytes,
    String? existingUrl,
  }) async {
    final existingKey = MediaUrl.apiImageKey(existingUrl);
    if (existingKey != null) {
      return (key: existingKey, displayUrl: MediaUrl.resolve(existingUrl));
    }
    if (imageBytes == null || imageBytes.isEmpty) return null;

    final scaled = await downscaleImageBytes(imageBytes);
    final result = await _uploadsRepository.uploadImage(
      accessToken: accessToken,
      imageBytes: scaled,
      filename: uploadImageFilename(scaled),
    );
    return (
      key: result.key,
      displayUrl: result.url ?? MediaUrl.resolve(result.key),
    );
  }

  CustomFoodPreset _foodPresetWithImage(
    CustomFoodPreset preset, {
    String? imageKey,
    String? displayUrl,
  }) {
    final url = displayUrl ?? MediaUrl.resolve(imageKey);
    if (url == null || url.isEmpty) return preset;
    return preset.copyWith(food: preset.food.copyWith(imageUrl: url));
  }

  CustomMealPreset _mealPresetWithImage(
    CustomMealPreset preset, {
    String? imageKey,
    String? displayUrl,
  }) {
    final url = displayUrl ?? MediaUrl.resolve(imageKey);
    if (url == null || url.isEmpty) return preset;
    return preset.copyWith(imageUrl: url);
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

      if (serverId == null && isUpdate) {
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
      }

      final uploaded = await _imageForSync(
        accessToken: accessToken,
        imageBytes: preset.imageBytes,
        existingUrl: preset.imageUrl,
      );
      final toSync = _mealPresetWithImage(
        serverId != null ? preset.copyWith(id: serverId) : preset,
        imageKey: uploaded?.key,
        displayUrl: uploaded?.displayUrl,
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
          preset: toSync,
          imageUrl: uploaded?.key,
        );
      } else {
        debugPrint(
          'FoodController: calling POST my-meals API at '
          '${ApiEndpoints.myMealsUrl} '
          '(isUpdate=$isUpdate localId=${preset.id})',
        );
        synced = await _customMealsRepository.createCustomMeal(
          accessToken: accessToken,
          preset: toSync,
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
    } on UploadsApiException catch (error) {
      debugPrint('FoodController: my-meals image upload failed: $error');
      AppSnackbar.error(
        error.message.isNotEmpty
            ? error.message
            : 'Could not upload the photo for ${preset.name}.',
        title: 'Photo upload failed',
      );
      return preset;
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

    _forgetRemoteCustomMeal(id);
    if (removed != null) {
      _forgetRemoteCustomMeal(removed.id);
      _suppressDroppedQuickItemNames(_quickItemNamesForMeals([removed]));
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
        final sameMeal =
            mealKey == null ||
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
      debugPrint('FoodController: failed resolving server my-meal id: $error');
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

    _refreshMealsFuture =
        _refreshMealsFromApi(
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

    await refreshMealsFromApi(period: 'custom', fromDate: from, toDate: to);
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
          'name=${meal.food.name} meal=${meal.meal} g=${meal.grams} '
          'image=${meal.food.imageUrl}',
        );
      }

      final preserved = _hydrateMealsFromCatalog(fetched);

      apiMeals.assignAll(preserved);

      if (date != null) {
        final normalized = MealEntry.normalizeDate(date);
        // API is source of truth for that day — do not keep local-only ghosts.
        entries.assignAll([
          ...entries.where((e) => e.date != normalized),
          ...preserved,
        ]);
        _markEntriesDirty();
      } else if (preserved.isNotEmpty) {
        // Full meals payload replaces in-memory diary (API source of truth).
        entries.assignAll(preserved);
        _markEntriesDirty();
      }

      _notifyStreakController();
      unawaited(_hydrateMissingMealCatalog(preserved));
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

  List<MealEntry> _hydrateMealsFromCatalog(List<MealEntry> fetched) {
    final preserved = _preserveHouseholdServings(fetched);
    return [
      for (final entry in preserved)
        entry.copyWith(food: _foodWithCatalog(entry.food, grams: entry.grams)),
    ];
  }

  Future<void> _hydrateMissingMealCatalog(List<MealEntry> meals) async {
    final missing = <String>{
      for (final meal in meals)
        if (!meal.food.hasDisplayServing ||
            (meal.food.imageUrl ?? '').trim().isEmpty)
          meal.food.name.trim(),
    }..removeWhere((name) => name.isEmpty);
    if (missing.isEmpty) return;

    await Future.wait(missing.map(_lookupCatalogFood));
    _applyCatalogToLoadedMeals();
  }

  void _applyCatalogToLoadedMeals() {
    var changed = false;

    FoodItem apply(MealEntry entry) {
      final food = entry.food;
      final next = _foodWithCatalog(food, grams: entry.grams);
      if (next.imageUrl != food.imageUrl ||
          next.servingUnit != food.servingUnit ||
          next.gramsPerServing != food.gramsPerServing) {
        changed = true;
      }
      return next;
    }

    for (var i = 0; i < entries.length; i++) {
      final food = apply(entries[i]);
      if (!identical(food, entries[i].food)) {
        entries[i] = entries[i].copyWith(food: food);
      }
    }
    for (var i = 0; i < apiMeals.length; i++) {
      final food = apply(apiMeals[i]);
      if (!identical(food, apiMeals[i].food)) {
        apiMeals[i] = apiMeals[i].copyWith(food: food);
      }
    }
    if (changed) {
      _markEntriesDirty();
      entriesRevision.value++;
    }
  }

  List<MealEntry> _preserveHouseholdServings(List<MealEntry> fetched) {
    if (fetched.isEmpty) return fetched;
    final previous = [...entries, ...apiMeals];
    if (previous.isEmpty) return fetched;

    final byId = <String, MealEntry>{};
    for (final entry in previous) {
      if (entry.food.usesHouseholdServing) {
        byId[entry.id] = entry;
      }
    }

    return fetched.map((remote) {
      if (remote.food.usesHouseholdServing) return remote;

      final byServerId = byId[remote.id];
      if (byServerId != null) {
        return remote.copyWith(
          food: remote.food.withServingFrom(byServerId.food),
        );
      }

      for (final local in previous) {
        if (!local.food.usesHouseholdServing) continue;
        if (local.food.name.toLowerCase() != remote.food.name.toLowerCase()) {
          continue;
        }
        if (local.meal != remote.meal || local.date != remote.date) continue;
        return remote.copyWith(food: remote.food.withServingFrom(local.food));
      }
      return remote;
    }).toList();
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
    final yesterdayMeals = entries.where((e) => e.date == yesterday).toList();
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

    final previousDays =
        entries
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
      await AnalyticsService.logFoodSearch(trimmed);
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
    final foods = await _api.searchFoods(
      trimmed,
      accessToken: accessToken,
      page: 1,
      limit: 20,
    );
    _rememberFoodPhotos(foods);
    return foods;
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
    final selectedMealType = meal ?? selectedMeal.value;

    _insertEntry(
      MealEntry(
        food: food,
        grams: grams ?? food.defaultGrams,
        meal: selectedMealType,
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
      final synced = created.copyWith(
        food: created.food.withServingFrom(entry.food),
      );

      final index = entries.indexWhere((e) => e.id == entry.id);
      if (_looksLikeLocalMealId(synced.id)) {
        // Response missing server id — drop draft and reload from API.
        if (index >= 0) entries.removeAt(index);
        await refreshMealsFromApi(date: entry.date);
        return;
      }

      if (index >= 0) {
        entries[index] = synced;
      } else {
        entries.add(synced);
      }
      await AnalyticsService.logMealAdded(synced.meal);

      apiMeals.removeWhere((e) => e.id == entry.id || e.id == synced.id);
      apiMeals.add(synced);

      _dropDuplicateEntriesById(synced.id);
      _markEntriesDirty(celebrationDay: synced.date);
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
  Future<bool> updateEntry(
    MealEntry entry, {
    int? grams,
    String? meal,
    FoodItem? food,
  }) async {
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index < 0) return false;

    final updated = entry.copyWith(grams: grams, meal: meal, food: food);
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
      final synced = saved.copyWith(
        food: saved.food.withServingFrom(updated.food),
        grams: grams ?? saved.grams,
        meal: meal ?? saved.meal,
      );
      final i = entries.indexWhere(
        (e) => e.id == entry.id || e.id == synced.id,
      );
      if (i >= 0) {
        entries[i] = synced;
      }
      apiMeals.removeWhere((e) => e.id == entry.id || e.id == synced.id);
      apiMeals.add(synced);
      _markEntriesDirty(celebrationDay: synced.date);
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
          apiMeals.removeWhere((e) => e.id == entry.id || e.id == created.id);
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
          await refreshMealsFromApi(
            date: entry.date,
          ).timeout(const Duration(seconds: 6));
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
      await refreshMealsFromApi(
        date: entry.date,
      ).timeout(const Duration(seconds: 6));
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
      debugPrint('FoodController: commitDeletingGroup failed: $error\n$stack');
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
      debugPrint('FoodController: force-clear stuck delete animation id=$id');
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
      AppSnackbar.success('Removed from your diary.', title: 'Deleted');
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
    return _deletingGroups.where((g) => g.representative.meal == meal).toList();
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
    AppSnackbar.info("Past meals can't be edited.", title: 'Read only');
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}
