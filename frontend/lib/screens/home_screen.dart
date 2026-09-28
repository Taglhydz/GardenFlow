import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/garden.dart';
import '../providers/auth_provider.dart';
import '../providers/garden_providers.dart';
import '../widgets/create_garden_dialog.dart';
import '../widgets/garden_mini_map.dart';
import '../widgets/welcome_dialog.dart';
import 'garden_view.dart';
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
      return GardenView(
        key: ValueKey(selectedGarden.id),
        garden: selectedGarden,
        onHome: () => ref.read(selectedGardenIdProvider.notifier).select(null),
        onProfile: _openProfile,
      );
    }

    // Afficher la sélection/création de jardin
    return _buildGardenSelectionView(gardensAsync.value!);
  }

  /// Page with the header on top : nothing is hidden behind the buttons.
  Widget _buildPage(Widget content) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  /// House icon on the left (already on the home page : does nothing), "GardenFlow" in the middle,
  /// profile on the right.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: AppColors.primary, size: 28),
            onPressed: () {},
            tooltip: 'home.title'.tr(),
          ),
          Expanded(
            child: Text(
              'app_name'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
              onPressed: _openProfile,
              tooltip: 'profile.title'.tr(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return _buildPage(
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
    );
  }

  Widget _buildGardenSelectionView(List<Garden> gardens) {
    return _buildPage(gardens.isEmpty ? _buildNoGardenView() : _buildGardenListView(gardens));
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
                return _GardenCard(
                  garden: gardens[index],
                  onTap: () => ref.read(selectedGardenIdProvider.notifier).select(gardens[index].id),
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

/// A garden of the list : its name at the top, its mini plan (~3 cm) on the left,
/// its place and description on the right.
class _GardenCard extends StatelessWidget {
  const _GardenCard({required this.garden, required this.onTap});

  final Garden garden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      garden.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.grey),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GardenMiniMap(gardenId: garden.id),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (garden.location != null) ...[
                          Row(
                            children: [
                              Icon(Icons.place_outlined, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  garden.location!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          garden.description ?? 'home.no_description'.tr(),
                          maxLines: 8,
                          overflow: TextOverflow.ellipsis,
                          style: garden.description != null
                              ? const TextStyle(fontSize: 14)
                              : TextStyle(fontSize: 14, color: Colors.grey[500], fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
