import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/food_controller.dart';
import '../controllers/main_controller.dart';
import '../core/responsive.dart';
import '../models/food_item.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import '../widgets/food_emoji_avatar.dart';
import '../widgets/responsive_page.dart';

class AddFoodView extends GetView<FoodController> {
  const AddFoodView({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      appBar: AppBar(title: const Text('Food Search')),
      body: ResponsivePage(
        scrollable: false,
        maxWidth: r.isWide ? 900 : null,
        child: Column(
          children: [
            Obx(
              () => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Adding to: ${controller.selectedMeal.value}',
                  style: TextStyle(
                    fontSize: r.scale(13, tablet: 14),
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            SizedBox(height: r.scale(8)),
            ResponsiveLayout(
              mobile: _SearchBar(
                onScan: () {
                  Get.back();
                  if (Get.isRegistered<MainController>()) {
                    Get.find<MainController>().changeTab(2);
                  }
                },
              ),
              tablet: Row(
                children: [
                  const Expanded(child: _SearchBar()),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 160,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Get.back();
                        if (Get.isRegistered<MainController>()) {
                          Get.find<MainController>().changeTab(2);
                        }
                      },
                      icon: Icon(Icons.qr_code_scanner),
                      label: const Text('Scan'),
                    ),
                  ),
                ],
              ),
            ),
            Obx(() {
              if (controller.recentFoods.isEmpty) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: EdgeInsets.only(top: r.scale(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Recent Searches',
                          style: TextStyle(
                            fontSize: r.scale(15, tablet: 16),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: controller.clearRecentFoods,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    SizedBox(height: r.scale(8)),
                    ...controller.recentFoods.map(
                      (food) => _RecentFoodTile(
                        food: food,
                        onTap: () {
                          controller.recordRecentFood(food);
                          Get.toNamed(
                            AppRoutes.foodDetails,
                            arguments: food,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
            SizedBox(height: r.scale(8)),
            Padding(
              padding: EdgeInsets.symmetric(vertical: r.scale(8)),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Obx(() {
                  if (controller.isSearching.value) {
                    return const Text('Searching...');
                  }
                  return Text(
                    'Results',
                    style: TextStyle(
                      fontSize: r.scale(18, tablet: 19),
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: Obx(() {
                final foods = controller.filteredFoods;

                if (controller.isSearching.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (foods.isEmpty) {
                  return Center(
                    child: Text(
                      controller.searchQuery.value.isEmpty
                          ? 'Search for a food to add to your log'
                          : 'No foods found. Try another search.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: foods.length,
                  separatorBuilder: (_, index) => Divider(height: 1),
                  itemBuilder: (_, i) => _FoodRow(
                    food: foods[i],
                    onTap: () {
                      controller.recordRecentFood(foods[i]);
                      Get.toNamed(
                        AppRoutes.foodDetails,
                        arguments: foods[i],
                      );
                    },
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

class _RecentFoodTile extends StatelessWidget {
  const _RecentFoodTile({required this.food, required this.onTap});

  final FoodItem food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: FoodEmojiAvatar(emoji: food.emoji, size: 40),
      title: Text(food.name),
      trailing: Text(
        '${food.caloriesPer100g} kcal',
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({this.onScan});

  final VoidCallback? onScan;

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
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            decoration: const InputDecoration(
              hintText: 'Search food...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _controller.onSearchChanged,
          ),
        ),
        if (widget.onScan != null) ...[
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: widget.onScan,
            icon: Icon(Icons.qr_code_scanner),
            label: const Text('Scan'),
          ),
        ],
      ],
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.food, required this.onTap});

  final FoodItem food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: FoodEmojiAvatar(emoji: food.emoji, size: 48),
      title: Text(food.name),
      trailing: Text(
        '${food.caloriesPer100g} kcal',
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
