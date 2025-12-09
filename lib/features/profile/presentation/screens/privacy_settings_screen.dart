import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/profile_provider.dart';
import '../../../../core/services/user_service.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  LocationPrivacy? _selectedPrivacy;
  List<String> _whitelist = [];
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Posizione'),
        actions: [
          if (_isDirty)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveSettings,
            ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Utente non trovato'));

          // Initialize state from user data if not dirty and not yet initialized
          if (!_isDirty && _selectedPrivacy == null) {
             _selectedPrivacy = user.locationPrivacy;
             _whitelist = List.from(user.locationWhitelist);
          }
          
          final currentPrivacy = _selectedPrivacy ?? user.locationPrivacy;
          final currentWhitelist = _isDirty ? _whitelist : user.locationWhitelist;

          return ListView(
            children: [
              _buildRadioTile(
                title: 'Tutti',
                subtitle: 'La tua posizione è visibile a tutti gli utenti vicini.',
                value: LocationPrivacy.everyone,
                groupValue: currentPrivacy,
              ),
              _buildRadioTile(
                title: 'Solo Amici',
                subtitle: 'La tua posizione è visibile solo ai tuoi amici.',
                value: LocationPrivacy.friends,
                groupValue: currentPrivacy,
              ),
              _buildRadioTile(
                title: 'Personalizzato',
                subtitle: 'Scegli specifici amici che possono vederti.',
                value: LocationPrivacy.custom,
                groupValue: currentPrivacy,
              ),

              if (currentPrivacy == LocationPrivacy.custom) ...[
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Chi può vederti:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // List of friends to toggle
                // We need to fetch friends list.
                // This requires fetching user profiles for all friends.
                // For now, let's just show IDs or implement a friend list fetcher.
                _FriendsWhitelistSelector(
                  friendIds: user.friends,
                  whitelist: currentWhitelist,
                  onChanged: (newWhitelist) {
                    setState(() {
                      _whitelist = newWhitelist;
                      _selectedPrivacy = LocationPrivacy.custom;
                      _isDirty = true;
                    });
                  },
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Errore: $e')),
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required LocationPrivacy value,
    required LocationPrivacy groupValue,
  }) {
    return RadioListTile<LocationPrivacy>(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      groupValue: groupValue,
      onChanged: (newValue) {
        if (newValue != null) {
          setState(() {
            _selectedPrivacy = newValue;
            _isDirty = true;
            // Initialize whitelist if switching to custom for first time
            if (newValue == LocationPrivacy.custom && _whitelist.isEmpty) {
               // Keep existing or empty?
            }
          });
        }
      },
    );
  }

  void _saveSettings() {
    if (_selectedPrivacy == null) return;
    
    ref.read(friendControllerProvider.notifier).updateLocationPrivacy(
      privacy: _selectedPrivacy!,
      whitelist: _selectedPrivacy == LocationPrivacy.custom ? _whitelist : null,
    );
    setState(() {
      _isDirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impostazioni salvate')),
    );
  }
}

class _FriendsWhitelistSelector extends ConsumerWidget {
  final List<String> friendIds;
  final List<String> whitelist;
  final Function(List<String>) onChanged;

  const _FriendsWhitelistSelector({
    required this.friendIds,
    required this.whitelist,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (friendIds.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Non hai ancora amici.'),
      );
    }

    // Fetch friend profiles
    // This is a bit heavy, ideally should be paginated or cached.
    // For MVP, we fetch all.
    final friendsAsync = ref.watch(usersByIdsProvider(friendIds));

    return friendsAsync.when(
      data: (friends) {
        return Column(
          children: friends.map((friend) {
            final isSelected = whitelist.contains(friend.uid);
            return CheckboxListTile(
              title: Text(friend.fullName),
              value: isSelected,
              onChanged: (value) {
                final newWhitelist = List<String>.from(whitelist);
                if (value == true) {
                  newWhitelist.add(friend.uid);
                } else {
                  newWhitelist.remove(friend.uid);
                }
                onChanged(newWhitelist);
              },
              secondary: CircleAvatar(
                backgroundImage: friend.photoUrl != null ? NetworkImage(friend.photoUrl!) : null,
                child: friend.photoUrl == null ? Text(friend.firstName[0]) : null,
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const Text('Errore caricamento amici'),
    );
  }
}

// Provider to fetch multiple users by ID
final usersByIdsProvider = FutureProvider.family<List<UserModel>, List<String>>((ref, ids) async {
  if (ids.isEmpty) return [];
  final userService = ref.read(userServiceProvider);
  final List<UserModel> users = [];
  for (final id in ids) {
    final user = await userService.getUserById(id);
    if (user != null) users.add(user);
  }
  return users;
});

// Provider for current user stream
final userStreamProvider = StreamProvider<UserModel?>((ref) {
  final authUser = ref.watch(authServiceProvider).currentUser;
  if (authUser == null) return Stream.value(null);
  return ref.watch(userServiceProvider).getUserStream(authUser.uid);
});
