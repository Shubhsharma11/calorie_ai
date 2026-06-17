import 'dart:async';

import 'package:get/get.dart';

import '../models/daily_nutrition.dart';
import '../models/food_item.dart';
import '../models/meal_entry.dart';
import '../models/meal_summary.dart';
import '../models/meal_type.dart';
import '../services/food_api_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/calorie_goal_success_dialog.dart';
import 'dashboard_controller.dart';
import 'streak_controller.dart';

class FoodController extends GetxController {
  FoodController({
    FoodApiService? api,
    LocalStorageService? storage,
  })  : _api = api ?? FoodApiService(),
        _storage = storage ?? LocalStorageService();

  final FoodApiService _api;
  final LocalStorageService _storage;

  static const int maxRecentFoods = 10;

  /// All logged meals keyed by day via [MealEntry.date].
  final RxList<MealEntry> entries = <MealEntry>[].obs;

  /// Bumps on any add, update, or remove so UIs refresh beyond length changes.
  final RxInt entriesRevision = 0.obs;

  final RxString searchQuery = ''.obs;
  final RxString selectedMeal = MealType.breakfast.obs;
  final RxInt selectedGrams = 100.obs;
  final RxList<FoodItem> searchResults = <FoodItem>[].obs;
  final RxList<FoodItem> recentFoods = <FoodItem>[].obs;
  final RxBool isSearching = false.obs;
  final Rx<DateTime> selectedLogDate =
      MealEntry.normalizeDate(DateTime.now()).obs;

  Timer? _debounce;
  bool _calorieGoalCelebrationShown = false;

  @override
  void onInit() {
    super.onInit();
    _loadPersistedEntries();
  }

  Future<void> _loadPersistedEntries() async {
    final loaded = await _storage.loadMealEntries();
    if (loaded.isEmpty) return;

    entries.assignAll(loaded);
    entriesRevision.value++;
    _notifyStreakController();
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

  void recordRecentFood(FoodItem food) {
    recentFoods.removeWhere((f) => f.name == food.name);
    recentFoods.insert(0, food);
    if (recentFoods.length > maxRecentFoods) {
      recentFoods.removeRange(maxRecentFoods, recentFoods.length);
    }
  }

  void openRecentFood(FoodItem food) {
    recordRecentFood(food);
    searchQuery.value = food.name;
  }

  void clearRecentFoods() => recentFoods.clear();

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
  }) {
    recordRecentFood(food);
    entries.add(
      MealEntry(
        food: food,
        grams: selectedGrams.value,
        meal: meal ?? selectedMeal.value,
        date: date,
      ),
    );
    selectedGrams.value = 100;
    _notifyEntriesChanged();
  }

  void _notifyEntriesChanged() {
    entries.refresh();
    entriesRevision.value++;
    _persistEntries();
    _notifyStreakController();
    _maybeCelebrateCalorieGoal();
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
  }

  MealEntry? findEntry(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  bool _isToday(DateTime date) =>
      date == MealEntry.normalizeDate(DateTime.now());

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}
