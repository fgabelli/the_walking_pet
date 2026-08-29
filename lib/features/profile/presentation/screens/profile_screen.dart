import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/constants/tutorial_keys.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/social_post_model.dart';
import '../../../../shared/models/reel_model.dart';
import '../../../../core/services/social_feed_service.dart';
import '../../../../core/services/reel_service.dart';
import '../providers/dog_provider.dart';
import '../providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/review_service.dart';
import '../../../../core/services/purchase_service.dart'; 
import 'create_dog_profile_screen.dart';
import 'create_profile_screen.dart';
import 'pet_profile_screen.dart';


import 'business_profile_edit_screen.dart'; 
import 'business_profile_screen.dart';
import 'following_list_screen.dart'; 
import 'connections_list_screen.dart';
import 'blocked_users_screen.dart'; 
import 'who_viewed_me_screen.dart'; 
import '../../../subscriptions/presentation/screens/paywall_screen.dart'; 
import '../../../../core/services/user_service.dart';
import '../../../../features/map/presentation/providers/map_provider.dart'; 
import '../../../subscriptions/presentation/screens/subscription_settings_screen.dart';
import '../../../chat/presentation/providers/chat_provider.dart'; // Added
import '../../../chat/presentation/screens/chat_screen.dart'; // Added
import '../../../walking/presentation/screens/walk_stats_screen.dart';
import '../../../chatbot/presentation/screens/chatbot_screen.dart';
import '../../../social/presentation/screens/social_feed_screen.dart';
import '../../../social/presentation/screens/reels_screen.dart';
import '../../../../shared/utils/share_content_helper.dart';


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
          ] else ...[
             // Block / Report Menu
             PopupMenuButton<String>(
               onSelected: (value) {
                 if (value == 'block') {
                   // Block User
                   ref.read(userServiceProvider).blockUser(currentUser!.uid, userId!);
                   Navigator.pop(context); // Close profile
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Utente bloccato e nascosto dalla mappa.')),
                   );
                 } else if (value == 'report') {
                   // Report User
                   showDialog(
                      context: context,
                      builder: (context) => _ReportUserDialog(
                        onReport: (reason, description) async {
                          try {
                             await ref.read(userServiceProvider).reportUser(
                               reporterId: currentUser!.uid,
                               reportedUserId: userId!,
                               reason: reason,
                               description: description,
                             );
                             if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 const SnackBar(content: Text('Segnalazione inviata. Grazie per il tuo contributo alla sicurezza.')),
                               );
                             }
                          } catch (e) {
                             if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(content: Text('Errore nell\'invio della segnalazione: $e')),
                               );
                             }
                          }
                        },
                      ),
                   );
                 }
               },
               itemBuilder: (context) => [
                 const PopupMenuItem(
                   value: 'report',
                   child: Row(
                     children: [Icon(Icons.flag, color: Colors.orange), SizedBox(width: 8), Text('Segnala')],
                   ),
                 ),
                 const PopupMenuItem(
                   value: 'block',
                   child: Row(
                     children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 8), Text('Blocca')],
                   ),
                 ),
               ],
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

class _ProfileContent extends ConsumerStatefulWidget {
  final UserModel user;
  final bool isMe;
  const _ProfileContent({required this.user, required this.isMe});
  @override
  ConsumerState<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<_ProfileContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _postCount = 0;
  bool get isMe => widget.isMe;
  UserModel get user => widget.user;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dogService = ref.watch(dogServiceProvider);
    final currentUser = ref.watch(authServiceProvider).currentUser;
    final currentUserProfile = ref.watch(currentUserProfileProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER: Avatar + Stats
                Row(
                  children: [
                    Container(
                      width: 86, height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [AppColors.accent, AppColors.primary]),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
                        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                        child: user.photoUrl == null ? Icon(Icons.person, size: 40, color: AppColors.textSecondary) : null,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statCol('$_postCount', 'post'),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ConnectionsListScreen(
                                  title: 'Follower',
                                  userIds: user.followers,
                                ),
                              ),
                            ),
                            child: _statCol('${user.followers.length}', 'follower'),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ConnectionsListScreen(
                                  title: 'Seguiti',
                                  userIds: user.following,
                                ),
                              ),
                            ),
                            child: _statCol('${user.following.length}', 'seguiti'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // NAME + BIO
                Text('${user.firstName} ${user.lastName}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                if (user.zone.isNotEmpty)
                  Row(children: [
                    Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 2),
                    Flexible(child: Text(user.zone, style: TextStyle(fontSize: 13, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                if (user.bio?.isNotEmpty ?? false)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text(user.bio!, style: const TextStyle(fontSize: 14, height: 1.3), maxLines: 3)),
                const SizedBox(height: 14),
                // ACTION BUTTONS
                if (isMe)
                  Row(children: [
                    Expanded(child: _actionBtn('Modifica profilo', () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateProfileScreen(userToEdit: user))))),
                    const SizedBox(width: 8),
                    Expanded(child: _actionBtn('Condividi profilo', () {
                      Share.share('Guarda il mio profilo su Dogzn! 🐾\nhttps://dogzn.com');
                    })),
                  ])
                else if (currentUserProfile != null)
                  Row(children: [
                    Expanded(child: _followBtn(ref, currentUserProfile, user)),
                    const SizedBox(width: 8),
                    Expanded(child: _actionBtn('Messaggio', () async {
                      final chatId = await ref.read(chatControllerProvider.notifier).createChat(user.uid);
                      if (chatId != null && context.mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId, otherUser: user)));
                      }
                    })),
                  ]),
                const SizedBox(height: 16),
                // PET AVATARS
                StreamBuilder<List<DogModel>>(
                  stream: dogService.getDogsStreamByOwnerId(user.uid),
                  builder: (context, snapshot) {
                    final dogs = snapshot.data ?? [];
                    if (dogs.isEmpty && !isMe) return const SizedBox.shrink();
                    return SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: dogs.length + (isMe ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          if (isMe && index == 0) {
                            return SizedBox(
                              width: 68,
                              child: Column(children: [
                                GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateDogProfileScreen())),
                                  child: Container(
                                    key: TutorialKeys.addPetKey,
                                    width: 64, height: 64,
                                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300, width: 1.5)),
                                    child: const Icon(Icons.add, size: 28, color: Colors.grey),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text('Aggiungi', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ]),
                            );
                          }
                          final dog = dogs[isMe ? index - 1 : index];
                          return GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PetProfileScreen(dog: dog, isOwner: isMe))),
                            child: _PetAvatar(dog: dog),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        // TAB BAR
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            TabBar(
              controller: _tabController,
              indicatorColor: isDark ? Colors.white : AppColors.primary,
              indicatorWeight: 1.5,
              labelColor: isDark ? Colors.white : AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: const [Tab(icon: Icon(Icons.grid_on, size: 24)), Tab(icon: Icon(Icons.play_arrow_rounded, size: 26)), Tab(icon: Icon(Icons.menu, size: 24))],
            ),
            isDark: isDark,
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _PostsGridView(userId: user.uid, isMe: isMe, onCount: (c) {
            if (_postCount != c) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _postCount = c); });
          }),
          _ReelsGridView(userId: user.uid),
          _SettingsListView(user: user, isMe: isMe),
        ],
      ),
    );
  }

  Widget _statCol(String val, String label) => Column(mainAxisSize: MainAxisSize.min, children: [
    Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
  ]);

  Widget _actionBtn(String label, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36, alignment: Alignment.center,
        decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
      ),
    );
  }

  Widget _followBtn(WidgetRef ref, UserModel me, UserModel target) {
    final following = me.following.contains(target.uid);
    return GestureDetector(
      onTap: () => following
          ? ref.read(userServiceProvider).unfollowUser(me.uid, target.uid)
          : ref.read(userServiceProvider).followUser(me.uid, target.uid),
      child: Container(
        height: 36, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: following ? Colors.grey[200] : AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(following ? 'Segui già' : 'Segui', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: following ? Colors.black87 : Colors.white)),
      ),
    );
  }
}

// Compact pet avatar for profile view (Instagram Stories style)
class _PetAvatar extends StatelessWidget {
  final DogModel dog;
  const _PetAvatar({required this.dog});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          // Avatar with species badge
          Stack(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accent.withOpacity(0.4),
                    width: 2.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: dog.photoUrl != null
                      ? NetworkImage(dog.photoUrl!)
                      : null,
                  child: dog.photoUrl == null
                      ? Icon(
                          dog.species == PetSpecies.cat ? Icons.emoji_nature : Icons.pets,
                          size: 28,
                          color: AppColors.accent,
                        )
                      : null,
                ),
              ),
              // Species badge
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      dog.species == PetSpecies.cat ? '🐱' : '🐶',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Name
          Text(
            dog.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ===== STICKY TAB BAR DELEGATE =====
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isDark;
  _TabBarDelegate(this.tabBar, {required this.isDark});

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: isDark ? AppColors.backgroundDark : Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

// ===== POSTS GRID TAB =====
class _PostsGridView extends ConsumerWidget {
  final String userId;
  final bool isMe;
  final ValueChanged<int> onCount;

  const _PostsGridView({required this.userId, required this.isMe, required this.onCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedService = ref.watch(socialFeedServiceProvider);

    return StreamBuilder<List<SocialPostModel>>(
      stream: feedService.getUserPostsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final posts = snapshot.data ?? [];
        onCount(posts.length);

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  isMe ? 'Condividi un momento\ncon il tuo pet 🐾' : 'Nessun post',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(1),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2,
          ),
          itemCount: posts.length + (isMe ? 1 : 0),
          itemBuilder: (context, index) {
            // First item: "+" button for creating a new post (own profile only)
            if (isMe && index == 0) {
              return GestureDetector(
                onTap: () => showCreatePostSheet(context),
                child: Container(
                  color: Colors.grey.shade100,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 36, color: AppColors.primary.withOpacity(0.7)),
                        const SizedBox(height: 6),
                        Text('Nuovo Post', style: TextStyle(fontSize: 11, color: AppColors.primary.withOpacity(0.7), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              );
            }

            final post = posts[isMe ? index - 1 : index];
            return GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                builder: (_) => _PostDetailSheet(post: post),
              ),
              child: Container(
                color: Colors.grey.shade200,
                child: post.imageUrl != null
                    ? Image.network(post.imageUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)))
                    : Center(child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(post.text ?? '', style: const TextStyle(fontSize: 11), maxLines: 5, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                      )),
              ),
            );
          },
        );
      },
    );
  }
}

// ===== REELS GRID TAB =====
class _ReelsGridView extends ConsumerWidget {
  final String userId;
  const _ReelsGridView({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reelService = ref.watch(reelServiceProvider);

    return StreamBuilder<List<ReelModel>>(
      stream: reelService.getUserReels(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reels = snapshot.data ?? [];
        if (reels.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline, size: 48, color: AppColors.textTertiary),
                const SizedBox(height: 12),
                Text('Nessun reel', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(1),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 9 / 16,
          ),
          itemCount: reels.length,
          itemBuilder: (context, index) {
            final reel = reels[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReelsScreen(
                      initialReels: reels,
                      initialIndex: index,
                    ),
                  ),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Thumbnail or gradient placeholder
                  if (reel.thumbnailUrl != null)
                    Image.network(reel.thumbnailUrl!, fit: BoxFit.cover)
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary.withValues(alpha: 0.3), AppColors.accent.withValues(alpha: 0.3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(child: Icon(Icons.play_arrow, color: Colors.white, size: 32)),
                    ),
                  // Play icon overlay
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Row(
                      children: [
                        const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                        const SizedBox(width: 2),
                        Text(
                          '${reel.viewCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ===== SETTINGS / INFO TAB =====
class _SettingsListView extends ConsumerWidget {
  final UserModel user;
  final bool isMe;
  const _SettingsListView({required this.user, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isMe) {
      return ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
        if (user.address != null && user.address!.isNotEmpty)
          ListTile(leading: const Icon(Icons.location_on_outlined), title: Text(user.address!)),
        if (user.birthDate != null)
          ListTile(leading: const Icon(Icons.cake_outlined), title: Text('${_calcAge(user.birthDate!)} anni')),
      ]);
    }
    return ListView(padding: const EdgeInsets.symmetric(vertical: 4), children: [
      ListTile(leading: const Icon(Icons.bar_chart, color: AppColors.accent), title: const Text('Le Tue Statistiche'),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalkStatsScreen()))),
      ListTile(leading: const Icon(Icons.visibility_outlined), title: const Text('Visite al Profilo'),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WhoViewedMeScreen()))),
      const Divider(height: 1),
      if (user.isPremium)
        ListTile(leading: const Icon(Icons.credit_card, color: AppColors.primary), title: const Text('Il mio Abbonamento'),
          trailing: const Icon(Icons.chevron_right, size: 20),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionSettingsScreen()))),
      if (!user.isPremium)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.amber.shade300, Colors.amber.shade500]), borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.star, color: Colors.white),
            title: const Text('Passa a Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaywallScreen())),
          ),
        ),
      ListTile(
        key: TutorialKeys.businessProfileKey,
        leading: const Icon(Icons.store_outlined, color: AppColors.primary),
        title: Text(user.accountType == AccountType.business ? 'Gestisci Profilo Business' : 'Passa a Profilo Business', style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () async {
          final ci = await ref.read(purchaseServiceProvider).getCustomerInfo();
          final isBiz = ci != null && ref.read(purchaseServiceProvider).isBusiness(ci);
          if (!context.mounted) return;
          if (isBiz || user.accountType == AccountType.business) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessProfileEditScreen(user: user)));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => PaywallScreen(offeringId: 'business_pro')));
          }
        },
      ),
      const Divider(height: 1),
      ListTile(leading: const Icon(Icons.smart_toy_outlined, color: AppColors.primary), title: const Text('Assistente AI'),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen()))),
      ListTile(leading: const Icon(Icons.block_outlined), title: const Text('Utenti Bloccati'),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BlockedUsersScreen()))),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.download_outlined),
        title: const Text('Scarica i miei dati (GDPR)'),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => _showDownloadDataDialog(context, ref),
      ),
      const Divider(height: 1),
      ListTile(
        leading: const Icon(Icons.delete_outline, color: AppColors.error),
        title: const Text('Elimina Account', style: TextStyle(color: AppColors.error)),
        onTap: () {
          if (user.isPremium) {
            showDialog(context: context, builder: (ctx) => AlertDialog(
              title: const Text('Abbonamento Attivo'),
              content: const Text('Hai un abbonamento attivo. L\'eliminazione dell\'account NON annullerà il rinnovo sullo store.'),
              actions: [
                TextButton(onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionSettingsScreen())); }, child: const Text('Gestisci Abbonamento')),
                TextButton(onPressed: () { Navigator.pop(ctx); _showDeleteDialog(context, ref); }, style: TextButton.styleFrom(foregroundColor: AppColors.error), child: const Text('Procedi')),
              ],
            ));
          } else {
            _showDeleteDialog(context, ref);
          }
        },
      ),
    ]);
  }

  void _showDownloadDataDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Esporta i tuoi dati (GDPR)'),
        content: const Text(
          'In conformità con l\'Art. 20 del GDPR (Portabilità dei dati), puoi richiedere e scaricare una copia strutturata di tutti i tuoi dati memorizzati (profilo, pet, post, reels, commenti, amicizie e messaggi inviati).\n\nL\'operazione potrebbe richiedere qualche istante.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _handleDataExport(context);
            },
            child: const Text('Esporta'),
          ),
        ],
      ),
    );
  }

  void _handleDataExport(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Generazione archivio in corso...')),
          ],
        ),
      ),
    );

    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('exportUserData')
          .call();

      if (context.mounted) Navigator.pop(context);

      final data = result.data;
      if (data == null) {
        throw Exception('Nessun dato restituito.');
      }

      const encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(data);

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/TWP_Dati_Personali.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'TWP - Esportazione Dati Personali (GDPR)',
        text: 'Ecco l\'esportazione dei tuoi dati personali da The Walking Pet.',
      );
    } catch (e) {
      try {
        if (context.mounted) Navigator.pop(context);
      } catch (_) {}
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Errore'),
            content: Text('Impossibile esportare i dati: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }


  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Elimina Account'),
      content: const Text('Sei sicuro? Questa azione è irreversibile.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
        TextButton(
          onPressed: () { Navigator.pop(ctx); ref.read(profileControllerProvider.notifier).deleteAccount(); },
          style: TextButton.styleFrom(foregroundColor: AppColors.error), child: const Text('Elimina')),
      ],
    ));
  }

  int _calcAge(DateTime bd) {
    final now = DateTime.now();
    int age = now.year - bd.year;
    if (now.month < bd.month || (now.month == bd.month && now.day < bd.day)) age--;
    return age;
  }
}




/// Bottom sheet to view a single post in detail from the profile grid
class _PostDetailSheet extends ConsumerWidget {
  final SocialPostModel post;

  const _PostDetailSheet({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Author header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: post.authorId)));
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.accent.withOpacity(0.2),
                    backgroundImage: post.authorPhotoUrl != null
                        ? NetworkImage(post.authorPhotoUrl!)
                        : null,
                    child: post.authorPhotoUrl == null
                        ? Text(
                            post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: post.authorId)));
                    },
                    child: Text(
                      post.authorName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
                Text(
                  _formatDate(post.createdAt),
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                if (post.imageUrl != null) ...[
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(Icons.ios_share, size: 20, color: AppColors.textTertiary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ShareContentHelper.sharePost(
                        context: context,
                        imageUrl: post.imageUrl!,
                        authorName: post.authorName,
                        caption: post.text,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Image
          if (post.imageUrl != null)
            Flexible(
              child: Image.network(
                post.imageUrl!,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.grey[100],
                  child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                ),
              ),
            ),
          // Text
          if (post.text != null && post.text!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  post.text!,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ),
            ),
          // Like / comment counts
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _showLikers(context, ref, post.likes),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.red, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likeCount}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.chat_bubble_outline, color: AppColors.textTertiary, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${post.commentCount}',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLikers(BuildContext context, WidgetRef ref, List<String> likerIds) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Piace a', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black)),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: likerIds.isEmpty
                  ? const Center(child: Text('Nessun like ancora', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: likerIds.length,
                      itemBuilder: (context, index) {
                        final uid = likerIds[index];
                        return FutureBuilder<UserModel?>(
                          future: ref.read(userServiceProvider).getUserById(uid),
                          builder: (context, snap) {
                            final user = snap.data;
                            if (user == null) {
                              return const ListTile(
                                leading: CircleAvatar(backgroundColor: Colors.grey, radius: 20),
                                title: Text('...'),
                              );
                            }
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                                backgroundColor: AppColors.surfaceVariant,
                                child: user.photoUrl == null
                                    ? Text(
                                        user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
                                      )
                                    : null,
                              ),
                              title: Text(
                                '${user.firstName} ${user.lastName}'.trim(),
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                              subtitle: user.zone.isNotEmpty
                                  ? Text(
                                      user.zone,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    )
                                  : null,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ProfileScreen(userId: uid)),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final d = date;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

class _ReportUserDialog extends StatefulWidget {
  final Function(String reason, String? description) onReport;

  const _ReportUserDialog({required this.onReport});

  @override
  State<_ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends State<_ReportUserDialog> {
  String? _selectedReason;
  final _descriptionController = TextEditingController();
  final List<String> _reasons = [
    'Contenuti offensivi o inappropriati',
    'Spam o truffa',
    'Molestie o bullismo',
    'Discorso d\'odio',
    'Altro',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Segnala Utente'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Seleziona un motivo:'),
            const SizedBox(height: 8),
            ..._reasons.map((reason) => RadioListTile<String>(
              title: Text(reason, style: const TextStyle(fontSize: 14)),
              value: reason,
              groupValue: _selectedReason,
              onChanged: (value) => setState(() => _selectedReason = value),
              contentPadding: EdgeInsets.zero,
              dense: true,
            )),
            if (_selectedReason == 'Altro') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrizione (opzionale)',
                  hintText: 'Fornisci maggiori dettagli...',
                ),
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: _selectedReason == null
              ? null
              : () {
                  widget.onReport(_selectedReason!, _descriptionController.text);
                  Navigator.pop(context);
                },
          child: const Text('Segnala'),
        ),
      ],
    );
  }
}
