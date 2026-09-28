import 'dart:ui';
import '../config/constants.dart';
import '../models/parcel.dart';
import '../models/suggestion.dart';
import '../models/zone.dart';
import 'api_service.dart';

/// Zones drawn inside the parcels. Shapes are relative to the parcel position.
class ZoneService {
  ZoneService(this._api);

  final ApiService _api;

  /// Zones of all the parcels of a garden (one request for the plans).
  Future<List<Zone>> getZonesByGarden(int gardenId) async {
    final response = await _api.get('${AppConstants.gardensEndpoint}/$gardenId/zones') as List;
    return response.map((json) => Zone.fromJson(json)).toList();
  }

  /// A new zone has no name : its name is automatic (see ZoneNames).
  Future<Zone> createZone(int parcelId, {required List<Offset> shape}) async {
    final response = await _api.post('${AppConstants.parcelsEndpoint}/$parcelId/zones', {
      'shape': shapeToJson(shape),
    });
    return Zone.fromJson(response);
  }

  /// [name] null : back to the automatic name.
  Future<Zone> renameZone(int id, String? name) async {
    return Zone.fromJson(await _api.patch('${AppConstants.zonesEndpoint}/$id', {'name': name}));
  }

  Future<Zone> updateZone(int id, {required List<Offset> shape}) async {
    final response = await _api.patch('${AppConstants.zonesEndpoint}/$id', {
      'shape': shapeToJson(shape),
    });
    return Zone.fromJson(response);
  }

  /// Its crops stay in the parcel, without zone.
  Future<void> deleteZone(int id) => _api.delete('${AppConstants.zonesEndpoint}/$id');

  /// Plants to sow / plant in the zone for [month] (1-12), best first. Computed by the server.
  Future<ParcelSuggestions> getSuggestions(int zoneId, int month) async {
    return ParcelSuggestions.fromJson(await _api.get('${AppConstants.zonesEndpoint}/$zoneId/suggestions?month=$month'));
  }
}
