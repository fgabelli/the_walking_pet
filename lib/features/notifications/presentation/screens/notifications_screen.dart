import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/services/friend_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';

// Provider for fetching friend requests
final friendRequestsProvider = FutureProvider<List<UserModel>>((ref) async {
  final currentUser = ref.watch(authServiceProvider).currentUser;
  if (currentUser == null) return [];
  
  // We need the FULL user model to get the request UIDs
  // But wait, currentUser from authService is Firebase User.
  // We need to fetch the real user model first.
  final userService = UserService(); // or use provider
  final userModel = await userService.getUserById(currentUser.uid);
  
  if (userModel == null || userModel.friendRequests.isEmpty) return [];

  // Fetch all requesting users
  final requests = <UserModel>[];
  for (final uid in userModel.friendRequests) {
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
            return const Center(child: Text('Nessuna nuova notifica'));
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
