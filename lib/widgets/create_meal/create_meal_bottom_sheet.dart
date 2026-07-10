import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/food_controller.dart';
import '../../core/app_snackbar.dart';
import '../../core/responsive.dart';
import '../../models/custom_meal_preset.dart';
import '../../models/meal_type.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../filter_chip_pill.dart';
import '../food_emoji_avatar.dart';

void showCreateMealSheet(
  BuildContext context, {
  String? initialMeal,
}) {
  Get.toNamed(
    AppRoutes.createMeal,
    arguments: initialMeal ?? Get.find<FoodController>().selectedMeal.value,
  );
}

Future<void> showCustomMealLogSheet(
  BuildContext context, {
  required CustomMealPreset preset,
}) {
  final controller = Get.find<FoodController>();
  var selectedMeal = preset.meal;
  if (!MealType.all.contains(selectedMeal)) {
    selectedMeal = MealType.breakfast;
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final r = sheetContext.responsive;
      final createdLabel = DateFormat('MMM d, yyyy').format(preset.createdAt);

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (context, scrollController) {
          return StatefulBuilder(
            builder: (context, setState) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    r.scale(20),
                    r.scale(12),
                    r.scale(20),
                    r.scale(24),
                  ),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    SizedBox(height: r.scale(16)),
                    Text(
                      preset.name,
                      style: TextStyle(
                        fontSize: r.scale(20),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: r.scale(4)),
                    Text(
                      '${preset.items.length} foods · ${preset.totalCalories} kcal · ${preset.visibility.label}',
                      style: TextStyle(
                        fontSize: r.scale(13),
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'Created $createdLabel',
                      style: TextStyle(
                        fontSize: r.scale(12),
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: r.scale(16)),
                    Container(
                      padding: EdgeInsets.all(r.scale(12)),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: preset.items.map((item) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: r.scale(8)),
                            child: Row(
                              children: [
                                FoodEmojiAvatar(
                                  emoji: item.food.emoji,
                                  size: 38,
                                ),
                                SizedBox(width: r.scale(10)),
                                Expanded(
                                  child: Text(
                                    item.food.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: r.scale(14),
                                    ),
                                  ),
                                ),
                                Text(
                                  '${item.grams}g · ${item.calories} kcal',
                                  style: TextStyle(
                                    fontSize: r.scale(12),
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: r.scale(16)),
                    Text(
                      'Log to',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: r.scale(14),
                      ),
                    ),
                    SizedBox(height: r.scale(8)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: MealType.all.map((meal) {
                        return FilterChipPill(
                          label: meal,
                          selected: selectedMeal == meal,
                          onTap: () => setState(() => selectedMeal = meal),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: r.scale(20)),
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          controller.logCustomMealPreset(
                            preset,
                            meal: selectedMeal,
                          );
                          Navigator.pop(sheetContext);
                          AppSnackbar.success(
                            '${preset.name} added to $selectedMeal.',
                            title: 'Logged',
                          );
                        },
                        child: Text('Log to $selectedMeal'),
                      ),
                    ),
                    SizedBox(height: r.scale(8)),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              Get.toNamed(
                                AppRoutes.createMeal,
                                arguments: preset,
                              );
                            },
                            child: const Text('Edit meal'),
                          ),
                        ),
                        SizedBox(width: r.scale(10)),
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: sheetContext,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Delete meal?'),
                                  content: Text(
                                    'Remove "${preset.name}" from My Meals?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              await controller.removeCustomMealPreset(
                                preset.id,
                              );
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                              AppSnackbar.success(
                                '${preset.name} was removed.',
                                title: 'Deleted',
                              );
                            },
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}
