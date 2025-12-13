import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../../shared/models/user_model.dart';
import '../providers/dog_provider.dart';
import '../providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/review_service.dart';
import 'create_dog_profile_screen.dart';
import 'create_profile_screen.dart';

import '../providers/friend_provider.dart';
import 'privacy_settings_screen.dart';
import 'friends_list_screen.dart';
import 'blocked_users_screen.dart'; // Import
import '../../../subscriptions/presentation/screens/paywall_screen.dart';
import 'business_profile_edit_screen.dart'; // Import
import '../../../../core/services/user_service.dart';

class ProfileScreen extends ConsumerWidget {
  final String? userId; // If null, shows current user

  const ProfileScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authServiceProvider).currentUser;
    final isMe = userId == null || userId == currentUser?.uid;
    
    final userAsync = isMe 
        ? ref.watch(currentUserProfileProvider)
        : ref.watch(userStreamProvider(userId!));
    
    final authController = ref.read(authControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(isMe ? 'Il mio Profilo' : 'Profilo Utente'),
        actions: [
          if (isMe) ...[
             IconButton(
              icon: const Icon(Icons.privacy_tip),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PrivacySettingsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Sei sicuro di voler uscire?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annulla'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          authController.signOut();
                        },
                        child: const Text('Esci'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Utente non trovato'));
          return _ProfileContent(user: user, isMe: isMe);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Errore: $e')),
      ),
    );
  }
}

// Provider for fetching other user stream
final userStreamProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
  return ref.watch(userServiceProvider).getUserStream(uid);
});

class _ProfileContent extends ConsumerWidget {
  final UserModel user;
  final bool isMe;

  const _ProfileContent({required this.user, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dogService = ref.watch(dogServiceProvider);
    final currentUser = ref.watch(authServiceProvider).currentUser;
    // We need full current user model to check friends list
    final currentUserProfile = ref.watch(currentUserProfileProvider).value;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: user.photoUrl != null
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null
                            ? const Icon(Icons.person, size: 40)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${user.firstName} ${user.lastName}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (user.birthDate != null || user.gender != null)
                              Text(
                                [
                                  if (user.birthDate != null) '${_calculateAge(user.birthDate!)} anni',
                                  if (user.gender != null) user.gender!.displayName,
                                ].join(' • '),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            Text(
                              user.zone,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                            if (user.address != null && user.address!.isNotEmpty)
                              Text(
                                user.address!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            const SizedBox(height: 8),
                            // Review Rating
                            FutureBuilder<double>(
                              future: ReviewService().getUserAverageRating(user.uid),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData || snapshot.data == 0) {
                                  return const SizedBox.shrink();
                                }
                                return Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      snapshot.data!.toStringAsFixed(1),
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Media recensioni',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!isMe && currentUserProfile != null) ...[
                    const SizedBox(height: 16),
                    _buildFriendAction(context, ref, currentUserProfile),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Bio Section
          if (user.bio?.isNotEmpty ?? false) ...[
            Text(
              'Bio',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(user.bio!),
            const SizedBox(height: 24),
          ],
          const SizedBox(height: 24),

          // Friends List
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('I miei Amici'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FriendsListScreen(),
                ),
              );
            },
          ),
          const Divider(),
          
          // Privacy Settings
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Privacy Posizione'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacySettingsScreen(),
                ),
              );
            },
          ),
          
          if (!user.isPremium)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade300, Colors.amber.shade500],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.star, color: Colors.white),
                title: const Text(
                  'Passa a Premium',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaywallScreen(),
                    ),
                  );
                },
              ),
            ),
          
          if (isMe) ...[
            // Business Profile Entry Point
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: const Icon(Icons.store, color: AppColors.primary),
                title: Text(
                  user.accountType == AccountType.business 
                      ? 'Gestisci Profilo Business' 
                      : 'Passa a Profilo Business',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                subtitle: user.accountType == AccountType.business 
                    ? null
                    : const Text('Per attività e professionisti', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BusinessProfileEditScreen(user: user),
                    ),
                  );
                },
              ),
            ),
             const SizedBox(height: 8),
             
            const Divider(),
            // Blocked Users
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Utenti Bloccati'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BlockedUsersScreen(),
                  ),
                );
              },
            ),
            // Edit Profile
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Modifica Profilo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateProfileScreen(userToEdit: user),
                  ),
                );
              },
            ),
            
            // Delete Account
            ListTile(
              leading: const Icon(Icons.delete_forever, color: AppColors.error),
              title: const Text(
                'Elimina Account',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Elimina Account'),
                    content: const Text(
                      'Sei sicuro di voler eliminare definitivamente il tuo account? Questa azione è irreversibile e perderai tutti i tuoi dati.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annulla'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ref.read(profileControllerProvider.notifier).deleteAccount();
                        },
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        child: const Text('Elimina'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 24),

          // Dogs Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'I miei Cani',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateDogProfileScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Dogs List
          StreamBuilder<List<DogModel>>(
            stream: dogService.getDogsStreamByOwnerId(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Errore: ${snapshot.error}');
              }
              final dogs = snapshot.data ?? [];
              
              if (dogs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text('Non hai ancora aggiunto nessun pet.'),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dogs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final dog = dogs[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: dog.photoUrl != null
                            ? NetworkImage(dog.photoUrl!)
                            : null,
                        child: dog.photoUrl == null
                            ? const Icon(Icons.pets)
                            : null,
                      ),
                      title: Text(dog.name),
                      subtitle: Text('${dog.breed} • ${dog.gender.displayName} • ${dog.age} anni'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateDogProfileScreen(dogToEdit: dog),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }


  Widget _buildFriendAction(BuildContext context, WidgetRef ref, UserModel currentUserProfile) {
    final isFriend = currentUserProfile.friends.contains(user.uid);
    final isRequestSent = user.friendRequests.contains(currentUserProfile.uid);
    final isRequestReceived = currentUserProfile.friendRequests.contains(user.uid);

    if (isFriend) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Rimuovi Amico'),
                content: Text('Vuoi rimuovere ${user.firstName} dagli amici?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annulla'),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(friendControllerProvider.notifier).removeFriend(user.uid);
                      Navigator.pop(context);
                    },
                    child: const Text('Rimuovi'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.person_remove),
          label: const Text('Rimuovi Amico'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
        ),
      );
    }

    if (isRequestReceived) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                ref.read(friendControllerProvider.notifier).declineFriendRequest(user.uid);
              },
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Rifiuta'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                ref.read(friendControllerProvider.notifier).acceptFriendRequest(user.uid);
              },
              child: const Text('Accetta'),
            ),
          ),
        ],
      );
    }

    if (isRequestSent) {
      return const SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: null, // Disable or allow cancel
          child: Text('Richiesta Inviata'),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          ref.read(friendControllerProvider.notifier).sendFriendRequest(user.uid);
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Aggiungi Amico'),
      ),
    );
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}
