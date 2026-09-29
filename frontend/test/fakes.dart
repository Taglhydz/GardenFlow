// In-memory services used by the tests instead of the real API.
import 'dart:ui';
import 'package:GardenFlow/models/crop.dart';
import 'package:GardenFlow/models/garden.dart';
import 'package:GardenFlow/models/gardener_level.dart';
import 'package:GardenFlow/models/parcel.dart';
import 'package:GardenFlow/models/plant.dart';
import 'package:GardenFlow/models/plant_association.dart';
import 'package:GardenFlow/models/suggestion.dart';
import 'package:GardenFlow/models/user.dart';
import 'package:GardenFlow/models/zone.dart';
import 'package:GardenFlow/providers/profile_providers.dart';
import 'package:GardenFlow/services/api_service.dart';
import 'package:GardenFlow/services/auth_service.dart';
import 'package:GardenFlow/services/crop_service.dart';
import 'package:GardenFlow/services/garden_service.dart';
import 'package:GardenFlow/services/parcel_service.dart';
import 'package:GardenFlow/services/plant_service.dart';
import 'package:GardenFlow/services/user_service.dart';
import 'package:GardenFlow/services/zone_service.dart';
import 'package:GardenFlow/utils/geometry.dart';

const alice = User(id: 1, username: 'alice', email: 'alice@test.dev');

class FakeAuthService implements AuthService {
  /// What restoreSession returns (a User, null, or an exception to throw)
  Object? restoreResult;
  bool loggedOut = false;

  @override
  Future<User?> restoreSession() async {
    final result = restoreResult;
    if (result is Exception) throw result;
    return result as User?;
  }

  @override
  Future<User> login({required String email, required String password}) async {
    if (password != 'good') {
      throw ApiException(statusCode: 401, code: 'INVALID_CREDENTIALS', message: 'wrong');
    }
    return alice;
  }

  @override
  Future<User> register({required String username, required String email, required String password, DateTime? birthdate}) async => alice;

  @override
  Future<void> logout() async => loggedOut = true;
}

class FakeGardenService implements GardenService {
  List<Garden> gardens = [];

  @override
  Future<List<Garden>> getMyGardens() async => gardens;

  @override
  Future<Garden> createGarden({required String name, String? location, String? description}) async {
    final garden = Garden(id: 100 + gardens.length, userId: alice.id, name: name);
    gardens = [...gardens, garden];
    return garden;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeParcelService implements ParcelService {
  List<Parcel> parcels = [];

  /// Returned by getSuggestions
  List<Suggestion> suggestions = [];

  /// Every PATCH sent : (id, changes)
  final updates = <(int, Map<String, dynamic>)>[];

  /// Every POST sent
  final created = <Map<String, dynamic>>[];

  Parcel _fromFields(int id, int gardenId, Map<String, dynamic> f, [Parcel? base]) {
    double? d(String key) => (f[key] as num?)?.toDouble();
    final shape = f['shape'] != null ? shapeFromJson(f['shape']) : base?.shape ?? const <Offset>[];
    return Parcel(
      id: id,
      gardenId: gardenId,
      name: f['name'] as String? ?? base?.name ?? '',
      posX: d('pos_x') ?? base?.posX ?? 0,
      posY: d('pos_y') ?? base?.posY ?? 0,
      shape: shape,
      areaM2: Geometry.area(shape),
      soilType: f['soil_type'] as String? ?? base?.soilType ?? 'standard',
      sunlight: f['sunlight'] as String? ?? base?.sunlight ?? 'medium',
      moisture: f['moisture'] as String? ?? base?.moisture ?? 'medium',
    );
  }

  @override
  Future<List<Parcel>> getParcelsByGarden(int gardenId) async => parcels.where((p) => p.gardenId == gardenId).toList();

  @override
  Future<Parcel> createParcel(int gardenId, Map<String, dynamic> fields) async {
    created.add(fields);
    final parcel = _fromFields(500 + parcels.length, gardenId, fields);
    parcels = [...parcels, parcel];
    return parcel;
  }

  @override
  Future<Parcel> updateParcel(int id, Map<String, dynamic> changes) async {
    updates.add((id, changes));
    final current = parcels.firstWhere((p) => p.id == id);
    final updated = _fromFields(id, current.gardenId, changes, current);
    parcels = [for (final p in parcels) p.id == id ? updated : p];
    return updated;
  }

  @override
  Future<void> deleteParcel(int id) async => parcels = parcels.where((p) => p.id != id).toList();

  @override
  Future<ParcelSuggestions> getSuggestions(int parcelId, int month) async =>
      ParcelSuggestions(parcelId: parcelId, month: month, suggestions: suggestions);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeZoneService implements ZoneService {
  List<Zone> zones = [];

  /// Returned by getSuggestions
  List<Suggestion> suggestions = [];

  /// Zone ids asked by getSuggestions
  final suggestionsAskedFor = <int>[];

  @override
  Future<List<Zone>> getZonesByGarden(int gardenId) async => zones;

  @override
  Future<Zone> createZone(int parcelId, {required List<Offset> shape}) async {
    final zone = Zone(id: 700 + zones.length, parcelId: parcelId, shape: shape, areaM2: Geometry.area(shape));
    zones = [...zones, zone];
    return zone;
  }

  @override
  Future<Zone> renameZone(int id, String? name) async {
    final current = zones.firstWhere((z) => z.id == id);
    final updated = Zone(id: id, parcelId: current.parcelId, name: name, shape: current.shape);
    zones = [for (final z in zones) z.id == id ? updated : z];
    return updated;
  }

  @override
  Future<Zone> updateZone(int id, {required List<Offset> shape}) async {
    final current = zones.firstWhere((z) => z.id == id);
    final updated = Zone(id: id, parcelId: current.parcelId, name: current.name, shape: shape);
    zones = [for (final z in zones) z.id == id ? updated : z];
    return updated;
  }

  @override
  Future<void> deleteZone(int id) async => zones = zones.where((z) => z.id != id).toList();

  @override
  Future<ParcelSuggestions> getSuggestions(int zoneId, int month) async {
    suggestionsAskedFor.add(zoneId);
    return ParcelSuggestions(parcelId: zones.firstWhere((z) => z.id == zoneId).parcelId, zoneId: zoneId, month: month, suggestions: suggestions);
  }
}

class FakeCropService implements CropService {
  List<Crop> crops = [];

  @override
  Future<List<Crop>> getCropsByGarden(int gardenId) async => crops;

  @override
  Future<Crop> createCrop(
    int parcelId, {
    int? zoneId,
    required int plantId,
    DateTime? sowDate,
    DateTime? expectedHarvestDate,
    DateTime? actualHarvestDate,
    String? comment,
  }) async {
    final crop = Crop(
      id: 900 + crops.length,
      parcelId: parcelId,
      zoneId: zoneId,
      plantId: plantId,
      sowDate: sowDate,
      expectedHarvestDate: expectedHarvestDate,
      actualHarvestDate: actualHarvestDate,
      comment: comment,
    );
    crops = [...crops, crop];
    return crop;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakePlantService implements PlantService {
  List<Plant> plants = const [
    Plant(id: 1, code: 'tomato', name: 'Tomate', family: 'solanaceae', daysToMaturity: 70),
    Plant(id: 2, code: 'basil', name: 'Basilic', type: 'herb', daysToMaturity: 60),
  ];

  @override
  Future<List<Plant>> getAllPlants() async => plants;

  @override
  Future<List<PlantAssociation>> getAllAssociations() async => const [];

  /// Hues chosen by the user, by plant id
  Map<int, int> colors = {};

  @override
  Future<Map<int, int>> getMyPlantColors() async => colors;

  @override
  Future<void> setPlantColor(int plantId, int hue) async => colors = {...colors, plantId: hue};

  @override
  Future<void> resetPlantColor(int plantId) async => colors = {...colors}..remove(plantId);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeUserService implements UserService {
  GardenerLevel level = const GardenerLevel(rank: 'seedling', points: 176, rankMin: 150, nextRank: 'gardener', nextRankMin: 350, planted: 6);

  /// Last photo sent (bytes)
  List<int>? uploaded;

  @override
  Future<GardenerLevel> getMyLevel() async => level;

  @override
  Future<User> setAvatar(String avatar) async => User(id: alice.id, username: alice.username, email: alice.email, avatar: avatar);

  @override
  Future<User> uploadPhoto(List<int> bytes, {required String filename, required String contentType}) async {
    uploaded = bytes;
    return User(id: alice.id, username: alice.username, email: alice.email, photo: '1-abc.jpg');
  }

  @override
  Future<User> removePicture(User user) async => alice;

  bool deleted = false;

  @override
  Future<void> deleteMe() async => deleted = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Camera and gallery without a device : returns [photo] (null = cancelled).
class FakePhotoPicker implements PhotoPicker {
  PickedPhoto? photo = const PickedPhoto(bytes: [1, 2, 3], filename: 'me.jpg', contentType: 'image/jpeg');
  bool camera = true;

  /// The source asked for the last photo (true = camera)
  bool? usedCamera;

  @override
  bool get canUseCamera => camera;

  @override
  Future<PickedPhoto?> pick({required bool camera}) async {
    usedCamera = camera;
    return photo;
  }
}
