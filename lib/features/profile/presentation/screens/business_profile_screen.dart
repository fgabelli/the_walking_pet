import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/review_model.dart';
import '../providers/profile_provider.dart'; // For currentUserProfileProvider
import '../../../../features/offers/presentation/screens/offers_screen.dart'; // Reuse offer listing logic if possible, or create a streamlined widget

class BusinessProfileScreen extends ConsumerStatefulWidget {
  final UserModel businessUser;

  const BusinessProfileScreen({super.key, required this.businessUser});

  @override
  ConsumerState<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends ConsumerState<BusinessProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.businessUser;
    
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200.0,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover Image (Placeholder for now until we add upload)
                    user.coverImageUrl != null 
                        ? Image.network(user.coverImageUrl!, fit: BoxFit.cover)
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primary, AppColors.secondary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(Icons.store, size: 80, color: Colors.white24),
                          ),
                    // Gradient Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 38,
                            backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                            child: user.photoUrl == null ? const Icon(Icons.pets, size: 40) : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Name & Category
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.businessCategory ?? user.firstName, // Use category or First Name
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (user.reviewCount > 0)
                                Row(
                                  children: [
                                    Icon(Icons.star, color: Colors.amber, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      '${user.averageRating.toStringAsFixed(1)} (${user.reviewCount})',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              if (user.businessCategory != null)
                                Chip(
                                  label: Text(
                                    user.businessCategory!, 
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                  backgroundColor: AppColors.secondary,
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    if (user.bio != null && user.bio!.isNotEmpty)
                      Text(user.bio!),
                    
                    const SizedBox(height: 24),
                    
                    // Action Buttons (Socials & Contact)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Follow Button
                        Consumer(
                          builder: (context, ref, _) {
                            final currentUserAsync = ref.watch(currentUserProfileProvider);
                            return currentUserAsync.when(
                              data: (currentUser) {
                                if (currentUser == null || currentUser.uid == user.uid) return const SizedBox();
                                final isFollowing = currentUser.following.contains(user.uid);
                                
                                return _ActionButton(
                                  icon: isFollowing ? Icons.notifications_active : Icons.notifications_none,
                                  label: isFollowing ? 'Segui già' : 'Segui',
                                  color: isFollowing ? AppColors.secondary : Colors.grey,
                                  onTap: () async {
                                    final userService = ref.read(userServiceProvider);
                                    if (isFollowing) {
                                      await userService.unfollowUser(currentUser.uid, user.uid);
                                    } else {
                                      await userService.followUser(currentUser.uid, user.uid);
                                    }
                                  },
                                );
                              },
                              loading: () => const SizedBox(),
                              error: (_, __) => const SizedBox(),
                            );
                          },
                        ),
                        if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
                          _ActionButton(
                            icon: Icons.phone, 
                            label: 'Chiama', 
                            onTap: () => _launchUrl('tel:${user.phoneNumber}'),
                          ),
                        if (user.website != null && user.website!.isNotEmpty)
                          _ActionButton(
                            icon: Icons.language, 
                            label: 'Sito', 
                            onTap: () => _launchUrl(user.website!.startsWith('http') ? user.website! : 'https://${user.website}'),
                          ),
                        if (user.instagramHandle != null && user.instagramHandle!.isNotEmpty)
                           _ActionButton(
                            icon: FontAwesomeIcons.instagram, 
                            label: 'Insta', 
                            onTap: () => _launchUrl('https://instagram.com/${user.instagramHandle!.replaceAll('@', '')}'),
                          ),
                         if (user.tiktokHandle != null && user.tiktokHandle!.isNotEmpty)
                           _ActionButton(
                            icon: FontAwesomeIcons.tiktok, 
                            label: 'TikTok', 
                            onTap: () => _launchUrl('https://tiktok.com/@${user.tiktokHandle!.replaceAll('@', '')}'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(text: 'Info'),
                    Tab(text: 'Recensioni'),
                    Tab(text: 'Offerte'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Info Tab
            _InfoTab(user: user),
            // Reviews Tab
            _ReviewsTab(businessUser: user),
            // Offers Tab (Placeholder for now, or fetch offers by authorId)
            Center(child: Text('Le offerte di ${user.businessCategory ?? "questa attività"} appariranno qui.', style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: (color ?? AppColors.primary).withOpacity(0.1),
            child: Icon(icon, color: color ?? AppColors.primary, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  final UserModel user;
  const _InfoTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (user.openingHours != null && user.openingHours!.isNotEmpty) ...[
          _InfoRow(icon: Icons.access_time, title: 'Orari', content: user.openingHours!),
          const Divider(),
        ],
        if (user.address != null && user.address!.isNotEmpty) ...[
          _InfoRow(icon: Icons.location_on, title: 'Indirizzo', content: user.address!),
          const Divider(),
        ],
        if (user.email.isNotEmpty)
          _InfoRow(icon: Icons.email, title: 'Email', content: user.email),
        
        // Add more fields here (Reviews snapshot, Gallery grid, etc.)
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _InfoRow({required this.icon, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(content, style: const TextStyle(color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height + 1; // +1 for border
  @override
  double get maxExtent => _tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          _tabBar,
          const Divider(height: 1),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

class _ReviewsTab extends ConsumerWidget {
  final UserModel businessUser;
  const _ReviewsTab({required this.businessUser});

  void _showAddReviewDialog(BuildContext context, WidgetRef ref) {
    final commentController = TextEditingController();
    double tempRating = 5.0; // Changed variable name to avoid conflict if any

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Scrivi una recensione'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < tempRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          tempRating = index + 1.0;
                        });
                      },
                    );
                  }),
                ),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    hintText: 'Racconta la tua esperienza...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla'),
              ),
              TextButton(
                onPressed: () async {
                  final currentUser = ref.read(currentUserProfileProvider).value;
                  if (currentUser == null) return;

                  final reviewService = ref.read(reviewServiceProvider);
                  final review = ReviewModel(
                    id: '', // Service will generate
                    authorId: currentUser.uid,
                    authorName: currentUser.fullName,
                    authorPhotoUrl: currentUser.photoUrl,
                    targetUserId: businessUser.uid,
                    rating: tempRating,
                    comment: commentController.text,
                    timestamp: DateTime.now(),
                  );

                  await reviewService.addBusinessReview(review);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Invia'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewService = ref.watch(reviewServiceProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${businessUser.reviewCount} Recensioni',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              OutlinedButton.icon(
                onPressed: () => _showAddReviewDialog(context, ref),
                icon: const Icon(Icons.edit),
                label: const Text('Scrivi'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ReviewModel>>(
            stream: reviewService.getBusinessReviews(businessUser.uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Errore: ${snapshot.error}'));
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final reviews = snapshot.data ?? [];
              if (reviews.isEmpty) {
                return const Center(child: Text('Nessuna recensione ancora.'));
              }

              return ListView.builder(
                itemCount: reviews.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final review = reviews[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: review.authorPhotoUrl != null 
                                    ? NetworkImage(review.authorPhotoUrl!) 
                                    : null,
                                child: review.authorPhotoUrl == null 
                                    ? const Icon(Icons.person, size: 16) 
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(review.authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Row(
                                children: List.generate(5, (starIndex) {
                                  return Icon(
                                    starIndex < review.rating ? Icons.star : Icons.star_border,
                                    size: 14,
                                    color: Colors.amber,
                                  );
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(review.comment),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
