import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/profile_provider.dart';
import 'privacy_settings_screen.dart'; // For usersByIdsProvider
import 'profile_screen.dart';
import '../../../../core/services/user_service.dart';

class FriendsListScreen extends ConsumerStatefulWidget {
  const FriendsListScreen({super.key});

  @override
  ConsumerState<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends ConsumerState<FriendsListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) async {
    if (query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await ref.read(userServiceProvider).searchUsersByName(query);
      setState(() => _searchResults = results);
    } catch (e) {
      print('Error searching users: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('I miei Amici'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Amici'),
            Tab(text: 'Richieste'),
            Tab(text: 'Cerca'),
          ],
        ),
      ),
      body: currentUserAsync.when(
        data: (currentUser) {
          if (currentUser == null) return const Center(child: Text('Utente non trovato'));

          return TabBarView(
            controller: _tabController,
            children: [
              // 1. Friends List
              _buildFriendsList(currentUser.friends),

              // 2. Requests List
              _buildRequestsList(currentUser.friendRequests),

              // 3. Search
              _buildSearchTab(currentUser),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Errore: $e')),
      ),
    );
  }

  Widget _buildFriendsList(List<String> friendIds) {
    if (friendIds.isEmpty) {
      return const Center(child: Text('Non hai ancora aggiunto amici.'));
    }

    final friendsAsync = ref.watch(usersByIdsProvider(friendIds));

    return friendsAsync.when(
      data: (friends) {
        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: friend.photoUrl != null ? NetworkImage(friend.photoUrl!) : null,
                child: friend.photoUrl == null ? Text(friend.firstName[0]) : null,
              ),
              title: Text(friend.fullName),
              subtitle: Text(friend.zone),
              trailing: IconButton(
                icon: const Icon(Icons.person_remove, color: AppColors.error),
                onPressed: () {
                  _showRemoveFriendDialog(friend);
                },
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen(userId: friend.uid)),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Errore: $e')),
    );
  }

  Widget _buildRequestsList(List<String> requestIds) {
    if (requestIds.isEmpty) {
      return const Center(child: Text('Nessuna richiesta in sospeso.'));
    }

    final requestsAsync = ref.watch(usersByIdsProvider(requestIds));

    return requestsAsync.when(
      data: (requests) {
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final user = requests[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null ? Text(user.firstName[0]) : null,
              ),
              title: Text(user.fullName),
              subtitle: const Text('Vuole essere tuo amico'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.error),
                    onPressed: () {
                      ref.read(friendControllerProvider.notifier).declineFriendRequest(user.uid);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: AppColors.success),
                    onPressed: () {
                      ref.read(friendControllerProvider.notifier).acceptFriendRequest(user.uid);
                    },
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen(userId: user.uid)),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Errore: $e')),
    );
  }

  Widget _buildSearchTab(UserModel currentUser) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cerca persone...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _performSearch(_searchController.text),
              ),
            ),
            onSubmitted: _performSearch,
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    if (user.uid == currentUser.uid) return const SizedBox.shrink();

                    final isFriend = currentUser.friends.contains(user.uid);
                    final isPending = currentUser.friendRequests.contains(user.uid) || 
                                      user.friendRequests.contains(currentUser.uid); // Simplified check

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                        child: user.photoUrl == null ? Text(user.firstName[0]) : null,
                      ),
                      title: Text(user.fullName),
                      subtitle: Text(user.zone),
                      trailing: isFriend
                          ? const Icon(Icons.people, color: AppColors.primary)
                          : isPending
                              ? const Icon(Icons.hourglass_empty, color: AppColors.textSecondary)
                              : IconButton(
                                  icon: const Icon(Icons.person_add),
                                  onPressed: () {
                                    ref.read(friendControllerProvider.notifier).sendFriendRequest(user.uid);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Richiesta inviata')),
                                    );
                                  },
                                ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ProfileScreen(userId: user.uid)),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showRemoveFriendDialog(UserModel friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rimuovi Amico'),
        content: Text('Vuoi rimuovere ${friend.firstName} dagli amici?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              ref.read(friendControllerProvider.notifier).removeFriend(friend.uid);
              Navigator.pop(context);
            },
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
  }
}
