import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // Added
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
import '../providers/map_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart'; // for safetyServiceProvider
import '../../../profile/presentation/providers/dog_provider.dart'; // Added
import '../../../../shared/presentation/widgets/sos_dialog.dart'; // Added
import '../../../profile/presentation/screens/my_pets_screen.dart'; // Added
import '../../../notifications/presentation/screens/notifications_screen.dart'; // Corrected import
import '../../../chat/presentation/providers/chat_provider.dart'; // Added
import '../../../chat/presentation/screens/chat_screen.dart'; // Added
import '../../../../core/services/notification_service.dart'; // Added
import '../../../../core/services/sos_service.dart'; // Added
import '../../../../shared/models/safety_alert_model.dart'; // Added
// Added SOS Model
// Added ChatModel import
import '../../../walks/presentation/screens/walk_detail_screen.dart';
import '../../../nextdoor/presentation/screens/announcement_detail_screen.dart';
import '../../../events/presentation/screens/event_detail_screen.dart'; // Added
import '../../../activities/presentation/screens/activities_list_screen.dart'; // Unified Screen
import '../../../../shared/presentation/widgets/user_profile_bottom_sheet.dart';
import '../../../../features/walking/presentation/screens/active_walk_screen.dart'; // Added Walk Screen import
import '../widgets/map_filter_bottom_sheet.dart';
import '../widgets/pet_business_bottom_sheet.dart'; // Pet Businesses
import '../widgets/sighting_report_dialog.dart';
import '../../../ads/presentation/widgets/unified_ad_card.dart'; // Ads
import 'package:google_mobile_ads/google_mobile_ads.dart'; // AdSize
import 'package:url_launcher/url_launcher.dart'; // Added
import '../../../profile/data/visitor_service.dart'; // Added Visitor Service
import '../../../../shared/constants/map_markers.dart';
import '../../../../features/profile/presentation/screens/privacy_settings_screen.dart'; // Added
import '../../../chatbot/presentation/screens/chatbot_screen.dart'; // Chatbot


import '../../../../core/constants/tutorial_keys.dart';
import '../../../../core/services/completed_walk_service.dart';
import '../../../../shared/models/completed_walk_model.dart';
import '../../../../core/services/dog_service.dart';
import '../../../../shared/models/dog_model.dart';




class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    
    // Request location safely after the first frame has rendered.
    // This prevents the permission prompt from being dropped by Android
    // if called during a state transition or simultaneously with other prompts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapControllerProvider.notifier).initLocation();
    });
  }
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapControllerProvider);
    final userAsync = ref.watch(currentUserProfileProvider);
    final isPremium = userAsync.value?.isPremium ?? false;

    // Listen for selected user changes to show bottom sheet
    ref.listen(mapControllerProvider, (previous, next) {
      if (previous?.selectedUser != next.selectedUser &&
          next.selectedUser != null) {
        
        // Record Visit (Premium Feature)
        final currentUser = ref.read(authServiceProvider).currentUser;
        if (currentUser != null && currentUser.uid != next.selectedUser!.uid) {
           // Fire and forget
           ref.read(visitorServiceProvider).recordVisit(next.selectedUser!.uid, currentUser.uid);
        }

        _showUserProfile(context, next.selectedUser!);
      }
    });
    
    // Auto-center map when location is found or when it switches from mocked to real GPS
    ref.listen(mapControllerProvider, (previous, next) {
      final prevPos = previous?.currentPosition;
      final nextPos = next.currentPosition;
      
      if (nextPos == null) return;

      // Case 1: First time we get a position
      if (prevPos == null) {
        _mapController.move(LatLng(nextPos.latitude, nextPos.longitude), 15.0);
      } 
      // Case 2: We had a mocked/fallback position and now we have a real GPS fix
      else if (previous?.isMocked == true && next.isMocked == false) {
        print('Real GPS fix obtained, moving camera');
        _mapController.move(LatLng(nextPos.latitude, nextPos.longitude), 15.0);
      }
    });

    // Listen for selected WALK
    ref.listen(mapControllerProvider.select((value) => value.selectedWalk), (previous, next) {
      if (next != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'walk_detail'),
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

    // Listen for selected ANNOUNCEMENT
    ref.listen(mapControllerProvider.select((value) => value.selectedAnnouncement), (previous, next) {
      if (next != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'announcement_detail'),
            builder: (context) => AnnouncementDetailScreen(announcement: next),
          ),
        ).then((_) {
          ref.read(mapControllerProvider.notifier).clearSelectedAnnouncement();
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
                Icon(Icons.pets, color: Colors.red, size: 32),
                SizedBox(width: 8),
                Text('PET SMARRITO', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 const Text('Un nostro amico a 4 zampe è stato smarrito in questa zona! Aiutaci a trovarlo.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black87)),
                 const SizedBox(height: 16),
                 if (next.message != null && next.message!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Text(next.message!, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87)),
                    ),
                 const SizedBox(height: 16),
                 const Text('Se lo vedi, contatta subito il proprietario:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                 const SizedBox(height: 8),
                 Text(next.contactPhone, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Chiudi', style: TextStyle(color: Colors.grey)),
              ),               if (ref.read(authServiceProvider).currentUser != null && ref.read(authServiceProvider).currentUser!.uid != next.ownerId)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  onPressed: () async {
                    final currentUser = ref.read(authServiceProvider).currentUser;
                    if (currentUser == null) return;
                    Navigator.pop(context); // Close alert dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );
                    try {
                      final position = await ref.read(locationServiceProvider).getCurrentPosition();
                      if (context.mounted) {
                        Navigator.pop(context); // Remove loader
                        final success = await showDialog<bool>(
                          context: context,
                          builder: (context) => SightingReportDialog(
                            alertId: next.id,
                            petId: next.petId,
                            ownerId: next.ownerId,
                            finderId: currentUser.uid,
                            latitude: position.latitude,
                            longitude: position.longitude,
                          ),
                        );
                        if (success == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Posizione e dettagli dell\'avvistamento inviati con successo! Grazie per l\'aiuto.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context); // Remove loader
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Errore nel rilevamento della posizione: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.location_on),
                  label: const Text('L\'HO VISTO QUI!'),
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () async {
                  final uri = Uri.parse('tel:${next.contactPhone}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Impossibile chiamare ${next.contactPhone}')),
                      );
                    }
                  }
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
    });

    // Listen for selected EVENT (Added)
    ref.listen(mapControllerProvider.select((value) => value.selectedEvent), (previous, next) {
      if (next != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'event_detail'),
            builder: (context) => EventDetailScreen(event: next),
          ),
        ).then((_) {
          ref.read(mapControllerProvider.notifier).clearSelectedEvent();
        });
      }
    });

    // Listen for selected SIGHTING (Avvistamento)
    ref.listen(mapControllerProvider.select((value) => value.selectedSighting), (previous, next) {
      if (next != null) {
        showDialog(
          context: context,
          builder: (context) => Consumer(
            builder: (context, ref, _) {
              final dogAsync = ref.watch(dogByIdProvider(next.petId));
              final finderAsync = ref.watch(userProfileStreamProvider(next.finderId));
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.green, size: 28),
                    SizedBox(width: 8),
                    Text('Avvistamento Pet! 📍', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      dogAsync.when(
                        data: (dog) => Text(
                          'Qualcuno ha avvistato ${dog?.name ?? "il tuo pet"} in questo punto!',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const Text('Qualcuno ha avvistato il tuo pet in questo punto!'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Data e ora: ${next.createdAt.day}/${next.createdAt.month}/${next.createdAt.year} alle ${next.createdAt.hour}:${next.createdAt.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                      
                      // Display photo if available (new field)
                      if (next.photoUrl.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            next.photoUrl,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 150,
                                color: Colors.grey.shade100,
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              height: 150,
                              color: Colors.grey.shade200,
                              child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                            ),
                          ),
                        ),
                      ],

                      // Display description if available (new field)
                      if (next.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.notes, size: 16, color: Colors.orange),
                                  SizedBox(width: 4),
                                  Text(
                                    'Dettagli avvistamento:',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                next.description,
                                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Segnalato da:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      finderAsync.when(
                        data: (finder) {
                          if (finder == null) return const Text('Utente sconosciuto');
                          return Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: finder.photoUrl != null && finder.photoUrl!.isNotEmpty
                                    ? NetworkImage(finder.photoUrl!)
                                    : null,
                                child: finder.photoUrl == null || finder.photoUrl!.isEmpty
                                    ? const Icon(Icons.person, size: 16)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                finder.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const Text('Impossibile caricare il profilo'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Chiudi'),
                  ),
                  finderAsync.when(
                    data: (finder) {
                      if (finder == null) return const SizedBox.shrink();
                      return ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          Navigator.pop(context); // Close dialog
                          final chatController = ref.read(chatControllerProvider.notifier);
                          final chatId = await chatController.createChat(finder.uid);
                          
                          if (chatId != null && context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
            settings: const RouteSettings(name: 'chat'),
                                builder: (_) => ChatScreen(
                                  chatId: chatId,
                                  otherUser: finder,
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.chat),
                        label: const Text('CONTATTA'),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
        ).then((_) {
          ref.read(mapControllerProvider.notifier).clearSelectedSighting();
        });
      }
    });

    // Listen for selected PET BUSINESS
    ref.listen(mapControllerProvider.select((value) => value.selectedPetBusiness), (previous, next) {
      if (next != null) {
        showPetBusinessBottomSheet(context, next);
        // Clear after showing
        Future.delayed(const Duration(milliseconds: 100), () {
          ref.read(mapControllerProvider.notifier).clearSelectedPetBusiness();
        });
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // Map Layer (unconditional render with fallback)
          // Map Layer - Only show if position is available
          if (mapState.currentPosition == null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (mapState.error != null) ...[
                    const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                    const SizedBox(height: 16),
                    Text(
                      mapState.error!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                         ref.read(mapControllerProvider.notifier).retryLocation();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Riprova'),
                    ),
                  ] else ...[
                     const CircularProgressIndicator(),
                     const SizedBox(height: 16),
                     const Text('Ricerca segnale GPS in corso...'),
                  ],
                ],
              ),
            )
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(
                        mapState.currentPosition!.latitude,
                        mapState.currentPosition!.longitude,
                      ),
                initialZoom: 15.0,
                onTap: (_, __) {
                  ref.read(mapControllerProvider.notifier).clearSelectedUser();
                  // Also clear others if needed
                },
              ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.dogzn.app',
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
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                             BoxShadow(
                               color: Colors.black.withValues(alpha: 0.2), 
                               blurRadius: 6, 
                               offset: const Offset(0, 3)
                             )
                          ]
                        ),
                        child: Icon(
                          MapMarkers.getIcon(userAsync.value?.mapMarkerId),
                          color: Colors.white,
                          size: 28,
                        ),
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
                   // App Bar / Header — frosted glass so it stays visible over markers
                   ClipRRect(
                     borderRadius: BorderRadius.circular(28),
                     child: BackdropFilter(
                       filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                       child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                         decoration: BoxDecoration(
                           color: Colors.white.withOpacity(0.85),
                           borderRadius: BorderRadius.circular(28),
                           boxShadow: [
                             BoxShadow(
                               color: Colors.black.withOpacity(0.08),
                               blurRadius: 12,
                               offset: const Offset(0, 4),
                             ),
                           ],
                         ),
                         child: Row(
                           crossAxisAlignment: CrossAxisAlignment.center,
                           children: [
                             // Map Filter Button
                             Container(
                               key: TutorialKeys.mapFilterKey,
                               width: 44,
                               height: 44,
                               decoration: const BoxDecoration(
                                 color: Colors.white,
                                 shape: BoxShape.circle,
                               ),
                               child: IconButton(
                                 icon: const Icon(Icons.tune, color: AppColors.primary, size: 20),
                                 onPressed: () {
                                   showModalBottomSheet(
                                     context: context,
                                     backgroundColor: Colors.transparent,
                                     isScrollControlled: true,
                                     builder: (context) => const MapFilterBottomSheet(),
                                   );
                                 },
                                 padding: EdgeInsets.zero,
                                 tooltip: 'Filtri',
                               ),
                             ),
                             const SizedBox(width: 6),

                             // Visibility Toggle Button
                             Container(
                               key: TutorialKeys.mapVisibilityKey,
                               width: 44,
                               height: 44,
                               decoration: const BoxDecoration(
                                 color: Colors.white,
                                 shape: BoxShape.circle,
                               ),
                               child: IconButton(
                                 icon: Icon(
                                   mapState.isSharingActive ? Icons.visibility : Icons.visibility_off,
                                   color: mapState.isSharingActive ? AppColors.primary : Colors.grey,
                                   size: 20,
                                 ),
                                 onPressed: () {
                                   _showVisibilityOptions(context, mapState.isSharingActive);
                                 },
                                 padding: EdgeInsets.zero,
                                 tooltip: 'Chi può vedermi',
                               ),
                             ),

                             const Spacer(),

                             // START WALK BUTTON (circular play-style)
                             GestureDetector(
                               key: TutorialKeys.mapStartWalkKey,
                               onTap: () => _showStartWalkSheet(context),
                               child: Container(
                                 width: 44,
                                 height: 44,
                                 decoration: const BoxDecoration(
                                   shape: BoxShape.circle,
                                   gradient: LinearGradient(
                                     colors: [Color(0xFFFF6B4A), Color(0xFFFF8A65)],
                                     begin: Alignment.topLeft,
                                     end: Alignment.bottomRight,
                                   ),
                                 ),
                                 child: const Icon(
                                   Icons.pets,
                                   color: Colors.white,
                                   size: 20,
                                 ),
                               ),
                             ),

                             const Spacer(),

                             // Notification Button
                             Consumer(
                               builder: (context, ref, _) {
                                 final unreadCount = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
                                 return Container(
                                   key: TutorialKeys.notificationTabKey,
                                   width: 44,
                                   height: 44,
                                   decoration: const BoxDecoration(
                                     color: Colors.white,
                                     shape: BoxShape.circle,
                                   ),
                                   child: Stack(
                                     children: [
                                       IconButton(
                                         icon: const Icon(Icons.notifications_none, color: AppColors.primary, size: 20),
                                         onPressed: () {
                                           Navigator.push(
                                             context,
                                             MaterialPageRoute(
            settings: const RouteSettings(name: 'notifications'),
                                               builder: (context) => const NotificationsScreen(),
                                             ),
                                           );
                                         },
                                         padding: EdgeInsets.zero,
                                       ),
                                       // Red Badge (only if unread notifications exist)
                                       if (unreadCount > 0)
                                         Positioned(
                                           right: 4,
                                           top: 4,
                                           child: Container(
                                             padding: const EdgeInsets.all(2),
                                             constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                             decoration: const BoxDecoration(
                                               color: AppColors.error,
                                               shape: BoxShape.circle,
                                             ),
                                             child: Center(
                                               child: Text(
                                                 unreadCount > 9 ? '9+' : '$unreadCount',
                                                 style: const TextStyle(
                                                   color: Colors.white,
                                                   fontSize: 9,
                                                   fontWeight: FontWeight.w700,
                                                 ),
                                               ),
                                             ),
                                           ),
                                         ),
                                     ],
                                   ),
                                 );
                               },
                             ),
                           ],
                         ),
                       ),
                     ),
                   ),
                  
                  // --- RADAR INDICATOR (Added) ---
                  if (mapState.radarMatchCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: GestureDetector(
                        onTap: () => _showRadarDialog(context, mapState.radarMatchCount, mapState.radarMatchIds),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.95, end: 1.05),
                          duration: const Duration(milliseconds: 800),
                          builder: (context, value, child) {
                            return Transform.scale(scale: value, child: child);
                          },
                          onEnd: () {}, // Loop handled by StatefulWidget wrapper if needed, or simple toggle
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.indigo,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.indigo.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.radar, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '${mapState.radarMatchCount} nascosti in zona',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (!isPremium)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: UnifiedAdCard(
                        zone: 'map_banner',
                        adSize: AdSize.mediumRectangle,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── PROXIMITY ALERT BANNER ──────────────────────
          if (mapState.proximityAlert != null)
            Positioned(
              bottom: 90,
              left: 16,
              right: 16,
              child: _ProximityAlertBanner(
                alert: mapState.proximityAlert!,
                onDismiss: () {
                  ref.read(mapControllerProvider.notifier).dismissProximityAlert();
                },
              ),
            ),
        ],
      ),
      floatingActionButton: mapState.currentPosition != null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // AI Chatbot FAB
                  _MapMiniButton(
                    heroTag: 'chatbot_fab',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
            settings: const RouteSettings(name: 'chatbot'),
                          builder: (context) => const ChatbotScreen(),
                        ),
                      );
                    },
                    backgroundColor: Colors.teal,
                    icon: Icons.support_agent,
                  ),
                  const SizedBox(height: 10),
                  // Safety Report FAB
                  _MapMiniButton(
                    key: TutorialKeys.mapSafetyFabKey,
                    heroTag: 'safety_fab',
                    onPressed: () => _showReportDangerDialog(context, mapState.currentPosition!),
                    backgroundColor: Colors.red.shade400,
                    icon: Icons.warning_amber_rounded,
                  ),
                  const SizedBox(height: 10),
                  // SOS Lost Pet FAB
                  _MapMiniButton(
                    heroTag: 'sos_lost_pet_fab',
                    onPressed: () => _handleLostPetTap(context, ref),
                    backgroundColor: Colors.red.shade700,
                    icon: Icons.sos,
                  ),
                  const SizedBox(height: 10),
                  // Activities & Events FAB
                  _MapMiniButton(
                    key: TutorialKeys.activitiesFabKey,
                    heroTag: 'events_fab',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
            settings: const RouteSettings(name: 'activities_list'),
                          builder: (context) => const ActivitiesListScreen(),
                        ),
                      );
                    },
                    backgroundColor: Colors.deepPurple.shade400,
                    icon: Icons.diversity_3,
                  ),
                  const SizedBox(height: 10),
                  // My Location FAB
                  Container(
                    key: TutorialKeys.recenterFabKey,
                    width: 44,
                    height: 44,
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
                      icon: Icon(Icons.my_location, color: AppColors.primary, size: 20),
                      onPressed: () {
                        _mapController.move(
                          LatLng(
                            mapState.currentPosition!.latitude,
                            mapState.currentPosition!.longitude,
                          ),
                          15.0,
                        );
                      },
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  void _showUserProfile(BuildContext context, UserModel user) {
    showUserProfileBottomSheet(context, user).whenComplete(() {
      ref.read(mapControllerProvider.notifier).clearSelectedUser();
    });
  }

  Future<void> _handleLostPetTap(BuildContext context, WidgetRef ref) async {
    final currentUser = ref.read(authServiceProvider).currentUser;
    if (currentUser == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pets = await ref.read(dogServiceProvider).getDogsByOwnerId(currentUser.uid);
      
      if (context.mounted) {
        Navigator.pop(context); // Remove loading indicator
      }

      if (pets.isEmpty) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Nessun pet registrato'),
              content: const Text(
                'Per poter segnalare lo smarrimento di un pet, devi prima aggiungerne uno al tuo profilo.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
            settings: const RouteSettings(name: 'my_pets'),builder: (context) => const MyPetsScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  child: const Text('Aggiungi Pet'),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (pets.length == 1) {
        if (context.mounted) {
          showSOSDialog(context, ref, pets.first);
        }
        return;
      }

      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seleziona il Pet da segnalare smarrito 🚨',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: pets.length,
                      itemBuilder: (context, index) {
                        final pet = pets[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: pet.photoUrl != null && pet.photoUrl!.isNotEmpty
                                ? NetworkImage(pet.photoUrl!)
                                : null,
                            child: pet.photoUrl == null || pet.photoUrl!.isEmpty
                                ? const Icon(Icons.pets)
                                : null,
                          ),
                          title: Text(pet.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(pet.breed),
                          onTap: () {
                            Navigator.pop(context); // Close bottom sheet
                            showSOSDialog(context, ref, pet); // Open SOS Dialog
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Ensure loading indicator is removed on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nel caricamento dei pet: $e')),
        );
      }
    }
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
                    initialValue: selectedType,
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

  void _showStartWalkSheet(BuildContext context) {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _StartWalkSheetContent(
        userId: user.uid,
        onStart: (selectedPetIds) {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(
            settings: const RouteSettings(name: 'active_walk'),
              builder: (_) => ActiveWalkScreen(petIds: selectedPetIds),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B4A).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFF6B4A)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFF6B4A),
            ),
          ),
        ],
      ),
    );
  }

  void _showVisibilityOptions(BuildContext context, bool currentStatus) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Chi può vederti sulla mappa?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.public, color: Colors.blue),
              title: const Text('Visibile a Tutti'),
              subtitle: const Text('Tutti gli utenti possono vedere la tua posizione'),
              onTap: () async {
                 Navigator.pop(context);
                 await _updateVisibility(LocationPrivacy.everyone);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people, color: Colors.orange),
              title: const Text('Solo Amici'),
              subtitle: const Text('Solo i tuoi amici possono vederti'),
              onTap: () async {
                 Navigator.pop(context);
                 await _updateVisibility(LocationPrivacy.friends);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.visibility_off, color: Colors.grey),
              title: const Text('Nascondi Posizione'),
              subtitle: const Text('Nessuno potrà vederti (Modalità Fantasma)'),
              onTap: () async {
                 Navigator.pop(context);
                 await ref.read(mapControllerProvider.notifier).toggleLocationSharing(false);
                 if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Sei ora invisibile sulla mappa.')),
                   );
                 }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _updateVisibility(LocationPrivacy privacy) async {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;

      try {
        // 1. Update Preference
        await ref.read(userServiceProvider).updateUserFields(
          user.uid, 
          {'locationPrivacy': privacy.name}
        );
        
        // 2. Enable Sharing logic (Check-in)
        await ref.read(mapControllerProvider.notifier).toggleLocationSharing(true);
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Visibilità impostata su: ${privacy == LocationPrivacy.everyone ? "Tutti" : "Solo Amici"}')),
           );
        }
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Errore aggiornamento privacy: $e')),
           );
        }
      }
  }

  void _showRadarDialog(BuildContext context, int count, List<String> targetIds) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.radar, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Radar Pet'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text('Hai trovato $count compagni di passeggiata che corrispondono ai tuoi filtri, ma sono in modalità invisibile!'),
             const SizedBox(height: 16),
             const Text('Vuoi inviare un "Abbaio" (Ping) per far sapere che ci sei e invitarli a connettersi?'),
             const SizedBox(height: 8),
             const Text(
               'Loro riceveranno una notifica generica e potranno decidere se rivelarsi.',
               style: TextStyle(fontSize: 12, color: Colors.grey),
             ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Lascia stare'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              
              final currentUser = ref.read(authServiceProvider).currentUser;
              if (currentUser == null) return;
              
              // We could fetch user details to get breed name, but for now just use "Un amico"
              // or rely on backend/local name.
              
              try {
                 await ref.read(notificationServiceProvider).sendRadarPing(
                   targetIds: targetIds,
                   senderName: currentUser.displayName ?? 'Un vicino',
                   petSummary: 'Un amico', // Can be refined
                 );
                 
                 if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Abbaio inviato! 🐾')),
                    );
                 }
              } catch (e) {
                 if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Errore invio: $e')),
                    );
                 }
              }
            },
            icon: const Icon(Icons.pets),
            label: const Text('ABBAIA!'), 
          ),
        ],
      ),
    );
  }
}

/// Compact circular action button for the map overlay
class _MapMiniButton extends StatelessWidget {
  final String heroTag;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final IconData icon;

  const _MapMiniButton({
    super.key,
    required this.heroTag,
    required this.onPressed,
    required this.backgroundColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.35),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        tooltip: heroTag,
      ),
    );
  }
}

// ── PROXIMITY ALERT BANNER ──────────────────────────
class _ProximityAlertBanner extends StatefulWidget {
  final ProximityAlert alert;
  final VoidCallback onDismiss;

  const _ProximityAlertBanner({
    required this.alert,
    required this.onDismiss,
  });

  @override
  State<_ProximityAlertBanner> createState() => _ProximityAlertBannerState();
}

class _ProximityAlertBannerState extends State<_ProximityAlertBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSafety = widget.alert.type == 'safety';
    final bgColor = isSafety ? Colors.red.shade700 : Colors.orange.shade700;
    final icon = isSafety ? Icons.warning_amber_rounded : Icons.sos;
    final distLabel = widget.alert.distanceMeters < 100
        ? 'meno di 100m'
        : '${widget.alert.distanceMeters.round()}m';

    return ScaleTransition(
      scale: _pulseAnimation,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        shadowColor: bgColor.withOpacity(0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bgColor, bgColor.withOpacity(0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.alert.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.alert.message} • $distLabel',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onDismiss,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── PET PICKER WALK SHEET ──────────────────────────
class _StartWalkSheetContent extends ConsumerStatefulWidget {
  final String userId;
  final void Function(List<String> selectedPetIds) onStart;

  const _StartWalkSheetContent({required this.userId, required this.onStart});

  @override
  ConsumerState<_StartWalkSheetContent> createState() => _StartWalkSheetContentState();
}

class _StartWalkSheetContentState extends ConsumerState<_StartWalkSheetContent> {
  List<DogModel> _pets = [];
  final Set<String> _selected = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    try {
      final pets = await DogService().getDogsByOwnerId(widget.userId);
      if (mounted) {
        setState(() {
          _pets = pets;
          if (pets.length == 1) _selected.add(pets.first.id);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFFFF6B4A), Color(0xFFFF8A65)]),
              ),
              child: const Icon(Icons.pets, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chi porti a spasso?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Puoi selezionare anche più di un pet',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            if (_loading)
              const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
            else if (_pets.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Nessun pet registrato.\nPuoi comunque iniziare!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500]),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _pets.length,
                  itemBuilder: (context, index) {
                    final pet = _pets[index];
                    final isSelected = _selected.contains(pet.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          isSelected ? _selected.remove(pet.id) : _selected.add(pet.id);
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF6B4A).withOpacity(0.1)
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFFF6B4A) : Colors.grey[200]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundImage: pet.photoUrl != null ? NetworkImage(pet.photoUrl!) : null,
                                backgroundColor: const Color(0xFFFF6B4A).withOpacity(0.2),
                                child: pet.photoUrl == null
                                    ? Text(pet.species == PetSpecies.cat ? '🐱' : '🐶', style: const TextStyle(fontSize: 20))
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(pet.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                    Text(
                                      '${pet.breed} · ${pet.species.displayName}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected ? Icons.check_circle : Icons.circle_outlined,
                                color: isSelected ? const Color(0xFFFF6B4A) : Colors.grey[300],
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => widget.onStart(_selected.toList()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B4A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: Text(
                  _selected.isEmpty ? 'INIZIA SENZA PET' : 'INIZIA TRACKING 🐾',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _logManualWalk(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[800],
                  side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: const Icon(Icons.edit_note),
                label: const Text(
                  'Aggiungi Passeggiata Manuale',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _logManualWalk(BuildContext context) {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno un pet per registrare la passeggiata.')),
      );
      return;
    }

    int duration = 30;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Registra Passeggiata'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Hai già portato fuori i pet oggi? Registra qui i minuti per mantenere aggiornato il piano salute senza usare il GPS.'),
                const SizedBox(height: 20),
                const Text('Durata della passeggiata:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Slider(
                  value: duration.toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  label: '$duration min',
                  activeColor: const Color(0xFFFF6B4A),
                  onChanged: (val) => setDialogState(() => duration = val.toInt()),
                ),
                Text('$duration minuti', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFF6B4A))),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B4A), foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _saveManualWalk(duration);
                  if (mounted) {
                    Navigator.pop(context); // close bottom sheet
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Passeggiata manuale registrata con successo!')),
                    );
                  }
                },
                child: const Text('Salva Attività'),
              )
            ],
          );
        }
      ),
    );
  }

  Future<void> _saveManualWalk(int durationMinutes) async {
    final now = DateTime.now();
    // Use an average walking speed of 4km/h for distance estimation
    final distanceKm = (durationMinutes / 60) * 4.0; 
    
    final walk = CompletedWalkModel(
      id: '', // Will be generated by Firestore
      userId: widget.userId,
      startTime: now.subtract(Duration(minutes: durationMinutes)),
      endTime: now,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      steps: durationMinutes * 80, // Estimate
      caloriesBurned: durationMinutes * 4, // Estimate
      petIds: _selected.toList(),
    );
    
    await ref.read(completedWalkServiceProvider).saveCompletedWalk(walk);
  }
}
