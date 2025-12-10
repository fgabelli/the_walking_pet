import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
import '../providers/map_provider.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../chat/presentation/providers/chat_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapControllerProvider);

    // Listen for selected user changes to show bottom sheet
    ref.listen(mapControllerProvider, (previous, next) {
      if (previous?.selectedUser != next.selectedUser &&
          next.selectedUser != null) {
        _showUserProfile(context, next.selectedUser!);
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          if (mapState.currentPosition != null)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: mapState.currentPosition != null 
                    ? LatLng(
                        mapState.currentPosition!.latitude,
                        mapState.currentPosition!.longitude,
                      )
                    : const LatLng(41.9028, 12.4964), // Default to Rome
                initialZoom: 15.0,
                onTap: (_, __) {
                  ref.read(mapControllerProvider.notifier).clearSelectedUser();
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.thewalkingpet.app',
                ),
                MarkerLayer(
                  markers: [
                    // Current Position Marker only if we have it
                    if (mapState.currentPosition != null)
                      Marker(
                        point: LatLng(
                          mapState.currentPosition!.latitude,
                          mapState.currentPosition!.longitude,
                        ),
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                    // Other Markers
                    ...mapState.markers,
                  ],
                ),
              ],
            )
          else if (mapState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (mapState.error != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    mapState.error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Retry logic could be added here
                    },
                    child: const Text('Riprova'),
                  ),
                ],
              ),
            ),

          // Custom UI Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Search Bar / Filter Bar Placeholder
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      onChanged: (value) {
                        ref.read(mapControllerProvider.notifier).setSearchQuery(value);
                      },
                      decoration: InputDecoration(
                        hintText: 'Cerca passeggiate o amici...',
                        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                        suffixIcon: mapState.searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                                onPressed: () {
                                  ref.read(mapControllerProvider.notifier).setSearchQuery('');
                                },
                              )
                            : const Icon(Icons.tune, color: AppColors.primary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: mapState.currentPosition != null
          ? FloatingActionButton(
              onPressed: () {
                _mapController.move(
                  LatLng(
                    mapState.currentPosition!.latitude,
                    mapState.currentPosition!.longitude,
                  ),
                  15.0,
                );
              },
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              child: const Icon(Icons.my_location),
            )
          : null,
    );
  }

  void _showUserProfile(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Profile Info
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Text(
                          user.firstName[0].toUpperCase(),
                          style: const TextStyle(fontSize: 24),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (user.bio != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          user.bio!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Navigate to full profile
                      Navigator.pop(context);
                    },
                    child: const Text('Vedi Profilo'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Create chat and navigate
                      Navigator.pop(context); // Close bottom sheet
                      
                      final chatController = ref.read(chatControllerProvider.notifier);
                      final chatId = await chatController.createChat(user.uid);
                      
                      if (chatId != null && context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              chatId: chatId,
                              otherUserName: user.fullName,
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Messaggio'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ).whenComplete(() {
      // Clear selection when bottom sheet is closed
      ref.read(mapControllerProvider.notifier).clearSelectedUser();
    });
  }
}
