import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../core/api_errors.dart';
import '../core/app_snackbar.dart';
import '../core/meal_entry_merge.dart';
import '../models/daily_nutrition.dart';
import '../models/food_item.dart';
import '../models/meal_entry.dart';
import '../models/meal_suggestion.dart';
import '../models/meal_summary.dart';
import '../models/meal_type.dart';
import '../models/saved_meal_item.dart';
import '../repositories/meals_repository.dart';
import '../services/food_api_service.dart';
import '../services/local_storage_service.dart';
import '../services/api_endpoints.dart';
import '../services/meals_api_service.dart';
import '../widgets/calorie_goal_success_dialog.dart';
import 'dashboard_controller.dart';
import 'streak_controller.dart';
import 'user_controller.dart';

class FoodController extends GetxController {
  FoodController({
    FoodApiService? api,
    LocalStorageService? storage,
    MealsRepository? mealsRepository,
  })  : _api = api ?? FoodApiService(),
        _storage = storage ?? LocalStorageService(),
        _mealsRepository = mealsRepository ?? MealsRepository();

  final FoodApiService _api;
  final LocalStorageService _storage;
  final MealsRepository _mealsRepository;

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
  final RxMap<String, bool> expandedMeals = <String, bool>{}.obs;
  final RxList<MealEntry> repeatedYesterdayEntries = <MealEntry>[].obs;
  final RxSet<String> selectedYesterdayMeals = <String>{}.obs;
  final RxBool isSearching = false.obs;
  final RxBool isLoadingMealsApi = false.obs;
  final RxnString mealsApiErrorMessage = RxnString();
  final Rx<DateTime> selectedLogDate =
      MealEntry.normalizeDate(DateTime.now()).obs;  

  Timer? _debounce;
  bool _calorieGoalCelebrationShown = false;
  Future<void>? _refreshMealsFuture;
  String? _dismissedBreakfastSuggestionDate;
  static const String _repeatCardDismissKey =
    'repeat_card_dismiss_date';

  @override
void onInit() {
  super.onInit();

  unawaited(_loadPersistedEntries());
  unawaited(loadRepeatYesterdayCardState());
}

  Future<void> _loadPersistedEntries() async {
    final loaded = await _storage.loadMealEntries();
      if (loaded.isNotEmpty) {
        entries.assignAll(loaded);
        entriesRevision.value++;
        _notifyStreakController();
    }

    favoriteMeals.assignAll(await _storage.loadFavoriteMeals());
    _dismissedBreakfastSuggestionDate =
        await _storage.loadDismissedBreakfastSuggestionDate();

    unawaited(refreshMealsFromApi());
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

  int mealCountOnDate(DateTime date) {
    final day = MealEntry.normalizeDate(date);
    return entries.where((entry) => entry.date == day).length;
  }

  int get yesterdayMealCount {
    final yesterday =
        selectedLogDate.value.subtract(const Duration(days: 1));
    return mealCountOnDate(yesterday);
  }

  bool get canRepeatYesterday => yesterdayMealCount > 0;
  bool get hasRepeatedYesterdayMeals =>
    repeatedYesterdayEntries.isNotEmpty;

  bool get isBreakfastSuggestionDismissed {
    final todayKey = MealEntry.dateToKey(DateTime.now());
    return _dismissedBreakfastSuggestionDate == todayKey;
  }

  MealSuggestion? get breakfastSuggestion {
    entriesRevision.value;
    if (!_isToday(selectedLogDate.value)) return null;
    if (mealsForSelectedDate(MealType.breakfast).isNotEmpty) return null;
    if (isBreakfastSuggestionDismissed) return null;

    final yesterday =
        selectedLogDate.value.subtract(const Duration(days: 1));
    final yesterdayBreakfast =
        mealsForDate(yesterday, MealType.breakfast);
    if (yesterdayBreakfast.isNotEmpty) {
      final items =
          yesterdayBreakfast.map(SavedMealItem.fromMealEntry).toList();
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
    return favoriteMeals.any((favorite) => favorite.storageKey == item.storageKey);
  }

  bool isFavoriteFood(FoodItem food, String meal) {
    return favoriteMeals.any((item) => item.matchesFoodAndMeal(food, meal));
  }

  Future<void> toggleFavorite(SavedMealItem item) async {
    final index = favoriteMeals.indexWhere(
      (favorite) => favorite.storageKey == item.storageKey,
    );

    if (index >= 0) {
      favoriteMeals.removeAt(index);
    } else {
      favoriteMeals.insert(0, item);
    }

    await _storage.saveFavoriteMeals(favoriteMeals.toList());
  }

  Future<void> toggleFavoriteFood({
    required FoodItem food,
    required int grams,
    required String meal,
  }) async {
    await toggleFavorite(SavedMealItem(food: food, grams: grams, meal: meal));
  }

  Future<void> removeFavorite(SavedMealItem item) async {
    favoriteMeals.removeWhere(
      (favorite) => favorite.storageKey == item.storageKey,
    );
    await _storage.saveFavoriteMeals(favoriteMeals.toList());
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
    await _storage.saveDismissedBreakfastSuggestionDate(todayKey);
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

  Future<void> refreshMealsFromApi({DateTime? date}) {
    if (_refreshMealsFuture != null) {
      return _refreshMealsFuture!;
    }

    _refreshMealsFuture = _refreshMealsFromApi(date: date).whenComplete(() {
      _refreshMealsFuture = null;
    });
    return _refreshMealsFuture!;
  }

  Future<void> _refreshMealsFromApi({DateTime? date}) async {
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

    try {
      debugPrint('FoodController: calling GET meals API at ${ApiEndpoints.url(ApiEndpoints.mealsWithQuery(date: date))}');
      final fetched = await _mealsRepository.fetchMeals(
        accessToken: userController.accessToken,
        date: date,
      );

      debugPrint('FoodController: meals API returned ${fetched.length} meals');

      apiMeals.assignAll(fetched);

      if (date != null) {
        final normalized = MealEntry.normalizeDate(date);
        entries.assignAll(
          MealEntryMerge.mergeForDay(
            current: entries.toList(),
            day: normalized,
            fetched: fetched,
          ),
        );
        _markEntriesDirty();
      } else if (fetched.isNotEmpty) {
        entries.assignAll(
          MealEntryMerge.mergeAll(
            current: entries.toList(),
            fetched: fetched,
          ),
        );
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
  }

  List<MealEntry> mealsForDate(DateTime day, String meal) {
    final normalized = MealEntry.normalizeDate(day);
    return entries
        .where((e) => e.date == normalized && e.meal == meal)
        .toList();
  }
  List<MealEntry> getYesterdayMeals() {
  final yesterday = MealEntry.normalizeDate(
    selectedLogDate.value.subtract(const Duration(days: 1)),
  );

  return entries
      .where((entry) => entry.date == yesterday)
      .toList();
}

  List<MealEntry> mealsForSelectedDate(String meal) =>
      mealsForDate(selectedLogDate.value, meal);

  int caloriesForMealOnDate(DateTime day, String meal) =>
      mealsForDate(day, meal).fold(0, (sum, e) => sum + e.calories);

  int caloriesForMealOnSelectedDate(String meal) =>
      caloriesForMealOnDate(selectedLogDate.value, meal);

  int get selectedDateCalories =>
      selectedDateMeals.fold(0, (sum, e) => sum + e.calories);

  List<DailyNutrition> get last7Days =>
      nutritionForLastDays(7);

  List<DailyNutrition> nutritionForLastDays(int dayCount) {
    final today = MealEntry.normalizeDate(DateTime.now());
    return List.generate(dayCount, (index) {
      final day = today.subtract(Duration(days: dayCount - 1 - index));
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
      return;
    }

    isSearching.value = true;
    try {
      searchResults.value = await _api.searchFoods(trimmed);
    } finally {
      isSearching.value = false;
    }
  }

  void onSearchChanged(String value) {
    searchQuery.value = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      searchFoods(value);
    });
  }

  void logFromHistory(
    SavedMealItem item, {
    DateTime? date,
    String? meal,
  }) {
    _insertEntry(
      item.copyWith(meal: meal ?? item.meal).toMealEntry(
        date: date ?? selectedLogDate.value,
      ),
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
  final yesterday = target.subtract(const Duration(days: 1));

  final sourceMeals =
      entries.where((entry) => entry.date == yesterday).toList();

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
  final yesterday = target.subtract(const Duration(days: 1));

  final sourceMeals = entries.where(
    (entry) =>
        entry.date == yesterday &&
        selectedYesterdayMeals.contains(entry.id),
  ).toList();

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


  void _insertEntry(MealEntry entry) {
    entries.add(entry);
    _markEntriesDirty();
    unawaited(_syncCreateMeal(entry));
  }

  List<FoodItem> get filteredFoods => searchResults;

  int get totalCaloriesEaten =>
      todayMeals.fold(0, (sum, e) => sum + e.calories);

  double get totalProtein =>
      todayMeals.fold(0.0, (sum, e) => sum + e.protein);

  double get totalCarbs =>
      todayMeals.fold(0.0, (sum, e) => sum + e.carbs);

  double get totalFat => todayMeals.fold(0.0, (sum, e) => sum + e.fat);

  void addToLog(
    FoodItem food, {
    String? meal,
    DateTime? date,
    int? grams,
  }) {
    _insertEntry(
      MealEntry(
        food: food,
        grams: grams ?? selectedGrams.value,
        meal: meal ?? selectedMeal.value,
        date: date ?? selectedLogDate.value,
      ),
    );
    selectedGrams.value = 100;
  }

  Future<String?> _mealAccessToken() async {
    if (!Get.isRegistered<UserController>()) return null;

    final userController = Get.find<UserController>();
    await userController.localProfileReady;
    await userController.loadAuthSession();

    if (!userController.isLoggedIn || userController.accessToken.isEmpty) {
      return null;
    }

    return userController.accessToken;
  }

  Future<void> _syncCreateMeal(MealEntry entry) async {
    final accessToken = await _mealAccessToken();
    if (accessToken == null) return;

    try {
      debugPrint(
        'FoodController: calling POST meals API at ${ApiEndpoints.mealsUrl}',
      );
      final created = await _mealsRepository.createMeal(
        accessToken: accessToken,
        entry: entry,
      );

      final index = entries.indexWhere((e) => e.id == entry.id);
      if (index < 0) return;

      entries[index] = created;
      _markEntriesDirty();
      _notifyStreakController();
      await refreshMealsFromApi();
    } on MealsApiException catch (error) {
      debugPrint('FoodController: create meal API failed: $error');
      mealsApiErrorMessage.value = error.message;
      AppSnackbar.info(
        '${entry.food.name} was added to your diary. '
        'It could not sync to the server yet.',
        title: 'Saved on device',
      );
    } catch (error) {
      debugPrint('FoodController: create meal API failed: $error');
      mealsApiErrorMessage.value =
          apiNetworkErrorMessage(error, action: 'saving meal');
      AppSnackbar.info(
        '${entry.food.name} was added to your diary. '
        'It could not sync to the server yet.',
        title: 'Saved on device',
      );
    }
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

  for (final meal in getYesterdayMeals()) {
    selectedYesterdayMeals.add(meal.id);
  }
}

void unselectAllYesterdayMeals() {
  selectedYesterdayMeals.clear();
}
  void _markEntriesDirty() {
    entries.refresh();
    entriesRevision.value++;
    unawaited(_persistEntries());
    _notifyStreakController();
    _maybeCelebrateCalorieGoal();
  }

  void _notifyEntriesChanged() {
    _markEntriesDirty();
  }

  Future<void> _persistEntries() async {
    await _storage.saveMealEntries(entries.toList());
  }

  void _notifyStreakController() {
    if (!Get.isRegistered<StreakController>()) return;
    Get.find<StreakController>().onMealsChanged();
  }

  void _maybeCelebrateCalorieGoal() {
    if (!Get.isRegistered<DashboardController>()) return;

    final dash = Get.find<DashboardController>();
    final goal = dash.calorieGoal;
    if (goal <= 0) return;

    final consumed = dash.foodCalories;
    if (consumed < goal) {
      _calorieGoalCelebrationShown = false;
      return;
    }

    if (_calorieGoalCelebrationShown) return;
    _calorieGoalCelebrationShown = true;
    CalorieGoalSuccessDialog.show(consumed: consumed, goal: goal);
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

  void updateEntry(
    MealEntry entry, {
    int? grams,
    String? meal,
  }) {
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index < 0) return;

    entries[index] = entry.copyWith(
      grams: grams,
      meal: meal,
    );
    _notifyEntriesChanged();
  }

  void removeEntry(MealEntry entry) {
    entries.removeWhere((e) => e.id == entry.id);
    _notifyEntriesChanged();
    unawaited(_syncDeleteMeal(entry));
  }
  Future<void> cancelRepeatedYesterdayMeals() async {
  if (repeatedYesterdayEntries.isEmpty) return;

  final meals = List<MealEntry>.from(repeatedYesterdayEntries);

  repeatedYesterdayEntries.clear();

  for (final meal in meals) {
    removeEntry(meal);
  }

  entriesRevision.value++;  
}

  Future<void> _syncDeleteMeal(MealEntry entry) async {
    final accessToken = await _mealAccessToken();
    if (accessToken == null) return;

    try {
      debugPrint(
        'FoodController: calling DELETE meals API at '
        '${ApiEndpoints.mealsByIdUrl(entry.id)}',
      );
      await _mealsRepository.deleteMeal(
        accessToken: accessToken,
        mealId: entry.id,
      );

      _notifyStreakController();
      await refreshMealsFromApi();
    } on MealsApiException catch (error) {
      if (error.statusCode == 404) {
        debugPrint(
          'FoodController: delete meal API returned 404 for ${entry.id}',
        );
        return;
      }

      debugPrint('FoodController: delete meal API failed: $error');
      entries.add(entry);
      _markEntriesDirty();
      mealsApiErrorMessage.value = error.message;
      AppSnackbar.info(
        '${entry.food.name} was removed from your diary, but it could not '
        'be deleted on the server yet.',
        title: 'Removed on device',
      );
    } catch (error) {
      debugPrint('FoodController: delete meal API failed: $error');
      entries.add(entry);
      _markEntriesDirty();
      mealsApiErrorMessage.value =
          apiNetworkErrorMessage(error, action: 'deleting meal');
      AppSnackbar.info(
        '${entry.food.name} was removed from your diary, but it could not '
        'be deleted on the server yet.',
        title: 'Removed on device',
      );
    }
  }

  MealEntry? findEntry(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }
  Future<void> loadRepeatYesterdayCardState() async {
  final prefs = await SharedPreferences.getInstance();

  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final dismissedDate = prefs.getString(_repeatCardDismissKey);

  showRepeatYesterdayCard.value = dismissedDate != today;
}

Future<void> dismissRepeatYesterdayCard() async {
  final prefs = await SharedPreferences.getInstance();

  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  await prefs.setString(_repeatCardDismissKey, today);

  showRepeatYesterdayCard.value = false;
}

  bool _isToday(DateTime date) =>
      date == MealEntry.normalizeDate(DateTime.now());

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}
