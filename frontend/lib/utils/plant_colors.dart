import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../models/plant.dart';

/// Color of each plant on the plans : always the same for a plant, computed from its id.
/// The zones take the color of their plant, the names of the plants are written in its dark shade.
class PlantColors {
  PlantColors._();

  /// Golden angle : two plants with close ids get far apart hues
  static const double _goldenAngle = 137.508;

  static double _hue(Plant plant) => (plant.id * _goldenAngle) % 360;

  /// Light shade : background of a zone
  static Color light(Plant plant) => HSLColor.fromAHSL(1, _hue(plant), 0.55, 0.80).toColor();

  /// Dark shade : border of a zone and name of the plant
  static Color dark(Plant plant) => HSLColor.fromAHSL(1, _hue(plant), 0.60, 0.30).toColor();

  /// Background and border of a zone : the color of its first plant, green when it is empty.
  static (Color fill, Color border) zone(List<Plant> plants) =>
      plants.isEmpty ? (AppColors.primaryLight, AppColors.primaryDark) : (light(plants.first), dark(plants.first));
}
