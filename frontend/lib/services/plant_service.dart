import '../config/constants.dart';
import '../models/plant.dart';
import 'api_service.dart';

class PlantService {
  final ApiService _apiService = ApiService();

  Future<List<Plant>> getAllPlants() async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.get(AppConstants.plantsEndpoint);
      
      if (response is List) {
        return response.map((json) => Plant.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Erreur lors de la récupération des plantes: $e');
    }
  }

  Future<Plant> getPlantById(int id) async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.get('${AppConstants.plantsEndpoint}/$id');
      return Plant.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération de la plante: $e');
    }
  }

  Future<Plant> createPlant(Plant plant) async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.post(
        AppConstants.plantsEndpoint,
        plant.toJson(),
      );
      return Plant.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la création de la plante: $e');
    }
  }

  Future<Plant> updatePlant(int id, Plant plant) async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.put(
        '${AppConstants.plantsEndpoint}/$id',
        plant.toJson(),
      );
      return Plant.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de la plante: $e');
    }
  }

  Future<void> deletePlant(int id) async {
    try {
      await _apiService.loadToken();
      await _apiService.delete('${AppConstants.plantsEndpoint}/$id');
    } catch (e) {
      throw Exception('Erreur lors de la suppression de la plante: $e');
    }
  }
}
