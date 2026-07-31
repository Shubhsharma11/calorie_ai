import 'package:calorie_ai/widgets/epeat_yesterday_meal_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/food_controller.dart';
import '../../core/app_snackbar.dart';
import '../../models/meal_entry.dart';
import '../../models/meal_type.dart';
import '../../theme/app_colors.dart';

class RepeatYesterdayBottomSheet extends StatefulWidget {
  const RepeatYesterdayBottomSheet({super.key});

  @override
  State<RepeatYesterdayBottomSheet> createState() =>
      _RepeatYesterdayBottomSheetState();
}

class _RepeatYesterdayBottomSheetState
    extends State<RepeatYesterdayBottomSheet> {
  final FoodController controller = Get.find<FoodController>();
  late List<MealEntry> _meals;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _meals = controller.getLastLoggedMeals();
    if (_meals.isNotEmpty) {
      controller.selectAllYesterdayMeals();
    }
    _loadFullDay();
  }

  Future<void> _loadFullDay() async {
    final loaded = await controller.ensureLastLoggedMealsLoaded();
    if (!mounted) return;
    setState(() {
      _meals = loaded;
      _loading = false;
    });
    if (loaded.isNotEmpty) {
      controller.selectAllYesterdayMeals();
    }
  }

  List<MealEntry> _mealsFor(String mealType) {
    return _meals
        .where((entry) => entry.meal.toLowerCase() == mealType.toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final meals = _meals;
    final totalCalories = meals.fold<int>(
      0,
      (sum, meal) => sum + meal.calories,
    );
    final dayLabel = controller.lastLoggedDayLabel;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Material(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text(
                      'Last logged meals',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (dayLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Logged on $dayLabel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _infoCard(
                              iconPath: 'assets/image/food.png',
                              value: '${meals.length}',
                              label: meals.length == 1 ? 'Meal' : 'Meals',
                              iconSize: 38,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _infoCard(
                              iconPath: 'assets/image/flame.png',
                              value:
                                  NumberFormat('#,###').format(totalCalories),
                              label: 'kcal',
                              iconSize: 28,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Obx(() {
                final allSelected =
                    controller.selectedYesterdayMealCount == meals.length &&
                    meals.isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      title: Text(
                        'Select all',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      secondary: Text(
                        '${controller.selectedYesterdayMealCount}/${meals.length}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      value: allSelected,
                      onChanged: _loading
                          ? null
                          : (value) {
                              if (value == true) {
                                controller.selectAllYesterdayMeals();
                              } else {
                                controller.unselectAllYesterdayMeals();
                              }
                            },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      activeColor: AppColors.primary,
                    ),
                  ),
                );
              }),
              Expanded(
                child: _loading
                    ? Center(
                        child: Text(
                          'Loading all meals…',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        children: [
                          for (final mealType in MealType.all)
                            if (_mealsFor(mealType).isNotEmpty)
                              _mealSection(
                                controller,
                                mealType,
                                _mealsFor(mealType),
                              ),
                          if (meals.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: Text(
                                'No meals found for this day.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            AppSnackbar.info(
                              'No meals were copied. You can try again anytime.',
                              title: 'Cancelled',
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Obx(() {
                          final count = controller.selectedYesterdayMealCount;
                          return FilledButton(
                            onPressed: _loading || count == 0
                                ? null
                                : () async {
                                    final added = controller
                                        .copySelectedYesterdayMeals();
                                    if (added > 0) {
                                      await controller
                                          .dismissRepeatYesterdayCard();
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    }
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              disabledBackgroundColor: AppColors.border,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              count == 0
                                  ? 'Select meals'
                                  : 'Add $count meal${count == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mealSection(
    FoodController controller,
    String title,
    List<MealEntry> meals,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ...meals.map(
          (meal) => Obx(
            () => RepeatYesterdayMealCard(
              title: meal.food.name,
              subtitle: '${meal.grams} g · ${meal.calories} kcal',
              selected: controller.isYesterdayMealSelected(meal.id),
              onTap: () => controller.toggleYesterdayMeal(meal.id),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoCard({
    required String iconPath,
    required String value,
    required String label,
    double iconSize = 30,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          Image.asset(
            iconPath,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
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
