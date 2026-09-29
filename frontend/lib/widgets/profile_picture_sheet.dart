import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/app_localizations.dart';
import '../config/avatars.dart';
import '../config/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_providers.dart';

/// Changes the profile picture : a photo (camera or gallery), a plant avatar, or none.
///   ProfilePictureSheet.show(context);
class ProfilePictureSheet extends ConsumerStatefulWidget {
  const ProfilePictureSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ProfilePictureSheet(),
    );
  }

  @override
  ConsumerState<ProfilePictureSheet> createState() => _ProfilePictureSheetState();
}

class _ProfilePictureSheetState extends ConsumerState<ProfilePictureSheet> {
  bool _saving = false;

  /// Saves the change, then closes the sheet ; stays open with a message when it fails.
  Future<void> _save(Future<void> Function() change) async {
    setState(() => _saving = true);
    try {
      await change();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.errorMessage(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _pickPhoto({required bool camera}) async {
    final photo = await ref.read(photoPickerProvider).pick(camera: camera);
    if (photo == null || !mounted) return; // cancelled
    await _save(() => ref.read(profilePictureProvider).uploadPhoto(photo));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final picker = ref.watch(photoPickerProvider);
    final hasPicture = user?.photo != null || user?.avatar != null;

    return AbsorbPointer(
      absorbing: _saving,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'profile_picture.title'.tr(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_saving) const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 8),
            if (picker.canUseCamera)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
                title: Text('profile_picture.take_photo'.tr()),
                onTap: () => _pickPhoto(camera: true),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: Text('profile_picture.from_gallery'.tr()),
              onTap: () => _pickPhoto(camera: false),
            ),
            const SizedBox(height: 8),
            Text('profile_picture.choose_avatar'.tr(), style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final code in Avatars.codes)
                  Tooltip(
                    message: 'avatars.$code'.tr(),
                    child: InkResponse(
                      onTap: () => _save(() => ref.read(profilePictureProvider).setAvatar(code)),
                      radius: 32,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: user?.avatar == code ? AppColors.primary : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: SvgPicture.asset(Avatars.asset(code), width: 56, height: 56),
                      ),
                    ),
                  ),
              ],
            ),
            if (hasPicture) ...[
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: Text('profile_picture.remove'.tr(), style: const TextStyle(color: AppColors.error)),
                onTap: () => _save(() => ref.read(profilePictureProvider).remove()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
