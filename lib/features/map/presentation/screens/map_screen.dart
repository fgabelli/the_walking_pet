import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // Added
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
import '../providers/map_provider.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/friend_service.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart'; // for safetyServiceProvider
import '../../../notifications/presentation/screens/notifications_screen.dart'; // Corrected import
import '../../../../shared/models/safety_alert_model.dart'; // Added
import '../../../../shared/models/lost_pet_alert_model.dart'; // Added SOS Model
import '../../../../shared/models/chat_model.dart'; // Added ChatModel import
import '../../../walks/presentation/screens/walk_detail_screen.dart';
import '../../../nextdoor/presentation/screens/announcement_detail_screen.dart';
import '../../../events/presentation/screens/event_detail_screen.dart'; // Added
import '../../../events/presentation/screens/events_list_screen.dart'; // Added
import '../../../../shared/presentation/widgets/user_profile_bottom_sheet.dart'; // Added Shared Widget Import
import '../widgets/map_filter_bottom_sheet.dart'; // FILTER IMPORT

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
    
    // Auto-center map when location is found (if it was previously null/loading)
    ref.listen(mapControllerProvider.select((value) => value.currentPosition), (previous, next) {
      if (previous == null && next != null) {
        _mapController.move(
          LatLng(next.latitude, next.longitude),
          15.0,
        );
      }
    });

    // Listen for selected WALK
    ref.listen(mapControllerProvider.select((value) => value.selectedWalk), (previous, next) {
      if (next != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WalkDetailScreen(walk: next),
          ),
        ).then((_) {
          ref.read(mapControllerProvider.notifier).clearSelectedWalk();
        });
      }
    });

    // Listen for selected ALERT
    ref.listen(mapControllerProvider.select((value) => value.selectedAlert), (previous, next) {
      if (next != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                Text(next.type.displayName),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (next.description != null && next.description!.isNotEmpty)
                  Text(next.description!),
                const SizedBox(height: 8),
                Text(
                  'Segnalato il ${next.createdAt.day}/${next.createdAt.month} alle ${next.createdAt.hour}:${next.createdAt.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Chiudi'),
              ),
            ],
          ),
        ).then((_) {
          ref.read(mapControllerProvider.notifier).clearSelectedAlert();
        });
      }
    });

    // Listen for selected SOS (Added)
    ref.listen(mapControllerProvider.select((value) => value.selectedSOS), (previous, next) {
      if (next != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.red[50],
            title: const Row(
              children: [
                Icon(Icons.sos, color: Colors.red, size: 32),
                SizedBox(width: 8),
                Text('SOS PET SMARRITO', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 const Text('Un nostro amico a 4 zampe è stato smarrito in questa zona! Aiutaci a trovarlo.', textAlign: TextAlign.center),
                 const SizedBox(height: 16),
                 if (next.message != null && next.message!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Text(next.message!, style: const TextStyle(fontStyle: FontStyle.italic)),
                    ),
                 const SizedBox(height: 16),
                 const Text('Se lo vedi, contatta subito il proprietario:', style: TextStyle(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 8),
                 Text(next.contactPhone, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Chiudi', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () {
                  // TODO: Launch dialer
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Chiamata a ${next.contactPhone}...')),
                  );
                },
                icon: const Icon(Icons.call),
                label: const Text('CHIAMA ORA'),
              ),
            ],
          ),
        ).then((_) {
          ref.read(mapControllerProvider.notifier).clearSelectedSOS();
        });
      }
    }); // Added closing brace for ref.listen

    // Listen for selected EVENT (Added)
    ref.listen(mapControllerProvider.select((value) => value.selectedEvent), (previous, next) {
      if (next != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailScreen(event: next),
          ),
        ).then((_) {
          ref.read(mapControllerProvider.notifier).clearSelectedEvent();
        });
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // Map Layer (unconditional render with fallback)
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
                // Also clear others if needed
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
            ),
          
          if (mapState.isLoading)
             const Center(child: CircularProgressIndicator()),
             
          if (mapState.error != null)
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
                      // Retry logic
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
                  // Search Bar & Notifications
                  Row(
                    children: [
                      Expanded(
                        child: Card(
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
                                  : IconButton(
                                      icon: const Icon(Icons.tune, color: AppColors.primary),
                                      onPressed: () {
                                        showModalBottomSheet(
                                          context: context,
                                          backgroundColor: Colors.transparent,
                                          isScrollControlled: true,
                                          builder: (context) => const MapFilterBottomSheet(),
                                        );
                                      },
                                    ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Notifications Button
                      Consumer(
                        builder: (context, ref, child) {
                          final requestsAsync = ref.watch(friendRequestsProvider);
                          final hasNotifications = requestsAsync.maybeWhen(
                            data: (data) => data.isNotEmpty,
                            orElse: () => false,
                          );

                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const NotificationsScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.notifications_outlined, color: AppColors.primary),
                                ),
                              ),
                              if (hasNotifications)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: mapState.currentPosition != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                 // Safety Report FAB (Added)
                FloatingActionButton(
                  heroTag: 'safety_fab',
                  onPressed: () => _showReportDangerDialog(context, mapState.currentPosition!),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.campaign), // or warning
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'events_fab',
                  onPressed: () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EventsListScreen(),
                      ),
                    );
                  },
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.calendar_today),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'location_fab',
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
                ),
              ],
            )
          : null,
    );
  }

  void _showUserProfile(BuildContext context, UserModel user) {
    showUserProfileBottomSheet(context, user).whenComplete(() {
      ref.read(mapControllerProvider.notifier).clearSelectedUser();
    });
  }
  
  void _showReportDangerDialog(BuildContext context, Position position) {
    SafetyAlertType selectedType = SafetyAlertType.other;
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Segnala Pericolo'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Aiuta la community segnalando un pericolo in questa zona.'),
                  const SizedBox(height: 16),
                  
                  // Type Dropdown
                  DropdownButtonFormField<SafetyAlertType>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo di Pericolo',
                      border: OutlineInputBorder(),
                    ),
                    items: SafetyAlertType.values.map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descrizione (Opzionale)',
                      border: OutlineInputBorder(),
                      hintText: 'Dettagli utili...'
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
               TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () {
                  final user = ref.read(authServiceProvider).currentUser;
                  if (user == null) return;

                  ref.read(safetyServiceProvider).reportDanger(
                    authorId: user.uid,
                    type: selectedType,
                    latitude: position.latitude,
                    longitude: position.longitude,
                    description: descriptionController.text.trim(),
                  );
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Segnalazione inviata! Grazie per il tuo aiuto.')),
                  );
                },
                child: const Text('Segnala'),
              ),
            ],
          );
        }
      ),
    );
  }
}
