import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
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

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
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
          
          // Filters UI (always visible to tease, but disabled if !isPremium)
          Opacity(
            opacity: isPremium ? 1.0 : 0.5,
            child: IgnorePointer(
              ignoring: !isPremium,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sesso', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildGenderChip(ref, mapState, null, 'Tutti'),
                      const SizedBox(width: 8),
                      _buildGenderChip(ref, mapState, Gender.male, 'Uomo'),
                      const SizedBox(width: 8),
                      _buildGenderChip(ref, mapState, Gender.female, 'Donna'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Ghost Mode Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Row(
                         children: [
                           const Icon(Icons.visibility_off, color: Colors.grey),
                           const SizedBox(width: 8),
                           Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               const Text('Ghost Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                               Text('Diventa invisibile sulla mappa', style: Theme.of(context).textTheme.bodySmall),
                             ],
                           ),
                         ],
                       ),
                       Switch(
                         value: mapState.isGhostModeEnabled, 
                         onChanged: (val) {
                           // Update local state (and ideally sync to remote via ProfileController)
                           // ref.read(profileControllerProvider.notifier).updateGhostMode(val); 
                         },
                         activeColor: AppColors.primary,
                       )
                    ],
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

  Widget _buildGenderChip(WidgetRef ref, MapState state, Gender? value, String label) {
    final isSelected = state.filterGender == value;
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
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
