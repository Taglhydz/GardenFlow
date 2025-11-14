import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/garden_service.dart';
import '../models/garden.dart';
import '../config/constants.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _gardenService = GardenService();
  List<Garden> _gardens = [];
  Garden? _selectedGarden;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGardens();
  }

  Future<void> _loadGardens() async {
    try {
      final gardens = await _gardenService.getAllGardens();
      final prefs = await SharedPreferences.getInstance();
      final lastGardenId = prefs.getInt('last_garden_id');

      if (mounted) {
        setState(() {
          _gardens = gardens;
          
          // Si un seul jardin, le sélectionner automatiquement
          if (gardens.length == 1) {
            _selectedGarden = gardens.first;
            _saveLastGarden(gardens.first.id!);
          } 
          // Si plusieurs jardins et qu'un dernier jardin existe, le charger
          else if (gardens.length > 1 && lastGardenId != null) {
            _selectedGarden = gardens.firstWhere(
              (g) => g.id == lastGardenId,
              orElse: () => gardens.first,
            );
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _saveLastGarden(int gardenId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_garden_id', gardenId);
  }

  void _selectGarden(Garden garden) {
    setState(() => _selectedGarden = garden);
    _saveLastGarden(garden.id!);
  }

  Future<void> _showCreateGardenDialog() async {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créer un jardin'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du jardin *',
                  hintText: 'Mon potager',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Localisation',
                  hintText: 'Paris, France',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Un petit jardin ensoleillé...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Le nom est obligatoire')),
                );
                return;
              }

              try {
                // Récupérer l'ID utilisateur depuis le profil
                final prefs = await SharedPreferences.getInstance();
                final userId = prefs.getInt('user_id');
                
                if (userId == null) {
                  throw Exception('Utilisateur non trouvé');
                }

                final newGarden = Garden(
                  userId: userId,
                  name: nameController.text.trim(),
                  location: locationController.text.trim().isEmpty 
                      ? null 
                      : locationController.text.trim(),
                  description: descriptionController.text.trim().isEmpty 
                      ? null 
                      : descriptionController.text.trim(),
                );

                await _gardenService.createGarden(newGarden);
                
                if (context.mounted) {
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Jardin créé avec succès !'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (result == true) {
      _loadGardens();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Afficher le jardin sélectionné
    if (_selectedGarden != null) {
      return _buildGardenView();
    }

    // Afficher la sélection/création de jardin
    return _buildGardenSelectionView();
  }

  Widget _buildGardenView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Titre "GardenFlow" aux 3/4 de la hauteur
          Positioned(
            top: MediaQuery.of(context).size.height * 0.25 - 30,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'GardenFlow',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          // Contenu principal
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.yard,
                  size: 80,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  _selectedGarden!.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_selectedGarden!.description != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _selectedGarden!.description!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
                if (_selectedGarden!.location != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _selectedGarden!.location!,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                const Text(
                  'Vue du jardin à venir...',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          // Icône maison en haut à gauche
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.home_outlined, color: AppColors.primary, size: 28),
              onPressed: () {
                setState(() => _selectedGarden = null);
              },
              tooltip: 'Mes jardins',
            ),
          ),
          // Boutons en haut à droite
          Positioned(
            top: 47,
            right: 8,
            child: Row(
              children: [
                // Bouton profil
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
                    icon: const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfileScreen()),
                      );
                    },
                    tooltip: 'Profil',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGardenSelectionView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Titre "GardenFlow" aux 3/4 de la hauteur
          Positioned(
            top: MediaQuery.of(context).size.height * 0.25 - 30,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'GardenFlow',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          // Contenu principal
          _gardens.isEmpty ? _buildNoGardenView() : _buildGardenListView(),
          // Icône maison en haut à gauche
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.home_outlined, color: AppColors.primary, size: 28),
              onPressed: () {
                // Déjà sur la page d'accueil, ne rien faire
              },
              tooltip: 'Accueil',
            ),
          ),
          // Icône profil en haut à droite
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
                tooltip: 'Profil',
              ),
            ),
          ),
        ],
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
            const Text(
              'Aucun jardin pour le moment',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Créez votre premier jardin pour commencer',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showCreateGardenDialog,
              icon: const Icon(Icons.add),
              label: const Text('Créer un jardin'),
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

  Widget _buildGardenListView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Sélectionnez un jardin',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _gardens.length,
            itemBuilder: (context, index) {
              final garden = _gardens[index];
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
                    child: Icon(
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
                  onTap: () => _selectGarden(garden),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showCreateGardenDialog,
              icon: const Icon(Icons.add),
              label: const Text('Créer un nouveau jardin'),
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
