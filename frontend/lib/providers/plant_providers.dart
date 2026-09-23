import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plant.dart';
import '../models/plant_association.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

/// Reference catalog, loaded once per session.
final plantsProvider = FutureProvider<List<Plant>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  return ref.read(plantServiceProvider).getAllPlants();
});

/// Plants by id, for quick lookups (crop.plantId -> Plant).
final plantsByIdProvider = Provider<Map<int, Plant>>((ref) {
  final plants = ref.watch(plantsProvider).value ?? const <Plant>[];
  return {for (final plant in plants) plant.id: plant};
});

final plantAssociationsProvider = FutureProvider<List<PlantAssociation>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  return ref.read(plantServiceProvider).getAllAssociations();
});
