import 'package:flutter/material.dart';

import '../core/food_serving.dart';
import '../models/food_item.dart';
import '../theme/app_colors.dart';

class ServingQuantityStepper extends StatelessWidget {
  const ServingQuantityStepper({
    super.key,
    required this.food,
    required this.quantity,
    required this.onChanged,
    this.dense = false,
    this.showTitle = true,
  });

  final FoodItem food;
  final double quantity;
  final ValueChanged<double> onChanged;
  final bool dense;
  final bool showTitle;

  String get _unit => food.servingUnit;

  double get _min => FoodServing.quantityMin(_unit);

  String _unitTitle(String unit) {
    final normalized = FoodServing.normalizeUnit(unit);
    if (normalized.isEmpty) return 'Serving';
    if (normalized == 'g' ||
        normalized == 'ml' ||
        normalized == 'tbsp' ||
        normalized == 'tsp') {
      return normalized;
    }
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final grams = food.gramsForServings(quantity);
    final label = FoodServing.formatVisible(
      quantity: quantity,
      unit: food.servingUnit,
    );

    return Column(
      children: [
        if (showTitle) ...[
          Text(
            'Quantity · ${_unitTitle(food.servingUnit)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: dense ? 13 : 14,
            ),
          ),
          SizedBox(height: dense ? 4 : 8),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: quantity > _min
                  ? () => onChanged(
                      FoodServing.steppedQuantity(
                        unit: _unit,
                        quantity: quantity,
                        direction: -1,
                      ),
                    )
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: dense ? 20 : 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed: () => onChanged(
                FoodServing.steppedQuantity(
                  unit: _unit,
                  quantity: quantity,
                  direction: 1,
                ),
              ),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        if (FoodServing.isHouseholdUnit(_unit) && grams > 1)
          Text(
            '$grams g',
            style: TextStyle(
              fontSize: dense ? 13 : 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}
