import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/food_controller.dart';
import '../../core/meal_log_group.dart';
import '../../core/meal_type_icons.dart';
import '../../core/responsive.dart';
import '../../models/meal_entry.dart';
import '../../models/saved_meal_item.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../food_emoji_avatar.dart';
import '../log_history_sheet.dart';

class DailyLogMealBlock extends GetView<FoodController> {
  const DailyLogMealBlock({
    super.key,
    required this.meal,
    required this.onEditEntry,
  });

  final String meal;
  final void Function(MealEntry entry) onEditEntry;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Obx(() {
      final _ = controller.entriesRevision.value;
      controller.apiMeals.length;
      final quickMeals = controller.quickMealsFor(meal);
      final logged = controller.mealsForSelectedDate(meal);
      final grouped = MealLogGroup.fromEntries(logged);
      final calories = controller.caloriesForMealOnSelectedDate(meal);
      final isExpanded = controller.isMealExpanded(meal);

      return Container(
        decoration: BoxDecoration(
          color: logged.isEmpty ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => controller.toggleMealExpanded(meal),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      r.scale(12),
                      r.scale(12),
                      r.scale(4),
                      r.scale(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.selectionFill,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            MealTypeIcons.iconFor(meal),
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: r.scale(10)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meal,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: r.scale(17),
                                ),
                              ),
                              Text(
                                logged.isEmpty
                                    ? 'Nothing logged yet'
                                    : '$calories kcal logged · ${logged.length} item${logged.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: r.scale(12),
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            controller.setSelectedMeal(meal);
                            Get.toNamed(AppRoutes.addFood);
                          },
                          child: const Text('+ Add'),
                        ),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isExpanded) ...[
                if (quickMeals.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(r.scale(12), 0, r.scale(12), 0),
                    child: SizedBox(
                      height: r.scale(40),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: quickMeals.length,
                        separatorBuilder: (_, index) =>
                            SizedBox(width: r.scale(8)),
                        itemBuilder: (_, index) {
                          final item = quickMeals[index];
                          return _QuickMealChip(
                            item: item,
                            isFavorite: controller.isFavorite(item),
                            onTap: () => showLogHistorySheet(
                              context,
                              item: item,
                              initialMeal: meal,
                            ),
                            onToggleFavorite: () =>
                                controller.toggleFavorite(item),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: r.scale(10)),
                ],
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    r.scale(12),
                    0,
                    r.scale(12),
                    r.scale(12),
                  ),
                  child: logged.isEmpty
                      ? Text(
                          'Tap + Add to log your first item.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: r.scale(13),
                          ),
                        )
                      : Column(
                          children: grouped
                              .map(
                                (group) => _LoggedRow(
                                  group: group,
                                  onTap: () => onEditEntry(group.representative),
                                  onDelete: () =>
                                      controller.removeEntry(group.lastEntry),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ],
          ),
      );
    });
  }
}

class _QuickMealChip extends StatelessWidget {
  const _QuickMealChip({
    required this.item,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final SavedMealItem item;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        onLongPress: onToggleFavorite,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.scale(160, tablet: 180)),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: r.scale(10),
              vertical: r.scale(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.food.emoji, style: TextStyle(fontSize: r.scale(16))),
                SizedBox(width: r.scale(6)),
                Flexible(
                  child: Text(
                    item.food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: r.scale(13),
                    ),
                  ),
                ),
                SizedBox(width: r.scale(6)),
                Text(
                  '${item.calories}',
                  style: TextStyle(
                    fontSize: r.scale(12),
                    color: AppColors.textSecondary,
                  ),
                ),
                if (isFavorite) ...[
                  SizedBox(width: r.scale(4)),
                  Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: const Color(0xFFFFB800),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoggedRow extends StatelessWidget {
  const _LoggedRow({
    required this.group,
    required this.onTap,
    required this.onDelete,
  });

  final MealLogGroup group;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final entry = group.representative;
    final countLabel = group.count > 1 ? ' ×${group.count}' : '';

    return Dismissible(
      key: ValueKey(
        '${entry.id}-${entry.meal}-${entry.grams}-${group.entries.length}',
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: EdgeInsets.only(bottom: r.scale(6)),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: r.scale(6)),
        child: Material(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: onTap,
            dense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: r.scale(12),
              vertical: r.scale(2),
            ),
            leading: FoodEmojiAvatar(emoji: entry.food.emoji, size: 38),
            title: Text(
              entry.food.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: r.scale(14),
              ),
            ),
            subtitle: Text(
              '${entry.grams}g$countLabel',
              style: TextStyle(fontSize: r.scale(12)),
            ),
            trailing: Text(
              '${group.totalCalories} kcal',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                fontSize: r.scale(13),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
