import '../config/constants.dart';
import '../models/crop.dart';
import 'api_service.dart';

class CropService {
  final ApiService _apiService = ApiService();

  // Récupérer toutes les cultures
  Future<List<Crop>> getAllCrops() async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.get(AppConstants.cropsEndpoint);
      
      if (response is List) {
        return response.map((json) => Crop.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Erreur lors de la récupération des cultures: $e');
    }
  }

  // Récupérer une culture par ID
  Future<Crop> getCropById(int id) async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.get('${AppConstants.cropsEndpoint}/$id');
      return Crop.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération de la culture: $e');
    }
  }

  // Créer une culture
  Future<Crop> createCrop(Crop crop) async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.post(
        AppConstants.cropsEndpoint,
        crop.toJson(),
      );
      return Crop.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la création de la culture: $e');
    }
  }

  // Mettre à jour une culture
  Future<Crop> updateCrop(int id, Crop crop) async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.put(
        '${AppConstants.cropsEndpoint}/$id',
        crop.toJson(),
      );
      return Crop.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de la culture: $e');
    }
  }

  // Supprimer une culture
  Future<void> deleteCrop(int id) async {
    try {
      await _apiService.loadToken();
      await _apiService.delete('${AppConstants.cropsEndpoint}/$id');
    } catch (e) {
      throw Exception('Erreur lors de la suppression de la culture: $e');
    }
  }
}
