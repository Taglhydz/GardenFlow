import 'package:flutter_test/flutter_test.dart';
import 'package:GardenFlow/config/constants.dart';
import 'package:GardenFlow/models/plant.dart';
import 'package:GardenFlow/utils/plant_colors.dart';

void main() {
  const tomato = Plant(id: 1, code: 'tomato', name: 'Tomate');
  const basil = Plant(id: 2, code: 'basil', name: 'Basilic');

  test('a plant always gets the same color, two plants get different ones', () {
    expect(PlantColors.dark(tomato), PlantColors.dark(const Plant(id: 1, code: 'tomato', name: 'Tomate')));
    expect(PlantColors.dark(tomato), isNot(PlantColors.dark(basil)));
  });

  test('the name and the border are darker than the background of the zone', () {
    expect(PlantColors.dark(tomato).computeLuminance(), lessThan(PlantColors.light(tomato).computeLuminance()));
  });

  test('a zone takes the color of its first plant, green when empty', () {
    expect(PlantColors.zone(const [basil, tomato]), (PlantColors.light(basil), PlantColors.dark(basil)));
    expect(PlantColors.zone(const []), (AppColors.primaryLight, AppColors.primaryDark));
  });
}
