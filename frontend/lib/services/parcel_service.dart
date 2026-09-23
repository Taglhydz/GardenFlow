import '../config/constants.dart';
import '../models/parcel.dart';
import 'api_service.dart';

class ParcelService {
  ParcelService(this._api);

  final ApiService _api;

  Future<List<Parcel>> getParcelsByGarden(int gardenId) async {
    final response = await _api.get('${AppConstants.gardensEndpoint}/$gardenId/parcels') as List;
    return response.map((json) => Parcel.fromJson(json)).toList();
  }

  Future<Parcel> getParcelById(int id) async {
    return Parcel.fromJson(await _api.get('${AppConstants.parcelsEndpoint}/$id'));
  }

  /// [fields] uses the API names : name, area_m2, pos_x, pos_y, width, length, soil_type, sunlight, moisture
  Future<Parcel> createParcel(int gardenId, Map<String, dynamic> fields) async {
    return Parcel.fromJson(await _api.post('${AppConstants.gardensEndpoint}/$gardenId/parcels', fields));
  }

  /// Only the given fields are modified.
  Future<Parcel> updateParcel(int id, Map<String, dynamic> changes) async {
    return Parcel.fromJson(await _api.patch('${AppConstants.parcelsEndpoint}/$id', changes));
  }

  /// Also deletes its crops.
  Future<void> deleteParcel(int id) => _api.delete('${AppConstants.parcelsEndpoint}/$id');
}
