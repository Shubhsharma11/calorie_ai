import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/food_controller.dart';
import '../core/responsive.dart';
import '../models/food_item.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/food_emoji_avatar.dart';
import '../widgets/log_history_sheet.dart';
import '../widgets/responsive_page.dart';

class AddFoodView extends StatefulWidget {
  const AddFoodView({super.key});

  @override
  State<AddFoodView> createState() => _AddFoodViewState();
}

class _AddFoodViewState extends State<AddFoodView> {
  late final FoodController _food = Get.find<FoodController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _food.refreshQuickItemsFromApi();
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Food')),
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
            const _SearchBar(),
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

                return _QuickItemsList(selectedMeal: _food.selectedMeal.value);
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickItemsList extends GetView<FoodController> {
  const _QuickItemsList({required this.selectedMeal});

  final String selectedMeal;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Obx(() {
      final revision = controller.entriesRevision.value;
      final isLoading = controller.isLoadingMealsApi.value;
      final apiError = controller.mealsApiErrorMessage.value;
      controller.apiMeals.length;
      final items = controller.recentQuickMeals;

      return ListView(
        key: ValueKey(revision),
        children: [
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
          if (isLoading && items.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: r.scale(24)),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: r.scale(16)),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: r.scale(28),
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: r.scale(12)),
                  Expanded(
                    child: Text(
                      apiError ??
                          'Log a meal and your recent foods will appear here.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: r.scale(13),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(items.length, (index) {
              final item = items[index];
              final isFavorite = controller.isFavorite(item);
              final isLast = index == items.length - 1;

              return Column(
                children: [
                  ListTile(
                    onTap: () => showLogHistorySheet(
                      context,
                      item: item,
                      initialMeal: selectedMeal,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: r.scale(4),
                    ),
                    leading: FoodEmojiAvatar(
                      emoji: item.food.emoji,
                      size: 44,
                    ),
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
                          Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: const Color(0xFFFFB800),
                          ),
                      ],
                    ),
                    subtitle: Text('${item.grams}g · ${item.meal}'),
                    trailing: Text(
                      '${item.calories} kcal',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: r.scale(14),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(height: 1, color: AppColors.border),
                ],
              );
            }),
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
                  itemBuilder: (_, i) => ListTile(
                    onTap: () => Get.toNamed(
                      AppRoutes.foodDetails,
                      arguments: foods[i],
                    ),
                    leading: FoodEmojiAvatar(
                      emoji: foods[i].emoji,
                      size: 48,
                    ),
                    title: Text(foods[i].name),
                    trailing: Text(
                      '${foods[i].caloriesPer100g} kcal',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar();

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
        decoration: InputDecoration(
          hintText: 'Search for a new food...',
          prefixIcon: Icon(Icons.search),
          suffixIcon: _controller.searchQuery.value.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _textController.clear();
                    _controller.onSearchChanged('');
                  },
                  icon: Icon(Icons.close_rounded),
                )
              : null,
        ),
        onChanged: _controller.onSearchChanged,
      );
    });
  }
}
