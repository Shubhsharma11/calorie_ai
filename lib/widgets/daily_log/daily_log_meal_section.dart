import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/food_controller.dart';
import '../../core/meal_log_group.dart';
import '../../core/responsive.dart';
import '../../models/meal_entry.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../confirm_delete_sheet.dart';
import '../delete_lottie.dart';
import '../meal_type_icon.dart';

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
      controller.deletingMealIds.length;

      final logged = controller.mealsForSelectedDate(meal);
      final grouped = MealLogGroup.fromEntries(logged);
      final calories = controller.caloriesForMealOnSelectedDate(meal);
      final isExpanded = controller.isMealExpanded(meal);

      // Keep rows that are mid-delete animation even after the API removes them,
      // so the trash Lottie stays visible (~1s) instead of vanishing instantly.
      final animating = controller.deletingGroupsForMeal(meal);
      final visible = <MealLogGroup>[
        ...grouped,
        for (final g in animating)
          if (!grouped.any((x) => x.representative.id == g.representative.id))
            g,
      ];

      return Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor,
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
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
                      MealTypeIcon(meal: meal),
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
                              logged.isEmpty && animating.isEmpty
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
                          controller.clearDeletingAnimations();
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
              Padding(
                padding: EdgeInsets.fromLTRB(
                  r.scale(12),
                  0,
                  r.scale(12),
                  r.scale(12),
                ),
                child: visible.isEmpty
                    ? Text(
                        'Tap + Add to log your first item.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: r.scale(13),
                        ),
                      )
                    : Column(
                        children: [
                          for (final group in visible)
                            _MealItemDeleteCard(
                              key: ValueKey(
                                'meal-item-${group.representative.id}',
                              ),
                              group: group,
                              isDeleting: controller.deletingMealIds
                                  .contains(group.representative.id),
                              onTap: () =>
                                  onEditEntry(group.representative),
                            ),
                        ],
                      ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _MealItemDeleteCard extends StatefulWidget {
  const _MealItemDeleteCard({
    super.key,
    required this.group,
    required this.isDeleting,
    required this.onTap,
  });

  final MealLogGroup group;
  final bool isDeleting;
  final VoidCallback onTap;

  @override
  State<_MealItemDeleteCard> createState() => _MealItemDeleteCardState();
}

class _MealItemDeleteCardState extends State<_MealItemDeleteCard> {
  bool _busy = false;

  MealLogGroup get group => widget.group;

  @override
  void didUpdateWidget(covariant _MealItemDeleteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Controller cleared delete state while this State stayed alive (IndexedStack
    // / navigate to Add Food). Drop local busy so the trash row cannot stick.
    if (_busy && !widget.isDeleting) {
      _busy = false;
    }
  }

  Future<void> _onDeletePressed() async {
    if (_busy || widget.isDeleting) return;
    final food = Get.find<FoodController>();
    // Snapshot before the dialog — sync may replace the local id while open,
    // disposing this State (`mounted=false`).
    final groupSnapshot = group;
    final id = groupSnapshot.representative.id;
    if (food.deletingMealIds.contains(id)) return;

    HapticFeedback.selectionClick();
    debugPrint(
      'DailyLog: X pressed id=$id name=${groupSnapshot.representative.food.name} '
      'entries=${groupSnapshot.entries.length}',
    );

    final countPart =
        groupSnapshot.count > 1 ? ' (${groupSnapshot.count} items)' : '';
    final name = groupSnapshot.representative.food.name;
    final navigatorContext = Get.overlayContext ?? Get.context ?? context;
    final confirmed = await showConfirmDeleteSheet(
      context: navigatorContext,
      title: 'Remove from diary?',
      message:
          '“$name”$countPart will be permanently deleted from your daily log.',
      cancelLabel: 'Keep',
      confirmLabel: 'Remove',
    );

    debugPrint(
      'DailyLog: confirm=$confirmed id=$id mounted=$mounted',
    );
    if (!confirmed) return;

    if (mounted) setState(() => _busy = true);
    // Controller owns the delete — safe even when this State is disposed.
    unawaited(food.deleteMealGroupWithFeedback(groupSnapshot).whenComplete(() {
      if (mounted) setState(() => _busy = false);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final entry = group.representative;
    final countLabel = group.count > 1 ? ' ×${group.count}' : '';
    final radius = BorderRadius.circular(r.scale(10));
    final rowHeight = r.scale(64);
    final isDeleting = _busy || widget.isDeleting;
    final isDark = AppColors.isDark(context);

    return Padding(
      padding: EdgeInsets.only(bottom: r.scale(8)),
      child: Material(
        color: isDeleting
            ? AppColors.error.withValues(alpha: 0.06)
            : isDark
                ? AppColors.surface
                : const Color(0xFFF7FBF8),
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: isDeleting
                  ? AppColors.error.withValues(alpha: 0.22)
                  : AppColors.border,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isDeleting
                ? DeleteLottieBox(
                    key: ValueKey('lottie-${entry.id}'),
                    height: rowHeight,
                    size: rowHeight,
                    onCompleted: () {},
                  )
                : SizedBox(
                    key: ValueKey('row-${entry.id}'),
                    height: rowHeight,
                    child: Row(
                      children: [
                        Container(
                          width: r.scale(3),
                          height: double.infinity,
                          color: AppColors.primary,
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: isDeleting ? null : widget.onTap,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                r.scale(12),
                                r.scale(10),
                                r.scale(4),
                                r.scale(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    entry.food.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: r.scale(14),
                                      color: AppColors.textPrimary,
                                      height: 1.2,
                                    ),
                                  ),
                                  SizedBox(height: r.scale(3)),
                                  Text(
                                    '${group.totalCalories} kcal'
                                    ' · ${entry.grams}g$countLabel',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: r.scale(12.5),
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: isDeleting ? null : _onDeletePressed,
                          tooltip: 'Remove',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.all(r.scale(8)),
                          constraints: BoxConstraints(
                            minWidth: r.scale(40),
                            minHeight: r.scale(40),
                          ),
                          icon: Icon(
                            Icons.close_rounded,
                            size: r.scale(20),
                            color: AppColors.error.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
