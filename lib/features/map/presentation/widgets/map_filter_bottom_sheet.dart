import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/dog_model.dart'; // Added
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../features/subscriptions/presentation/screens/paywall_screen.dart';
import '../providers/map_provider.dart';

class MapFilterBottomSheet extends ConsumerWidget {
  const MapFilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch current user profile to check Premium status
    final userAsync = ref.watch(currentUserProfileProvider);
    final isPremium = userAsync.value?.isPremium ?? false;
    
    final mapState = ref.watch(mapControllerProvider);
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filtra Mappa',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (mapState.filterBreed != null || mapState.filterGender != null)
                TextButton(
                  onPressed: () {
                    ref.read(mapControllerProvider.notifier).clearFilters();
                    Navigator.pop(context);
                  },
                  child: const Text('Resetta'),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // --- Custom User Filter (Species) ---
          Text('Specie', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
             spacing: 8,
             children: [
                _buildSpeciesChip(context, ref, mapState, null, 'Tutti'),
                _buildSpeciesChip(context, ref, mapState, PetSpecies.dog, 'Cani'),
                _buildSpeciesChip(context, ref, mapState, PetSpecies.cat, 'Gatti'),
             ],
          ),
          const SizedBox(height: 24),
          
          if (!isPremium) ...[
             _buildLockedFeature(context, 'Filtri Avanzati Disponibili con Premium'),
             const SizedBox(height: 24),
             SizedBox(
               width: double.infinity,
               child: ElevatedButton.icon(
                 onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => const PaywallScreen())
                    );
                 },
                 icon: const Icon(Icons.star),
                 label: const Text('Sblocca Filtri'),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.amber,
                   foregroundColor: Colors.white,
                 ),
               ),
             ),
             const SizedBox(height: 12),
           ],
          

          // --- Premium Filters UI ---
          Opacity(
            opacity: isPremium ? 1.0 : 0.5,
            child: IgnorePointer(
              ignoring: !isPremium,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Dog Size
                   Text('Taglia del Cane', style: Theme.of(context).textTheme.titleMedium),
                   const SizedBox(height: 12),
                   Wrap(
                     spacing: 8,
                     children: DogSize.values.map((size) {
                        final isSelected = mapState.filterDogSizes.contains(size);
                        return FilterChip(
                          label: Text(size.displayName),
                          selected: isSelected,
                          onSelected: (selected) {
                             final newSizes = List<DogSize>.from(mapState.filterDogSizes);
                             if (selected) {
                               newSizes.add(size);
                             } else {
                               newSizes.remove(size);
                             }
                             ref.read(mapControllerProvider.notifier).setDogFilters(sizes: newSizes);
                          },
                          checkedIcon: const Icon(Icons.check, size: 18),
                        );
                     }).toList(),
                   ),
                   const SizedBox(height: 24),

                   // Dog Gender
                   Text('Sesso del Cane', style: Theme.of(context).textTheme.titleMedium),
                   const SizedBox(height: 12),
                   Wrap(
                     spacing: 8,
                     children: DogGender.values.map((gender) {
                        final isSelected = mapState.filterDogGenders.contains(gender);
                        return FilterChip(
                          label: Text(gender.displayName),
                          selected: isSelected,
                          onSelected: (selected) {
                             final newGenders = List<DogGender>.from(mapState.filterDogGenders);
                             if (selected) {
                               newGenders.add(gender);
                             } else {
                               newGenders.remove(gender);
                             }
                             ref.read(mapControllerProvider.notifier).setDogFilters(genders: newGenders);
                          },
                          checkedIcon: const Icon(Icons.check, size: 18),
                        );
                     }).toList(),
                   ),
                   const SizedBox(height: 24),
                   
                   // Dog Breed (Simple Text Filter for now)
                   Text('Razza', style: Theme.of(context).textTheme.titleMedium),
                   const SizedBox(height: 12),
                   TextField(
                     decoration: InputDecoration(
                       hintText: 'Cerca razza (es. Labrador)...',
                       prefixIcon: const Icon(Icons.search),
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                       contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                     ),
                     onChanged: (value) {
                       // Debounce ideally, but for now updates on typing
                       // We treat non-empty string as a single filter item for simplicity in this UI
                       // If empty, clear list.
                       final list = value.trim().isEmpty ? <String>[] : [value.trim()];
                       ref.read(mapControllerProvider.notifier).setDogFilters(breeds: list);
                     },
                     // If existing filter, populate it? 
                     // Hard with TextField. Just simpler to be a search bar.
                   ),
                   if (mapState.filterDogBreeds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          "Filtro attivo: ${mapState.filterDogBreeds.join(', ')}",
                          style: const TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  
  Widget _buildLockedFeature(BuildContext context, String text) {
     return Container(
       padding: const EdgeInsets.all(12),
       decoration: BoxDecoration(
         color: Colors.amber.withOpacity(0.1),
         borderRadius: BorderRadius.circular(8),
         border: Border.all(color: Colors.amber),
       ),
       child: Row(
         children: [
           const Icon(Icons.lock, color: Colors.amber),
           const SizedBox(width: 12),
           Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber))),
         ],
       ),
     );
  }

  Widget _buildGenderChip(BuildContext context, WidgetRef ref, MapState state, Gender? value, String label) {
    final isSelected = state.filterGender == value;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isSelected 
        ? AppColors.primary 
        : (isDarkMode ? Colors.white : Colors.black87);
        
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
           ref.read(mapControllerProvider.notifier).setFilters(
             gender: value,
             breed: state.filterBreed,
           );
        }
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      backgroundColor: isDarkMode ? Colors.grey[800] : null,
      labelStyle: TextStyle(
        color: textColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
  Widget _buildSpeciesChip(BuildContext context, WidgetRef ref, MapState state, PetSpecies? value, String label) {
    final isSelected = state.filterPetSpecies == value;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isSelected 
        ? AppColors.primary 
        : (isDarkMode ? Colors.white : Colors.black87);
        
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
           ref.read(mapControllerProvider.notifier).setPetSpeciesFilter(value);
        } else {
           // Deselecting applies null (Tutti) ONLY if we are clicking a specific one?
           // ChoiceChip behavior: toggle. If we unselect, we go back to null?
           // But 'Tutti' implies null.
           if (value != null) {
              ref.read(mapControllerProvider.notifier).setPetSpeciesFilter(null);
           }
        }
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      backgroundColor: isDarkMode ? Colors.grey[800] : null,
      labelStyle: TextStyle(
        color: textColor,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
