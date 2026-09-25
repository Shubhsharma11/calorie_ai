import 'package:calorie_ai/models/diet_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MealsPerDayOptions slots', () {
    test('3 meals = Breakfast + Lunch + Dinner', () {
      expect(
        MealsPerDayOptions.slotsFor(3),
        ['Breakfast', 'Lunch', 'Dinner'],
      );
      expect(
        MealsPerDayOptions.structureLabel(3),
        'Breakfast + Lunch + Dinner',
      );
    });

    test('4 meals = Breakfast + Lunch + Snack + Dinner', () {
      expect(
        MealsPerDayOptions.slotsFor(4),
        ['Breakfast', 'Lunch', 'Snack', 'Dinner'],
      );
      expect(
        MealsPerDayOptions.structureLabel(4),
        'Breakfast + Lunch + Snack + Dinner',
      );
    });

    test(
      '5 meals = Breakfast + Morning Snack + Lunch + Evening Snack + Dinner',
      () {
        expect(
          MealsPerDayOptions.slotsFor(5),
          [
            'Breakfast',
            'Morning Snack',
            'Lunch',
            'Evening Snack',
            'Dinner',
          ],
        );
        expect(
          MealsPerDayOptions.structureLabel(5),
          'Breakfast + Morning Snack + Lunch + Evening Snack + Dinner',
        );
      },
    );

    test('sortBySlotOrder follows meals-per-day layout', () {
      final unsorted = ['Dinner', 'Morning Snack', 'Breakfast', 'Lunch'];
      final sorted = MealsPerDayOptions.sortBySlotOrder(
        unsorted,
        5,
        (s) => s,
      );
      expect(sorted, [
        'Breakfast',
        'Morning Snack',
        'Lunch',
        'Dinner',
      ]);
    });
  });
}
