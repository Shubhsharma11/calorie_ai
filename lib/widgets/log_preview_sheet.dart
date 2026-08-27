import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/food_controller.dart';
import '../core/app_snackbar.dart';
import '../core/media_url.dart';
import '../core/pick_cropped_image.dart';
import '../core/responsive.dart';
import '../models/custom_food_preset.dart';
import '../models/custom_meal_preset.dart';
import '../models/food_item.dart';
import '../models/meal_type.dart';
import '../models/saved_meal_item.dart';
import '../theme/app_colors.dart';
import 'app_bottom_sheet.dart';
import 'app_network_image.dart';
import 'food_emoji_avatar.dart';
import 'meal_type_chip_row.dart';
import 'meal_visibility_chip.dart';
import 'media_viewer.dart';
import 'serving_quantity_stepper.dart';

String _normalizedMeal(String? meal) {
  if (meal != null && MealType.all.contains(meal)) return meal;
  if (Get.isRegistered<FoodController>()) {
    final selected = Get.find<FoodController>().selectedMeal.value;
    if (MealType.all.contains(selected)) return selected;
  }
  return MealType.breakfast;
}

/// Gym-style preview used to log a custom meal, history item, or catalog food.
Future<void> showLogPreviewSheet(
  BuildContext context, {
  required String title,
  required List<SavedMealItem> items,
  String? initialMeal,
  MealShareVisibility? visibility,
  Uint8List? imageBytes,
  String? imageUrl,
  String? subtitle,
  int? calories,
  required FutureOr<void> Function(String meal) onLog,
  String Function(String meal)? successMessage,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      return _LogPreviewSheet(
        title: title,
        items: items,
        initialMeal: _normalizedMeal(initialMeal),
        visibility: visibility,
        imageBytes: imageBytes,
        imageUrl: imageUrl,
        subtitle: subtitle,
        calories: calories,
        onLog: onLog,
        successMessage: successMessage,
      );
    },
  );
}

Future<void> showFoodItemLogSheet(
  BuildContext context, {
  required FoodItem food,
  String? initialMeal,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => AdjustableFoodLogSheet(
      food: food,
      initialMeal: _normalizedMeal(initialMeal),
    ),
  );
}

class _LogPreviewSheet extends StatefulWidget {
  const _LogPreviewSheet({
    required this.title,
    required this.items,
    required this.initialMeal,
    required this.onLog,
    this.visibility,
    this.imageBytes,
    this.imageUrl,
    this.subtitle,
    this.calories,
    this.successMessage,
  });

  final String title;
  final List<SavedMealItem> items;
  final String initialMeal;
  final MealShareVisibility? visibility;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final String? subtitle;
  final int? calories;
  final FutureOr<void> Function(String meal) onLog;
  final String Function(String meal)? successMessage;

  @override
  State<_LogPreviewSheet> createState() => _LogPreviewSheetState();
}

class _LogPreviewSheetState extends State<_LogPreviewSheet> {
  late String _selectedMeal = widget.initialMeal;
  bool _logging = false;

  int get _calories =>
      widget.calories ??
      widget.items.fold(0, (sum, item) => sum + item.calories);

  String get _subtitle {
    if (widget.subtitle != null) return widget.subtitle!;
    final count = widget.items.length;
    return count == 1 ? '1 food' : '$count foods';
  }

  Future<void> _log() async {
    if (_logging) return;
    setState(() => _logging = true);
    try {
      await widget.onLog(_selectedMeal);
      if (!mounted) return;
      setState(() => _logging = false);
      Navigator.pop(context);
      AppSnackbar.success(
        widget.successMessage?.call(_selectedMeal) ??
            '${widget.title} added to $_selectedMeal.',
        title: 'Logged',
      );
    } finally {
      if (mounted && _logging) setState(() => _logging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_logging,
      child: LogPreviewBody(
        title: widget.title,
        subtitle: _subtitle,
        visibility: widget.visibility,
        calories: _calories,
        items: widget.items,
        selectedMeal: _selectedMeal,
        imageBytes: widget.imageBytes,
        imageUrl: widget.imageUrl,
        isLogging: _logging,
        onMealSelected: _logging
            ? (_) {}
            : (meal) => setState(() => _selectedMeal = meal),
        onLog: _log,
      ),
    );
  }
}

double _initialServingCount(FoodItem food, SavedMealItem? item) {
  if (item != null) return item.displayedServingQuantity;
  if (food.usesHouseholdServing) return 1;
  return food.servingQuantity;
}

class AdjustableFoodLogSheet extends StatefulWidget {
  const AdjustableFoodLogSheet({
    super.key,
    required this.food,
    required this.initialMeal,
    this.historyItem,
    this.myFood,
    this.onLogged,
  });

  final FoodItem food;
  final String initialMeal;
  final SavedMealItem? historyItem;
  final CustomFoodPreset? myFood;
  final VoidCallback? onLogged;

  @override
  State<AdjustableFoodLogSheet> createState() => _AdjustableFoodLogSheetState();
}

class _AdjustableFoodLogSheetState extends State<AdjustableFoodLogSheet> {
  late String _selectedMeal = _normalizedMeal(widget.initialMeal);
  late double _servingCount = _initialServingCount(
    widget.food,
    widget.historyItem,
  );
  bool _favoriteBusy = false;
  bool _logging = false;

  FoodController get _food => Get.find<FoodController>();

  FoodItem get food => widget.food;

  int get _grams => food.gramsForServings(_servingCount);

  List<SavedMealItem> get _items {
    if (food.isCompositeMeal) {
      return food.ingredientsForPortions(_servingCount);
    }
    final history = widget.historyItem;
    if (history != null && history.hasServingNutrition) {
      return [
        history.copyWith(
          meal: _selectedMeal,
          servingQuantity: _servingCount,
          grams: _grams,
        ),
      ];
    }
    return [
      SavedMealItem(
        food: food,
        grams: _grams,
        meal: _selectedMeal,
        servingQuantity: _servingCount,
        servingUnit: food.servingUnit,
      ),
    ];
  }

  int get _calories => food.isCompositeMeal
      ? food.totalCaloriesForPortions(_servingCount)
      : _items.fold(0, (sum, item) => sum + item.calories);

  String get _subtitle {
    if (food.isCompositeMeal) {
      final count = food.ingredients.length;
      return count == 1 ? '1 food' : '$count foods';
    }
    return _items.single.servingDescription;
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteBusy || _logging) return;
    setState(() => _favoriteBusy = true);
    try {
      final added = await _food.toggleFavoriteFood(
        food: food,
        grams: _grams,
        meal: _selectedMeal,
      );
      if (!mounted || added == null) return;
      AppSnackbar.success(
        added ? 'Added to favourites.' : 'Removed from favourites.',
        title: added ? 'Saved' : 'Removed',
      );
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  Future<void> _log() async {
    if (_logging) return;
    setState(() => _logging = true);
    var ok = false;
    try {
      if (widget.myFood != null) {
        ok = await _food.logMyFood(
          widget.myFood!,
          meal: _selectedMeal,
          grams: _grams,
          servingQuantity: _servingCount,
        );
      } else if (food.isCompositeMeal) {
        ok = true;
        for (final item in _items) {
          final logged = await _food.logFromHistory(
            item.copyWith(meal: _selectedMeal),
            meal: _selectedMeal,
          );
          if (!logged) ok = false;
        }
      } else if (widget.historyItem != null) {
        ok = await _food.logFromHistory(_items.single, meal: _selectedMeal);
      } else {
        ok = await _food.addToLog(food, meal: _selectedMeal, grams: _grams);
      }
      if (!mounted) return;
      if (!ok) return;
      // Unlock PopScope before pop or the sheet can stay open with a spinner.
      setState(() => _logging = false);
      Navigator.pop(context);
      AppSnackbar.success(
        '${food.name} added to $_selectedMeal.',
        title: 'Logged',
      );
      widget.onLogged?.call();
    } finally {
      if (mounted && _logging) setState(() => _logging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_logging,
      child: Obx(() {
        _food.favoriteMeals.length;
        final isFavorite = _food.isFavoriteFood(food, _selectedMeal);
        return LogPreviewBody(
          title: food.name,
          subtitle: _subtitle,
          calories: _calories,
          items: _items,
          selectedMeal: _selectedMeal,
          imageUrl: food.imageUrl,
          isFavorite: isFavorite,
          isLogging: _logging,
          onFavoriteTap: _logging ? null : _toggleFavorite,
          onMealSelected: _logging
              ? (_) {}
              : (meal) => setState(() => _selectedMeal = meal),
          onLog: _log,
          belowItems: ServingQuantityStepper(
            food: food,
            quantity: _servingCount,
            dense: true,
            onChanged: _logging
                ? (_) {}
                : (value) => setState(() => _servingCount = value),
          ),
        );
      }),
    );
  }
}

/// Visual body of the Gym-style log sheet (handle, foods, chips, log button).
class LogPreviewBody extends StatelessWidget {
  const LogPreviewBody({
    super.key,
    required this.title,
    required this.subtitle,
    required this.calories,
    required this.items,
    required this.selectedMeal,
    required this.onMealSelected,
    required this.onLog,
    this.visibility,
    this.imageBytes,
    this.imageUrl,
    this.isFavorite,
    this.onFavoriteTap,
    this.belowItems,
    this.isLogging = false,
  });

  final String title;
  final String subtitle;
  final int calories;
  final List<SavedMealItem> items;
  final String selectedMeal;
  final ValueChanged<String> onMealSelected;
  final VoidCallback onLog;
  final MealShareVisibility? visibility;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final bool? isFavorite;
  final VoidCallback? onFavoriteTap;
  final Widget? belowItems;
  final bool isLogging;

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final hasPhoto = canViewMedia(imageBytes: imageBytes, imageUrl: imageUrl);

    return AppSheetScaffold(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasPhoto) ...[
              _PhotoBanner(
                title: title,
                imageBytes: imageBytes,
                imageUrl: imageUrl,
              ),
              SizedBox(height: r.scale(16)),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: r.scale(22),
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                height: 1.15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (onFavoriteTap != null)
                            IconButton(
                              tooltip: isFavorite == true
                                  ? 'Remove from favourites'
                                  : 'Add to favourites',
                              onPressed: onFavoriteTap,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints.tightFor(
                                width: r.scale(36),
                                height: r.scale(36),
                              ),
                              icon: Icon(
                                isFavorite == true
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: isFavorite == true
                                    ? const Color(0xFFFFB800)
                                    : AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: r.scale(6)),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: r.scale(13),
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (visibility != null) ...[
                            SizedBox(width: r.scale(8)),
                            MealVisibilityChip(visibility: visibility!),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: r.scale(12)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$calories',
                      style: TextStyle(
                        fontSize: r.scale(28),
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'kcal',
                      style: TextStyle(
                        fontSize: r.scale(12),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: r.scale(16)),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: r.scale(220)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: items.length > 4
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, _) => SizedBox(height: r.scale(8)),
                itemBuilder: (_, index) =>
                    LogPreviewFoodRow(item: items[index]),
              ),
            ),
            if (belowItems != null) ...[
              SizedBox(height: r.scale(12)),
              belowItems!,
            ],
            SizedBox(height: r.scale(16)),
            MealTypeChipRow(
              selectedMeal: selectedMeal,
              onSelected: onMealSelected,
            ),
            SizedBox(height: r.scale(16)),
            AppSheetPrimaryButton(
              label: 'Log to $selectedMeal',
              isLoading: isLogging,
              onPressed: onLog,
            ),
          ],
        ),
      ),
    );
  }
}

class LogPreviewFoodRow extends StatelessWidget {
  const LogPreviewFoodRow({super.key, required this.item});

  final SavedMealItem item;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final food = item.food;
    final radius = BorderRadius.circular(r.scale(10));
    final isDark = AppColors.isDark(context);

    return Material(
      color: isDark ? AppColors.surface : const Color(0xFFF7FBF8),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: AppColors.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: r.scale(3),
                color: AppColors.primary,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    r.scale(12),
                    r.scale(10),
                    r.scale(12),
                    r.scale(10),
                  ),
                  child: Row(
                    children: [
                      FoodEmojiAvatar(
                        key: ValueKey(food.imageUrl ?? food.name),
                        emoji: food.displayEmoji,
                        imageUrl: food.imageUrl,
                        size: r.scale(40),
                        backgroundColor: AppColors.card,
                        onTap: mediaViewerOpener(
                          context: context,
                          imageUrl: food.imageUrl,
                          title: food.name,
                        ),
                      ),
                      SizedBox(width: r.scale(10)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              food.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: r.scale(14),
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: r.scale(2)),
                            Text(
                              item.servingDescription,
                              style: TextStyle(
                                fontSize: r.scale(12),
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: r.scale(8)),
                      Text(
                        '${item.calories} kcal',
                        style: TextStyle(
                          fontSize: r.scale(13),
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoBanner extends StatelessWidget {
  const _PhotoBanner({required this.title, this.imageBytes, this.imageUrl});

  final String title;
  final Uint8List? imageBytes;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final radius = BorderRadius.circular(r.scale(16));

    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showMediaViewer(
          context: context,
          imageBytes: imageBytes,
          imageUrl: imageUrl,
          title: title,
        ),
        child: SizedBox(
          height: r.scale(176),
          width: double.infinity,
          child: imageBytes != null
              ? CappedMemoryImage(bytes: imageBytes!)
              : AppNetworkImage(
                  MediaUrl.resolve(imageUrl)!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, _) => Icon(
                    Icons.restaurant_menu_rounded,
                    color: AppColors.primary,
                    size: r.scale(36),
                  ),
                ),
        ),
      ),
    );
  }
}
