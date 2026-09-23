import '../config/constants.dart';
import '../models/plant.dart';
import '../models/plant_association.dart';
import 'api_service.dart';

/// Reference catalog (read only for users, admin endpoints are not used by the app yet).
class PlantService {
  PlantService(this._api);

  final ApiService _api;

  Future<List<Plant>> getAllPlants() async {
    final response = await _api.get(AppConstants.plantsEndpoint) as List;
    return response.map((json) => Plant.fromJson(json)).toList();
  }

  Future<Plant> getPlantById(int id) async {
    return Plant.fromJson(await _api.get('${AppConstants.plantsEndpoint}/$id'));
  }

  Future<List<PlantAssociation>> getAllAssociations() async {
    final response = await _api.get(AppConstants.plantAssociationsEndpoint) as List;
    return response.map((json) => PlantAssociation.fromJson(json)).toList();
  }
}
