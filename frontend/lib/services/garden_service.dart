import '../config/constants.dart';
import '../models/garden.dart';
import 'api_service.dart';

class GardenService {
  final ApiService _apiService = ApiService();

  // Récupérer tous les jardins
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

  // Récupérer un jardin par ID
  Future<Garden> getGardenById(int id) async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.get('${AppConstants.gardensEndpoint}/$id');
      return Garden.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération du jardin: $e');
    }
  }

  // Récupérer les jardins d'un utilisateur
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

  // Créer un jardin
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

  // Mettre à jour un jardin
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

  // Supprimer un jardin
  Future<void> deleteGarden(int id) async {
    try {
      await _apiService.loadToken();
      await _apiService.delete('${AppConstants.gardensEndpoint}/$id');
    } catch (e) {
      throw Exception('Erreur lors de la suppression du jardin: $e');
    }
  }
}
