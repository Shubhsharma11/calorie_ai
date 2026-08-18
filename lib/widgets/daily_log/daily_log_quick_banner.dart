import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/food_controller.dart';
import '../../core/app_snackbar.dart';
import '../../core/responsive.dart';
import '../../models/meal_suggestion.dart';
import '../../theme/app_colors.dart';
import '../food_emoji_avatar.dart';

class DailyLogQuickBanner extends GetView<FoodController> {
  const DailyLogQuickBanner({super.key, required this.suggestion});

  final MealSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      margin: EdgeInsets.only(bottom: r.scale(16)),
      padding: EdgeInsets.symmetric(
        horizontal: r.scale(14),
        vertical: r.scale(12),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.14),
            AppColors.primary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          FoodEmojiAvatar(
            emoji: suggestion.items.first.food.displayEmoji,
            imageUrl: suggestion.items.first.food.imageUrl,
            size: 40,
          ),
          SizedBox(width: r.scale(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usual ${suggestion.meal.toLowerCase()}',
                  style: TextStyle(
                    fontSize: r.scale(12),
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  suggestion.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: r.scale(15),
                  ),
                ),
                Text(
                  '${suggestion.calories} kcal',
                  style: TextStyle(
                    fontSize: r.scale(12),
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () {
              controller.logSuggestion(suggestion);
              AppSnackbar.success('Added to your log.', title: 'Done');
            },
            style: FilledButton.styleFrom(
              minimumSize: Size(r.scale(64), 36),
              padding: EdgeInsets.symmetric(horizontal: r.scale(12)),
            ),
            child: const Text('Add'),
          ),
          IconButton(
            onPressed: controller.dismissBreakfastSuggestion,
            icon: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
