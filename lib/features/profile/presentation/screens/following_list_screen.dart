import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user_model.dart';
import '../providers/profile_provider.dart';
import '../../../../core/theme/app_colors.dart';

class FollowingListScreen extends ConsumerWidget {
  const FollowingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Following'),
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Utente non trovato'));
          if (user.following.isEmpty) {
            return const Center(child: Text('Non segui ancora nessuno.'));
          }

          return ListView.builder(
            itemCount: user.following.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final targetId = user.following[index];
              return _UserTile(targetId: targetId, currentUser: user);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Errore: $e')),
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  final String targetId;
  final UserModel currentUser;

  const _UserTile({required this.targetId, required this.currentUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // using currentUserProfileProvider for anyone is not correct if we want a generic stream
    // assuming there is a provider that takes uid
    final userAsync = ref.watch(userProfileStreamProvider(targetId));

    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null ? Text(user.firstName[0]) : null,
            ),
            title: Text(user.fullName),
            subtitle: Text(user.accountType == AccountType.business ? 'Business' : 'Standard'),
            trailing: IconButton(
              icon: const Icon(Icons.person_remove_outlined, color: Colors.grey),
              onPressed: () => _confirmUnfollow(context, ref, user),
              tooltip: 'Smetti di seguire',
            ),
            onTap: () {
               // Navigate to their profile
               // (This screen is already in Profile Navigator usually)
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
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
