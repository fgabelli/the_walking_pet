import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../../core/services/friend_service.dart';
import '../../../../core/services/user_service.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/chat/presentation/providers/chat_provider.dart';
import '../../../features/chat/presentation/screens/chat_screen.dart';

class UserProfileBottomSheet extends ConsumerWidget {
  final UserModel user;

  const UserProfileBottomSheet({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
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
              // Options Menu (Block/Report)
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'block') {
                    _confirmBlockUser(context, ref);
                  }
                },
                itemBuilder: (context) => [
                   const PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(Icons.block, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Blocca utente', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final currentUser = ref.watch(authServiceProvider).currentUser;
                    
                    final myUid = currentUser?.uid;
                    final isMe = myUid == user.uid;
                    
                    // We need real-time data for friendship status, not just what's in 'user' model passed in
                    // which might be stale.
                    final friendService = FriendService(); // Or provider if available
                    // But checking firestore for every button render is expensive/complex in build.
                    // For now, let's rely on user model passed, BUT we should verify 'isFriend' against MY list.
                    
                    // To do this correctly, we need the CURRENT USER's full model.
                    // Let's fetch it or watch it.
                    // Assuming we don't have a provider that streams the full current user model yet exposed easily here.
                    // We can use the 'user' passed in for THEY -> ME relationship?
                    
                    final isFriend = myUid != null && user.friends.contains(myUid);
                    final isRequestSent = myUid != null && user.friendRequests.contains(myUid);
                    
                    if (isMe) return const SizedBox(); 

                    if (isFriend) {
                       return OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.check),
                        label: const Text('Amici'),
                      );
                    }

                    if (isRequestSent) {
                       return OutlinedButton.icon(
                        onPressed: null, 
                        icon: const Icon(Icons.hourglass_empty),
                        label: const Text('Inviata'),
                      );
                    }

                    return OutlinedButton.icon(
                      onPressed: () async {
                         try {
                           await FriendService().sendFriendRequest(user.uid);
                           if (context.mounted) {
                             Navigator.pop(context);
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text('Richiesta inviata!')),
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
                    _navigateToChat(context, ref);
                  },
                  child: const Text('Messaggio'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _confirmBlockUser(BuildContext context, WidgetRef ref) async {
    final currentUser = ref.read(authServiceProvider).currentUser;
    if (currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Blocca utente'),
        content: Text('Sei sicuro di voler bloccare ${user.fullName}? Non vedrai più i suoi contenuti e non potrà contattarti.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Blocca'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await UserService().blockUser(currentUser.uid, user.uid);
        if (context.mounted) {
          Navigator.pop(context); // Close sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Utente bloccato.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Errore: $e')),
           );
        }
      }
    }
  }

  void _navigateToChat(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context); // Close bottom sheet
    
    final chatController = ref.read(chatControllerProvider.notifier);
    final currentUser = ref.read(authServiceProvider).currentUser;
    final myUid = currentUser?.uid;
    
    final isMe = myUid == user.uid;
    final isFriend = myUid != null && user.friends.contains(myUid);
    final status = (isFriend || isMe) ? ChatStatus.accepted : ChatStatus.pending;
    
    try {
      final chatId = await chatController.createChat(
        user.uid, 
        initialStatus: status,
      );
      
      // If it's a self-chat, ensure it's accepted (fixes existing pending self-chats)
      if (chatId != null && isMe) {
        await chatController.acceptChat(chatId);
      }
      
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Errore apertura chat: $e')),
        );
      }
    }
  }
}

// Helper method to show the sheet easily
Future<void> showUserProfileBottomSheet(BuildContext context, UserModel user) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => UserProfileBottomSheet(user: user),
  );
}
