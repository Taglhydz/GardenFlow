import 'package:easy_localization/easy_localization.dart';
import '../config/app_localizations.dart';
import '../models/crop.dart';
import '../models/plant.dart';
import '../models/zone.dart';

/// Plants of the zones and their names.
///
/// A zone without a name given by the user (name null) has an automatic name, computed each time
/// from its plants (so it follows the plants and the language) : "Add a plant" when it is empty,
/// else "Zone" + its first plant, numbered in its parcel when several zones have the same plant
/// ("Zone Aneth", "Zone Aneth 2"). Once renamed, the zone keeps its name ; an empty name
/// brings the automatic one back.
class ZoneNames {
  ZoneNames._();

  /// Plants in the ground in the zone, each one once, in the order they were planted.
  static List<Plant> plantsIn(int zoneId, List<Crop> crops, Map<int, Plant> plantsById) => {
    for (final crop in crops)
      if (crop.zoneId == zoneId && crop.isInGround && plantsById[crop.plantId] != null) plantsById[crop.plantId]!,
  }.toList();

  /// Name shown for each zone (id -> name).
  static Map<int, String> of(List<Zone> zones, List<Crop> crops, Map<int, Plant> plantsById) {
    final names = <int, String>{};
    // zones already named after a plant, per parcel : (parcel id, plant id) -> count
    final counts = <(int, int), int>{};
    // the oldest zone keeps the name without number
    for (final zone in [...zones]..sort((a, b) => a.id.compareTo(b.id))) {
      final given = zone.name;
      if (given != null) {
        names[zone.id] = given;
        continue;
      }
      final plants = plantsIn(zone.id, crops, plantsById);
      if (plants.isEmpty) {
        names[zone.id] = 'zone_name.empty'.tr();
        continue;
      }
      final key = (zone.parcelId, plants.first.id);
      final number = counts[key] = (counts[key] ?? 0) + 1;
      final name = 'zone_name.of_plant'.tr(args: [AppLocalizations.plantName(plants.first)]);
      names[zone.id] = number == 1 ? name : '$name $number';
    }
    return names;
  }
}
