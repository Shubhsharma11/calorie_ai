import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/food_controller.dart';
import '../core/responsive.dart';
import '../models/meal_entry.dart';
import '../models/meal_type.dart';
import '../routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'food_emoji_avatar.dart';
import 'media_viewer.dart';

/// Reactive today's meals breakdown — rebuilds on any entry change.
class TodayMealsSection extends StatelessWidget {
  const TodayMealsSection({
    super.key,
    this.compact = false,
    this.showAddButtons = true,
  });

  final bool compact;
  final bool showAddButtons;

  @override
  Widget build(BuildContext context) {
    final food = Get.find<FoodController>();
    final r = context.responsive;

    return Obx(() {
      final _ = food.entriesRevision.value;
      food.selectedLogDate.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final meal in MealType.all) ...[
            _MealGroup(
              meal: meal,
              entries: food.mealsForToday(meal),
              calories: food.caloriesForMeal(meal),
              compact: compact,
              showAddButton: showAddButtons,
              r: r,
            ),
            SizedBox(height: r.scale(compact ? 8 : 12)),
          ],
        ],
      );
    });
  }
}

class _MealGroup extends StatelessWidget {
  const _MealGroup({
    required this.meal,
    required this.entries,
    required this.calories,
    required this.compact,
    required this.showAddButton,
    required this.r,
  });

  final String meal;
  final List<MealEntry> entries;
  final int calories;
  final bool compact;
  final bool showAddButton;
  final Responsive r;

  @override
  Widget build(BuildContext context) {
    final food = Get.find<FoodController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal,
                    style: TextStyle(
                      fontSize: r.scale(compact ? 15 : 17, tablet: 18),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$calories kcal · ${entries.length} item'
                    '${entries.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (showAddButton)
              TextButton.icon(
  onPressed: () {
    // If the user is viewing an old day,
    // switch back to today before adding a meal.
    food.prepareForNewMeal();

    // Remember which meal (Breakfast/Lunch/etc.) they selected.
    food.setSelectedMeal(meal);

    // Open the Add Food screen.
    Get.toNamed(AppRoutes.addFood);
  },
                icon: Icon(Icons.add, size: 18, color: AppColors.primary),
                label: Text(
                  'Add',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
          ],
        ),
        if (entries.isNotEmpty) ...[
          SizedBox(height: r.scale(6)),
          ...entries.map(
            (e) => _MealEntryRow(entry: e, compact: compact),
          ),
        ] else if (!compact)
          Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'No items yet',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

class _MealEntryRow extends StatelessWidget {
  const _MealEntryRow({required this.entry, required this.compact});

  final MealEntry entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => Get.toNamed(AppRoutes.editMeal, arguments: entry),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(10),
            vertical: r.scale(compact ? 8 : 10),
          ),
          child: Row(
            children: [
              FoodEmojiAvatar(
                emoji: entry.food.displayEmoji,
                imageUrl: entry.food.imageUrl,
                size: r.scale(compact ? 36 : 40),
                onTap: mediaViewerOpener(
                  context: context,
                  imageUrl: entry.food.imageUrl,
                  title: entry.food.name,
                ),
              ),
              SizedBox(width: r.scale(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.food.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      entry.quantityLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${entry.calories} kcal',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
