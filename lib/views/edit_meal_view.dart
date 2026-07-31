import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/food_controller.dart';
import '../models/food_item.dart';
import '../models/meal_entry.dart';
import '../models/meal_type.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
import '../widgets/confirm_delete_sheet.dart';
import '../widgets/delete_lottie.dart';
import '../widgets/food_emoji_avatar.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_page.dart';

class EditMealView extends StatefulWidget {
  const EditMealView({super.key});

  static const meals = MealType.all;

  @override
  State<EditMealView> createState() => _EditMealViewState();
}

class _EditMealViewState extends State<EditMealView> {
  late final FoodController _food = Get.find<FoodController>();
  late MealEntry _entry;
  late int _grams;
  late String _meal;
  bool _deleting = false;

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
      _grams = 100;
      _meal = MealType.breakfast;
      return;
    }
    _entry = args;
    _grams = _entry.grams;
    _meal = MealType.all.contains(_entry.meal)
        ? _entry.meal
        : MealType.breakfast;
  }

  @override
  Widget build(BuildContext context) {
    final calories = _entry.food.caloriesForGrams(_grams);

    return Scaffold(
      appBar: AppAppBar(
        title: 'Edit Food',
        actions: [
          if (!_deleting)
            IconButton(
              onPressed: _startDelete,
              icon: Icon(Icons.delete_outline, color: AppColors.error),
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
                      emoji: _entry.food.emoji,
                      imageUrl: _entry.food.imageUrl,
                      size: 96,
                      fontSize: 52,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _entry.food.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$calories kcal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: _meal,
                    decoration: const InputDecoration(labelText: 'Meal'),
                    items: EditMealView.meals
                        .map(
                          (m) => DropdownMenuItem(value: m, child: Text(m)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _meal = v);
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text('Quantity (grams)'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _grams > 50
                            ? () => setState(() => _grams -= 50)
                            : null,
                        icon: Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '${_grams}g',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _grams += 50),
                        icon: Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  PrimaryButton(label: 'Save Changes', onPressed: _save),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
                ],
              ),
      ),
    );
  }

  Future<void> _save() async {
    final ok = await _food.updateEntry(_entry, grams: _grams, meal: _meal);
    if (!mounted) return;
    if (ok) Get.back();
  }

  Future<void> _startDelete() async {
    if (_deleting) return;

    final confirmed = await showConfirmDeleteSheet(
      context: context,
      title: 'Remove from diary?',
      message:
          '“${_entry.food.name}” will be permanently deleted from your daily log.',
      cancelLabel: 'Keep',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);

    final ok = await _food.deleteMealEntry(_entry);
    if (!mounted) return;

    if (ok) {
      Get.back();
      return;
    }

    setState(() => _deleting = false);
  }
}
