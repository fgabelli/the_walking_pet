import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
import '../providers/map_provider.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/friend_service.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart'; // Corrected import
import '../../../../shared/models/chat_model.dart'; // Added ChatModel import

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
                                  : const Icon(Icons.tune, color: AppColors.primary),
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
                  child: Consumer(
                    builder: (context, ref, child) {
                      final currentUser = ref.watch(authServiceProvider).currentUser;
                      // Logic to determine button state
                      // We need to know if they are already friends, or if a request is pending.
                      // Since we don't have the FULL currentUser model here with 'friends' list up-to-date locally 
                      // (unless we assume authProvider holds it, but authProvider usually holds Firebase User),
                      // we might need to fetch it or pass it. 
                      // Wait, mapState has markers, but not the current user's full profile with friends list?
                      // Actually, let's look at how we get currentUser.
                      // ref.watch(authServiceProvider).currentUser is Firebase User.
                      // We need the UserModel of the logged-in user to check the 'friends' list.
                      // We can get it from a userProvider if we have one, or fetch it.
                      // For now, let's assumed we can get it or we will fetch it.
                      // A better approach: The 'user' passed to this method is the OTHER user.
                      // Does IT have 'friends'? Yes. 
                      // If 'user.friends' contains me, we are friends.
                      // If 'user.friendRequests' contains me, I sent a request.
                      
                      final myUid = currentUser?.uid;
                      final isMe = myUid == user.uid;
                      final isFriend = myUid != null && user.friends.contains(myUid);
                      final isRequestSent = myUid != null && user.friendRequests.contains(myUid);
                      final hasIncomingRequest = myUid != null && (user.friends.contains(myUid) == false) && (
                          // logic for incoming not easily checked via 'user' unless we check my own profile
                          // For now let's focus on "Add Friend" vs "Request Sent" vs "Friend"
                          false // Placeholder for incoming check
                      );

                      if (isMe) return const SizedBox(); // Don't show add friend for self

                      if (isFriend) {
                         return OutlinedButton.icon(
                          onPressed: () {
                            // Already friends (maybe show 'Remove' in a submenu?)
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Amici'),
                        );
                      }

                      if (isRequestSent) {
                         return OutlinedButton.icon(
                          onPressed: null, // Disable
                          icon: const Icon(Icons.hourglass_empty),
                          label: const Text('Richiesta inviata'),
                        );
                      }

                      return OutlinedButton.icon(
                        onPressed: () async {
                           try {
                             await FriendService().sendFriendRequest(user.uid);
                             // Force close or show snackbar
                             if (context.mounted) {
                               Navigator.pop(context);
                               ScaffoldMessenger.of(context).showSnackBar(
                                 const SnackBar(content: Text('Richiesta di amicizia inviata!')),
                               );
                             }
                           } catch (e) {
                             if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(content: Text('Errore: $e')),
                               );
                             }
                           }
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Aggiungi'),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Create chat and navigate
                      Navigator.pop(context); // Close bottom sheet
                      
                      final chatController = ref.read(chatControllerProvider.notifier);
                      
                      // Check if already friends to decide status
                      final currentUser = ref.read(authServiceProvider).currentUser;
                      // We need to re-verify friendship status because 'user' might be stale OR 
                      // we need to check 'my' friends list properly.
                      // Ideally we have the 'isFriend' logic calculated above available here.
                      // Let's re-calculate efficiently or assume the previously calculated 'isFriend' is valid?
                      // The 'isFriend' variable is inside Consumer builder above, not accessible here directly 
                      // unless we move this logic inside a Consumer too.
                      // Actually, this ElevatedButton IS inside the Row children, but the Consumer was only around the "Add Friend" button.
                      // This "Messaggio" button is sibling to that Consumer.
                      
                      // Let's implement the check here.
                      final myUid = currentUser?.uid;
                      final isFriend = myUid != null && user.friends.contains(myUid);
                      // Note: verifying 'user.friends.contains(myUid)' is checking if THEY consider ME a friend.
                      // Which is correct for bi-directional friendship. 
                      
                      final status = isFriend ? ChatStatus.accepted : ChatStatus.pending;
                      
                      final chatId = await chatController.createChat(
                        user.uid, 
                        initialStatus: status,
                      );
                      
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
