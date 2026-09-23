import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/crop.dart';
import '../models/garden.dart';
import '../models/json_utils.dart';
import '../models/parcel.dart';
import '../models/suggestion.dart';
import '../models/zone.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

// ======
// Gardens
// ======

/// Gardens of the logged in user, reloaded when the user changes.
final gardensProvider = AsyncNotifierProvider<GardensNotifier, List<Garden>>(GardensNotifier.new);

class GardensNotifier extends AsyncNotifier<List<Garden>> {
  @override
  Future<List<Garden>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    return ref.read(gardenServiceProvider).getMyGardens();
  }

  /// Creates a garden and selects it.
  Future<Garden> create({required String name, String? location, String? description}) async {
    final garden = await ref.read(gardenServiceProvider).createGarden(
      name: name,
      location: location,
      description: description,
    );
    state = AsyncData([...state.value ?? const [], garden]);
    ref.read(selectedGardenIdProvider.notifier).select(garden.id);
    return garden;
  }

  Future<Garden> updateGarden(int id, {String? name, String? location, String? description}) async {
    final updated = await ref.read(gardenServiceProvider).updateGarden(
      id,
      name: name,
      location: location,
      description: description,
    );
    state = AsyncData([
      for (final garden in state.value ?? const <Garden>[]) garden.id == id ? updated : garden,
    ]);
    return updated;
  }

  /// Also deletes its parcels and crops on the server.
  Future<void> delete(int id) async {
    await ref.read(gardenServiceProvider).deleteGarden(id);
    state = AsyncData([
      for (final garden in state.value ?? const <Garden>[]) if (garden.id != id) garden,
    ]);
    if (ref.read(selectedGardenIdProvider) == id) {
      ref.read(selectedGardenIdProvider.notifier).select(null);
    }
  }
}

/// Id of the opened garden (null = garden list), remembered between launches.
final selectedGardenIdProvider = NotifierProvider<SelectedGardenIdNotifier, int?>(SelectedGardenIdNotifier.new);

class SelectedGardenIdNotifier extends Notifier<int?> {
  @override
  int? build() {
    // reset when another user logs in
    ref.watch(currentUserIdProvider);
    return ref.read(sharedPreferencesProvider).getInt(AppConstants.lastGardenIdKey);
  }

  void select(int? gardenId) {
    state = gardenId;
    final prefs = ref.read(sharedPreferencesProvider);
    if (gardenId == null) {
      prefs.remove(AppConstants.lastGardenIdKey);
    } else {
      prefs.setInt(AppConstants.lastGardenIdKey, gardenId);
    }
  }
}

/// The opened garden, or null if none is selected or it no longer exists.
final selectedGardenProvider = Provider<Garden?>((ref) {
  final gardens = ref.watch(gardensProvider).value ?? const <Garden>[];
  final selectedId = ref.watch(selectedGardenIdProvider);
  if (selectedId == null) return null;

  for (final garden in gardens) {
    if (garden.id == selectedId) return garden;
  }
  return null;
});

// ================
// Parcels and crops
// ================

/// Parcels of a garden : ref.watch(parcelsProvider(gardenId)).
final parcelsProvider = AsyncNotifierProvider.family<ParcelsNotifier, List<Parcel>, int>(ParcelsNotifier.new);

class ParcelsNotifier extends AsyncNotifier<List<Parcel>> {
  ParcelsNotifier(this.gardenId);

  final int gardenId;

  @override
  Future<List<Parcel>> build() async {
    ref.watch(currentUserIdProvider);
    return ref.read(parcelServiceProvider).getParcelsByGarden(gardenId);
  }

  List<Parcel> get _parcels => state.value ?? const [];

  void _replace(Parcel parcel) {
    state = AsyncData([for (final p in _parcels) p.id == parcel.id ? parcel : p]);
  }

  /// [fields] uses the API names : name, pos_x, pos_y, shape (see shapeToJson), soil_type, sunlight, moisture
  Future<Parcel> create(Map<String, dynamic> fields) async {
    final parcel = await ref.read(parcelServiceProvider).createParcel(gardenId, fields);
    state = AsyncData([..._parcels, parcel]);
    return parcel;
  }

  /// Only the given fields are modified (API names).
  Future<Parcel> updateParcel(int id, Map<String, dynamic> changes) async {
    final parcel = await ref.read(parcelServiceProvider).updateParcel(id, changes);
    _replace(parcel);
    ref.invalidate(suggestionsProvider);
    return parcel;
  }

  /// Moves the parcel on the plan (its zones follow it).
  Future<void> move(Parcel parcel, Offset position) => _optimistic(
        parcel,
        parcel.copyWith(position: position),
        {'pos_x': position.dx, 'pos_y': position.dy},
      );

  /// New shape (points relative to the parcel position). Refused by the server if a zone would be outside.
  Future<void> reshape(Parcel parcel, List<Offset> shape) => _optimistic(
        parcel,
        parcel.copyWith(shape: shape),
        {'shape': shapeToJson(shape)},
      );

  /// Shown immediately, saved in the background, the previous parcel comes back if the server refuses.
  Future<void> _optimistic(Parcel previous, Parcel updated, Map<String, dynamic> changes) async {
    _replace(updated);
    try {
      _replace(await ref.read(parcelServiceProvider).updateParcel(updated.id, changes));
      ref.invalidate(suggestionsProvider);
    } catch (_) {
      _replace(previous);
      rethrow;
    }
  }

  /// Also deletes its crops on the server.
  Future<void> delete(int id) async {
    await ref.read(parcelServiceProvider).deleteParcel(id);
    state = AsyncData([for (final p in _parcels) if (p.id != id) p]);
    ref.invalidate(gardenCropsProvider(gardenId));
    ref.invalidate(zonesProvider(gardenId));
    ref.invalidate(suggestionsProvider);
  }
}

/// Crops of all the parcels of a garden : ref.watch(gardenCropsProvider(gardenId)).
final gardenCropsProvider = AsyncNotifierProvider.family<GardenCropsNotifier, List<Crop>, int>(GardenCropsNotifier.new);

class GardenCropsNotifier extends AsyncNotifier<List<Crop>> {
  GardenCropsNotifier(this.gardenId);

  final int gardenId;

  @override
  Future<List<Crop>> build() async {
    ref.watch(currentUserIdProvider);
    return ref.read(cropServiceProvider).getCropsByGarden(gardenId);
  }

  List<Crop> get _crops => state.value ?? const [];

  void _changed(List<Crop> crops) {
    state = AsyncData(crops);
    // companions and rotation depend on the crops
    ref.invalidate(suggestionsProvider);
  }

  Future<Crop> create(
    int parcelId, {
    int? zoneId,
    required int plantId,
    DateTime? sowDate,
    DateTime? expectedHarvestDate,
    String? comment,
  }) async {
    final crop = await ref.read(cropServiceProvider).createCrop(
      parcelId,
      zoneId: zoneId,
      plantId: plantId,
      sowDate: sowDate,
      expectedHarvestDate: expectedHarvestDate,
      comment: comment,
    );
    _changed([..._crops, crop]);
    return crop;
  }

  /// Only the given fields are modified. Dates must be formatted with JsonUtils.formatDate.
  Future<Crop> updateCrop(int id, Map<String, dynamic> changes) async {
    final crop = await ref.read(cropServiceProvider).updateCrop(id, changes);
    _changed([for (final c in _crops) c.id == id ? crop : c]);
    return crop;
  }

  Future<Crop> harvest(int id, DateTime date) => updateCrop(id, {'actual_harvest_date': JsonUtils.formatDate(date)});

  Future<void> delete(int id) async {
    await ref.read(cropServiceProvider).deleteCrop(id);
    _changed([for (final c in _crops) if (c.id != id) c]);
  }
}

// =====
// Zones
// =====

/// Zones of all the parcels of a garden : ref.watch(zonesProvider(gardenId)).
final zonesProvider = AsyncNotifierProvider.family<ZonesNotifier, List<Zone>, int>(ZonesNotifier.new);

class ZonesNotifier extends AsyncNotifier<List<Zone>> {
  ZonesNotifier(this.gardenId);

  final int gardenId;

  @override
  Future<List<Zone>> build() async {
    ref.watch(currentUserIdProvider);
    return ref.read(zoneServiceProvider).getZonesByGarden(gardenId);
  }

  List<Zone> get _zones => state.value ?? const [];

  void _replace(Zone zone) => state = AsyncData([for (final z in _zones) z.id == zone.id ? zone : z]);

  /// The server refuses a zone outside its parcel or overlapping another zone.
  Future<Zone> create(int parcelId, {required String name, required List<Offset> shape}) async {
    final zone = await ref.read(zoneServiceProvider).createZone(parcelId, name: name, shape: shape);
    state = AsyncData([..._zones, zone]);
    ref.invalidate(suggestionsProvider);
    return zone;
  }

  Future<Zone> rename(int id, String name) async {
    final zone = await ref.read(zoneServiceProvider).updateZone(id, name: name);
    _replace(zone);
    return zone;
  }

  /// New shape : shown immediately, the previous one comes back if the server refuses.
  Future<void> reshape(Zone zone, List<Offset> shape) async {
    _replace(zone.copyWith(shape: shape));
    try {
      _replace(await ref.read(zoneServiceProvider).updateZone(zone.id, shape: shape));
      ref.invalidate(suggestionsProvider);
    } catch (_) {
      _replace(zone);
      rethrow;
    }
  }

  /// Its crops stay in the parcel, without zone.
  Future<void> delete(int id) async {
    await ref.read(zoneServiceProvider).deleteZone(id);
    state = AsyncData([for (final z in _zones) if (z.id != id) z]);
    ref.invalidate(gardenCropsProvider(gardenId));
    ref.invalidate(suggestionsProvider);
  }
}

// ===========
// Suggestions
// ===========

/// Plants to sow / plant in a zone (or the whole parcel when zoneId is null) for a month,
/// computed by the server. Reloaded when the crops, parcels or zones change (the notifiers invalidate it).
final suggestionsProvider =
    FutureProvider.autoDispose.family<ParcelSuggestions, ({int parcelId, int? zoneId, int month})>((ref, key) {
  ref.watch(currentUserIdProvider);
  return key.zoneId != null
      ? ref.read(zoneServiceProvider).getSuggestions(key.zoneId!, key.month)
      : ref.read(parcelServiceProvider).getSuggestions(key.parcelId, key.month);
});
