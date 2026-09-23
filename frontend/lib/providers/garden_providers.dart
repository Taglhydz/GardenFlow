import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/crop.dart';
import '../models/garden.dart';
import '../models/parcel.dart';
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
/// After a modification, call ref.invalidate(parcelsProvider(gardenId)) to reload.
final parcelsProvider = FutureProvider.family<List<Parcel>, int>((ref, gardenId) {
  ref.watch(currentUserIdProvider);
  return ref.read(parcelServiceProvider).getParcelsByGarden(gardenId);
});

/// Crops of a parcel : ref.watch(cropsProvider(parcelId)).
final cropsProvider = FutureProvider.family<List<Crop>, int>((ref, parcelId) {
  ref.watch(currentUserIdProvider);
  return ref.read(cropServiceProvider).getCropsByParcel(parcelId);
});
