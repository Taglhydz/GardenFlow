import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/plant.dart';

/// Color of each plant on the plans : the one chosen by the user, else an automatic one computed
/// from its id (always the same for a plant). A color is a hue : the zones take its light shade,
/// the names of the plants and the borders its dark shade.
///   final colors = ref.watch(plantColorsProvider);
class PlantColors {
  const PlantColors([this.chosen = const {}]);

  /// Hues (degrees) chosen by the user, by plant id
  final Map<int, int> chosen;

  /// Golden angle : two plants with close ids get far apart hues
  static const double _goldenAngle = 137.508;

  /// Hues offered to the user, every 20 degrees
  static const List<int> palette = [0, 20, 40, 60, 80, 100, 120, 140, 160, 180, 200, 220, 240, 260, 280, 300, 320, 340];

  /// Two hues closer than that (degrees) look like the same color
  static const double sameColorGap = 10;

  static double automaticHue(Plant plant) => (plant.id * _goldenAngle) % 360;

  double hue(Plant plant) => chosen[plant.id]?.toDouble() ?? automaticHue(plant);

  bool isChosen(Plant plant) => chosen.containsKey(plant.id);

  /// Light shade : background of a zone
  static Color lightOf(double hue) => HSLColor.fromAHSL(1, hue, 0.55, 0.80).toColor();

  /// Dark shade : border of a zone and name of the plant
  static Color darkOf(double hue) => HSLColor.fromAHSL(1, hue, 0.60, 0.30).toColor();

  Color light(Plant plant) => lightOf(hue(plant));

  Color dark(Plant plant) => darkOf(hue(plant));

  /// Background and border of a zone : the color of its first plant, green when it is empty.
  (Color fill, Color border) zone(List<Plant> plants) =>
      plants.isEmpty ? (AppColors.primaryLight, AppColors.primaryDark) : (light(plants.first), dark(plants.first));

  /// Plants of [others] (except [plant]) that would look like the same color as [hue].
  List<Plant> sameColorAs(Plant plant, double hue, Iterable<Plant> others) {
    bool close(double other) {
      final gap = (other - hue).abs() % 360;
      return (gap > 180 ? 360 - gap : gap) < sameColorGap;
    }

    return [for (final p in others) if (p.id != plant.id && close(this.hue(p))) p];
  }
}
