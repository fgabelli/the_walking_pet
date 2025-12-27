import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/announcement_model.dart';
import '../../../../shared/models/user_model.dart'; // Added
import '../providers/nextdoor_provider.dart';
import 'create_announcement_screen.dart';
import 'announcement_detail_screen.dart';
import '../../../offers/presentation/screens/offers_screen.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/screens/business_profile_screen.dart'; // Added
import '../../../../features/ads/presentation/widgets/unified_ad_card.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class NextdoorScreen extends ConsumerStatefulWidget {
  const NextdoorScreen({super.key});

  @override
  ConsumerState<NextdoorScreen> createState() => _NextdoorScreenState();
}

class _NextdoorScreenState extends ConsumerState<NextdoorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update FAB visibility
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nextdoor'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Bacheca'),
            Tab(text: 'Offerte'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Announcements
          _AnnouncementsTab(),
          // Tab 2: Offers
          const OffersScreen(),
        ],
      ),
      floatingActionButton: _tabController.index == 0 
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateAnnouncementScreen(),
                  ),
                );
              },
              label: const Text('Nuovo Annuncio'),
              icon: const Icon(Icons.add),
              backgroundColor: AppColors.primary,
              heroTag: 'nextdoor_fab',
              foregroundColor: Colors.white,
            )
          : null, // Hide FAB on Offers tab (let OffersScreen handle it)
    );
  }
}

class _AnnouncementsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends ConsumerState<_AnnouncementsTab> {
  bool _showFriendsOnly = false;
  AnnouncementCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final nextdoorState = ref.watch(nextdoorControllerProvider);
    final currentUserAsync = ref.watch(currentUserProfileProvider);
    final showAds = currentUserAsync.value != null && !currentUserAsync.value!.isPremium;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Tutti'), icon: Icon(Icons.public, size: 16)),
                    ButtonSegment(value: true, label: Text('Amici'), icon: Icon(Icons.people, size: 16)),
                  ],
                  selected: {_showFriendsOnly},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() {
                      _showFriendsOnly = newSelection.first;
                    });
                  },
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Category Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Tutte le categorie'),
                selected: _selectedCategory == null,
                onSelected: (selected) {
                  setState(() => _selectedCategory = null);
                },
                visualDensity: VisualDensity.compact,
              ),
              ...AnnouncementCategory.values.map((cat) => Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ChoiceChip(
                  label: Text(cat.displayName),
                  selected: _selectedCategory == cat,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = selected ? cat : null);
                  },
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(cat.icon, size: 14, color: _selectedCategory == cat ? Colors.white : cat.color),
                  selectedColor: cat.color,
                  labelStyle: TextStyle(
                    color: _selectedCategory == cat ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              )),
            ],
          ),
        ),
        
        // Ads and Showcase
        if (showAds && !nextdoorState.isLoading && nextdoorState.error == null)
           Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: UnifiedAdCard(
              zone: 'nextdoor_top',
              adSize: AdSize.largeBanner,
            ),
          ),

        if (!_showFriendsOnly && nextdoorState.businesses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
               children: [
                 const Icon(Icons.verified, color: Colors.blue, size: 16),
                 const SizedBox(width: 8),
                 Text(
                   'Attività Partner',
                   style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                 ),
               ],
            ),
          ),

        Expanded(
          child: nextdoorState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : nextdoorState.error != null
                  ? Center(child: Text('Errore: ${nextdoorState.error}'))
                  : currentUserAsync.when(
                      data: (currentUser) {
                        final showAds = currentUser != null && !currentUser.isPremium;
                        var announcements = nextdoorState.announcements;
                        var businesses = nextdoorState.businesses;
                        
                        if (_showFriendsOnly && currentUser != null) {
                          announcements = announcements.where((a) {
                            return currentUser.friends.contains(a.userId) || a.userId == currentUser.uid;
                          }).toList();
                          businesses = []; // Don't show businesses on friends-only feed
                        }

                        if (_selectedCategory != null) {
                          announcements = announcements.where((a) {
                            return a.category == _selectedCategory;
                          }).toList();
                          // Could also filter businesses by category if UserModel had a rigorous one
                        }

                        // Combine into a single feed
                        final List<dynamic> combinedFeed = [];
                        int busIdx = 0;
                        int announcementIdx = 0;

                        while (announcementIdx < announcements.length || busIdx < businesses.length) {
                          // Inject a business every 4 announcements (or at the start)
                          if (busIdx < businesses.length && (combinedFeed.isEmpty || (combinedFeed.length + 1) % 5 == 0)) {
                             combinedFeed.add(businesses[busIdx]);
                             busIdx++;
                          } else if (announcementIdx < announcements.length) {
                             combinedFeed.add(announcements[announcementIdx]);
                             announcementIdx++;
                          } else if (busIdx < businesses.length) {
                             // If out of announcements, add remaining businesses
                             combinedFeed.add(businesses[busIdx]);
                             busIdx++;
                          }
                        }

                        return Column(
                          children: [
                            Expanded(
                              child: combinedFeed.isEmpty 
                                  ? _buildEmptyState(showAds)
                                  : _buildUnifiedList(combinedFeed, showAds),
                            ),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Center(child: Text('Errore utente: $e')),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool showAds) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showAds)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: UnifiedAdCard(
              zone: 'nextdoor_empty',
              adSize: AdSize.largeBanner,
            ),
          ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.campaign_outlined,
                    size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text(
                  _showFriendsOnly
                      ? 'Nessun annuncio dai tuoi amici'
                      : 'Nessun annuncio nelle vicinanze',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                if (!_showFriendsOnly) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Sii il primo a scrivere qualcosa!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnifiedList(List<dynamic> items, bool showAds) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), // Increased bottom padding for FAB
      itemCount: showAds 
          ? items.length + (items.length ~/ 3)
          : items.length,
      itemBuilder: (context, index) {
        if (showAds) {
          // Ad Injection Logic (Every 3 regular items)
          if (index > 0 && (index + 1) % 4 == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: UnifiedAdCard(
                zone: 'nextdoor_feed',
                adSize: AdSize.largeBanner,
              ),
            );
          }
          final itemIndex = index - (index ~/ 4);
          if (itemIndex >= items.length) return const SizedBox.shrink();
          final item = items[itemIndex];
          if (item is AnnouncementModel) {
            return _AnnouncementCard(announcement: item);
          } else if (item is UserModel) {
            return _BusinessFeedCard(business: item);
          }
          return const SizedBox.shrink();
        } else {
          final item = items[index];
          if (item is AnnouncementModel) {
            return _AnnouncementCard(announcement: item);
          } else if (item is UserModel) {
            return _BusinessFeedCard(business: item);
          }
          return const SizedBox.shrink();
        }
      },
    );
  }
}



class _AnnouncementCard extends ConsumerWidget {
  final AnnouncementModel announcement;

  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProfileProvider);
    final currentUser = currentUserAsync.value;
    final isCloseFriend = currentUser?.closeFriends.contains(announcement.userId) ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnnouncementDetailScreen(announcement: announcement),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Author and Category
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.surfaceVariant,
                    backgroundImage: announcement.authorPhotoUrl != null
                        ? NetworkImage(announcement.authorPhotoUrl!)
                        : null,
                    child: announcement.authorPhotoUrl == null
                        ? const Icon(Icons.person, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                announcement.authorName,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCloseFriend) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.star, size: 14, color: Colors.amber),
                            ],
                          ],
                        ),
                        Text(
                          '${announcement.zone} • ${timeago.format(announcement.createdAt, locale: 'it')}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: announcement.category.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(announcement.category.icon, size: 12, color: announcement.category.color),
                        const SizedBox(width: 4),
                        Text(
                          announcement.category.displayName,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: announcement.category.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                announcement.message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.4,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Image
            if (announcement.imageUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      announcement.imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: AppColors.surfaceVariant,
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  ),
                ),
              ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 12, color: AppColors.textSecondary.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(
                    'Scade tra ${_getTimeRemaining(announcement.expiresAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                  ),
                  const Spacer(),
                  _ReactionButton(
                    icon: Icons.pets,
                    count: announcement.responses.where((r) => r.type == ResponseType.watching).length,
                    onPressed: () {
                      ref.read(nextdoorControllerProvider.notifier).addResponse(
                            announcement.id,
                            ResponseType.watching,
                          );
                    },
                    isActive: announcement.responses.any((r) => r.userId == currentUser?.uid && r.type == ResponseType.watching),
                    activeColor: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _ReactionButton(
                    icon: Icons.chat_bubble_outline,
                    count: announcement.responses.where((r) => r.type == ResponseType.message).length,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AnnouncementDetailScreen(announcement: announcement),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeRemaining(DateTime expiresAt) {
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'scaduto';
    if (diff.inHours > 0) return '${diff.inHours}h';
    return '${diff.inMinutes}m';
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onPressed;
  final bool isActive;
  final Color? activeColor;

  const _ReactionButton({
    required this.icon,
    required this.count,
    required this.onPressed,
    this.isActive = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? (activeColor ?? AppColors.primary) : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isActive ? (activeColor ?? AppColors.primary) : AppColors.textSecondary,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessFeedCard extends StatelessWidget {
  final UserModel business;

  const _BusinessFeedCard({required this.business});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BusinessProfileScreen(businessUser: business),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Business Info and Sponsored Tag
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                   CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.surfaceVariant,
                    backgroundImage: business.photoUrl != null
                        ? NetworkImage(business.photoUrl!)
                        : null,
                    child: business.photoUrl == null
                        ? const Icon(Icons.storefront, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                business.fullName,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 14, color: Colors.blue),
                          ],
                        ),
                        Text(
                          '${business.businessCategory ?? "Attività"} • ${business.zone}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'SPONSORIZZATO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Description/Bio
            if (business.bio != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  business.bio!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Cover Image
            if (business.coverImageUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      business.coverImageUrl!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    '${business.averageRating} (${business.reviewCount} recensioni)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                       Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BusinessProfileScreen(businessUser: business),
                        ),
                      );
                    },
                    child: const Text('Visita profilo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
