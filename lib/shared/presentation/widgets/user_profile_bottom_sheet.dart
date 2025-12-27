import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/chat/presentation/providers/chat_provider.dart';
import '../../../features/chat/presentation/screens/chat_screen.dart';
import '../../../features/profile/presentation/screens/business_profile_screen.dart';
import '../../../features/profile/presentation/providers/profile_provider.dart';

class UserProfileBottomSheet extends ConsumerWidget {
  final UserModel user;

  const UserProfileBottomSheet({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final myUid = authState.value?.uid;
    final isMe = myUid == user.uid;

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
            ],
          ),
          const SizedBox(height: 24),
          
          if (!isMe && myUid != null) ...[
            ref.watch(currentUserProfileProvider).when(
              data: (currentUserProfile) {
                if (currentUserProfile == null) return const SizedBox();

                final isBusiness = user.accountType == AccountType.business;
                final isFollowing = user.followers.contains(myUid);

                return Column(
                  children: [
                    if (isBusiness) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BusinessProfileScreen(businessUser: user),
                              ),
                            );
                          },
                          icon: const Icon(Icons.store),
                          label: const Text('Visita Pagina'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                             if (isFollowing) {
                               ref.read(userServiceProvider).unfollowUser(myUid, user.uid);
                             } else {
                               ref.read(userServiceProvider).followUser(myUid, user.uid);
                             }
                          },
                          icon: Icon(isFollowing ? Icons.check : Icons.add),
                          label: Text(isFollowing ? 'Seguito' : 'Segui'),
                        ),
                      ),
                    ] else ...[
                      _buildFriendAction(context, ref, currentUserProfile, user),
                    ],

                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToChat(context, ref, myUid),
                        icon: const Icon(Icons.message_outlined),
                        label: const Text('Messaggio'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _confirmBlockUser(context, ref, myUid),
                      icon: const Icon(Icons.block, color: AppColors.error),
                      label: const Text('Blocca utente', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, __) => Text('Errore: $e'),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFriendAction(BuildContext context, WidgetRef ref, UserModel currentUser, UserModel targetUser) {
    final isFollowing = targetUser.followers.contains(currentUser.uid);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          if (isFollowing) {
            ref.read(userServiceProvider).unfollowUser(currentUser.uid, targetUser.uid);
          } else {
            ref.read(userServiceProvider).followUser(currentUser.uid, targetUser.uid);
          }
        },
        icon: Icon(isFollowing ? Icons.check : Icons.person_add),
        label: Text(isFollowing ? 'Seguito' : 'Segui'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: isFollowing ? Colors.grey : AppColors.primary),
          foregroundColor: isFollowing ? Colors.grey : AppColors.primary,
        ),
      ),
    );
  }

  void _confirmBlockUser(BuildContext context, WidgetRef ref, String myUid) async {
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
        await ref.read(userServiceProvider).blockUser(myUid, user.uid);
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

  void _navigateToChat(BuildContext context, WidgetRef ref, String myUid) async {
    Navigator.pop(context); // Close bottom sheet
    
    final chatController = ref.read(chatControllerProvider.notifier);
    final isMe = myUid == user.uid;
    final status = isMe ? ChatStatus.accepted : ChatStatus.pending;
    
    try {
      final chatId = await chatController.createChat(
        user.uid, 
        initialStatus: status,
      );
      
      if (chatId != null && isMe) {
        await chatController.acceptChat(chatId);
      }
      
      if (chatId != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              otherUser: user,
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
