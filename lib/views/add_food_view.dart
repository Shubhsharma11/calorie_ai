import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/food_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../models/custom_meal_preset.dart';
import '../models/food_item.dart';
import '../models/saved_meal_item.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/create_meal/create_meal_bottom_sheet.dart';
import '../widgets/create_meal/create_meal_promo_card.dart';
import '../widgets/filter_chip_pill.dart';
import '../widgets/food_emoji_avatar.dart';
import '../widgets/log_history_sheet.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/responsive_page.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _food.refreshQuickItemsFromApi();
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      appBar: const AppAppBar(title: 'Add Food'),
      body: ResponsivePage(
        scrollable: false,
        maxWidth: r.isWide ? 900 : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(
              () => Text(
                'Adding to ${_food.selectedMeal.value}',
                style: TextStyle(
                  fontSize: r.scale(13, tablet: 14),
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(height: r.scale(8)),
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
                  );
                }

                return _FoodBrowseList(
                  selectedMeal: _food.selectedMeal.value,
                  catalogTab: _catalogTab,
                  onCatalogTabChanged: (tab) =>
                      setState(() => _catalogTab = tab),
                  onCreateMeal: () => showCreateMealSheet(
                    context,
                    initialMeal: _food.selectedMeal.value,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

enum _FoodCatalogTab { all, myMeals }

class _FoodBrowseList extends GetView<FoodController> {
  const _FoodBrowseList({
    required this.selectedMeal,
    required this.catalogTab,
    required this.onCatalogTabChanged,
    required this.onCreateMeal,
  });

  final String selectedMeal;
  final _FoodCatalogTab catalogTab;
  final ValueChanged<_FoodCatalogTab> onCatalogTabChanged;
  final VoidCallback onCreateMeal;

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

      return ListView(
        key: ValueKey('$revision-${catalogTab.name}'),
        children: [
          Row(
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
            ],
          ),
          SizedBox(height: r.scale(16)),
          if (catalogTab == _FoodCatalogTab.all)
            ..._buildQuickItemsSection(
              context,
              quickItems: quickItems,
              isLoading: isLoading,
              apiError: apiError,
            )
          else
            ..._buildMyMealsSection(context, customMeals: customMeals),
        ],
      );
    });
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
      SizedBox(height: r.scale(4)),
      Text(
        'Your last 5 meals from history',
        style: TextStyle(
          fontSize: r.scale(12, tablet: 13),
          color: AppColors.textSecondary,
        ),
      ),
      SizedBox(height: r.scale(10)),
      if (isLoading && quickItems.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: r.scale(24)),
          child: const Center(child: CircularProgressIndicator()),
        )
      else if (quickItems.isEmpty)
        _emptyState(
          context,
          icon: Icons.bolt_rounded,
          message: apiError ??
              'Log a meal and your recent foods will appear here.',
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
      if (customMeals.isEmpty)
        _emptyState(
          context,
          icon: Icons.bookmark_border_rounded,
          message: 'Your saved meal templates will appear here.',
        )
      else
        ..._customMealTiles(context, presets: customMeals),
    ];
  }

  Widget _emptyState(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) {
    final r = context.responsive;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.scale(16)),
      child: Row(
        children: [
          Icon(icon, size: r.scale(28), color: AppColors.textSecondary),
          SizedBox(width: r.scale(12)),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: r.scale(13),
              ),
            ),
          ),
        ],
      ),
    );
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

      return Column(
        children: [
          ListTile(
            onTap: () => showCustomMealLogSheet(context, preset: preset),
            contentPadding: EdgeInsets.symmetric(vertical: r.scale(4)),
            leading: Container(
              width: r.scale(44),
              height: r.scale(44),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(r.scale(12)),
              ),
              child: Icon(
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
                  'Created $createdDate',
                  style: TextStyle(
                    fontSize: r.scale(11),
                    color: AppColors.textSecondary,
                  ),
                ),
                if (compactTrailing)
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
            trailing: compactTrailing
                ? PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.textSecondary,
                      size: r.scale(20),
                    ),
                    onSelected: (action) => _onCustomMealAction(
                      context,
                      preset: preset,
                      action: action,
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
                        onSelected: (action) => _onCustomMealAction(
                          context,
                          preset: preset,
                          action: action,
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
            isThreeLine: compactTrailing,
          ),
          if (!isLast) Divider(height: 1, color: AppColors.border),
        ],
      );
    });
  }

  Future<void> _onCustomMealAction(
    BuildContext context, {
    required CustomMealPreset preset,
    required String action,
  }) async {
    switch (action) {
      case 'log':
        await showCustomMealLogSheet(context, preset: preset);
      case 'edit':
        await Get.toNamed(AppRoutes.createMeal, arguments: preset);
      case 'delete':
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
        if (confirmed == true) {
          await controller.removeCustomMealPreset(preset.id);
          AppSnackbar.success(
            '${preset.name} was removed.',
            title: 'Deleted',
          );
        }
    }
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
            leading: FoodEmojiAvatar(emoji: item.food.emoji, size: 44),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.food.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: r.scale(15),
                    ),
                  ),
                ),
                if (isFavorite)
                  const Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: Color(0xFFFFB800),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.grams}g · ${item.meal}'),
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
            trailing: Text(
              '${item.calories} kcal',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: r.scale(14),
              ),
            ),
          ),
          if (!isLast) Divider(height: 1, color: AppColors.border),
        ],
      );
    });
  }
}

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.isSearching,
    required this.foods,
  });

  final bool isSearching;
  final List<FoodItem> foods;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    if (isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

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
              ? Center(
                  child: Text(
                    'No foods found. Try another search.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
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
      return TextField(
        controller: _textController,
        focusNode: widget.focusNode,
        decoration: InputDecoration(
          hintText: 'Search for a new food...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.searchQuery.value.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _textController.clear();
                    _controller.onSearchChanged('');
                  },
                  icon: const Icon(Icons.close_rounded),
                )
              : null,
        ),
        onChanged: _controller.onSearchChanged,
      );
    });
  }
}
