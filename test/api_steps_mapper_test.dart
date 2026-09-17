import 'package:calorie_ai/models/api_steps_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiStepsMapper', () {
    test('parses single day GET payload', () {
      final result = ApiStepsMapper.fetchResultFromResponse({
        'success': true,
        'data': {
          'id': 'abc',
          'date': '2026-03-26',
          'steps': 8420,
          'caloriesBurned': 337,
        },
      });

      expect(result.entries, hasLength(1));
      expect(result.entries.first.steps, 8420);
      expect(result.entries.first.caloriesBurned, 337);
      expect(result.stepsFor(DateTime(2026, 3, 26)), 8420);
    });

    test('computes caloriesBurned when GET entry omits it', () {
      final result = ApiStepsMapper.fetchResultFromResponse({
        'success': true,
        'message': 'Success',
        'data': {
          'entries': [
            {
              'id': '6aabc45fae7ca2804552d388',
              'date': '2026-09-17',
              'steps': 1962,
              'timezone': 'Asia/Kolkata',
            },
          ],
          'meta': {
            'page': 1,
            'limit': 50,
            'total': 1,
            'totalPages': 1,
            'totalSteps': 1962,
            'totalCaloriesBurned': 0,
            'date': '2026-09-17',
          },
        },
      }, fallbackDate: DateTime(2026, 9, 17));

      expect(result.entries, hasLength(1));
      expect(result.entries.first.steps, 1962);
      expect(result.entries.first.caloriesBurned, isNull);
      expect(result.entries.first.resolvedCaloriesBurned, 78);
      expect(result.hasServerCalories(DateTime(2026, 9, 17)), isFalse);
      expect(result.caloriesFor(DateTime(2026, 9, 17)), 78);
    });

    test('parses POST Steps logged response', () {
      final response = ApiStepsMapper.logResponseFromJson({
        'success': true,
        'message': 'Steps logged',
        'data': {
          'id': 'step_1',
          'date': '2026-03-26',
          'steps': 8420,
          'caloriesBurned': 337,
          'timezone': 'Asia/Kolkata',
        },
      });

      expect(response.entry, isNotNull);
      expect(response.entry!.id, 'step_1');
      expect(response.entry!.steps, 8420);
      expect(response.entry!.caloriesBurned, 337);
      expect(response.entry!.date, DateTime(2026, 3, 26));
    });

    test('builds POST body with date and timezone', () {
      final body = ApiStepsMapper.requestBody(
        steps: 1000,
        caloriesBurned: 40,
        date: DateTime(2026, 3, 26),
        timezone: 'Asia/Kolkata',
      );

      expect(body['steps'], 1000);
      expect(body['caloriesBurned'], 40);
      expect(body['date'], '2026-03-26');
      expect(body['timezone'], 'Asia/Kolkata');
    });
  });
}
