import '../config/constants.dart';
import '../models/garden.dart';
import 'api_service.dart';

class GardenService {
  final ApiService _apiService = ApiService();

  Future<List<Garden>> getAllGardens() async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.get(AppConstants.gardensEndpoint);
      
      if (response is List) {
        return response.map((json) => Garden.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Erreur lors de la récupération des jardins: $e');
    }
  }

  Future<Garden> getGardenById(int id) async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.get('${AppConstants.gardensEndpoint}/$id');
      return Garden.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération du jardin: $e');
    }
  }

  Future<List<Garden>> getGardensByUserId(int userId) async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.get('${AppConstants.gardensEndpoint}/user/$userId');
      
      if (response is List) {
        return response.map((json) => Garden.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Erreur lors de la récupération des jardins: $e');
    }
  }

  Future<Garden> createGarden(Garden garden) async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.post(
        AppConstants.gardensEndpoint,
        garden.toJson(),
      );
      return Garden.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la création du jardin: $e');
    }
  }

  Future<Garden> updateGarden(int id, Garden garden) async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.put(
        '${AppConstants.gardensEndpoint}/$id',
        garden.toJson(),
      );
      return Garden.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du jardin: $e');
    }
  }

  Future<void> deleteGarden(int id) async {
    try {
      await _apiService.loadToken();
      await _apiService.delete('${AppConstants.gardensEndpoint}/$id');
    } catch (e) {
      throw Exception('Erreur lors de la suppression du jardin: $e');
    }
  }
}
