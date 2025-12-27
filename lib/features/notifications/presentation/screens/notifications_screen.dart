import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/services/friend_service.dart';
import '../../../../core/theme/app_colors.dart';

// Provider for fetching friend requests
import '../../../profile/presentation/providers/profile_provider.dart'; // Added

// Provider for fetching friend requests
final friendRequestsProvider = FutureProvider<List<UserModel>>((ref) async {
  final currentUserState = ref.watch(currentUserProfileProvider);
  
  // If loading or error, return empty? Or preserve previous? Start empty.
  // accessing .value returns the latest data if available
  final userModel = currentUserState.value;
    
  if (userModel == null || userModel.friendRequests.isEmpty) return [];

  final userService = UserService(); // or use provider
  final requests = <UserModel>[];
  
  // Fetch details for each requester
  // Optimisation: Could use whereIn query if list is large, but for now loop is fine
  for (final uid in userModel.friendRequests) {
    // If we have a provider for generic users, we could use it, but plain fetch is okay
    final sender = await userService.getUserById(uid);
    if (sender != null) requests.add(sender);
  }
  
  return requests;
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(friendRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifiche'),
      ),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Nessuna nuova notifica',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final user = requests[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                  child: user.photoUrl == null ? Text(user.firstName[0]) : null,
                ),
                title: Text('${user.fullName} vuole stringere amicizia'),
                subtitle: const Text('Richiesta di amicizia'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: AppColors.primary),
                      onPressed: () async {
                         await FriendService().acceptFriendRequest(user.uid);
                         ref.refresh(friendRequestsProvider);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () async {
                         await FriendService().declineFriendRequest(user.uid);
                         ref.refresh(friendRequestsProvider);
                      },
                    ),
                  ],
                ),
                onTap: () {
                   // Navigate to profile?
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Errore: $err')),
      ),
    );
  }
}
