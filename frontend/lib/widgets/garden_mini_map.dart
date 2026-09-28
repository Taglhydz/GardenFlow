import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/crop.dart';
import '../models/parcel.dart';
import '../models/zone.dart';
import '../providers/garden_providers.dart';
import '../providers/plant_providers.dart';
import '../screens/garden_view.dart' show soilColor;
import '../utils/geometry.dart';
import '../utils/plant_colors.dart';
import '../utils/zone_names.dart';

/// Small square plan of a garden (garden list) : its parcels in the color of their soil,
/// their zones in the color of their plant, the whole garden fitted in the square.
class GardenMiniMap extends ConsumerWidget {
  const GardenMiniMap({super.key, required this.gardenId, this.size = 180});

  final int gardenId;

  /// Side of the square (logical px, ~3 cm on a phone)
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcels = ref.watch(parcelsProvider(gardenId)).value ?? const <Parcel>[];
    final zones = ref.watch(zonesProvider(gardenId)).value ?? const <Zone>[];
    final crops = ref.watch(gardenCropsProvider(gardenId)).value ?? const <Crop>[];
    final plantsById = ref.watch(plantsByIdProvider);
    final parcelsById = {for (final p in parcels) p.id: p};

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: size,
        child: parcels.isEmpty
            ? const ColoredBox(
                color: Color(0xFFF1F8E9),
                child: Center(child: Icon(Icons.yard_outlined, size: 48, color: AppColors.primaryLight)),
              )
            : CustomPaint(
                painter: _MiniMapPainter(
                  parcels: [for (final p in parcels) (p.absoluteShape, soilColor(p.soilType))],
                  zones: [
                    for (final z in zones)
                      if (parcelsById[z.parcelId] != null)
                        (z.absoluteShape(parcelsById[z.parcelId]!), PlantColors.zone(ZoneNames.plantsIn(z.id, crops, plantsById))),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter({required this.parcels, required this.zones});

  final List<(List<Offset>, Color)> parcels;
  final List<(List<Offset>, (Color, Color))> zones;

  static const _padding = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF1F8E9));

    // the whole garden, centered in the square
    final bounds = Geometry.bounds([for (final (points, _) in parcels) ...points]);
    final scale = math.min(
      (size.width - 2 * _padding) / math.max(bounds.width, 0.01),
      (size.height - 2 * _padding) / math.max(bounds.height, 0.01),
    );
    final origin = Offset((size.width - bounds.width * scale) / 2, (size.height - bounds.height * scale) / 2);
    Path path(List<Offset> points) =>
        Path()..addPolygon([for (final p in points) origin + (p - bounds.topLeft) * scale], true);

    for (final (points, color) in parcels) {
      canvas.drawPath(path(points), Paint()..color = color);
      canvas.drawPath(path(points), Paint()..color = AppColors.parcels..style = PaintingStyle.stroke..strokeWidth = 1);
    }
    for (final (points, (fill, border)) in zones) {
      canvas.drawPath(path(points), Paint()..color = fill.withValues(alpha: 0.75));
      canvas.drawPath(path(points), Paint()..color = border..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) => old.parcels != parcels || old.zones != zones;
}
