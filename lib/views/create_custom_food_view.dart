import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/food_controller.dart';
import '../core/app_snackbar.dart';
import '../core/responsive.dart';
import '../models/custom_food_preset.dart';
import '../models/food_item.dart';
import '../models/meal_type.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/filter_chip_pill.dart';
import '../widgets/responsive_page.dart';

class CreateCustomFoodView extends StatefulWidget {
  const CreateCustomFoodView({super.key});

  @override
  State<CreateCustomFoodView> createState() => _CreateCustomFoodViewState();
}

class _CreateCustomFoodViewState extends State<CreateCustomFoodView> {
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

  final _nameController = TextEditingController();
  final _servingController = TextEditingController(text: '100');
  final _caloriesController = TextEditingController();
  final _carbsController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  final _imagePicker = ImagePicker();
  late final FoodController _food = Get.find<FoodController>();
  CustomFoodPreset? _editingPreset;
  Uint8List? _foodImageBytes;
  String? _errorText;
  bool _isSaving = false;
  String _servingUnit = 'g';
  late String _selectedMeal;

  bool get _isEditing => _editingPreset != null;
  double get _nutritionBasisQuantity =>
      _servingUnit == 'g' || _servingUnit == 'ml' ? 100 : 1;

  String get _selectedUnitLabel => switch (_servingUnit) {
        'tbsp' => 'tbsp',
        'g' => 'g',
        'ml' => 'ml',
        _ => _servingUnits[_servingUnit] ?? _servingUnit,
      };

  @override
  void initState() {
    super.initState();
    _selectedMeal = _food.selectedMeal.value;
    final args = Get.arguments;
    if (args is CustomFoodPreset) {
      _editingPreset = args;
      _servingUnit =
          _servingUnits.containsKey(args.servingUnit) ? args.servingUnit : 'g';
      _nameController.text = args.food.name;
      _servingController.text = _format(args.displayedServingQuantity);
      _caloriesController.text = _format(args.food.caloriesPer100g.toDouble());
      _carbsController.text = _format(args.food.carbs);
      _proteinController.text = _format(args.food.protein);
      _fatController.text = _format(args.food.fat);
      _foodImageBytes = args.imageBytes;
    }
  }

  Future<void> _showFoodImageOptions() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
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
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 95,
      );
      if (image == null || !mounted) return;

      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop food photo',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            statusBarLight: false,
            activeControlsWidgetColor: AppColors.primary,
            backgroundColor: Colors.black,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
          IOSUiSettings(
            title: 'Crop food photo',
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
        ],
      );
      if (cropped == null || !mounted) return;

      final bytes = await cropped.readAsBytes();
      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _foodImageBytes = bytes);
      });
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(
        'The photo could not be selected. Please try again.',
        title: 'Photo unavailable',
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingController.dispose();
    _caloriesController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

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
                    final isSelected = entry.key == _servingUnit;
                    return InkWell(
                      onTap: () => Navigator.pop(sheetContext, entry.key),
                      borderRadius: BorderRadius.circular(r.scale(10)),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(r.scale(10)),
                          border: Border.all(
                            color: isSelected
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
                            color: isSelected
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
      _servingController.text =
          selected == 'g' || selected == 'ml' ? '100' : '1';
      _caloriesController.clear();
      _carbsController.clear();
      _proteinController.clear();
      _fatController.clear();
      _errorText = null;
    });
  }

  Future<void> _save({required bool logAfterSave}) async {
    final name = _nameController.text.trim();
    final servingQuantity =
        double.tryParse(_servingController.text.trim()) ?? 0;
    final canonicalGrams =
        _servingUnit == 'g' ? servingQuantity.round() : 100;
    final calories = int.tryParse(
          _caloriesController.text.trim().split('.').first,
        ) ??
        double.tryParse(_caloriesController.text.trim())?.round() ??
        0;
    final carbs = double.tryParse(_carbsController.text.trim()) ?? 0;
    final protein = double.tryParse(_proteinController.text.trim()) ?? 0;
    final fat = double.tryParse(_fatController.text.trim()) ?? 0;

    String? error;
    if (name.isEmpty) {
      error = 'Enter the food name.';
    } else if (servingQuantity <= 0 || servingQuantity > 5000) {
      error = 'Serving quantity must be greater than zero.';
    } else if (calories <= 0) {
      error = 'Enter calories for this amount.';
    } else if (calories > 10000) {
      error = 'Calories must be 10,000 or less.';
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

    final customFood = FoodItem(
      name: name,
      caloriesPer100g: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      emoji: '🥣',
    );
    final preset = CustomFoodPreset(
      id: _editingPreset?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      food: customFood,
      defaultGrams: canonicalGrams,
      createdAt: _editingPreset?.createdAt ?? DateTime.now(),
      servingQuantity: servingQuantity,
      servingUnit: _servingUnit,
      nutritionBasisQuantity: _nutritionBasisQuantity,
      imageBytes: _foodImageBytes,
    );

    setState(() => _isSaving = true);
    try {
      final saved = await _food.saveCustomFoodPreset(
        preset,
        mealtime: _selectedMeal,
        isUpdate: _isEditing,
      );
      if (logAfterSave) {
        _food.logMyFood(saved, meal: _selectedMeal);
      }
      if (!mounted) return;
      Get.back<void>();
      AppSnackbar.success(
        logAfterSave
            ? '$name saved and logged to $_selectedMeal.'
            : '$name saved to My Food.',
        title: logAfterSave ? 'Saved & logged' : 'Saved',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      appBar: AppAppBar(
        title: _isEditing ? 'Edit My Food' : 'Create My Food',
      ),
      body: Column(
        children: [
          Expanded(
            child: ResponsivePage(
              scrollable: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    title: 'Food details',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FoodImagePicker(
                          imageBytes: _foodImageBytes,
                          onPick: _isSaving ? () {} : _showFoodImageOptions,
                          onRemove: () =>
                              setState(() => _foodImageBytes = null),
                        ),
                        SizedBox(height: r.scale(14)),
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => _clearError(),
                          decoration: _softFieldDecoration(
                            r,
                            hintText: 'e.g. Homemade dal',
                          ),
                        ),
                        SizedBox(height: r.scale(12)),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _servingController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d{0,4}([.]\d?)?'),
                                  ),
                                ],
                                onChanged: (_) => _clearError(),
                                decoration: _softFieldDecoration(
                                  r,
                                  hintText: 'Quantity',
                                ),
                              ),
                            ),
                            SizedBox(width: r.scale(10)),
                            Expanded(
                              flex: 2,
                              child: InkWell(
                                onTap: _selectServingUnit,
                                borderRadius: BorderRadius.circular(14),
                                child: InputDecorator(
                                  decoration: _softFieldDecoration(
                                    r,
                                    hintText: 'Unit',
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedUnitLabel,
                                          style: TextStyle(
                                            fontSize: r.scale(13),
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
                      ],
                    ),
                  ),
                  SizedBox(height: r.scale(12)),
                  _SectionCard(
                    title: 'Nutrition',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Values for ${_format(_nutritionBasisQuantity)} '
                          '$_selectedUnitLabel',
                          style: TextStyle(
                            fontSize: r.scale(12),
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: r.scale(12)),
                        _NutrientInput(
                          label: 'Calories',
                          controller: _caloriesController,
                          color: AppColors.primary,
                          suffixText: 'kcal',
                          maxIntegerDigits: 4,
                          onChanged: _clearError,
                        ),
                        SizedBox(height: r.scale(10)),
                        Row(
                          children: [
                            Expanded(
                              child: _NutrientInput(
                                label: 'Carbs',
                                controller: _carbsController,
                                color: const Color(0xFF2196F3),
                                onChanged: _clearError,
                              ),
                            ),
                            SizedBox(width: r.scale(8)),
                            Expanded(
                              child: _NutrientInput(
                                label: 'Protein',
                                controller: _proteinController,
                                color: const Color(0xFF4CAF50),
                                onChanged: _clearError,
                              ),
                            ),
                            SizedBox(width: r.scale(8)),
                            Expanded(
                              child: _NutrientInput(
                                label: 'Fat',
                                controller: _fatController,
                                color: const Color(0xFF9C27B0),
                                onChanged: _clearError,
                              ),
                            ),
                          ],
                        ),
                        if (_errorText != null) ...[
                          SizedBox(height: r.scale(12)),
                          Text(
                            _errorText!,
                            style: TextStyle(
                              fontSize: r.scale(12),
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: r.scale(12)),
                  _SectionCard(
                    title: 'Log to',
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: MealType.all.map((meal) {
                          return Padding(
                            padding: EdgeInsets.only(right: r.scale(8)),
                            child: FilterChipPill(
                              label: meal,
                              selected: _selectedMeal == meal,
                              onTap: () =>
                                  setState(() => _selectedMeal = meal),
                              fontSize: r.scale(12),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: r.scale(8)),
                ],
              ),
            ),
          ),
          _BottomActions(
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

  InputDecoration _softFieldDecoration(
    Responsive r, {
    required String hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.45),
        ),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: r.scale(16),
        vertical: r.scale(14),
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

class _FoodImagePicker extends StatelessWidget {
  const _FoodImagePicker({
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
                        'Add food photo',
                        style: TextStyle(
                          fontSize: r.scale(14),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: r.scale(3)),
                      Text(
                        'Gallery or camera · optional',
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
                      Image.memory(
                        image,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                      Positioned(
                        right: r.scale(8),
                        bottom: r.scale(8),
                        child: Row(
                          children: [
                            _FoodImageAction(
                              icon: Icons.photo_camera_outlined,
                              tooltip: 'Change food photo',
                              onTap: onPick,
                            ),
                            SizedBox(width: r.scale(6)),
                            _FoodImageAction(
                              icon: Icons.delete_outline_rounded,
                              tooltip: 'Remove food photo',
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

class _FoodImageAction extends StatelessWidget {
  const _FoodImageAction({
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
        iconSize: 18,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
    this.suffixText = 'g',
    this.maxIntegerDigits = 3,
  });

  final String label;
  final TextEditingController controller;
  final Color color;
  final VoidCallback onChanged;
  final String suffixText;
  final int maxIntegerDigits;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp('^\\d{0,$maxIntegerDigits}([.]\\d?)?'),
        ),
      ],
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        suffixText: suffixText,
        labelStyle: TextStyle(color: color),
        floatingLabelStyle: TextStyle(color: color),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color.withValues(alpha: 0.45)),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
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
                      ? 'Update in My Food only'
                      : 'Save to My Food only',
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
