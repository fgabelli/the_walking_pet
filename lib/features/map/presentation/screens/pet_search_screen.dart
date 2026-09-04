
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../providers/map_provider.dart';
import '../../../../core/services/dog_service.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/dog_provider.dart';

class PetSearchScreen extends ConsumerStatefulWidget {
  const PetSearchScreen({super.key});

  @override
  ConsumerState<PetSearchScreen> createState() => _PetSearchScreenState();
}

class _PetSearchScreenState extends ConsumerState<PetSearchScreen> {
  bool _isLoading = true;
  List<DogModel> _results = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  Future<void> _performSearch() async {
    final mapState = ref.read(mapControllerProvider);
    final dogService = ref.read(dogServiceProvider);

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Build Query Filters based on MapState
      // Note: We are searching the DOGS collection directly
      final dogs = await dogService.searchDogs(
        species: mapState.filterPetSpecies,
        sizes: mapState.filterDogSizes, // List
        genders: mapState.filterDogGenders, // List
        breedQuery: mapState.filterDogBreeds.isNotEmpty ? mapState.filterDogBreeds.first : null, // Taking first for now
      );
      
      // 2. Client-side filtering if needed (e.g. detailed breed check if searchDogs is broad)
      // Done in service ideally.
      
      setState(() {
        _results = dogs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Errore ricerca: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ricerca Pet'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('Nessun pet trovato con questi filtri.'),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              ref.read(mapControllerProvider.notifier).clearDogFilters();
                              _performSearch();
                            },
                            child: const Text('Resetta Filtri'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final dog = _results[index];
                        return _buildDogCard(dog);
                      },
                    ),
    );
  }

  Widget _buildDogCard(DogModel dog) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
           // Navigate to Owner Profile
           Navigator.push(
             context, 
             MaterialPageRoute(
            settings: const RouteSettings(name: 'profile'),
               builder: (_) => ProfileScreen(userId: dog.ownerId),
             ),
           );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 30,
                backgroundImage: dog.photoUrl != null 
                    ? NetworkImage(dog.photoUrl!) 
                    : null,
                child: dog.photoUrl == null 
                    ? const Icon(Icons.pets, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dog.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dog.breed} • ${dog.age != null ? "${dog.age} anni" : ""}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    // Species/Gender Badges could go here
                     Row(
                       children: [
                         if (dog.species != null)
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                             margin: const EdgeInsets.only(right: 4),
                             decoration: BoxDecoration(
                               color: AppColors.primary.withOpacity(0.1),
                               borderRadius: BorderRadius.circular(4),
                             ),
                             child: Text(
                               dog.species == PetSpecies.dog ? 'Cane' : dog.species == PetSpecies.cat ? 'Gatto' : 'Altro',
                               style: const TextStyle(fontSize: 10, color: AppColors.primary),
                             ),
                           ),
                         if (dog.gender != null)
                             Icon(
                               dog.gender == DogGender.male ? Icons.male : Icons.female,
                               size: 16,
                               color: dog.gender == DogGender.male ? Colors.blue : Colors.pink,
                             ),
                       ],
                     )
                  ],
                ),
              ),
              
              // Arrow
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
