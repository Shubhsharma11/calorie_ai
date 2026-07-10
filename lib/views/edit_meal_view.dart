import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/food_controller.dart';
import '../models/food_item.dart';
import '../models/meal_entry.dart';
import '../models/meal_type.dart';
import '../theme/app_colors.dart';
import '../widgets/app_app_bar.dart';
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
          IconButton(
            onPressed: _delete,
            icon: Icon(Icons.delete_outline, color: AppColors.error),
          ),
        ],
      ),
      body: ResponsivePage(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: FoodEmojiAvatar(
                emoji: _entry.food.emoji,
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
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
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

  void _save() {
    _food.updateEntry(_entry, grams: _grams, meal: _meal);
    Get.back();
  }

  void _delete() {
    _food.removeEntry(_entry);
    Get.back();
  }
}
