import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user_model.dart';
import '../providers/profile_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/user_service.dart';
import 'profile_screen.dart';

class ConnectionsListScreen extends ConsumerWidget {
  final String title;
  final List<String> userIds;

  const ConnectionsListScreen({
    super.key,
    required this.title,
    required this.userIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: currentUserAsync.when(
        data: (currentUser) {
          if (currentUser == null) return const Center(child: Text('Utente non trovato'));
          if (userIds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Nessun utente trovato in questa lista.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: userIds.length,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemBuilder: (context, index) {
              final targetId = userIds[index];
              return _UserConnectionTile(
                targetId: targetId,
                currentUser: currentUser,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Errore: $e')),
      ),
    );
  }
}

class _UserConnectionTile extends ConsumerWidget {
  final String targetId;
  final UserModel currentUser;

  const _UserConnectionTile({
    required this.targetId,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileStreamProvider(targetId));
    final isMe = targetId == currentUser.uid;

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final isFollowing = currentUser.following.contains(targetId);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen(userId: targetId)),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                backgroundColor: AppColors.surfaceVariant,
                child: user.photoUrl == null
                    ? Text(
                        user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                      )
                    : null,
              ),
            ),
            title: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen(userId: targetId)),
              ),
              child: Text(
                user.fullName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            subtitle: Text(
              user.zone.isNotEmpty
                  ? user.zone
                  : (user.accountType == AccountType.business ? 'Profilo Business' : 'Utente Standard'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: isMe
                ? const SizedBox.shrink()
                : SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: () async {
                        final userService = ref.read(userServiceProvider);
                        if (isFollowing) {
                          _confirmUnfollow(context, ref, user);
                        } else {
                          await userService.followUser(currentUser.uid, targetId);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing ? Colors.grey.shade200 : AppColors.accent,
                        foregroundColor: isFollowing ? Colors.black87 : Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isFollowing ? 'Segui già' : 'Segui',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen(userId: targetId)),
            ),
          ),
        );
      },
      loading: () => Container(
        height: 72,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _confirmUnfollow(BuildContext context, WidgetRef ref, UserModel targetUser) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Smetti di seguire'),
        content: Text('Sei sicuro di voler smettere di seguire ${targetUser.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(userServiceProvider).unfollowUser(currentUser.uid, targetUser.uid);
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Smetti di seguire'),
          ),
        ],
      ),
    );
  }
}
