import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

import '../controllers/food_controller.dart';
import '../controllers/main_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../models/custom_food_preset.dart';
import '../models/custom_meal_preset.dart';
import '../models/food_item.dart';
import '../models/meal_type.dart';
import '../models/saved_meal_item.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/create_meal/create_meal_bottom_sheet.dart';
import '../widgets/create_meal/create_meal_promo_card.dart';
import '../widgets/filter_chip_pill.dart';
import '../widgets/food_emoji_avatar.dart';
import '../widgets/log_history_sheet.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/delete_lottie.dart';
import '../widgets/no_results_illustration.dart';
import '../widgets/responsive_page.dart';
import 'create_custom_food_view.dart';

class AddFoodView extends StatefulWidget {
  const AddFoodView({super.key});

  @override
  State<AddFoodView> createState() => _AddFoodViewState();
}

class _AddFoodViewState extends State<AddFoodView> {
  late final FoodController _food = Get.find<FoodController>();
  late final FocusNode _searchFocusNode;
  _FoodCatalogTab _catalogTab = _FoodCatalogTab.all;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
    // Always open Add Food with a fresh search field.
    _food.clearSearch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Quick items from meals; catalog lists load when their tabs are opened.
      _food.refreshQuickItemsFromApi();
    });
  }

  @override
  void dispose() {
    _food.clearSearch();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppAppBar(title: 'Add Food'),
      body: ResponsivePage(
        scrollable: false,
        maxWidth: r.isWide ? 900 : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(
              () => _MealSelector(
                selectedMeal: _food.selectedMeal.value,
                onSelected: _food.setSelectedMeal,
              ),
            ),
            SizedBox(height: r.scale(10)),
            _SearchBar(focusNode: _searchFocusNode),
            SizedBox(height: r.scale(12)),
            Expanded(
              child: Obx(() {
                final query = _food.searchQuery.value.trim();
                final isSearching = _food.isSearching.value;

                if (query.isNotEmpty) {
                  return _SearchResultsList(
                    isSearching: isSearching,
                    foods: _food.filteredFoods,
                    errorMessage: _food.searchErrorMessage.value,
                    onCreateFood: () => Get.to<void>(
                      () => const CreateCustomFoodView(),
                    ),
                  );
                }

                return _FoodBrowseList(
                  selectedMeal: _food.selectedMeal.value,
                  catalogTab: _catalogTab,
                  onCatalogTabChanged: (tab) {
                    setState(() => _catalogTab = tab);
                    switch (tab) {
                      case _FoodCatalogTab.myMeals:
                        unawaited(_food.refreshCustomMealsFromApi());
                      case _FoodCatalogTab.customFood:
                        unawaited(_food.refreshMyFoodsFromApi());
                      case _FoodCatalogTab.favourites:
                        unawaited(_food.refreshFavouritesFromApi());
                      case _FoodCatalogTab.all:
                        break;
                    }
                  },
                  onCreateMeal: () => showCreateMealSheet(
                    context,
                    initialMeal: _food.selectedMeal.value,
                  ),
                  onFindFavourite: () {
                    setState(() => _catalogTab = _FoodCatalogTab.all);
                    _searchFocusNode.requestFocus();
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealSelector extends StatelessWidget {
  const _MealSelector({
    required this.selectedMeal,
    required this.onSelected,
  });

  final String selectedMeal;
  final ValueChanged<String> onSelected;

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final r = sheetContext.responsive;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              r.scale(20),
              r.scale(16),
              r.scale(20),
              r.scale(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add to meal',
                  style: TextStyle(
                    fontSize: r.scale(18),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: r.scale(10)),
                ...MealType.all.map((meal) {
                  final isSelected = meal == selectedMeal;
                  return ListTile(
                    onTap: () => Navigator.pop(sheetContext, meal),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: r.scale(4),
                    ),
                    leading: Icon(
                      _mealIcon(meal),
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    title: Text(
                      meal,
                      style: TextStyle(
                        fontSize: r.scale(15),
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                          )
                        : null,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && selected != selectedMeal) {
      onSelected(selected);
    }
  }

  static IconData _mealIcon(String meal) => switch (meal) {
        MealType.breakfast => Icons.free_breakfast_rounded,
        MealType.lunch => Icons.lunch_dining_rounded,
        MealType.dinner => Icons.dinner_dining_rounded,
        MealType.snacks => Icons.cookie_rounded,
        _ => Icons.restaurant_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return InkWell(
      onTap: () => _openPicker(context),
      borderRadius: BorderRadius.circular(r.scale(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: r.scale(2)),
        child: Row(
          children: [
            Text(
              'Adding to ',
              style: TextStyle(
                fontSize: r.scale(13, tablet: 14),
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              selectedMeal,
              style: TextStyle(
                fontSize: r.scale(13, tablet: 14),
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: r.scale(20),
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

enum _FoodCatalogTab { all, myMeals, customFood, favourites }

class _FoodBrowseList extends GetView<FoodController> {
  const _FoodBrowseList({
    required this.selectedMeal,
    required this.catalogTab,
    required this.onCatalogTabChanged,
    required this.onCreateMeal,
    required this.onFindFavourite,
  });

  final String selectedMeal;
  final _FoodCatalogTab catalogTab;
  final ValueChanged<_FoodCatalogTab> onCatalogTabChanged;
  final VoidCallback onCreateMeal;
  final VoidCallback onFindFavourite;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Obx(() {
      final revision = controller.entriesRevision.value;
      final isLoading = controller.isLoadingMealsApi.value;
      final apiError = controller.mealsApiErrorMessage.value;
      controller.apiMeals.length;
      final quickItems = controller.recentQuickMeals;
      final customMeals = controller.customMealPresets.toList();
      final favorites = controller.favoriteMeals.toList();

      return ListView(
        key: ValueKey('$revision-${catalogTab.name}'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + r.scale(16),
        ),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChipPill(
                  label: 'All',
                  selected: catalogTab == _FoodCatalogTab.all,
                  onTap: () => onCatalogTabChanged(_FoodCatalogTab.all),
                  fontSize: r.scale(13),
                ),
                SizedBox(width: r.scale(10)),
                FilterChipPill(
                  label: 'My Meals',
                  selected: catalogTab == _FoodCatalogTab.myMeals,
                  onTap: () => onCatalogTabChanged(_FoodCatalogTab.myMeals),
                  fontSize: r.scale(13),
                ),
                SizedBox(width: r.scale(10)),
                FilterChipPill(
                  label: 'My Food',
                  selected: catalogTab == _FoodCatalogTab.customFood,
                  onTap: () => onCatalogTabChanged(_FoodCatalogTab.customFood),
                  fontSize: r.scale(13),
                ),
                SizedBox(width: r.scale(10)),
                FilterChipPill(
                  label: 'Favourite',
                  selected: catalogTab == _FoodCatalogTab.favourites,
                  onTap: () => onCatalogTabChanged(_FoodCatalogTab.favourites),
                  fontSize: r.scale(13),
                ),
              ],
            ),
          ),
          SizedBox(height: r.scale(16)),
          ...switch (catalogTab) {
            _FoodCatalogTab.all => _buildQuickItemsSection(
                context,
                quickItems: quickItems,
                isLoading: isLoading,
                apiError: apiError,
              ),
            _FoodCatalogTab.myMeals =>
              _buildMyMealsSection(context, customMeals: customMeals),
            _FoodCatalogTab.customFood => [const _CustomFoodCreator()],
            _FoodCatalogTab.favourites =>
              _buildFavoritesSection(context, favorites: favorites),
          },
        ],
      );
    });
  }

  List<Widget> _buildFavoritesSection(
    BuildContext context, {
    required List<SavedMealItem> favorites,
  }) {
    final r = context.responsive;

    if (favorites.isEmpty) {
      return [
        _FavoritesEmptyState(onAdd: onFindFavourite),
      ];
    }

    return [
      Text(
        'Favourite',
        style: TextStyle(
          fontSize: r.scale(18, tablet: 19),
          fontWeight: FontWeight.w700,
        ),
      ),
      SizedBox(height: r.scale(4)),
      Text(
        'Tap the star to remove from favourites',
        style: TextStyle(
          fontSize: r.scale(12, tablet: 13),
          color: AppColors.textSecondary,
        ),
      ),
      SizedBox(height: r.scale(10)),
      ..._savedMealTiles(
        context,
        items: favorites,
        selectedMeal: selectedMeal,
        allowUnfavorite: true,
      ),
    ];
  }

  List<Widget> _buildQuickItemsSection(
    BuildContext context, {
    required List<SavedMealItem> quickItems,
    required bool isLoading,
    required String? apiError,
  }) {
    final r = context.responsive;

    return [
      Text(
        'Quick items',
        style: TextStyle(
          fontSize: r.scale(18, tablet: 19),
          fontWeight: FontWeight.w700,
        ),
      ),
      SizedBox(height: r.scale(10)),
      if (isLoading && quickItems.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: r.scale(24)),
          child: const Center(child: CircularProgressIndicator()),
        )
      else if (quickItems.isEmpty)
        _AllFoodsEmptyState(
          message: apiError ??
              'Search and log a food to start building your recent items.',
        )
      else
        ..._savedMealTiles(
          context,
          items: quickItems,
          selectedMeal: selectedMeal,
        ),
    ];
  }

  List<Widget> _buildMyMealsSection(
    BuildContext context, {
    required List<CustomMealPreset> customMeals,
  }) {
    final r = context.responsive;

    if (customMeals.isEmpty) {
      return [_MyMealsEmptyState(onCreate: onCreateMeal)];
    }

    return [
      CreateMealPromoCard(onTap: onCreateMeal),
      SizedBox(height: r.scale(18)),
      Text(
        'My meal templates',
        style: TextStyle(
          fontSize: r.scale(18, tablet: 19),
          fontWeight: FontWeight.w700,
        ),
      ),
      SizedBox(height: r.scale(4)),
      Text(
        'Custom meals you created',
        style: TextStyle(
          fontSize: r.scale(12, tablet: 13),
          color: AppColors.textSecondary,
        ),
      ),
      SizedBox(height: r.scale(10)),
      ..._customMealTiles(context, presets: customMeals),
    ];
  }

  List<Widget> _customMealTiles(
    BuildContext context, {
    required List<CustomMealPreset> presets,
  }) {
    final r = context.responsive;

    return List.generate(presets.length, (index) {
      final preset = presets[index];
      final isLast = index == presets.length - 1;
      final createdDate = DateFormat('MMM d, yyyy').format(preset.createdAt);
      final compactTrailing = r.isCompact;

      return _MyMealDeleteTile(
        preset: preset,
        isLast: isLast,
        createdDate: createdDate,
        compactTrailing: compactTrailing,
        onAction: (action, onDeleteRequested) => _onCustomMealAction(
          context,
          preset: preset,
          action: action,
          onDeleteRequested: onDeleteRequested,
        ),
        onConfirmDelete: () => _confirmDeleteMeal(context, preset: preset),
        onPerformDelete: () => _performDeleteMeal(preset),
      );
    });
  }

  Future<bool> _confirmDeleteMeal(
    BuildContext context, {
    required CustomMealPreset preset,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text(
          'Remove "${preset.name}" from My Meals? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _performDeleteMeal(CustomMealPreset preset) async {
    try {
      await controller.removeCustomMealPreset(preset.id);
      AppSnackbar.success(
        '${preset.name} was removed.',
        title: 'Deleted',
      );
    } catch (error) {
      AppSnackbar.error(
        error.toString(),
        title: 'Delete failed',
      );
    }
  }

  Future<void> _onCustomMealAction(
    BuildContext context, {
    required CustomMealPreset preset,
    required String action,
    VoidCallback? onDeleteRequested,
  }) async {
    if (action == 'log') {
      await showCustomMealLogSheet(context, preset: preset);
      return;
    }
    if (action == 'edit') {
      await Get.toNamed(AppRoutes.createMeal, arguments: preset);
      return;
    }
    if (action != 'delete') return;
    onDeleteRequested?.call();
  }

  String? _createdDateLabel(SavedMealItem item) {
    DateTime? latest;
    for (final entry in controller.apiMeals) {
      final saved = SavedMealItem.fromMealEntry(entry);
      if (saved.storageKey != item.storageKey) continue;
      if (latest == null || entry.date.isAfter(latest)) {
        latest = entry.date;
      }
    }
    if (latest == null) return null;
    return DateFormat('MMM d, yyyy').format(latest);
  }

  List<Widget> _savedMealTiles(
    BuildContext context, {
    required List<SavedMealItem> items,
    required String selectedMeal,
    bool showCreatedDate = false,
    bool allowUnfavorite = false,
  }) {
    final r = context.responsive;

    return List.generate(items.length, (index) {
      final item = items[index];
      final isFavorite = controller.isFavorite(item);
      final isLast = index == items.length - 1;
      final createdDate = showCreatedDate ? _createdDateLabel(item) : null;

      return Column(
        children: [
          ListTile(
            onTap: () => showLogHistorySheet(
              context,
              item: item,
              initialMeal: selectedMeal,
            ),
            contentPadding: EdgeInsets.symmetric(vertical: r.scale(4)),
            leading: FoodEmojiAvatar(
              emoji: item.food.emoji,
              imageUrl: item.food.imageUrl,
              size: 44,
            ),
            title: Text(
              item.food.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: r.scale(15),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.servingDescription} · ${item.meal}'),
                if (createdDate != null)
                  Text(
                    'Created $createdDate',
                    style: TextStyle(
                      fontSize: r.scale(11),
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (allowUnfavorite)
                  IconButton(
                    tooltip: 'Remove from favourites',
                    onPressed: () async {
                      await controller.removeFavorite(item);
                      AppSnackbar.success(
                        '${item.food.name} removed from favourites.',
                        title: 'Removed',
                      );
                    },
                    icon: const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFB800),
                    ),
                  )
                else if (isFavorite)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: Color(0xFFFFB800),
                    ),
                  ),
                Text(
                  '${item.calories} kcal',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: r.scale(14),
                  ),
                ),
              ],
            ),
          ),
          if (!isLast) Divider(height: 1, color: AppColors.border),
        ],
      );
    });
  }
}

class _CustomFoodCreator extends StatefulWidget {
  const _CustomFoodCreator();

  @override
  State<_CustomFoodCreator> createState() => _CustomFoodCreatorState();
}

class _CustomFoodCreatorState extends State<_CustomFoodCreator> {
  late final FoodController _food = Get.find<FoodController>();

  void _edit(CustomFoodPreset preset) {
    Get.to<void>(
      () => const CreateCustomFoodView(),
      arguments: preset,
    );
  }

  SavedMealItem _savedItem(CustomFoodPreset preset) {
    return SavedMealItem(
      food: preset.food,
      grams: preset.defaultGrams,
      meal: _food.selectedMeal.value,
      servingQuantity: preset.servingQuantity,
      servingUnit: preset.servingUnit,
      nutritionBasisQuantity: preset.nutritionBasisQuantity,
      basisCarbs: preset.food.carbs,
      basisProtein: preset.food.protein,
      basisFat: preset.food.fat,
    );
  }

  Future<void> _open(CustomFoodPreset preset) {
    return showLogHistorySheet(
      context,
      item: _savedItem(preset),
      initialMeal: _food.selectedMeal.value,
      myFood: preset,
    );
  }

  Future<bool> _confirmDeleteFood(CustomFoodPreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete food?'),
        content: Text('Remove "${preset.food.name}" from My Food?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _performDeleteFood(CustomFoodPreset preset) async {
    try {
      await _food.removeCustomFoodPreset(preset.id);
      AppSnackbar.success(
        '${preset.food.name} was removed.',
        title: 'Deleted',
      );
    } catch (error) {
      AppSnackbar.error(
        error.toString(),
        title: 'Delete failed',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Obx(() {
      final presets = _food.customFoodPresets.toList();
      if (presets.isEmpty) {
        return _MyFoodEmptyState(
          onAdd: () => Get.to<void>(
            () => const CreateCustomFoodView(),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CreateMealPromoCard(
            onTap: () => Get.to<void>(
              () => const CreateCustomFoodView(),
            ),
            title: 'Create Food',
            description: 'Create and save food for faster logging.',
            actionLabel: 'Create New Food',
            illustrationAsset: 'assets/image/Cooking_imagery.json',
          ),
          SizedBox(height: r.scale(18)),
          Text(
            'My foods',
            style: TextStyle(
              fontSize: r.scale(18, tablet: 19),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: r.scale(4)),
          Text(
            'Foods you created and saved',
            style: TextStyle(
              fontSize: r.scale(12, tablet: 13),
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: r.scale(10)),
          ...presets.map((preset) {
            final item = _savedItem(preset);
            return Padding(
              padding: EdgeInsets.only(bottom: r.scale(8)),
              child: _MyFoodDeleteTile(
                preset: preset,
                subtitle:
                    '${item.servingDescription} · ${item.calories} kcal',
                onOpen: () => _open(preset),
                onEdit: () => _edit(preset),
                onConfirmDelete: () => _confirmDeleteFood(preset),
                onPerformDelete: () => _performDeleteFood(preset),
              ),
            );
          }),
        ],
      );
    });
  }
}

class _AllFoodsEmptyState extends StatelessWidget {
  const _AllFoodsEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return SizedBox(
      height: r.scale(500),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: r.scale(40),
            left: -r.scale(36),
            right: -r.scale(36),
            bottom: 0,
            child: ClipPath(
              clipper: _MyFoodEmptyClipper(),
              child: ColoredBox(color: AppColors.card),
            ),
          ),
          Positioned(
            top: r.scale(90),
            child: Lottie.asset(
              'assets/image/all_food.json',
              width: r.scale(250),
              height: r.scale(250),
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.fastfood_rounded,
                size: r.scale(72),
                color: AppColors.primary,
              ),
            ),
          ),
          Positioned(
            top: r.scale(355),
            left: r.scale(24),
            right: r.scale(24),
            child: Column(
              children: [
                Text(
                  'Find your next food',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.scale(22),
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: r.scale(10)),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.scale(13),
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoritesEmptyState extends StatelessWidget {
  const _FavoritesEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return SizedBox(
      height: r.scale(560),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: r.scale(40),
            left: -r.scale(36),
            right: -r.scale(36),
            bottom: 0,
              child: ClipPath(
              clipper: _MyFoodEmptyClipper(),
              child: ColoredBox(color: AppColors.card),
            ),
          ),
          Positioned(
            top: r.scale(120),
            child: Lottie.asset(
              'assets/image/Star_Success.json',
              width: r.scale(220),
              height: r.scale(220),
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.star_rounded,
                size: r.scale(88),
                color: const Color(0xFFFFB800),
              ),
            ),
          ),
          Positioned(
            top: r.scale(330),
            left: r.scale(24),
            right: r.scale(24),
            child: Column(
              children: [
                Text(
                  'No favourites yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.scale(22),
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: r.scale(10)),
                Text(
                  'Search for a food and tap the star to save it here '
                  'for faster logging.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.scale(13),
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: r.scale(18)),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.star_rounded),
                  label: const Text('Add favourite'),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.scale(24),
                      vertical: r.scale(12),
                    ),
                    minimumSize: Size(0, r.scale(46)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.scale(24)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyMealsEmptyState extends StatelessWidget {
  const _MyMealsEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return SizedBox(
      height: r.scale(550),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: r.scale(40),
            left: -r.scale(36),
            right: -r.scale(36),
            bottom: 0,
              child: ClipPath(
              clipper: _MyFoodEmptyClipper(),
              child: ColoredBox(color: AppColors.card),
            ),
          ),
          Positioned(
            top: r.scale(110),
            child: Lottie.asset(
              'assets/image/my_meal.json',
              width: r.scale(250),
              height: r.scale(250),
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.restaurant_menu_rounded,
                size: r.scale(72),
                color: AppColors.primary,
              ),
            ),
          ),
          Positioned(
            top: r.scale(380),
            left: r.scale(24),
            right: r.scale(24),
            child: Column(
              children: [
                Text(
                  'Build meals your way',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.scale(22),
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: r.scale(10)),
                Text(
                  'Combine your favorite foods into a meal and save it '
                  'for faster logging.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.scale(13),
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: r.scale(18)),
                _AddMyFoodButton(
                  onPressed: onCreate,
                  label: 'Create Meal',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyFoodEmptyState extends StatelessWidget {
  const _MyFoodEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return SizedBox(
      height: r.scale(550
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: r.scale(40),
            left: -r.scale(36),
            right: -r.scale(36),
            bottom: 0,
              child: ClipPath(
              clipper: _MyFoodEmptyClipper(),
              child: ColoredBox(color: AppColors.card),
            ),
          ),
          Positioned(
            top: r.scale(110),
            child: Lottie.asset(
              'assets/image/pizza.json',
              width: r.scale(250),
              height: r.scale(250),
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.local_pizza_rounded,
                size: r.scale(64),
                color: AppColors.primary,
              ),
            ),
          ),
          Positioned(
            top: r.scale(380),
            left: r.scale(24),
            right: r.scale(24),
            child: Column(
              children: [
                Text(
                  'Your foods, your way',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.scale(22),
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: r.scale(10)),
                Text(
                  'Can’t find it in search? Create your own food once '
                  'and log it anytime.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: r.scale(13),
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: r.scale(18)),
                _AddMyFoodButton(onPressed: onAdd),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMyFoodButton extends StatelessWidget {
  const _AddMyFoodButton({
    required this.onPressed,
    this.label = 'Add Food',
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded),
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: r.scale(24),
          vertical: r.scale(12),
        ),
        minimumSize: Size(0, r.scale(46)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.scale(24)),
        ),
      ),
    );
  }
}

class _MyFoodEmptyClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 150)
      ..quadraticBezierTo(size.width / 2, -110, size.width, 150)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_MyFoodEmptyClipper oldClipper) => false;
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.isSearching,
    required this.foods,
    required this.onCreateFood,
    this.errorMessage,
  });

  final bool isSearching;
  final List<FoodItem> foods;
  final VoidCallback onCreateFood;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    if (isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = errorMessage?.trim();
    final emptyTitle = (error != null && error.isNotEmpty)
        ? 'Search unavailable'
        : 'No results found';
    final emptyBody = (error != null && error.isNotEmpty)
        ? error
        : 'Can’t find it? Create your own food and log it anytime.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Search results',
          style: TextStyle(
            fontSize: r.scale(18, tablet: 19),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: r.scale(10)),
        Expanded(
          child: foods.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    final artMax = math.min(
                      r.scale(180, tablet: 200),
                      constraints.maxHeight * 0.38,
                    );
                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: r.scale(24)),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: artMax,
                              height: artMax,
                              child: NoResultsIllustration(
                                maxSize: artMax,
                                minSize: math.min(88, artMax),
                              ),
                            ),
                            SizedBox(height: r.scale(8)),
                            Text(
                              emptyTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: r.scale(18),
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: r.scale(8)),
                            Text(
                              emptyBody,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: r.scale(13),
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            SizedBox(height: r.scale(18)),
                            _AddMyFoodButton(
                              onPressed: onCreateFood,
                              label: 'Create Food',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : ListView.separated(
                  itemCount: foods.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final food = foods[i];
                    return ListTile(
                      onTap: () => Get.toNamed(
                        AppRoutes.foodDetails,
                        arguments: food,
                      ),
                      leading: FoodEmojiAvatar(
                        emoji: food.emoji,
                        imageUrl: food.imageUrl,
                        size: 48,
                      ),
                      title: Text(food.name),
                      trailing: Text(
                        '${food.caloriesPer100g} kcal',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.focusNode});

  final FocusNode focusNode;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _textController;
  late final FoodController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<FoodController>();
    _textController =
        TextEditingController(text: _controller.searchQuery.value);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasQuery = _controller.searchQuery.value.isNotEmpty;

      return TextField(
        controller: _textController,
        focusNode: widget.focusNode,
        decoration: InputDecoration(
          hintText: 'Search for a new food...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasQuery)
                IconButton(
                  tooltip: 'Clear',
                  onPressed: () {
                    _textController.clear();
                    _controller.onSearchChanged('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
              IconButton(
                tooltip: 'Scan barcode',
                onPressed: _openScan,
                icon: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        onChanged: _controller.onSearchChanged,
      );
    });
  }

  void _openScan() {
    widget.focusNode.unfocus();
    // Return to main, then open the Scan tab.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    if (Get.isRegistered<MainController>()) {
      Get.find<MainController>().changeTab(MainController.scanTabIndex);
    } else {
      Get.offAllNamed(AppRoutes.main);
    }
  }
}

class _MyFoodDeleteTile extends StatefulWidget {
  const _MyFoodDeleteTile({
    required this.preset,
    required this.subtitle,
    required this.onOpen,
    required this.onEdit,
    required this.onConfirmDelete,
    required this.onPerformDelete,
  });

  final CustomFoodPreset preset;
  final String subtitle;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final Future<bool> Function() onConfirmDelete;
  final Future<void> Function() onPerformDelete;

  @override
  State<_MyFoodDeleteTile> createState() => _MyFoodDeleteTileState();
}

class _MyFoodDeleteTileState extends State<_MyFoodDeleteTile> {
  bool _deleting = false;

  Future<void> _requestDelete() async {
    if (_deleting) return;
    final confirmed = await widget.onConfirmDelete();
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final preset = widget.preset;

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(r.scale(12)),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: _deleting
            ? DeleteLottieBox(
                height: r.scale(72),
                size: r.scale(72),
                onCompleted: () {
                  widget.onPerformDelete();
                },
              )
            : ListTile(
                onTap: widget.onOpen,
                leading: preset.imageBytes != null
                    ? Container(
                        width: r.scale(42),
                        height: r.scale(42),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(r.scale(12)),
                        ),
                        child: Image.memory(
                          preset.imageBytes!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      )
                    : FoodEmojiAvatar(
                        emoji: preset.food.emoji,
                        imageUrl: preset.food.imageUrl,
                        size: r.scale(42),
                      ),
                title: Text(
                  preset.food.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(widget.subtitle),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'log') {
                      widget.onOpen();
                    } else if (action == 'edit') {
                      widget.onEdit();
                    } else if (action == 'delete') {
                      _requestDelete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'log',
                      child: Text('Log food'),
                    ),
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MyMealDeleteTile extends StatefulWidget {
  const _MyMealDeleteTile({
    required this.preset,
    required this.isLast,
    required this.createdDate,
    required this.compactTrailing,
    required this.onAction,
    required this.onConfirmDelete,
    required this.onPerformDelete,
  });

  final CustomMealPreset preset;
  final bool isLast;
  final String createdDate;
  final bool compactTrailing;
  final void Function(String action, VoidCallback onDeleteRequested) onAction;
  final Future<bool> Function() onConfirmDelete;
  final Future<void> Function() onPerformDelete;

  @override
  State<_MyMealDeleteTile> createState() => _MyMealDeleteTileState();
}

class _MyMealDeleteTileState extends State<_MyMealDeleteTile> {
  bool _deleting = false;

  Future<void> _requestDelete() async {
    if (_deleting) return;
    final confirmed = await widget.onConfirmDelete();
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final preset = widget.preset;

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _deleting
              ? DeleteLottieBox(
                  height: r.scale(72),
                  size: r.scale(72),
                  onCompleted: () {
                    widget.onPerformDelete();
                  },
                )
              : ListTile(
                  onTap: () =>
                      showCustomMealLogSheet(context, preset: preset),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: r.scale(4)),
                  leading: Container(
                    width: r.scale(44),
                    height: r.scale(44),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(r.scale(12)),
                    ),
                    child: preset.imageBytes != null
                        ? Image.memory(
                            preset.imageBytes!,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          )
                        : Icon(
                            Icons.restaurant_menu_rounded,
                            color: AppColors.primary,
                            size: r.scale(22),
                          ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          preset.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: r.scale(15),
                          ),
                        ),
                      ),
                      if (preset.visibility == MealShareVisibility.public)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: r.scale(8),
                            vertical: r.scale(2),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(r.scale(8)),
                          ),
                          child: Text(
                            'Public',
                            style: TextStyle(
                              fontSize: r.scale(10),
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${preset.items.length} foods · ${preset.meal}',
                        style: TextStyle(fontSize: r.scale(12)),
                      ),
                      Text(
                        'Created ${widget.createdDate}',
                        style: TextStyle(
                          fontSize: r.scale(11),
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (widget.compactTrailing)
                        Padding(
                          padding: EdgeInsets.only(top: r.scale(4)),
                          child: Text(
                            '${preset.totalCalories} kcal',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: r.scale(13),
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: widget.compactTrailing
                      ? PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: AppColors.textSecondary,
                            size: r.scale(20),
                          ),
                          onSelected: (action) => widget.onAction(
                            action,
                            _requestDelete,
                          ),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'log',
                              child: Text('Log meal'),
                            ),
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${preset.totalCalories} kcal',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: r.scale(14),
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: AppColors.textSecondary,
                                size: r.scale(20),
                              ),
                              onSelected: (action) => widget.onAction(
                                action,
                                _requestDelete,
                              ),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'log',
                                  child: Text('Log meal'),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                  isThreeLine: widget.compactTrailing,
                ),
        ),
        if (!widget.isLast && !_deleting)
          Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}
