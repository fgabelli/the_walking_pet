import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  LocationPrivacy? _selectedPrivacy;
  bool? _isGhost; // Track Ghost Mode locally
  List<String> _whitelist = [];
  bool _isDirty = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);

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
             _isGhost = user.isGhost;
             _whitelist = List.from(user.locationWhitelist);
          }
          
          final currentPrivacy = _selectedPrivacy ?? user.locationPrivacy;
          final currentIsGhost = _isGhost ?? user.isGhost;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Chi può vedere la tua posizione sulla mappa?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                
                // Option 1: GHOST MODE (Nessuno)
                RadioListTile<bool>(
                  title: const Text('Nessuno (Ghost Mode)'),
                  subtitle: const Text('Sei invisibile a tutti. Puoi comunque vedere segnalazioni e locali.'),
                  value: true,
                  groupValue: currentIsGhost,
                  onChanged: (val) {
                    setState(() {
                      _isGhost = true;
                      _isDirty = true;
                    });
                  },
                  secondary: const Icon(Icons.visibility_off),
                ),
                
                const Divider(),
                
                // Option 2: EVERYONE
                RadioListTile<String>( // Type hack to distinguish, or just custom logic
                  title: const Text('Tutti'),
                  subtitle: const Text('Tutti gli utenti possono vedere la tua posizione.'),
                  value: 'everyone',
                  groupValue: !currentIsGhost && currentPrivacy == LocationPrivacy.everyone ? 'everyone' : null,
                  onChanged: (_) {
                     setState(() {
                       _isGhost = false;
                       _selectedPrivacy = LocationPrivacy.everyone;
                       _isDirty = true;
                     });
                  },
                   secondary: const Icon(Icons.public),
                ),

                // Option 3: FRIENDS
                RadioListTile<String>(
                  title: const Text('Amici'),
                  subtitle: const Text('Solo i tuoi amici possono vedere dove sei.'),
                  value: 'friends',
                  groupValue: !currentIsGhost && currentPrivacy == LocationPrivacy.friends ? 'friends' : null,
                  onChanged: (_) {
                     setState(() {
                       _isGhost = false;
                       _selectedPrivacy = LocationPrivacy.friends;
                       _isDirty = true;
                     });
                  },
                   secondary: const Icon(Icons.people),
                ),

                // Option 4: CLOSE FRIENDS
                RadioListTile<String>(
                  title: const Text('Amici Stretti'),
                  subtitle: const Text('Solo i tuoi amici stretti possono vedere la tua posizione.'),
                  value: 'closeFriends',
                  groupValue: !currentIsGhost && currentPrivacy == LocationPrivacy.closeFriends ? 'closeFriends' : null,
                  onChanged: (_) {
                     setState(() {
                       _isGhost = false;
                       _selectedPrivacy = LocationPrivacy.closeFriends;
                       _isDirty = true;
                     });
                  },
                   secondary: const Icon(Icons.favorite),
                ),

                // Option 5: CUSTOM
                RadioListTile<String>(
                  title: const Text('Personalizzata'),
                  subtitle: const Text('Scegli specificamente chi può vederti.'),
                  value: 'custom',
                  groupValue: !currentIsGhost && currentPrivacy == LocationPrivacy.custom ? 'custom' : null,
                  onChanged: (_) {
                     setState(() {
                       _isGhost = false;
                       _selectedPrivacy = LocationPrivacy.custom;
                       _isDirty = true;
                     });
                  },
                   secondary: const Icon(Icons.settings),
                ),
                
                if (!currentIsGhost && currentPrivacy == LocationPrivacy.custom) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Seleziona Amici',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  _FriendsWhitelistSelector(
                    friendIds: user.friends,
                    whitelist: _whitelist,
                    onChanged: (newList) {
                      setState(() {
                        _whitelist = newList;
                        _isDirty = true;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Errore: $e')),
      ),
    );
  }

  void _saveSettings() async {
    // If we're in Ghost Mode, that's the priority
    // Ideally we should update both, but updateProfile handles isGhost
    // We might need to make two calls or update profile provider to handle both
    
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    try {
      // 1. Update isGhost
      if (_isGhost != null) {
          await ref.read(profileControllerProvider.notifier).updateProfile(isGhost: _isGhost);
      }
      
      // 2. Update Location Privacy (only relevant if not ghost, but good to save anyway)
      if (_selectedPrivacy != null) {
          await ref.read(userServiceProvider).updateLocationPrivacy(
            user.uid,
            privacy: _selectedPrivacy!,
            whitelist: _selectedPrivacy == LocationPrivacy.custom ? _whitelist : [],
          );
      }
      
      if (mounted) {
        setState(() {
          _isDirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impostazioni salvate')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il salvataggio: $e')),
        );
      }
    }
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
