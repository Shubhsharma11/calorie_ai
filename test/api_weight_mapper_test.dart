import 'package:calorie_ai/models/api_weight_mapper.dart';
import 'package:calorie_ai/models/meal_entry.dart';
import 'package:calorie_ai/models/weight_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ApiWeightMapper maps paginated weight entries', () {
    final entries = ApiWeightMapper.entriesFromResponse({
      'success': true,
      'data': {
        'entries': [
          {
            'id': 'w-1',
            'weightKg': 70,
            'weightUnit': 'kg',
            'recordedAt': '2026-06-27T08:00:00.000Z',
          },
          {
            'id': 'w-2',
            'weight': 68,
            'recordedAt': '2026-06-29T12:00:00.000Z',
          },
        ],
      },
    });

    expect(entries, hasLength(2));
    expect(entries.first.kg, 70);
    expect(entries.first.date, DateTime(2026, 6, 27));
    expect(entries.last.kg, 68);
    expect(entries.last.id, 'w-2');
  });

  test('collapseToLatestPerDay keeps newest same-day log by createdAt', () {
    final entries = ApiWeightMapper.entriesFromResponse({
      'success': true,
      'data': {
        'entries': [
          {
            'id': 'newest',
            'weightKg': 60,
            'recordedAt': '2026-07-16T12:00:00.000Z',
            'createdAt': '2026-07-16T11:02:57.540Z',
          },
          {
            'id': 'mid',
            'weightKg': 36,
            'recordedAt': '2026-07-16T12:00:00.000Z',
            'createdAt': '2026-07-16T10:55:31.966Z',
          },
          {
            'id': 'oldest',
            'weightKg': 150,
            'recordedAt': '2026-07-16T12:00:00.000Z',
            'createdAt': '2026-07-16T09:00:00.000Z',
          },
        ],
      },
    });

    final collapsed = WeightEntry.collapseToLatestPerDay(entries);
    expect(collapsed, hasLength(1));
    expect(collapsed.single.kg, 60);
    expect(collapsed.single.id, 'newest');
  });

  test('ApiWeightMapper maps single date weight entry', () {
    final entries = ApiWeightMapper.entriesFromResponse({
      'success': true,
      'data': {
        'weightEntry': {
          'id': 'w-3',
          'weight': 68,
          'weightUnit': 'kg',
          'weightKg': 68,
          'recordedAt': '2026-06-29T12:00:00.000Z',
        },
      },

    });

    expect(entries, hasLength(1));
    expect(entries.single.kg, 68);
    expect(
      MealEntry.normalizeDate(entries.single.date),
      DateTime(2026, 6, 29),
    );
  });

  test('ApiWeightMapper maps Mongo-style _id on weight entries', () {
    final entries = ApiWeightMapper.entriesFromResponse({
      'success': true,
      'data': {
        'entries': [
          {
            '_id': 'mongo-w-1',
            'weightKg': 68,
            'recordedAt': '2026-06-29T12:00:00.000Z',
          },
        ],
      },
    });

    expect(entries.single.id, 'mongo-w-1');
    expect(entries.single.kg, 68);
  });

  test('ApiWeightMapper maps POST log response', () {
    final response = ApiWeightMapper.logResponseFromJson({
      'success': true,
      'message': 'Weight logged successfully',
      'data': {
        'weightEntry': {
          'id': 'w-4',
          'weight': 68,
          'weightKg': 68,
          'recordedAt': '2026-06-29T12:00:00.000Z',
        },
        'profileUpdated': true,
        'nutritionPlanRegenerated': false,
      },
    });

    expect(response.entry?.kg, 68);
    expect(response.profileUpdated, isTrue);
    expect(response.nutritionPlanRegenerated, isFalse);
  });
}
