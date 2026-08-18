import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/food_controller.dart';
import '../../core/app_snackbar.dart';
import '../../models/custom_meal_preset.dart';
import '../../models/meal_type.dart';
import '../../routes/app_routes.dart';
import '../app_bottom_sheet.dart';
import '../log_preview_sheet.dart';

void showCreateMealSheet(BuildContext context, {String? initialMeal}) {
  Get.toNamed(
    AppRoutes.createMeal,
    arguments: initialMeal ?? Get.find<FoodController>().selectedMeal.value,
  );
}

Future<void> showCustomMealLogSheet(
  BuildContext context, {
  required CustomMealPreset preset,
}) {
  var selectedMeal = preset.meal;
  if (!MealType.all.contains(selectedMeal)) {
    selectedMeal = MealType.breakfast;
  }

  final resolved = Get.isRegistered<FoodController>()
      ? Get.find<FoodController>().withItemPhotos(preset)
      : preset;

  return showAppBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      return _CustomMealLogSheet(preset: resolved, initialMeal: selectedMeal);
    },
  );
}

class _CustomMealLogSheet extends StatefulWidget {
  const _CustomMealLogSheet({required this.preset, required this.initialMeal});

  final CustomMealPreset preset;
  final String initialMeal;

  @override
  State<_CustomMealLogSheet> createState() => _CustomMealLogSheetState();
}

class _CustomMealLogSheetState extends State<_CustomMealLogSheet> {
  late String _selectedMeal = widget.initialMeal;
  late CustomMealPreset _preset = widget.preset;

  @override
  void initState() {
    super.initState();
    unawaited(_hydratePhotos());
  }

  Future<void> _hydratePhotos() async {
    if (!Get.isRegistered<FoodController>()) return;
    final updated = await Get.find<FoodController>().hydrateCustomMealPhotos(
      _preset,
    );
    if (!mounted) return;
    setState(() => _preset = updated);
  }

  void _log() {
    Get.find<FoodController>().logCustomMealPreset(
      _preset,
      meal: _selectedMeal,
    );
    Navigator.pop(context);
    AppSnackbar.success(
      '${_preset.name} added to $_selectedMeal.',
      title: 'Logged',
    );
  }

  @override
  Widget build(BuildContext context) {
    final foodCount = _preset.items.length;
    return LogPreviewBody(
      title: _preset.name,
      subtitle: foodCount == 1 ? '1 food' : '$foodCount foods',
      visibility: _preset.visibility,
      calories: _preset.totalCalories,
      items: _preset.items,
      selectedMeal: _selectedMeal,
      imageBytes: _preset.imageBytes,
      imageUrl: _preset.imageUrl,
      onMealSelected: (meal) => setState(() => _selectedMeal = meal),
      onLog: _log,
    );
  }
}
