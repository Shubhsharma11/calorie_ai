import 'package:calorie_ai/models/notification_model.dart';
import 'package:calorie_ai/models/notification_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationType.fromValue', () {
    test('maps lunch aliases to lunchReminder', () {
      expect(
        NotificationType.fromValue('lunch_reminder'),
        NotificationType.lunchReminder,
      );
      expect(NotificationType.fromValue('lunch'), NotificationType.lunchReminder);
      expect(
        NotificationType.fromValue('Lunch Time'),
        NotificationType.lunchReminder,
      );
    });
  });

  group('NotificationType.resolve', () {
    test('infers lunch from mealTime on a generic meal reminder', () {
      expect(
        NotificationType.resolve(
          type: 'meal_reminder',
          data: const {'mealTime': 'lunch'},
        ),
        NotificationType.lunchReminder,
      );
    });

    test('infers lunch from title when type is missing', () {
      expect(
        NotificationType.resolve(title: 'Lunch time'),
        NotificationType.lunchReminder,
      );
    });

    test('does not override a non-meal type from title text', () {
      expect(
        NotificationType.resolve(
          type: 'water_reminder',
          title: 'Drink water before lunch',
        ),
        NotificationType.waterReminder,
      );
    });
  });

  group('NotificationModel.fromJson', () {
    test('uses nested type and lunch title', () {
      final item = NotificationModel.fromJson({
        'id': '1',
        'title': 'Lunch time',
        'body': 'Log your lunch and keep your calories balanced.',
        'type': 'meal_reminder',
        'data': {'mealTime': 'lunch'},
      });
      expect(item.type, NotificationType.lunchReminder);
      expect(item.targetMeal, 'Lunch');
    });

    test('reads notification_type when type is absent', () {
      final item = NotificationModel.fromJson({
        'id': '2',
        'title': 'Lunch time',
        'notification_type': 'lunch_reminder',
      });
      expect(item.type, NotificationType.lunchReminder);
      expect(item.targetMeal, 'Lunch');
    });

    test('targetMeal prefers payload mealTime over generic reminder type', () {
      final item = NotificationModel.fromJson({
        'id': '3',
        'type': 'meal_reminder',
        'data': {'mealTime': 'dinner'},
      });
      expect(item.targetMeal, 'Dinner');
    });
  });

  group('NotificationType.targetMeal', () {
    test('maps meal reminder types to meal slots', () {
      expect(
        NotificationType.breakfastReminder.targetMeal,
        'Breakfast',
      );
      expect(NotificationType.lunchReminder.targetMeal, 'Lunch');
      expect(NotificationType.dinnerReminder.targetMeal, 'Dinner');
      expect(NotificationType.waterReminder.targetMeal, isNull);
    });
  });
}
