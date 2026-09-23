import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/garden.dart';
import '../providers/auth_provider.dart';
import '../providers/garden_providers.dart';
import '../widgets/create_garden_dialog.dart';
import '../widgets/welcome_dialog.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _autoSelectChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // pop-up de bienvenue après une inscription
      if (ref.read(welcomePendingProvider.notifier).consume()) {
        WelcomeDialog.show(context);
      }

      final gardens = ref.read(gardensProvider).value;
      if (gardens != null) _autoSelectSingleGarden(gardens);
    });
  }

  /// Au premier chargement : si un seul jardin et aucun jardin mémorisé, l'ouvrir directement.
  void _autoSelectSingleGarden(List<Garden> gardens) {
    if (_autoSelectChecked) return;
    _autoSelectChecked = true;

    if (gardens.length == 1 && ref.read(selectedGardenIdProvider) == null) {
      ref.read(selectedGardenIdProvider.notifier).select(gardens.first.id);
    }
  }

  Future<void> _createGarden() async {
    final created = await CreateGardenDialog.show(context);
    if (created && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('home.garden_created'.tr()),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gardensProvider, (_, next) {
      if (next.hasValue) _autoSelectSingleGarden(next.value!);
    });

    final gardensAsync = ref.watch(gardensProvider);
    final selectedGarden = ref.watch(selectedGardenProvider);

    if (!gardensAsync.hasValue) {
      return gardensAsync.hasError
          ? _buildErrorView()
          : const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Afficher le jardin sélectionné
    if (selectedGarden != null) {
      return _buildGardenView(selectedGarden);
    }

    // Afficher la sélection/création de jardin
    return _buildGardenSelectionView(gardensAsync.value!);
  }

  Widget _buildErrorView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 24),
                  Text(
                    'home.load_error'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(gardensProvider),
                    icon: const Icon(Icons.refresh),
                    label: Text('retry'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ..._buildTopButtons(onHome: null),
        ],
      ),
    );
  }

  Widget _buildGardenView(Garden garden) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildTitle(),
          // Contenu principal
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.yard,
                  size: 80,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  garden.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (garden.description != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      garden.description!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
                if (garden.location != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        garden.location!,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                Text(
                  'home.garden_view_coming'.tr(),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          // retour à la liste des jardins
          ..._buildTopButtons(onHome: () => ref.read(selectedGardenIdProvider.notifier).select(null)),
        ],
      ),
    );
  }

  Widget _buildGardenSelectionView(List<Garden> gardens) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildTitle(),
          // Contenu principal
          gardens.isEmpty ? _buildNoGardenView() : _buildGardenListView(gardens),
          // Déjà sur la page d'accueil : le bouton maison ne fait rien
          ..._buildTopButtons(onHome: null),
        ],
      ),
    );
  }

  /// Titre "GardenFlow" au quart de la hauteur
  Widget _buildTitle() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.25 - 30,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          'app_name'.tr(),
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  /// Icône maison en haut à gauche, icône profil en haut à droite.
  List<Widget> _buildTopButtons({required VoidCallback? onHome}) {
    return [
      Positioned(
        top: 40,
        left: 16,
        child: IconButton(
          icon: const Icon(Icons.home_outlined, color: AppColors.primary, size: 28),
          onPressed: onHome ?? () {},
          tooltip: onHome != null ? 'my_gardens'.tr() : 'home.title'.tr(),
        ),
      ),
      Positioned(
        top: 47,
        right: 16,
        child: Container(
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
            icon: const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
            onPressed: _openProfile,
            tooltip: 'profile.title'.tr(),
          ),
        ),
      ),
    ];
  }

  Widget _buildNoGardenView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.yard_outlined,
              size: 100,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'home.no_garden_title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'home.no_garden_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _createGarden,
              icon: const Icon(Icons.add),
              label: Text('home.create_garden'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGardenListView(List<Garden> gardens) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'home.select_garden'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(gardensProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: gardens.length,
              itemBuilder: (context, index) {
                final garden = gardens[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.yard,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      garden.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: garden.description != null
                        ? Text(
                            garden.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => ref.read(selectedGardenIdProvider.notifier).select(garden.id),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _createGarden,
              icon: const Icon(Icons.add),
              label: Text('home.create_new_garden'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
