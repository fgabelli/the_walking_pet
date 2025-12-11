import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../core/services/user_service.dart';
import '../providers/profile_provider.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserStream = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Utenti Bloccati'),
      ),
      body: currentUserStream.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Errore utente'));
          if (user.blockedUsers.isEmpty) {
            return const Center(child: Text('Nessun utente bloccato'));
          }

          return ListView.builder(
            itemCount: user.blockedUsers.length,
            itemBuilder: (context, index) {
              final blockedUserId = user.blockedUsers[index];
              return FutureBuilder<UserModel?>(
                future: UserService().getUserById(blockedUserId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final blockedUser = snapshot.data!;
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: blockedUser.photoUrl != null
                          ? NetworkImage(blockedUser.photoUrl!)
                          : null,
                      child: blockedUser.photoUrl == null
                          ? Text(blockedUser.firstName[0].toUpperCase())
                          : null,
                    ),
                    title: Text(blockedUser.fullName),
                    trailing: TextButton(
                      onPressed: () async {
                        try {
                          await UserService().unblockUser(user.uid, blockedUserId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Utente sbloccato')),
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
                      child: const Text('Sblocca', style: TextStyle(color: AppColors.error)),
                    ),
                  );
                },
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
