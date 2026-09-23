import '../config/constants.dart';
import '../models/garden.dart';
import 'api_service.dart';

/// The API only returns the gardens of the logged in user.
class GardenService {
  GardenService(this._api);

  final ApiService _api;

  Future<List<Garden>> getMyGardens() async {
    final response = await _api.get(AppConstants.gardensEndpoint) as List;
    return response.map((json) => Garden.fromJson(json)).toList();
  }

  Future<Garden> getGardenById(int id) async {
    return Garden.fromJson(await _api.get('${AppConstants.gardensEndpoint}/$id'));
  }

  Future<Garden> createGarden({required String name, String? location, String? description}) async {
    final response = await _api.post(AppConstants.gardensEndpoint, {
      'name': name,
      'location': location,
      'description': description,
    });
    return Garden.fromJson(response);
  }

  /// Only the given fields are modified, '' clears an optional field.
  Future<Garden> updateGarden(int id, {String? name, String? location, String? description}) async {
    final response = await _api.patch('${AppConstants.gardensEndpoint}/$id', {
      if (name != null) 'name': name,
      if (location != null) 'location': location,
      if (description != null) 'description': description,
    });
    return Garden.fromJson(response);
  }

  /// Also deletes its parcels and crops.
  Future<void> deleteGarden(int id) => _api.delete('${AppConstants.gardensEndpoint}/$id');
}
