import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/gardener_level.dart';
import 'auth_provider.dart';
import 'core_providers.dart';

/// Level of the logged in gardener. Invalidated when their crops change (see GardenCropsNotifier).
final levelProvider = FutureProvider<GardenerLevel?>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return null;
  return ref.read(userServiceProvider).getMyLevel();
});

/// Photo taken with the camera or chosen in the gallery, already resized.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.filename, required this.contentType});

  final List<int> bytes;
  final String filename;
  final String contentType;
}

/// Opens the camera or the gallery. Replaced by a fake in the tests.
class PhotoPicker {
  const PhotoPicker();

  /// Big enough for a profile picture, small enough to be sent quickly (the server accepts 2 MB)
  static const maxSize = 512.0;

  /// The camera is not available everywhere (desktop)
  bool get canUseCamera => ImagePicker().supportsImageSource(ImageSource.camera);

  /// Null when the user cancels.
  Future<PickedPhoto?> pick({required bool camera}) async {
    final file = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: maxSize,
      maxHeight: maxSize,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null) return null;

    final name = file.name.toLowerCase();
    final contentType = file.mimeType ??
        (name.endsWith('.png') ? 'image/png' : name.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
    return PickedPhoto(bytes: await file.readAsBytes(), filename: file.name, contentType: contentType);
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => const PhotoPicker());

/// Changes the picture of the logged in user : the new user replaces the old one everywhere.
final profilePictureProvider = Provider<ProfilePicture>(ProfilePicture.new);

class ProfilePicture {
  ProfilePicture(this._ref);

  final Ref _ref;

  Future<void> setAvatar(String avatar) async {
    _ref.read(authProvider.notifier).updateUser(await _ref.read(userServiceProvider).setAvatar(avatar));
  }

  Future<void> uploadPhoto(PickedPhoto photo) async {
    final user = await _ref
        .read(userServiceProvider)
        .uploadPhoto(photo.bytes, filename: photo.filename, contentType: photo.contentType);
    _ref.read(authProvider.notifier).updateUser(user);
  }

  Future<void> remove() async {
    final user = _ref.read(authProvider).value;
    if (user == null) return;
    _ref.read(authProvider.notifier).updateUser(await _ref.read(userServiceProvider).removePicture(user));
  }
}
