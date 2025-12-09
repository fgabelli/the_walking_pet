import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/walk_model.dart';
import '../providers/walk_provider.dart';
import 'create_walk_screen.dart';
import 'walk_detail_screen.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class WalksListScreen extends ConsumerStatefulWidget {
  const WalksListScreen({super.key});

  @override
  ConsumerState<WalksListScreen> createState() => _WalksListScreenState();
}

class _WalksListScreenState extends ConsumerState<WalksListScreen> {
  bool _showFriendsOnly = false;

  @override
  Widget build(BuildContext context) {
    final walksAsync = ref.watch(upcomingWalksProvider);
    final currentUserAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Passeggiate'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
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
        ),
      ),
      body: walksAsync.when(
        data: (walks) {
          return currentUserAsync.when(
            data: (currentUser) {
              var displayedWalks = walks;
              if (_showFriendsOnly && currentUser != null) {
                displayedWalks = walks.where((walk) {
                  return currentUser.friends.contains(walk.creatorId) || walk.creatorId == currentUser.uid;
                }).toList();
              }

              if (displayedWalks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.directions_walk, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(_showFriendsOnly 
                          ? 'Nessuna passeggiata dai tuoi amici' 
                          : 'Nessuna passeggiata in programma'),
                      if (!_showFriendsOnly) ...[
                        const SizedBox(height: 8),
                        const Text('Crea tu la prima!'),
                      ],
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: displayedWalks.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final walk = displayedWalks[index];
                  return _WalkCard(walk: walk);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Errore utente: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Errore: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateWalkScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        heroTag: 'walks_fab',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _WalkCard extends StatelessWidget {
  final WalkModel walk;

  const _WalkCard({required this.walk});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE d MMM, HH:mm', 'it');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WalkDetailScreen(walk: walk),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      walk.status.displayName,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${walk.participants.length} partecipanti',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                walk.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(walk.date),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.timer, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${walk.duration} min',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      walk.meetingPoint.address,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
