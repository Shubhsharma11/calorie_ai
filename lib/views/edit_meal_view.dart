import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/food_controller.dart';
import '../core/responsive.dart';
import '../models/food_item.dart';
import '../models/meal_entry.dart';
import '../models/meal_type.dart';
import '../models/saved_meal_item.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/confirm_delete_sheet.dart';
import '../widgets/delete_lottie.dart';
import '../widgets/food_emoji_avatar.dart';
import '../widgets/meal_ingredients_section.dart';
import '../widgets/meal_type_chip_row.dart';
import '../widgets/media_viewer.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_page.dart';
import '../widgets/serving_quantity_stepper.dart';

class EditMealView extends StatefulWidget {
  const EditMealView({super.key});

  @override
  State<EditMealView> createState() => _EditMealViewState();
}

class _EditMealViewState extends State<EditMealView> {
  late final FoodController _controller = Get.find<FoodController>();
  late MealEntry _entry;
  late FoodItem _food;
  late int _grams;
  late double _servingCount;
  late String _meal;
  bool _deleting = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is! MealEntry) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Get.back());
      _entry = MealEntry(
        food: const FoodItem(
          name: '',
          caloriesPer100g: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
        ),
        grams: 100,
        meal: MealType.breakfast,
      );
      _food = _entry.food;
      _grams = 100;
      _servingCount = 100;
      _meal = MealType.breakfast;
      return;
    }
    _entry = args;
    _food = args.food;
    _grams = _entry.grams;
    _servingCount = _food.servingCountForGrams(_entry.grams);
    _meal = MealType.all.contains(_entry.meal)
        ? _entry.meal
        : MealType.breakfast;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateFromCatalog();
    });
  }

  List<SavedMealItem> get _displayIngredients =>
      _food.ingredientsForPortions(_servingCount);

  Future<void> _hydrateFromCatalog() async {
    final hydrated = await _controller.hydrateLoggedFood(_food, grams: _grams);
    if (!mounted) return;
    if (hydrated.imageUrl == _food.imageUrl &&
        hydrated.servingUnit == _food.servingUnit &&
        hydrated.gramsPerServing == _food.gramsPerServing &&
        hydrated.category == _food.category) {
      return;
    }
    setState(() {
      _food = hydrated;
      _servingCount = _food.servingCountForGrams(_grams);
    });
  }

  @override
  Widget build(BuildContext context) {
    AppColors.syncFromContext(context);
    final r = context.responsive;
    final calories = _food.caloriesForGrams(_grams);
    final category = _food.category?.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppAppBar(
        title: 'Edit Food',
        actions: [
          if (!_deleting)
            IconButton(
              onPressed: _startDelete,
              tooltip: 'Remove from diary',
              icon: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
            ),
        ],
      ),
      body: ResponsivePage(
        scrollable: !_deleting,
        child: _deleting
            ? Material(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: DeleteLottieBox(
                  height: 220,
                  size: 140,
                  onCompleted: () {},
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: FoodEmojiAvatar(
                      emoji: _food.displayEmoji,
                      imageUrl: _food.imageUrl,
                      size: r.scale(120),
                      fontSize: r.scale(64),
                      onTap: mediaViewerOpener(
                        context: context,
                        imageUrl: _food.imageUrl,
                        title: _food.name,
                      ),
                    ),
                  ),
                  SizedBox(height: r.scale(16)),
                  Text(
                    _food.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: r.scale(22),
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (category != null && category.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: r.scale(6)),
                      child: Text(
                        category,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  SizedBox(height: r.scale(8)),
                  Text(
                    '$calories kcal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: r.scale(32),
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: r.scale(24)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MacroChip(
                        label: 'Protein',
                        value:
                            '${_food.macroForGrams(_food.protein, _grams).toStringAsFixed(1)}g',
                      ),
                      _MacroChip(
                        label: 'Carbs',
                        value:
                            '${_food.macroForGrams(_food.carbs, _grams).toStringAsFixed(1)}g',
                      ),
                      _MacroChip(
                        label: 'Fat',
                        value:
                            '${_food.macroForGrams(_food.fat, _grams).toStringAsFixed(1)}g',
                      ),
                    ],
                  ),
                  if (_food.isCompositeMeal) ...[
                    SizedBox(height: r.scale(32)),
                    MealIngredientsSection(items: _displayIngredients),
                  ],
                  SizedBox(height: r.scale(32)),
                  Text(
                    'Meal',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: r.scale(8)),
                  MealTypeChipRow(
                    selectedMeal: _meal,
                    onSelected: (meal) => setState(() => _meal = meal),
                  ),
                  SizedBox(height: r.scale(24)),
                  ServingQuantityStepper(
                    food: _food,
                    quantity: _servingCount,
                    onChanged: (value) {
                      setState(() {
                        _servingCount = value;
                        _grams = _food.gramsForServings(value);
                      });
                    },
                  ),
                  SizedBox(height: r.scale(32)),
                  PrimaryButton(
                    label: 'Save Changes',
                    isLoading: _saving,
                    onPressed: _save,
                  ),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
                ],
              ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await _controller.updateEntry(
      _entry,
      grams: _grams,
      meal: _meal,
      food: _food,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Get.back();
  }

  Future<void> _startDelete() async {
    if (_deleting) return;

    final confirmed = await showConfirmDeleteSheet(
      context: context,
      title: 'Remove from diary?',
      message:
          '“${_food.name}” will be permanently deleted from your daily log.',
      cancelLabel: 'Keep',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);

    final ok = await _controller.deleteMealEntry(_entry);
    if (!mounted) return;

    if (ok) {
      Get.back();
      return;
    }

    setState(() => _deleting = false);
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ],
    );
  }
}
