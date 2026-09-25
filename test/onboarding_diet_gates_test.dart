import 'package:calorie_ai/models/diet_type.dart';
import 'package:calorie_ai/models/lifestyle_habits.dart';
import 'package:calorie_ai/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DietTypeOnboardingGates', () {
    test('skips meat question for vegetarian-style diets', () {
      for (final diet in [
        DietType.vegetarian,
        DietType.vegan,
        DietType.eggetarian,
        DietType.lactoVegetarian,
        DietType.lactoOvoVegetarian,
        DietType.pescatarian,
      ]) {
        expect(diet.asksMeatPreferences, isFalse, reason: diet.name);
      }
    });

    test('asks meat question only for land-meat diets', () {
      expect(DietType.nonVegetarian.asksMeatPreferences, isTrue);
      expect(DietType.flexitarian.asksMeatPreferences, isTrue);
    });

    test('implies fish for pescatarian and vegetarian for plant diets', () {
      expect(DietType.pescatarian.impliedMeatPreferences, ['fish']);
      expect(DietType.vegan.impliedMeatPreferences, ['vegetarian']);
      expect(DietType.vegetarian.impliedMeatPreferences, ['vegetarian']);
    });
  });

  group('LifestyleHabitOptions diet filters', () {
    test('hides meat/seafood avoid chips for vegetarians', () {
      final values = LifestyleHabitOptions.foodsToAvoidFor(DietType.vegetarian)
          .map((o) => o.value)
          .toSet();

      expect(values.contains('none'), isTrue);
      expect(values.contains('spicy'), isTrue);
      expect(values.contains('red_meat'), isFalse);
      expect(values.contains('pork'), isFalse);
      expect(values.contains('seafood'), isFalse);
      expect(values.contains('eggs'), isTrue);
      expect(values.contains('dairy'), isTrue);
    });

    test('hides dairy and eggs avoid chips for vegans', () {
      final values = LifestyleHabitOptions.foodsToAvoidFor(DietType.vegan)
          .map((o) => o.value)
          .toSet();

      expect(values.contains('dairy'), isFalse);
      expect(values.contains('eggs'), isFalse);
      expect(values.contains('red_meat'), isFalse);
      expect(values.contains('spicy'), isTrue);
    });

    test('filters food preferences and allergies for vegan', () {
      final foods = LifestyleHabitOptions.foodPreferencesFor(DietType.vegan)
          .map((o) => o.value)
          .toSet();
      expect(foods.contains('eggs'), isFalse);
      expect(foods.contains('milk'), isFalse);
      expect(foods.contains('seafood'), isFalse);
      expect(foods.contains('tofu'), isTrue);

      final allergies = LifestyleHabitOptions.foodAllergiesFor(DietType.vegan)
          .map((o) => o.value)
          .toSet();
      expect(allergies.contains('fish'), isFalse);
      expect(allergies.contains('egg_protein'), isFalse);
      expect(allergies.contains('lactose'), isFalse);
      expect(allergies.contains('nuts'), isTrue);
    });

    test('meat options exclude vegetarian chip for meat-eaters', () {
      final values =
          LifestyleHabitOptions.meatPreferencesFor(DietType.nonVegetarian)
              .map((o) => o.value)
              .toSet();
      expect(values.contains('vegetarian'), isFalse);
      expect(values.contains('chicken'), isTrue);
      expect(values.contains('fish'), isTrue);
    });
  });

  group('UserModel.applyDietTypeConstraints', () {
    test('clears meat selections when switching to vegetarian', () {
      final user = UserModel()
        ..dietType = DietType.vegetarian
        ..meatPreferences = ['chicken', 'beef']
        ..foodPreferences = ['eggs', 'seafood', 'tofu', 'nuts', 'avocados']
        ..foodAllergies = ['Fish', 'Nuts']
        ..foodsToAvoid = 'Red meat, Spicy food, Seafood';

      user.applyDietTypeConstraints();

      expect(user.meatPreferences, ['vegetarian']);
      expect(user.foodPreferences, ['eggs', 'tofu', 'nuts', 'avocados']);
      expect(user.foodAllergies, ['Nuts']);
      expect(user.foodsToAvoid, 'Spicy food');
    });

    test('sets fish for pescatarian and keeps seafood prefs', () {
      final user = UserModel()
        ..dietType = DietType.pescatarian
        ..meatPreferences = ['chicken']
        ..foodPreferences = ['seafood', 'eggs', 'tofu'];

      user.applyDietTypeConstraints();

      expect(user.meatPreferences, ['fish']);
      expect(user.foodPreferences, ['seafood', 'eggs', 'tofu']);
    });
  });
}
