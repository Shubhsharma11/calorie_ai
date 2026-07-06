import 'package:calorie_ai/widgets/epeat_yesterday_meal_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/food_controller.dart';
import 'package:intl/intl.dart';

class RepeatYesterdayBottomSheet extends StatelessWidget {
  const RepeatYesterdayBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FoodController>();
    final meals = controller.getYesterdayMeals();
    for (final meal in meals) {
      debugPrint(meal.meal);
    }
    final totalCalories = meals.fold<int>(
      0,
      (sum, meal) => sum + meal.calories,
    );
    final breakfast = meals.where((meal) => meal.meal == 'Breakfast').toList();

    final lunch = meals.where((meal) => meal.meal == 'Lunch').toList();

    final snacks = meals.where((meal) => meal.meal == 'Snacks').toList();

    final dinner = meals.where((meal) => meal.meal == 'Dinner').toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.80,
      minChildSize: 0.60,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),

              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),

              const SizedBox(height: 20),
              Column(
  children: [
    const Text(
      "Yesterday",
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
      ),
    ),

    const SizedBox(height: 18),

    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
width: MediaQuery.of(context).size.width * 0.42,
  child:  _infoCard(
  iconPath: "assets/image/food.png",
            value: "${meals.length}",
            label: "Meals",
          ),
        ),

        const SizedBox(width: 14),

        SizedBox(
width: MediaQuery.of(context).size.width * 0.42,
  child: _infoCard(
  iconPath: "assets/image/fire.png",
           value: NumberFormat('#,###').format(totalCalories),
            label: "kcal",
          ),
        ),
      ],
    ),
  ],
),

              const SizedBox(height: 16),

              Obx(() {
                final allSelected =
                    controller.selectedYesterdayMealCount == meals.length &&
                    meals.isNotEmpty;

                return CheckboxListTile(
                  title: const Text(
                    "Select All",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  value: allSelected,
                  onChanged: (value) {
                    if (value == true) {
                      controller.selectAllYesterdayMeals();
                    } else {
                      controller.unselectAllYesterdayMeals();
                    }
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                );
              }),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    if (breakfast.isNotEmpty)
                      _mealSection(controller, "Breakfast", "🍳", breakfast),

                    _mealSection(controller, "Lunch", "🥗", lunch),

                    _mealSection(controller, "Snacks", "🍎", snacks),

                    _mealSection(controller, "Dinner", "🍽", dinner),

                    
                  ],
                ),
              ),
              

              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Obx(
                          () => ElevatedButton(
                            onPressed:
                                controller.selectedYesterdayMealCount == 0
                                ? null
                                : () {
                                    controller.copySelectedYesterdayMeals();
                                    Navigator.pop(context);
                                  },
                            child: Text(
                              "Add ${controller.selectedYesterdayMealCount} "
                              "Meal${controller.selectedYesterdayMealCount == 1 ? "" : "s"}",
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mealSection(
    FoodController controller,
    String title,
    String emoji,
    List meals,
  ) 
  
  
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        ...meals.map(
          (meal) => Obx(
            () => RepeatYesterdayMealCard(
              title: meal.food.name,
              subtitle: '${meal.grams} g • ${meal.calories} kcal',
              selected: controller.isYesterdayMealSelected(meal.id),
              onTap: () {
                controller.toggleYesterdayMeal(meal.id);
              },
            ),
          ),
        ),
      ],
    );
  }


  Widget _infoCard({
 required String iconPath,
  required String value,
  required String label,
}) {
  return Container(
    height: 66,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.grey.shade300,
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
       Image.asset(
  iconPath,
  width: 50,
  height: 50,
    fit: BoxFit.contain,
      filterQuality: FilterQuality.high,

),

        const SizedBox(width: 10),

      Row(
  children: [
    Text(
      value,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    const SizedBox(width: 6),
    Text(
      label,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black87,
        fontWeight: FontWeight.w500,
      ),
    ),
  ],
)
      ],
    ),
  );
}
}
