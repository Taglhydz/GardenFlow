import '../config/constants.dart';
import '../models/crop.dart';
import '../models/json_utils.dart';
import 'api_service.dart';

class CropService {
  CropService(this._api);

  final ApiService _api;

  /// Crops of all the parcels of a garden (one request for the garden plan).
  Future<List<Crop>> getCropsByGarden(int gardenId) async {
    final response = await _api.get('${AppConstants.gardensEndpoint}/$gardenId/crops') as List;
    return response.map((json) => Crop.fromJson(json)).toList();
  }

  Future<List<Crop>> getCropsByParcel(int parcelId) async {
    final response = await _api.get('${AppConstants.parcelsEndpoint}/$parcelId/crops') as List;
    return response.map((json) => Crop.fromJson(json)).toList();
  }

  Future<Crop> getCropById(int id) async {
    return Crop.fromJson(await _api.get('${AppConstants.cropsEndpoint}/$id'));
  }

  Future<Crop> createCrop(
    int parcelId, {
    required int plantId,
    DateTime? sowDate,
    DateTime? expectedHarvestDate,
    DateTime? actualHarvestDate,
    String? comment,
  }) async {
    final response = await _api.post('${AppConstants.parcelsEndpoint}/$parcelId/crops', {
      'plant_id': plantId,
      'sow_date': JsonUtils.formatDate(sowDate),
      'expected_harvest_date': JsonUtils.formatDate(expectedHarvestDate),
      'actual_harvest_date': JsonUtils.formatDate(actualHarvestDate),
      'comment': comment,
    });
    return Crop.fromJson(response);
  }

  /// Only the given fields are modified. Dates must be 'YYYY-MM-DD' (JsonUtils.formatDate) or null.
  Future<Crop> updateCrop(int id, Map<String, dynamic> changes) async {
    return Crop.fromJson(await _api.patch('${AppConstants.cropsEndpoint}/$id', changes));
  }

  Future<void> deleteCrop(int id) => _api.delete('${AppConstants.cropsEndpoint}/$id');
}
