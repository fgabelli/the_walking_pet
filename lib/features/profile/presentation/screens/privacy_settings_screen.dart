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
             _whitelist = List.from(user.locationWhitelist);
          }
          
          final currentPrivacy = _selectedPrivacy ?? user.locationPrivacy;

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
                _buildRadioTile(
                  title: 'Tutti',
                  subtitle: 'Tutti gli utenti possono vedere la tua posizione.',
                  value: LocationPrivacy.everyone,
                  groupValue: currentPrivacy,
                ),
                _buildRadioTile(
                  title: 'Amici',
                  subtitle: 'Solo i tuoi amici possono vedere dove sei.',
                  value: LocationPrivacy.friends,
                  groupValue: currentPrivacy,
                ),
                _buildRadioTile(
                  title: 'Amici Stretti',
                  subtitle: 'Solo i tuoi amici stretti possono vedere la tua posizione.',
                  value: LocationPrivacy.closeFriends,
                  groupValue: currentPrivacy,
                ),
                _buildRadioTile(
                  title: 'Personalizzata',
                  subtitle: 'Scegli specificamente chi può vederti.',
                  value: LocationPrivacy.custom,
                  groupValue: currentPrivacy,
                ),
                
                if (currentPrivacy == LocationPrivacy.custom) ...[
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
          });
        }
      },
    );
  }

  void _saveSettings() async {
    if (_selectedPrivacy == null) return;
    
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    try {
      await ref.read(userServiceProvider).updateLocationPrivacy(
        user.uid,
        privacy: _selectedPrivacy!,
        whitelist: _selectedPrivacy == LocationPrivacy.custom ? _whitelist : [],
      );
      
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
