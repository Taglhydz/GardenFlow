import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/constants.dart';
import '../models/garden.dart';
import '../providers/auth_provider.dart';
import '../providers/garden_providers.dart';
import '../widgets/create_garden_dialog.dart';
import '../widgets/plan_entrance.dart';
import '../widgets/garden_mini_map.dart';
import '../widgets/welcome_dialog.dart';
import 'garden_view.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  bool _autoSelectChecked = false;

  /// Opening of the garden (see PlanEntrance), played backwards when it closes
  late final AnimationController _entrance = AnimationController(vsync: this, duration: PlanEntrance.duration);

  /// Garden on the screen : still shown while it closes
  Garden? _shownGarden;

  /// Mini plan of each card : the garden grows out of it and shrinks back into it
  final _miniMapKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    // garden remembered from the last session : shown right away
    _shownGarden = ref.read(selectedGardenProvider);
    if (_shownGarden != null) _entrance.value = 1;

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

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _onSelectedGarden(Garden? previous, Garden? next) {
    if (next != null) {
      setState(() => _shownGarden = next);
      if (previous == null) _entrance.forward();
    } else if (_shownGarden != null) {
      _entrance.reverse().whenComplete(() {
        if (mounted && ref.read(selectedGardenProvider) == null) setState(() => _shownGarden = null);
      });
    }
  }

  Rect? _miniMapRect(int gardenId) {
    final box = _miniMapKeys[gardenId]?.currentContext?.findRenderObject() as RenderBox?;
    return box != null && box.hasSize && box.attached ? box.localToGlobal(Offset.zero) & box.size : null;
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
    ref.listen<Garden?>(selectedGardenProvider, _onSelectedGarden);

    final gardensAsync = ref.watch(gardensProvider);
    final garden = _shownGarden;

    if (!gardensAsync.hasValue) {
      return gardensAsync.hasError
          ? _buildErrorView()
          : const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // the list stays below the garden (hidden once it is open) : the mini plans stay where they are
    // for the garden to shrink back into them, and the list keeps its scroll position
    final list = _buildGardenSelectionView(gardensAsync.value!);
    final gardenView = garden == null
        ? null
        : PlanEntrance(
            animation: _entrance,
            from: () => _miniMapRect(garden.id),
            child: GardenView(
              key: ValueKey(garden.id),
              garden: garden,
              onHome: () => ref.read(selectedGardenIdProvider.notifier).select(null),
              onProfile: _openProfile,
            ),
          );

    return ColoredBox(
      color: AppColors.background,
      child: AnimatedBuilder(
        animation: _entrance,
        builder: (context, _) {
          final t = _entrance.value;
          return Stack(
            children: [
              Positioned.fill(
                child: Offstage(
                  offstage: gardenView != null && t == 1,
                  child: IgnorePointer(
                    ignoring: gardenView != null,
                    // the list fades out while the plan grows
                    child: Opacity(opacity: 1 - const Interval(0.2, 0.8).transform(t), child: list),
                  ),
                ),
              ),
              if (gardenView != null) Positioned.fill(child: gardenView),
            ],
          );
        },
      ),
    );
  }

  /// Page with the header on top : nothing is hidden behind the buttons.
  Widget _buildPage(Widget content, {Widget? floatingActionButton}) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: floatingActionButton,
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
    if (gardens.isEmpty) return _buildPage(_buildNoGardenView());

    return _buildPage(
      _buildGardenListView(gardens),
      floatingActionButton: FloatingActionButton(
        // the list stays below an open garden : its button needs its own tag
        heroTag: 'create_garden',
        onPressed: _createGarden,
        tooltip: 'home.create_new_garden'.tr(),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
    );
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
    return RefreshIndicator(
      onRefresh: () => ref.refresh(gardensProvider.future),
      child: ListView.builder(
        // bottom space : the last card is not hidden behind the + button
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: gardens.length,
        itemBuilder: (context, index) {
          return _GardenCard(
            garden: gardens[index],
            miniMapKey: _miniMapKeys.putIfAbsent(gardens[index].id, GlobalKey.new),
            onTap: () => ref.read(selectedGardenIdProvider.notifier).select(gardens[index].id),
          );
        },
      ),
    );
  }
}

/// A garden of the list : its name at the top, its mini plan (~3 cm) on the left,
/// its place and description on the right.
class _GardenCard extends StatelessWidget {
  const _GardenCard({required this.garden, required this.miniMapKey, required this.onTap});

  final Garden garden;

  /// The garden grows out of its mini plan when it opens
  final GlobalKey miniMapKey;
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
                  GardenMiniMap(key: miniMapKey, gardenId: garden.id),
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
