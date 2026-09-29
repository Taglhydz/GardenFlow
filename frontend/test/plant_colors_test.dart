import 'package:flutter_test/flutter_test.dart';
import 'package:GardenFlow/config/constants.dart';
import 'package:GardenFlow/models/plant.dart';
import 'package:GardenFlow/utils/plant_colors.dart';

void main() {
  const tomato = Plant(id: 1, code: 'tomato', name: 'Tomate');
  const basil = Plant(id: 2, code: 'basil', name: 'Basilic');
  const colors = PlantColors();

  test('a plant always gets the same color, two plants get different ones', () {
    expect(colors.dark(tomato), colors.dark(const Plant(id: 1, code: 'tomato', name: 'Tomate')));
    expect(colors.dark(tomato), isNot(colors.dark(basil)));
  });

  test('the name and the border are darker than the background of the zone', () {
    expect(colors.dark(tomato).computeLuminance(), lessThan(colors.light(tomato).computeLuminance()));
  });

  test('a zone takes the color of its first plant, green when empty', () {
    expect(colors.zone(const [basil, tomato]), (colors.light(basil), colors.dark(basil)));
    expect(colors.zone(const []), (AppColors.primaryLight, AppColors.primaryDark));
  });

  test('the color chosen by the user replaces the automatic one, only for that plant', () {
    const chosen = PlantColors({1: 200});
    expect(chosen.isChosen(tomato), isTrue);
    expect(chosen.dark(tomato), PlantColors.darkOf(200));
    expect(chosen.dark(basil), colors.dark(basil));
  });

  test('a color close to the one of another plant is reported, not the plant itself', () {
    final basilHue = colors.hue(basil);
    expect(colors.sameColorAs(tomato, basilHue + 5, const [tomato, basil]), [basil]);
    expect(colors.sameColorAs(tomato, basilHue + 30, const [tomato, basil]), isEmpty);
    expect(colors.sameColorAs(basil, basilHue, const [basil]), isEmpty);
    // around 0 / 360 degrees
    expect(const PlantColors({1: 355}).sameColorAs(basil, 3, const [tomato]), [tomato]);
  });
}
