import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
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
    _tabController = TabController(length: 2, vsync: this);
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
                    Tab(text: 'Informazioni'),
                    Tab(text: 'Offerte Attive'),
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

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Icon(icon, color: AppColors.primary, size: 20),
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
