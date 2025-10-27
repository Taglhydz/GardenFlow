import 'package:flutter/material.dart';
import '../models/garden.dart';
import '../services/garden_service.dart';
import '../config/constants.dart';
import '../widgets/garden_card.dart';

class GardensScreen extends StatefulWidget {
  const GardensScreen({super.key});

  @override
  State<GardensScreen> createState() => _GardensScreenState();
}

class _GardensScreenState extends State<GardensScreen> {
  final _gardenService = GardenService();
  List<Garden> _gardens = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGardens();
  }

  Future<void> _loadGardens() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final gardens = await _gardenService.getAllGardens();
      setState(() {
        _gardens = gardens;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Jardins'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur: $_error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadGardens,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _gardens.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.yard,
                            size: 64,
                            color: AppColors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucun jardin pour le moment',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppColors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Naviguer vers formulaire de création
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Création de jardin à venir...'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Créer mon premier jardin'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadGardens,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _gardens.length,
                        itemBuilder: (context, index) {
                          return GardenCard(garden: _gardens[index]);
                        },
                      ),
                    ),
      floatingActionButton: _gardens.isNotEmpty
          ? FloatingActionButton(
              onPressed: () {
                // TODO: Naviguer vers formulaire de création
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Création de jardin à venir...'),
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
