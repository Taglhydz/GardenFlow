import 'package:flutter_test/flutter_test.dart';
import 'package:GardenFlow/models/json_utils.dart';
import 'package:GardenFlow/models/parcel.dart';
import 'package:GardenFlow/models/plant.dart';
import 'package:GardenFlow/models/plant_association.dart';
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

  group('Plant months', () {
    test('normal range', () {
      const plant = Plant(id: 1, code: 'tomato', name: 'Tomate', sowStartMonth: 3, sowEndMonth: 4);
      expect(plant.canBeSownIn(3), isTrue);
      expect(plant.canBeSownIn(5), isFalse);
    });

    test('range wrapping around the year (October -> March)', () {
      const garlic = Plant(id: 2, code: 'garlic', name: 'Ail', sowStartMonth: 10, sowEndMonth: 3);
      expect(garlic.canBeSownIn(11), isTrue);
      expect(garlic.canBeSownIn(1), isTrue);
      expect(garlic.canBeSownIn(6), isFalse);
    });

    test('no range', () {
      const plant = Plant(id: 3, code: 'x', name: 'X');
      expect(plant.canBeSownIn(5), isFalse);
    });
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
