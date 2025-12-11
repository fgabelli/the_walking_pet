import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/announcement_model.dart';
import '../providers/nextdoor_provider.dart';
import 'create_announcement_screen.dart';
import 'announcement_detail_screen.dart';
import '../../../offers/presentation/screens/offers_screen.dart'; // Corrected Import
import '../../../profile/presentation/providers/profile_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final nextdoorState = ref.watch(nextdoorControllerProvider);
    final currentUserAsync = ref.watch(currentUserProfileProvider);

    return Column(
      children: [
        // Filter Segmented Button (moved from AppBar bottom)
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Tutti')),
              ButtonSegment(value: true, label: Text('Solo Amici')),
            ],
            selected: {_showFriendsOnly},
            onSelectionChanged: (Set<bool> newSelection) {
              setState(() {
                _showFriendsOnly = newSelection.first;
              });
            },
          ),
        ),
        
        Expanded(
          child: nextdoorState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : nextdoorState.error != null
                  ? Center(child: Text('Errore: ${nextdoorState.error}'))
                  : currentUserAsync.when(
                      data: (currentUser) {
                        var displayedAnnouncements = nextdoorState.announcements;
                        if (_showFriendsOnly && currentUser != null) {
                          displayedAnnouncements = nextdoorState.announcements.where((a) {
                            return currentUser.friends.contains(a.userId) || a.userId == currentUser.uid;
                          }).toList();
                        }
      
                        if (displayedAnnouncements.isEmpty) {
                          return Center(
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
                          );
                        }
      
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: displayedAnnouncements.length,
                          itemBuilder: (context, index) {
                            final announcement = displayedAnnouncements[index];
                            return _AnnouncementCard(announcement: announcement);
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Center(child: Text('Errore utente: $e')),
                    ),
        ),
      ],
    );
  }
} // End of _AnnouncementsTab



// ... (NextdoorScreen class remains same)

class _AnnouncementCard extends ConsumerWidget {
  final AnnouncementModel announcement;

  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      clipBehavior: Clip.antiAlias, // Clip for image
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
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
                        Text(
                          announcement.authorName,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Vicino a ${announcement.zone} • ${timeago.format(announcement.createdAt, locale: 'it')}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                announcement.message,
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),

            if (announcement.imageUrl != null)
              Image.network(
                announcement.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Scade ${timeago.format(announcement.expiresAt, locale: 'it', allowFromNow: true)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined),
                        onPressed: () {
                          ref.read(nextdoorControllerProvider.notifier).addResponse(
                                announcement.id,
                                ResponseType.watching,
                              );
                        },
                        tooltip: 'Tengo d\'occhio',
                      ),
                      Text(
                        '${announcement.responses.where((r) => r.type == ResponseType.watching).length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AnnouncementDetailScreen(announcement: announcement),
                            ),
                          );
                        },
                        tooltip: 'Commenta',
                      ),
                      Text(
                        '${announcement.responses.where((r) => r.type == ResponseType.message).length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
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
