import '../config/constants.dart';
import '../models/parcel.dart';
import 'api_service.dart';

class ParcelService {
  final ApiService _apiService = ApiService();

  // Récupérer toutes les parcelles
  Future<List<Parcel>> getAllParcels() async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.get(AppConstants.parcelsEndpoint);
      
      if (response is List) {
        return response.map((json) => Parcel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Erreur lors de la récupération des parcelles: $e');
    }
  }

  // Récupérer une parcelle par ID
  Future<Parcel> getParcelById(int id) async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.get('${AppConstants.parcelsEndpoint}/$id');
      return Parcel.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la récupération de la parcelle: $e');
    }
  }

  // Récupérer les parcelles d'un jardin
  Future<List<Parcel>> getParcelsByGardenId(int gardenId) async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.get('${AppConstants.parcelsEndpoint}/garden/$gardenId');
      
      if (response is List) {
        return response.map((json) => Parcel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Erreur lors de la récupération des parcelles: $e');
    }
  }

  // Créer une parcelle
  Future<Parcel> createParcel(Parcel parcel) async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.post(
        AppConstants.parcelsEndpoint,
        parcel.toJson(),
      );
      return Parcel.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la création de la parcelle: $e');
    }
  }

  // Mettre à jour une parcelle
  Future<Parcel> updateParcel(int id, Parcel parcel) async {
    try {
      await _apiService.loadToken();
      final response = await _apiService.put(
        '${AppConstants.parcelsEndpoint}/$id',
        parcel.toJson(),
      );
      return Parcel.fromJson(response);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de la parcelle: $e');
    }
  }

  // Supprimer une parcelle
  Future<void> deleteParcel(int id) async {
    try {
      await _apiService.loadToken();
      await _apiService.delete('${AppConstants.parcelsEndpoint}/$id');
    } catch (e) {
      throw Exception('Erreur lors de la suppression de la parcelle: $e');
    }
  }
}
