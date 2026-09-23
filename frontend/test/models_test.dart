import 'package:flutter_test/flutter_test.dart';
import 'package:GardenFlow/models/json_utils.dart';
import 'package:GardenFlow/models/parcel.dart';
import 'package:GardenFlow/models/plant.dart';
import 'package:GardenFlow/models/plant_association.dart';
import 'package:GardenFlow/models/suggestion.dart';
import 'package:GardenFlow/models/user.dart';

void main() {
  group('Parcel.fromJson', () {
    test('accepts numbers', () {
      final parcel = Parcel.fromJson({'id': 1, 'garden_id': 2, 'name': 'A', 'area_m2': 3, 'width': 1.5, 'length': 2});
      expect(parcel.areaM2, 3.0);
      expect(parcel.width, 1.5);
      expect(parcel.length, 2.0);
    });

    test('accepts decimals sent as strings (MySQL DECIMAL)', () {
      final parcel = Parcel.fromJson({'id': 1, 'garden_id': 2, 'name': 'A', 'area_m2': '12.50', 'pos_x': '0.00'});
      expect(parcel.areaM2, 12.5);
      expect(parcel.posX, 0.0);
    });

    test('applies defaults', () {
      final parcel = Parcel.fromJson({'id': 1, 'garden_id': 2, 'name': 'A'});
      expect(parcel.areaM2, isNull);
      expect(parcel.width, 0);
      expect(parcel.soilType, 'standard');
    });
  });

  group('dates', () {
    test("a 'YYYY-MM-DD' birthdate keeps its day (no timezone shift)", () {
      final user = User.fromJson({'id': 1, 'username': 'a', 'email': 'a@b.c', 'birthdate': '2000-01-01'});
      expect(user.birthdate!.year, 2000);
      expect(user.birthdate!.month, 1);
      expect(user.birthdate!.day, 1);
    });

    test('formatDate sends YYYY-MM-DD', () {
      expect(JsonUtils.formatDate(DateTime(2026, 4, 3, 15, 30)), '2026-04-03');
      expect(JsonUtils.formatDate(null), isNull);
    });
  });

  group('Plant calendar', () {
    test('parsed from the API with all its periods', () {
      final spinach = Plant.fromJson({
        'id': 1,
        'code': 'spinach',
        'name': 'Épinard',
        'family': 'amaranthaceae',
        'days_to_maturity': 45,
        'periods': [
          {'type': 'sow_outdoor', 'start_month': 2, 'end_month': 4},
          {'type': 'sow_outdoor', 'start_month': 8, 'end_month': 10},
          {'type': 'harvest', 'start_month': 4, 'end_month': 6},
        ],
      });
      expect(spinach.family, 'amaranthaceae');
      expect(spinach.periodsOf(PlantPeriod.sowOutdoor), hasLength(2));
      // sown in spring AND in autumn
      expect(spinach.canGoInGroundIn(3), isTrue);
      expect(spinach.canGoInGroundIn(9), isTrue);
      expect(spinach.canGoInGroundIn(6), isFalse);
      expect(spinach.canBeHarvestedIn(5), isTrue);
    });

    test('period wrapping around the year (October -> March)', () {
      const garlic = PlantPeriod(type: PlantPeriod.plantOut, startMonth: 10, endMonth: 3);
      expect(garlic.contains(11), isTrue);
      expect(garlic.contains(1), isTrue);
      expect(garlic.contains(6), isFalse);
    });

    test('planting out counts as going in the ground, sowing under cover does not', () {
      const tomato = Plant(id: 2, code: 'tomato', name: 'Tomate', periods: [
        PlantPeriod(type: PlantPeriod.sowIndoor, startMonth: 3, endMonth: 4),
        PlantPeriod(type: PlantPeriod.plantOut, startMonth: 5, endMonth: 6),
      ]);
      expect(tomato.canGoInGroundIn(4), isFalse);
      expect(tomato.canGoInGroundIn(5), isTrue);
    });

    test('expected harvest from days to maturity', () {
      const radish = Plant(id: 3, code: 'radish', name: 'Radis', daysToMaturity: 30);
      expect(radish.expectedHarvestFrom(DateTime(2026, 4, 10)), DateTime(2026, 5, 10));
      const unknown = Plant(id: 4, code: 'x', name: 'X');
      expect(unknown.expectedHarvestFrom(DateTime(2026, 4, 10)), isNull);
    });
  });

  test('suggestions are parsed with their reasons', () {
    final result = ParcelSuggestions.fromJson({
      'parcel_id': 5,
      'month': 5,
      'suggestions': [
        {
          'plant_id': 24,
          'plant_code': 'basil',
          'score': 87,
          'actions': ['sow_outdoor', 'plant_out'],
          'reasons': [
            {'code': 'good_companion', 'impact': 'positive', 'params': {'plant_code': 'tomato'}},
            {'code': 'sow_indoor_now', 'impact': 'info', 'params': {}},
          ],
        },
      ],
    });
    final basil = result.suggestions.single;
    expect(basil.score, 87);
    expect(basil.canGoInGroundNow, isTrue);
    expect(basil.reasons.first.isPositive, isTrue);
    expect(basil.reasons.first.params['plant_code'], 'tomato');
  });

  test('association translation key uses codes sorted alphabetically', () {
    final association = PlantAssociation.fromJson({
      'id': 1,
      'plant_id_1': 1,
      'plant_id_2': 24,
      'plant_code_1': 'tomato',
      'plant_code_2': 'basil',
      'relation_type': 'positive',
    });
    expect(association.translationKey, 'plant_associations.basil__tomato');
    expect(association.otherPlantId(24), 1);
  });
}
