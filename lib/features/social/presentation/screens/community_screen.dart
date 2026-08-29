import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/tutorial_keys.dart';
import '../../../../core/providers/ad_readiness_provider.dart';
import 'social_feed_screen.dart';
import 'reels_screen.dart';
import '../../../nextdoor/presentation/screens/nextdoor_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';

/// Unified Community screen that merges Social Feed and Bacheca
/// into a single tabbed view with a modern segmented header.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      ref.read(communityTabProvider.notifier).state = _tabController.index;
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(communityTabProvider.notifier).state = _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DOGZN',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 26,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final count = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
              return IconButton(
                icon: count > 0 
                  ? Badge(
                      label: Text('$count'),
                      child: const Icon(Icons.notifications_outlined, size: 26),
                    )
                  : const Icon(Icons.notifications_outlined, size: 26),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationsScreen(),
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            key: TutorialKeys.createPostKey,
            icon: const Icon(Icons.add_box_outlined, size: 26),
            onPressed: () => showCreatePostSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isDark ? Colors.white : AppColors.textPrimary,
          indicatorWeight: 1,
          labelColor: isDark ? Colors.white : AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: [
            Tab(key: TutorialKeys.feedTabKey, text: 'Per te'),
            Tab(key: TutorialKeys.reelsTabKey, child: Icon(Icons.play_circle_outline, size: 22)),
            Tab(key: TutorialKeys.bachecaTabKey, text: 'Bacheca'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _EmbeddedSocialFeed(),
          ReelsScreen(embedded: true),
          _EmbeddedBacheca(),
        ],
      ),
    );
  }
}

/// Embedded version of SocialFeedScreen without its own Scaffold/AppBar
class _EmbeddedSocialFeed extends StatelessWidget {
  const _EmbeddedSocialFeed();

  @override
  Widget build(BuildContext context) {
    // Reuse the full SocialFeedScreen which already has its own Scaffold
    // We wrap it to remove the AppBar duplication
    return const SocialFeedScreen(embedded: true);
  }
}

/// Embedded version of NextdoorScreen (Bacheca) without its own Scaffold/AppBar
class _EmbeddedBacheca extends StatelessWidget {
  const _EmbeddedBacheca();

  @override
  Widget build(BuildContext context) {
    return const NextdoorScreen(embedded: true);
  }
}
