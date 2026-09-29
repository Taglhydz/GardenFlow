import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plant.dart';
import '../models/plant_association.dart';
import '../utils/plant_colors.dart';
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

/// Hues chosen by the user for the plants (plant id -> degrees), see PlantColors.
final plantHuesProvider = AsyncNotifierProvider<PlantHuesNotifier, Map<int, int>>(PlantHuesNotifier.new);

class PlantHuesNotifier extends AsyncNotifier<Map<int, int>> {
  @override
  Future<Map<int, int>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return const {};
    return ref.read(plantServiceProvider).getMyPlantColors();
  }

  Map<int, int> get _hues => state.value ?? const {};

  /// The plans change color right away, and go back if the server refuses.
  Future<void> choose(int plantId, int hue) => _change({..._hues, plantId: hue}, () => ref.read(plantServiceProvider).setPlantColor(plantId, hue));

  /// Back to the automatic color
  Future<void> reset(int plantId) => _change({..._hues}..remove(plantId), () => ref.read(plantServiceProvider).resetPlantColor(plantId));

  Future<void> _change(Map<int, int> hues, Future<void> Function() save) async {
    final previous = _hues;
    state = AsyncData(hues);
    try {
      await save();
    } catch (e) {
      state = AsyncData(previous);
      rethrow;
    }
  }
}

/// Colors of the plants on the plans : the chosen ones, automatic for the others
/// (automatic for all while the choices are loading or can't be loaded).
final plantColorsProvider = Provider<PlantColors>((ref) => PlantColors(ref.watch(plantHuesProvider).value ?? const {}));
