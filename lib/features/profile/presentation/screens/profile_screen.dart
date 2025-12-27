import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../../shared/models/user_model.dart';
import '../providers/dog_provider.dart';
import '../providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/review_service.dart';
import '../../../../core/services/purchase_service.dart'; // Added
import 'create_dog_profile_screen.dart';
import 'create_profile_screen.dart';

import 'privacy_settings_screen.dart';
import 'business_profile_edit_screen.dart'; // Added
import 'business_profile_screen.dart';
import 'following_list_screen.dart'; // Changed
import 'blocked_users_screen.dart'; // Added
import 'who_viewed_me_screen.dart'; // Added
import '../../../subscriptions/presentation/screens/paywall_screen.dart'; // Added
import '../../../../core/services/user_service.dart';
import '../../../../features/map/presentation/providers/map_provider.dart'; // For LocationService via ref/provider
// Actually we need location service provider directly or import the class
import '../../../../core/services/location_service.dart'; // Assuming we need this
// Wait, map_provider.dart exports locationServiceProvider. I can just use the provider import.
// Let's add the provider import.
import '../../../../features/map/presentation/providers/map_provider.dart'; // Contains locationServiceProvider
import '../../../subscriptions/presentation/screens/subscription_settings_screen.dart'; // Added


class ProfileScreen extends ConsumerWidget {
  final String? userId; // If null, shows current user

  const ProfileScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authServiceProvider).currentUser;
    final isMe = userId == null || userId == currentUser?.uid;
    
    final userAsync = isMe 
        ? ref.watch(currentUserProfileProvider)
        : ref.watch(userProfileStreamProvider(userId!));
    
    final authController = ref.read(authControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(isMe ? 'Il mio Profilo' : 'Profilo Utente'),
        actions: [
          if (isMe) ...[
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

// Provider for fetching other user stream is now in profile_provider.dart (userProfileStreamProvider)

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
                    _buildFollowAction(context, ref, currentUserProfile, user),
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
            title: const Text('Profili Seguiti'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FollowingListScreen(),
                ),
              );
            },
          ),
          
          // Visitors (Premium Feature Entry)
          if (isMe)
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Visite al Profilo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WhoViewedMeScreen()),
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
          
          if (user.isPremium) 
            ListTile(
              leading: const Icon(Icons.credit_card, color: AppColors.primary),
              title: const Text('Il mio Abbonamento'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                 // Import needed at top
                 Navigator.push(
                   context,
                   MaterialPageRoute(
                     builder: (context) => const SubscriptionSettingsScreen(),
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
            // SOS Emergency Button (Added)

            
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
                onTap: () async {
                  // Check Business Entitlement
                  final customerInfo = await ref.read(purchaseServiceProvider).getCustomerInfo();
                  final isBusinessPro = customerInfo != null && 
                                      ref.read(purchaseServiceProvider).isBusiness(customerInfo);

                  if (!context.mounted) return;

                  if (isBusinessPro || user.accountType == AccountType.business) {
                    // Allow access if they have entitlement OR if they are already business (grandfathered/free)
                    // You might want to stricter check later
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusinessProfileEditScreen(user: user),
                      ),
                    );
                  } else {
                    // Show Paywall for Business
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaywallScreen(offeringId: 'business_pro'),
                      ),
                    );
                  }
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
                    builder: (context) => BlockedUsersScreen(),
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
                if (user.isPremium) {
                   // Premium Warning Dialog
                   showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Abbonamento Attivo'),
                      content: const Text(
                        'Attenzione: Hai un abbonamento attivo. L\'eliminazione dell\'account NON annullerà automaticamente il rinnovo automatico sullo store.\n\nTi consigliamo di gestire o annullare l\'abbonamento prima di procedere, per evitare addebiti indesiderati.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                               context,
                               MaterialPageRoute(builder: (_) => const SubscriptionSettingsScreen()),
                            );
                          },
                          child: const Text('Gestisci Abbonamento'),
                        ),
                        TextButton(
                          onPressed: () {
                             Navigator.pop(context);
                             _showDeleteConfirmation(context);
                          },
                          style: TextButton.styleFrom(foregroundColor: AppColors.error),
                          child: const Text('Ignora e Procedi'),
                        ),
                      ],
                    ),
                  );
                } else {
                   _showDeleteConfirmation(context);
                }
              },
            ),

          ],
          const SizedBox(height: 24),


        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
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
          Consumer(
            builder: (context, ref, _) {
              return TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(profileControllerProvider.notifier).deleteAccount();
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Elimina'),
              );
            }
          ),
        ],
      ),
    );
  }


  Widget _buildFollowAction(BuildContext context, WidgetRef ref, UserModel currentUserProfile, UserModel targetUser) {
    final isFollowing = currentUserProfile.following.contains(targetUser.uid);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          if (isFollowing) {
            ref.read(userServiceProvider).unfollowUser(currentUserProfile.uid, targetUser.uid);
          } else {
            ref.read(userServiceProvider).followUser(currentUserProfile.uid, targetUser.uid);
          }
        },
        icon: Icon(isFollowing ? Icons.person_remove : Icons.person_add),
        label: Text(isFollowing ? 'Smetti di seguire' : 'Segui'),
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing ? Colors.grey[200] : AppColors.primary,
          foregroundColor: isFollowing ? Colors.black87 : Colors.white,
        ),
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
