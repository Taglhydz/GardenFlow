import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_localizations.dart';
import '../config/constants.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/garden_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/level_badge.dart';
import '../widgets/profile_picture_sheet.dart';
import '../widgets/user_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('profile.logout_title'.tr()),
        content: Text('profile.logout_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('profile.logout_action'.tr()),
          ),
        ],
      ),
    );

    // AuthGate closes this screen and shows the login screen
    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  /// Everything is deleted for good : the dialog says it clearly, the red button is the only way to confirm.
  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 40),
        title: Text('profile.delete_account_title'.tr()),
        content: Text('profile.delete_account_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('profile.delete_account_action'.tr()),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    // AuthGate closes this screen and shows the login screen
    try {
      await ref.read(authProvider.notifier).deleteAccount();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.errorMessage(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _chooseLanguage(BuildContext context) async {
    final locale = await showModalBottomSheet<Locale>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'profile.choose_language'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            for (final supported in context.supportedLocales)
              ListTile(
                leading: const Icon(Icons.language),
                title: Text('language_${supported.languageCode}'.tr()),
                trailing: supported == context.locale
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, supported),
              ),
          ],
        ),
      ),
    );

    if (locale != null && context.mounted) {
      await context.setLocale(locale);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final gardenCount = ref.watch(gardensProvider).value?.length ?? 0;
    final level = ref.watch(levelProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Barre du haut : reste en place, le contenu défile en dessous
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // Flèche retour
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.primary, size: 28),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'back'.tr(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'profile.title'.tr(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  // Icône paramètres : choix de la langue
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.settings_outlined, color: AppColors.primary, size: 18),
                      onPressed: () => _chooseLanguage(context),
                      tooltip: 'settings'.tr(),
                    ),
                  ),
                ],
              ),
            ),
            // Contenu principal
            Expanded(
              child: user == null
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Photo de profil à gauche avec username et nombre de jardins à droite
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Photo de profil avec icône crayon : la touche change la photo ou l'avatar
                              Tooltip(
                                message: 'profile_picture.title'.tr(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => ProfilePictureSheet.show(context),
                                  child: Stack(
                                    children: [
                                      UserAvatar(user: user, size: 80),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.edit,
                                            size: 14,
                                            color: AppColors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Username et nombre de jardins
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.displayName,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.yard,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'profile.garden_count'.plural(gardenCount),
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Niveau : ancienneté et maîtrise du jardin
                          if (level != null) ...[
                            LevelCard(level: level),
                            const SizedBox(height: 16),
                          ],

                          // Informations
                          _buildInfoCard(context, user),
                          const SizedBox(height: 16),

                          // Bouton de déconnexion
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _logout(context, ref),
                              icon: const Icon(Icons.logout),
                              label: Text('logout'.tr()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: AppColors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Suppression du compte : discrète, sous la déconnexion
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () => _deleteAccount(context, ref),
                              icon: const Icon(Icons.delete_forever_outlined),
                              label: Text('profile.delete_account'.tr()),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, User user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'profile.information'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.person,
              label: 'username'.tr(),
              value: user.displayName,
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: Icons.email,
              label: 'email'.tr(),
              value: user.email,
            ),
            if (user.birthdate != null) ...[
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.cake,
                label: 'birthdate'.tr(),
                value: MaterialLocalizations.of(context).formatMediumDate(user.birthdate!),
              ),
            ],
            if (user.isAdmin) ...[
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.shield,
                label: 'profile.role'.tr(),
                value: AppLocalizations.getRoleLabel(user.role),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.greyDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
