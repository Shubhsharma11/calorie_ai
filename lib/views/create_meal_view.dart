import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/food_controller.dart';
import '../core/app_snackbar.dart';
import '../core/pick_cropped_image.dart';
import '../core/responsive.dart';
import '../models/custom_meal_preset.dart';
import '../services/food_api_service.dart';
import '../models/food_item.dart';
import '../models/meal_type.dart';
import '../models/saved_meal_item.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/food_emoji_avatar.dart';
import '../widgets/meal_type_chip_row.dart';
import '../widgets/no_results_illustration.dart';
import '../widgets/responsive_page.dart';
import 'create_custom_food_view.dart';

class CreateMealView extends StatefulWidget {
  const CreateMealView({super.key});

  @override
  State<CreateMealView> createState() => _CreateMealViewState();
}

class _CreateMealViewState extends State<CreateMealView> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _imagePicker = ImagePicker();
  late final FoodController _food = Get.find<FoodController>();
  late String _selectedMeal;
  final List<SavedMealItem> _items = [];
  List<FoodItem> _searchResults = [];
  bool _isSaving = false;
  bool _isSearching = false;
  String? _searchError;
  MealShareVisibility _visibility = MealShareVisibility.public;
  CustomMealPreset? _editingPreset;
  Timer? _searchDebounce;
  int _searchRequestId = 0;
  Uint8List? _mealImageBytes;

  bool get _isEditing => _editingPreset != null;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is CustomMealPreset) {
      _editingPreset = args;
      _nameController.text = args.name;
      _selectedMeal = MealType.all.contains(args.meal)
          ? args.meal
          : MealType.breakfast;
      _visibility = args.visibility;
      _items.addAll(args.items);
      _mealImageBytes = args.imageBytes;
    } else {
      final initial = args is String && MealType.all.contains(args)
          ? args
          : _food.selectedMeal.value;
      _selectedMeal =
          MealType.all.contains(initial) ? initial : MealType.breakfast;
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    final requestId = ++_searchRequestId;
    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final apiResults = await _food.searchFoodsEphemeral(query);
        if (!mounted || requestId != _searchRequestId) return;
        if (_searchController.text.trim() != query) return;

        setState(() {
          _searchResults = apiResults.take(8).toList();
          _isSearching = false;
          _searchError = null;
        });
      } on FoodApiException catch (error) {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _searchError = error.message;
        });
      } catch (_) {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() {
          _searchResults = [];
          _isSearching = false;
          _searchError = 'Unable to search foods. Please try again.';
        });
      }
    });
  }

  int get _totalCalories =>
      _items.fold(0, (sum, item) => sum + item.calories);

  double get _totalCarbs => _items.fold(
        0.0,
        (sum, item) => sum + item.carbs,
      );

  double get _totalProtein => _items.fold(
        0.0,
        (sum, item) => sum + item.protein,
      );

  double get _totalFat => _items.fold(
        0.0,
        (sum, item) => sum + item.fat,
      );

  double get _macroCalories =>
      _totalCarbs * 4 + _totalProtein * 4 + _totalFat * 9;

  double _macroShare(double grams, double kcalPerGram) {
    if (_macroCalories <= 0) return 0;
    return (grams * kcalPerGram) / _macroCalories;
  }

  void _addFood(FoodItem food) {
    setState(() {
      _items.add(
        SavedMealItem(food: food, grams: 100, meal: _selectedMeal),
      );
      _searchController.clear();
      _searchResults = [];
      _searchError = null;
      _isSearching = false;
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _customizeItem(int index) async {
    final item = _items[index];
    final customized = await showModalBottomSheet<_CustomizedFoodInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomizeNutritionSheet(item: item),
    );
    if (customized == null || !mounted || index >= _items.length) return;

    final customizedFood = FoodItem(
      name: customized.name,
      caloriesPer100g: (customized.carbs * 4 +
              customized.protein * 4 +
              customized.fat * 9)
          .round(),
      protein: customized.protein,
      carbs: customized.carbs,
      fat: customized.fat,
      emoji: item.food.emoji,
      imageUrl: item.food.imageUrl,
    );

    setState(() {
      _items[index] = SavedMealItem(
        food: customizedFood,
        grams: customized.canonicalGrams,
        meal: _selectedMeal,
        servingQuantity: customized.servingQuantity,
        servingUnit: customized.servingUnit,
        nutritionBasisQuantity: customized.nutritionBasisQuantity,
        basisCarbs: customized.carbs,
        basisProtein: customized.protein,
        basisFat: customized.fat,
      );
    });
  }

  Future<void> _showMealImageOptions() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () =>
                  Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    // Wait for the sheet route to finish disposing before opening native UI.
    // Opening the picker/cropper during sheet teardown triggers
    // `_dependents.isEmpty` / Duplicate GlobalKeys crashes.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    try {
      final bytes = await pickAndCropPhoto(
        picker: _imagePicker,
        source: source,
        cropTitle: 'Crop meal photo',
      );
      if (bytes == null || !mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _mealImageBytes = bytes);
      });
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(
        'The photo could not be selected. Please try again.',
        title: 'Photo unavailable',
      );
    }
  }

  Future<void> _save({required bool logAfterSave}) async {
    if (_isSaving) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackbar.error('Give your meal a name first.', title: 'Name required');
      return;
    }
    if (_items.isEmpty) {
      AppSnackbar.error('Add at least one food.', title: 'No foods');
      return;
    }

    _isSaving = true;
    setState(() {});
    // Let the loading overlay paint before we start async work.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    try {
      final preset = CustomMealPreset(
        id: _editingPreset?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        createdAt: _editingPreset?.createdAt ?? DateTime.now(),
        meal: _selectedMeal,
        items: _items
            .map((item) => item.copyWith(meal: _selectedMeal))
            .toList(),
        visibility: _visibility,
        imageBytes: _mealImageBytes,
      );

      final savedPreset = await _food.saveCustomMealPreset(
        preset,
        isUpdate: _isEditing,
      );

      if (logAfterSave) {
        _food.logCustomMealPreset(savedPreset, meal: _selectedMeal);
      }

      if (!mounted) return;
      Get.back<void>();

      AppSnackbar.success(
        logAfterSave
            ? '$name saved and logged to $_selectedMeal.'
            : _isEditing
                ? '$name updated in My Meals.'
                : '$name saved to My Meals.',
        title: logAfterSave ? 'Saved & logged' : 'Saved',
      );
      // Keep _isSaving true after success so a late tap cannot log again
      // while this route is still finishing its pop.
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
      AppSnackbar.error(
        'Could not save this meal. Please try again.',
        title: 'Save failed',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      appBar: AppAppBar(title: _isEditing ? 'Edit meal' : 'Create meal'),
      body: Column(
        children: [
          Expanded(
            child: ResponsivePage(
              scrollable: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    title: 'Meal details',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MealImagePicker(
                          imageBytes: _mealImageBytes,
                          onPick: _isSaving ? () {} : _showMealImageOptions,
                          onRemove: () =>
                              setState(() => _mealImageBytes = null),
                        ),
                        SizedBox(height: r.scale(14)),
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'e.g. Office lunch bowl',
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: r.scale(16),
                              vertical: r.scale(14),
                            ),
                          ),
                        ),
                        SizedBox(height: r.scale(14)),
                        Text(
                          'Default slot',
                          style: TextStyle(
                            fontSize: r.scale(12),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: r.scale(8)),
                        MealTypeChipRow(
                          selectedMeal: _selectedMeal,
                          onSelected: (meal) =>
                              setState(() => _selectedMeal = meal),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.scale(12)),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (r.isCompact) ...[
                          Text(
                            'Share with',
                            style: TextStyle(
                              fontSize: r.scale(16),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: r.scale(10)),
                          _ShareInlineToggle(
                            visibility: _visibility,
                            onChanged: (value) =>
                                setState(() => _visibility = value),
                          ),
                        ] else
                          Row(
                            children: [
                              Text(
                                'Share with',
                                style: TextStyle(
                                  fontSize: r.scale(16),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              _ShareInlineToggle(
                                visibility: _visibility,
                                onChanged: (value) =>
                                    setState(() => _visibility = value),
                              ),
                            ],
                          ),
                        SizedBox(height: r.scale(8)),
                        Text(
                          _visibility == MealShareVisibility.public
                              ? 'Public is saved on this device for now. Community sharing is coming soon.'
                              : 'Only you can see and use this meal template.',
                          style: TextStyle(
                            fontSize: r.scale(12),
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.scale(12)),
                  _MacroRingPanel(
                    calories: _totalCalories,
                    carbsG: _totalCarbs,
                    proteinG: _totalProtein,
                    fatG: _totalFat,
                    carbsShare: _macroShare(_totalCarbs, 4),
                    proteinShare: _macroShare(_totalProtein, 4),
                    fatShare: _macroShare(_totalFat, 9),
                  ),
                  SizedBox(height: r.scale(12)),
                  _SectionCard(
                    title: 'Add foods',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search foods...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _isSearching
                                ? Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        if (_searchResults.isNotEmpty) ...[
                          SizedBox(height: r.scale(10)),
                          Material(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: List.generate(
                                _searchResults.length,
                                (index) {
                                  final food = _searchResults[index];
                                  final isLast =
                                      index == _searchResults.length - 1;
                                  return Column(
                                    children: [
                                      ListTile(
                                        onTap: () => _addFood(food),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        leading: FoodEmojiAvatar(
                                          emoji: food.emoji,
                                          imageUrl: food.imageUrl,
                                          size: r.scale(42),
                                        ),
                                        title: Text(
                                          food.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${food.caloriesPer100g} kcal / 100g',
                                          style: TextStyle(
                                            fontSize: r.scale(12),
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        trailing: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.add_rounded,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      if (!isLast)
                                        Divider(
                                          height: 1,
                                          indent: 60,
                                          color: AppColors.border,
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ] else if (_searchController.text.trim().isNotEmpty &&
                            !_isSearching &&
                            _searchError != null) ...[
                          SizedBox(height: r.scale(10)),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: r.scale(12),
                            ),
                            child: Text(
                              _searchError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: r.scale(13),
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ] else if (_searchController.text.trim().isNotEmpty &&
                            !_isSearching) ...[
                          SizedBox(height: r.scale(10)),
                          _NoSearchResultsCreateFoodHint(
                            r: r,
                            query: _searchController.text.trim(),
                            onCreateFood: () => Get.to<void>(
                              () => const CreateCustomFoodView(),
                            ),
                          ),
                        ],
                        if (_items.isNotEmpty) ...[
                          SizedBox(height: r.scale(16)),
                          Text(
                            'Ingredients',
                            style: TextStyle(
                              fontSize: r.scale(14),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: r.scale(8)),
                          ...List.generate(_items.length, (index) {
                            final item = _items[index];
                            return _IngredientRow(
                              item: item,
                              onCustomize: () => _customizeItem(index),
                              onRemove: () => _removeItem(index),
                            );
                          }),
                        ] else if (_searchController.text.trim().isEmpty) ...[
                          SizedBox(height: r.scale(12)),
                          _EmptyIngredientsHint(r: r),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: r.scale(100)),
                ],
              ),
            ),
          ),
          _BottomActionBar(
            selectedMeal: _selectedMeal,
            isSaving: _isSaving,
            isEditing: _isEditing,
            onSaveAndLog: () => _save(logAfterSave: true),
            onSaveOnly: () => _save(logAfterSave: false),
          ),
        ],
      ),
    );
  }
}

class _CustomizedFoodInput {
  const _CustomizedFoodInput({
    required this.name,
    required this.canonicalGrams,
    required this.servingQuantity,
    required this.servingUnit,
    required this.nutritionBasisQuantity,
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  final String name;
  final int canonicalGrams;
  final double servingQuantity;
  final String servingUnit;
  final double nutritionBasisQuantity;
  final double carbs;
  final double protein;
  final double fat;
}

class _CustomizeNutritionSheet extends StatefulWidget {
  const _CustomizeNutritionSheet({required this.item});

  final SavedMealItem item;

  @override
  State<_CustomizeNutritionSheet> createState() =>
      _CustomizeNutritionSheetState();
}

class _CustomizeNutritionSheetState extends State<_CustomizeNutritionSheet> {
  static const _servingUnits = <String, String>{
    'piece': 'Piece',
    'bowl': 'Bowl',
    'plate': 'Plate',
    'cup': 'Cup',
    'glass': 'Glass',
    'slice': 'Slice',
    'tbsp': 'Tablespoon (tbsp)',
    'g': 'Grams (g)',
    'ml': 'Milliliters (ml)',
  };

  late final TextEditingController _nameController;
  late final TextEditingController _servingController;
  late final TextEditingController _carbsController;
  late final TextEditingController _proteinController;
  late final TextEditingController _fatController;
  late String _servingUnit;
  String? _errorText;

  double get _nutritionBasisQuantity =>
      _servingUnit == 'g' || _servingUnit == 'ml' ? 100 : 1;

  String get _nutritionBasisLabel {
    final quantity = _format(_nutritionBasisQuantity);
    return 'NUTRIENTS FOR $quantity ${_servingUnit.toUpperCase()}';
  }

  String get _selectedUnitLabel => switch (_servingUnit) {
        'tbsp' => 'tbsp',
        'g' => 'g',
        'ml' => 'ml',
        _ => _servingUnits[_servingUnit] ?? _servingUnit,
      };

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    final food = item.food;
    _nameController = TextEditingController(
      text: food.name.endsWith(' (Custom)')
          ? food.name
          : '${food.name} (Custom)',
    );
    _servingUnit = _servingUnits.containsKey(item.servingUnit)
        ? item.servingUnit
        : 'g';
    _servingController = TextEditingController(
      text: _format(item.displayedServingQuantity),
    );
    _carbsController = TextEditingController(
      text: _format(_initialBasisMacro(item, food.carbs, item.basisCarbs)),
    );
    _proteinController = TextEditingController(
      text: _format(_initialBasisMacro(item, food.protein, item.basisProtein)),
    );
    _fatController = TextEditingController(
      text: _format(_initialBasisMacro(item, food.fat, item.basisFat)),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  String _format(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  double _initialBasisMacro(
    SavedMealItem item,
    double per100Grams,
    double? savedBasis,
  ) {
    if (item.hasServingNutrition) return savedBasis!;
    if (_servingUnit == 'g' || _servingUnit == 'ml') return per100Grams;
    final quantity = item.displayedServingQuantity;
    if (quantity <= 0) return per100Grams;
    return item.food.macroForGrams(per100Grams, item.grams) / quantity;
  }

  void _clearError() {
    if (_errorText != null) setState(() => _errorText = null);
  }

  Future<void> _selectServingUnit() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final r = sheetContext.responsive;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              r.scale(20),
              r.scale(16),
              r.scale(20),
              r.scale(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Select serving unit',
                  style: TextStyle(
                    fontSize: r.scale(18),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: r.scale(14)),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: r.scale(8),
                  crossAxisSpacing: r.scale(8),
                  childAspectRatio: 2.4,
                  children: _servingUnits.entries.map((entry) {
                    final selected = entry.key == _servingUnit;
                    return InkWell(
                      onTap: () => Navigator.pop(sheetContext, entry.key),
                      borderRadius: BorderRadius.circular(r.scale(10)),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(r.scale(10)),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          entry.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: r.scale(10.5),
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || selected == _servingUnit || !mounted) return;

    setState(() {
      _servingUnit = selected;
      _errorText = null;
      _servingController.text =
          selected == 'g' || selected == 'ml' ? '100' : '1';
      _carbsController.clear();
      _proteinController.clear();
      _fatController.clear();
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    final servingQuantity =
        double.tryParse(_servingController.text.trim()) ?? 0;
    final canonicalGrams =
        _servingUnit == 'g' ? servingQuantity.round() : 100;
    final carbs = double.tryParse(_carbsController.text.trim()) ?? 0;
    final protein = double.tryParse(_proteinController.text.trim()) ?? 0;
    final fat = double.tryParse(_fatController.text.trim()) ?? 0;

    String? error;
    if (name.isEmpty) {
      error = 'Enter the food name.';
    } else if (servingQuantity <= 0 || servingQuantity > 5000) {
      error = 'Serving quantity must be greater than zero.';
    } else if (carbs < 0 || protein < 0 || fat < 0) {
      error = 'Nutrients cannot be negative.';
    } else if (carbs == 0 && protein == 0 && fat == 0) {
      error = 'Enter at least one nutrient value.';
    } else if (carbs > 1000 || protein > 1000 || fat > 1000) {
      error = 'Each nutrient value must be 1,000 g or less.';
    }

    if (error != null) {
      setState(() => _errorText = error);
      return;
    }

    Navigator.pop(
      context,
      _CustomizedFoodInput(
        name: name,
        canonicalGrams: canonicalGrams,
        servingQuantity: servingQuantity,
        servingUnit: _servingUnit,
        nutritionBasisQuantity: _nutritionBasisQuantity,
        carbs: carbs,
        protein: protein,
        fat: fat,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              r.scale(20),
              r.scale(12),
              r.scale(20),
              r.scale(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                SizedBox(height: r.scale(14)),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Customize nutrition',
                        style: TextStyle(
                          fontSize: r.scale(20),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(
                  'A private copy will be added to this meal. The original food remains unchanged.',
                  style: TextStyle(
                    fontSize: r.scale(12),
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: r.scale(16)),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => _clearError(),
                  decoration: const InputDecoration(
                    labelText: 'Food name',
                    prefixIcon: Icon(Icons.restaurant_rounded),
                  ),
                ),
                SizedBox(height: r.scale(12)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _servingController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d{0,4}([.]\d?)?'),
                          ),
                        ],
                        onChanged: (_) => _clearError(),
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          prefixIcon: Icon(Icons.scale_rounded),
                        ),
                      ),
                    ),
                    SizedBox(width: r.scale(10)),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _selectServingUnit,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Unit'),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedUnitLabel,
                                  style: TextStyle(
                                    fontSize: r.scale(12),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: r.scale(20),
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.scale(16)),
                Text(
                  _nutritionBasisLabel,
                  style: TextStyle(
                    fontSize: r.scale(11),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: r.scale(3)),
                Text(
                  'Enter values for this amount. Nutrition scales '
                  'automatically with quantity.',
                  style: TextStyle(
                    fontSize: r.scale(11),
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: r.scale(10)),
                Row(
                  children: [
                    Expanded(
                      child: _NutrientInput(
                        label: 'Carbs',
                        controller: _carbsController,
                        color: _MealMacroColors.carbs,
                        onChanged: _clearError,
                      ),
                    ),
                    SizedBox(width: r.scale(8)),
                    Expanded(
                      child: _NutrientInput(
                        label: 'Protein',
                        controller: _proteinController,
                        color: _MealMacroColors.protein,
                        onChanged: _clearError,
                      ),
                    ),
                    SizedBox(width: r.scale(8)),
                    Expanded(
                      child: _NutrientInput(
                        label: 'Fat',
                        controller: _fatController,
                        color: _MealMacroColors.fat,
                        onChanged: _clearError,
                      ),
                    ),
                  ],
                ),
                if (_errorText != null) ...[
                  SizedBox(height: r.scale(10)),
                  Text(
                    _errorText!,
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: r.scale(12),
                    ),
                  ),
                ],
                SizedBox(height: r.scale(18)),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save custom copy'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NutrientInput extends StatelessWidget {
  const _NutrientInput({
    required this.label,
    required this.controller,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final Color color;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}([.]\d?)?')),
      ],
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        suffixText: 'g',
        labelStyle: TextStyle(color: color),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

abstract final class _MealMacroColors {
  static const carbs = Color(0xFF2196F3);
  static const fat = Color(0xFF9C27B0);
  static const protein = Color(0xFF4CAF50);
}

class _MacroRingPanel extends StatelessWidget {
  const _MacroRingPanel({
    required this.calories,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    required this.carbsShare,
    required this.proteinShare,
    required this.fatShare,
  });

  final int calories;
  final double carbsG;
  final double proteinG;
  final double fatG;
  final double carbsShare;
  final double proteinShare;
  final double fatShare;

  bool get _hasData => calories > 0;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final ringSize = r.scale(r.isCompact ? 96 : 112, tablet: 124);
    final strokeWidth = r.scale(r.isCompact ? 9 : 11);
    final stackVertically = r.isCompact || r.width < 380;

    final ring = SizedBox(
      width: ringSize,
      height: ringSize,
      child: CustomPaint(
        painter: _MacroDonutPainter(
          carbsShare: carbsShare,
          fatShare: fatShare,
          proteinShare: proteinShare,
          strokeWidth: strokeWidth,
          trackColor: AppColors.surface,
        ),
        child: Center(
          child: _hasData
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$calories',
                      style: TextStyle(
                        fontSize: r.scale(r.isCompact ? 18 : 22),
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        height: 1,
                      ),
                    ),
                    Text(
                      'kcal',
                      style: TextStyle(
                        fontSize: r.scale(13),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pie_chart_outline_rounded,
                      size: r.scale(22),
                      color: AppColors.textSecondary.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    SizedBox(height: r.scale(4)),
                    Text(
                      'Add foods',
                      style: TextStyle(
                        fontSize: r.scale(11),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MacroLegendRow(
          color: _MealMacroColors.carbs,
          label: 'Carbs',
          grams: carbsG,
          share: carbsShare,
        ),
        SizedBox(height: r.scale(10)),
        _MacroLegendRow(
          color: _MealMacroColors.fat,
          label: 'Fat',
          grams: fatG,
          share: fatShare,
        ),
        SizedBox(height: r.scale(10)),
        _MacroLegendRow(
          color: _MealMacroColors.protein,
          label: 'Protein',
          grams: proteinG,
          share: proteinShare,
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(r.scale(16)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(r.scale(20)),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: stackVertically
          ? Column(
              children: [
                ring,
                SizedBox(height: r.scale(14)),
                legend,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ring,
                SizedBox(width: r.scale(16)),
                Expanded(child: legend),
              ],
            ),
    );
  }
}

class _MacroDonutPainter extends CustomPainter {
  const _MacroDonutPainter({
    required this.carbsShare,
    required this.fatShare,
    required this.proteinShare,
    required this.strokeWidth,
    required this.trackColor,
  });

  final double carbsShare;
  final double fatShare;
  final double proteinShare;
  final double strokeWidth;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final segments = <(double, Color)>[
      (carbsShare, _MealMacroColors.carbs),
      (fatShare, _MealMacroColors.fat),
      (proteinShare, _MealMacroColors.protein),
    ];

    var currentAngle = startAngle;
    for (final (share, color) in segments) {
      if (share <= 0) continue;
      final sweep = 2 * math.pi * share;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, currentAngle, sweep, false, paint);
      currentAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_MacroDonutPainter old) =>
      old.carbsShare != carbsShare ||
      old.fatShare != fatShare ||
      old.proteinShare != proteinShare ||
      old.strokeWidth != strokeWidth ||
      old.trackColor != trackColor;
}

class _MacroLegendRow extends StatelessWidget {
  const _MacroLegendRow({
    required this.color,
    required this.label,
    required this.grams,
    required this.share,
  });

  final Color color;
  final String label;
  final double grams;
  final double share;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Row(
      children: [
        Container(
          width: r.scale(10),
          height: r.scale(10),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: r.scale(10)),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: r.scale(14),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          grams > 0 ? '${grams.round()}g' : '—',
          style: TextStyle(
            fontSize: r.scale(13),
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MealImagePicker extends StatelessWidget {
  const _MealImagePicker({
    required this.imageBytes,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? imageBytes;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final image = imageBytes;

    return ClipRRect(
      borderRadius: BorderRadius.circular(r.scale(16)),
      child: Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: onPick,
          child: SizedBox(
            height: r.scale(150),
            child: image == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(r.scale(10)),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_a_photo_outlined,
                          size: r.scale(24),
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: r.scale(9)),
                      Text(
                        'Add meal photo',
                        style: TextStyle(
                          fontSize: r.scale(14),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: r.scale(3)),
                      Text(
                        'Choose from gallery or take a photo, then crop',
                        style: TextStyle(
                          fontSize: r.scale(11),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      CappedMemoryImage(bytes: image),
                      Positioned(
                        right: r.scale(8),
                        bottom: r.scale(8),
                        child: Row(
                          children: [
                            _MealImageAction(
                              icon: Icons.photo_camera_outlined,
                              tooltip: 'Change meal photo',
                              onTap: onPick,
                            ),
                            SizedBox(width: r.scale(6)),
                            _MealImageAction(
                              icon: Icons.delete_outline_rounded,
                              tooltip: 'Remove meal photo',
                              onTap: onRemove,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _MealImageAction extends StatelessWidget {
  const _MealImageAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.62),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.title,
  });

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.scale(16)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(r.scale(20)),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                fontSize: r.scale(16),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: r.scale(12)),
          ],
          child,
        ],
      ),
    );
  }
}

class _EmptyIngredientsHint extends StatelessWidget {
  const _EmptyIngredientsHint({required this.r});

  final Responsive r;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: r.scale(20),
        horizontal: r.scale(12),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            Icons.restaurant_rounded,
            size: r.scale(32),
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          SizedBox(height: r.scale(8)),
          Text(
            'No foods added yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: r.scale(14),
            ),
          ),
          SizedBox(height: r.scale(4)),
          Text(
            'Search above and tap a food to build your meal.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(12),
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSearchResultsCreateFoodHint extends StatelessWidget {
  const _NoSearchResultsCreateFoodHint({
    required this.r,
    required this.query,
    required this.onCreateFood,
  });

  final Responsive r;
  final String query;
  final VoidCallback onCreateFood;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(r.scale(14)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SizedBox(
              width: r.scale(120, tablet: 140),
              height: r.scale(120, tablet: 140),
              child: NoResultsIllustration(
                maxSize: r.scale(120, tablet: 140),
                minSize: 72,
              ),
            ),
          ),
          Text(
            'No foods found for “$query”',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: r.scale(14),
            ),
          ),
          SizedBox(height: r.scale(6)),
          Text(
            'Can’t find it? Create your own food and add it to this meal.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: r.scale(12),
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: r.scale(12)),
          FilledButton.icon(
            onPressed: onCreateFood,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Create My Food'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: r.scale(12)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.item,
    required this.onCustomize,
    required this.onRemove,
  });

  final SavedMealItem item;
  final VoidCallback onCustomize;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final carbs = item.carbs.round();
    final protein = item.protein.round();
    final fat = item.fat.round();

    return Padding(
      padding: EdgeInsets.only(bottom: r.scale(8)),
      child: Container(
        padding: EdgeInsets.all(r.scale(12)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FoodEmojiAvatar(
                  emoji: item.food.emoji,
                  imageUrl: item.food.imageUrl,
                  size: r.scale(42),
                ),
                SizedBox(width: r.scale(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.food.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: r.scale(15),
                          height: 1.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: r.scale(4)),
                      Text(
                        'Serving · ${item.servingDescription}',
                        style: TextStyle(
                          fontSize: r.scale(11.5),
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onCustomize,
                  tooltip: 'Customize nutrition',
                  icon: Icon(Icons.tune_rounded, size: r.scale(19)),
                  color: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.all(r.scale(6)),
                  constraints: BoxConstraints(
                    minWidth: r.scale(34),
                    minHeight: r.scale(34),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Remove food',
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: r.scale(20),
                  ),
                  color: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.all(r.scale(6)),
                  constraints: BoxConstraints(
                    minWidth: r.scale(34),
                    minHeight: r.scale(34),
                  ),
                ),
              ],
            ),
            SizedBox(height: r.scale(10)),
            Container(
              padding: EdgeInsets.symmetric(vertical: r.scale(9)),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _IngredientNutritionValue(
                      label: 'Calories',
                      value: '${item.calories}',
                      unit: 'kcal',
                      color: AppColors.primary,
                    ),
                  ),
                  const _IngredientNutritionDivider(),
                  Expanded(
                    child: _IngredientNutritionValue(
                      label: 'Carbs',
                      value: '$carbs',
                      unit: 'g',
                      color: _MealMacroColors.carbs,
                    ),
                  ),
                  const _IngredientNutritionDivider(),
                  Expanded(
                    child: _IngredientNutritionValue(
                      label: 'Protein',
                      value: '$protein',
                      unit: 'g',
                      color: _MealMacroColors.protein,
                    ),
                  ),
                  const _IngredientNutritionDivider(),
                  Expanded(
                    child: _IngredientNutritionValue(
                      label: 'Fat',
                      value: '$fat',
                      unit: 'g',
                      color: _MealMacroColors.fat,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientNutritionValue extends StatelessWidget {
  const _IngredientNutritionValue({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: r.scale(10),
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: r.scale(3)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: r.scale(13),
                fontWeight: FontWeight.w800,
                color: color,
              ),
              children: [
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: r.scale(9),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IngredientNutritionDivider extends StatelessWidget {
  const _IngredientNutritionDivider();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    return Container(
      width: 1,
      height: r.scale(28),
      color: AppColors.border,
    );
  }
}

class _ShareInlineToggle extends StatelessWidget {
  const _ShareInlineToggle({
    required this.visibility,
    required this.onChanged,
  });

  final MealShareVisibility visibility;
  final ValueChanged<MealShareVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.all(r.scale(3)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(r.scale(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ShareChip(
            label: 'Only me',
            selected: visibility == MealShareVisibility.onlyMe,
            onTap: () => onChanged(MealShareVisibility.onlyMe),
          ),
          _ShareChip(
            label: 'Public',
            selected: visibility == MealShareVisibility.public,
            onTap: () => onChanged(MealShareVisibility.public),
          ),
        ],
      ),
    );
  }
}

class _ShareChip extends StatelessWidget {
  const _ShareChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Material(
      color: selected ? AppColors.card : Colors.transparent,
      borderRadius: BorderRadius.circular(r.scale(9)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.scale(9)),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: r.scale(12),
            vertical: r.scale(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: r.scale(12),
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.selectedMeal,
    required this.isSaving,
    required this.isEditing,
    required this.onSaveAndLog,
    required this.onSaveOnly,
  });

  final String selectedMeal;
  final bool isSaving;
  final bool isEditing;
  final VoidCallback onSaveAndLog;
  final VoidCallback onSaveOnly;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Container(
      padding: EdgeInsets.fromLTRB(
        r.pagePadding.left,
        r.scale(12),
        r.pagePadding.right,
        r.scale(12) + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.contentMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: r.scale(50),
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSaving ? null : onSaveAndLog,
                  child: isSaving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: r.scale(18),
                              height: r.scale(18),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.onPrimary,
                              ),
                            ),
                            SizedBox(width: r.scale(10)),
                            Text(
                              'Saving...',
                              style: TextStyle(fontSize: r.scale(14)),
                            ),
                          ],
                        )
                      : Text(
                          isEditing
                              ? 'Update & log to $selectedMeal'
                              : 'Save & log to $selectedMeal',
                          style: TextStyle(fontSize: r.scale(14)),
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
              TextButton(
                onPressed: isSaving ? null : onSaveOnly,
                child: Text(
                  isEditing
                      ? 'Update in My Meals only'
                      : 'Save to My Meals only',
                  style: TextStyle(fontSize: r.scale(13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
