
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/event_service.dart';
import '../../../../shared/models/event_model.dart';
import '../../../walks/presentation/providers/walk_provider.dart';
import '../../../../shared/models/walk_model.dart';
import '../../models/activity_item.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../events/presentation/screens/event_detail_screen.dart';
import '../../../events/presentation/screens/create_event_screen.dart';
import '../../../walks/presentation/screens/walk_detail_screen.dart';
import '../../../walks/presentation/screens/create_walk_screen.dart';
import '../../../ads/presentation/widgets/unified_ad_card.dart'; // Added
import '../../../profile/presentation/providers/profile_provider.dart'; // Added

class ActivitiesListScreen extends ConsumerStatefulWidget {
  const ActivitiesListScreen({super.key});

  @override
  ConsumerState<ActivitiesListScreen> createState() => _ActivitiesListScreenState();
}

class _ActivitiesListScreenState extends ConsumerState<ActivitiesListScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Walks, 2: Events

  @override
  Widget build(BuildContext context) {
    final walksAsync = ref.watch(upcomingWalksProvider);
    final eventService = ref.watch(eventServiceProvider);
    final currentUserAsync = ref.watch(currentUserProfileProvider);
    final currentUser = currentUserAsync.value;
    final showAds = currentUser != null && !currentUser.isPremium;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attività & Incontri'),
        // ... (existing AppBar setup checked ok in context)
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tutte',
                  isSelected: _selectedFilterIndex == 0,
                  onTap: () => setState(() => _selectedFilterIndex = 0),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Passeggiate',
                  isSelected: _selectedFilterIndex == 1,
                  onTap: () => setState(() => _selectedFilterIndex = 1),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Eventi',
                  isSelected: _selectedFilterIndex == 2,
                  onTap: () => setState(() => _selectedFilterIndex = 2),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOptions(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuova Attività', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<List<EventModel>>(
        stream: eventService.getUpcomingEventsStream(),
        builder: (context, eventSnapshot) {
          return walksAsync.when(
            data: (walks) {
              // Combine Lists
              List<ActivityItem> allItems = [];
              
              // Add Walks
              if (_selectedFilterIndex == 0 || _selectedFilterIndex == 1) {
                allItems.addAll(walks.map((w) => ActivityItem.walk(w)));
              }
              
              // Add Events
              if ((_selectedFilterIndex == 0 || _selectedFilterIndex == 2) && 
                  eventSnapshot.hasData) {
                final events = eventSnapshot.data!;
                allItems.addAll(events.map((e) => ActivityItem.event(e)));
              }
              
              // Sort
              allItems = ActivityItem.sort(allItems);
              
              if (allItems.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: showAds 
                    ? allItems.length + (allItems.length ~/ 8) 
                    : allItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  if (showAds) {
                    // Ad Injection Logic: Every 8 items (indices 8, 17...)
                    // Based on my previous logic: index > 0 && (index + 1) % 9 == 0
                    if (index > 0 && (index + 1) % 9 == 0) {
                       return const UnifiedAdCard(zone: 'activities_list');
                    }

                    final itemIndex = index - (index ~/ 9);
                    if (itemIndex >= allItems.length) return const SizedBox.shrink();

                    final item = allItems[itemIndex];
                    if (item.type == ActivityType.walk) {
                      return _WalkCard(walk: item.walk!);
                    } else {
                      return _EventCard(event: item.event!);
                    }
                  } else {
                    // No Ads logic
                    final item = allItems[index];
                    if (item.type == ActivityType.walk) {
                      return _WalkCard(walk: item.walk!);
                    } else {
                      return _EventCard(event: item.event!);
                    }
                  }
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Errore: $err')),
          );
        },
      ),
    );
  }

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Text(
                'Cosa vuoi organizzare?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.directions_walk, color: Colors.white),
                ),
                title: const Text('Passeggiata'),
                subtitle: const Text('Organizza una camminata con altri'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CreateWalkScreen()),
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: Icon(Icons.event, color: Colors.white),
                ),
                title: const Text('Evento / Raduno'),
                subtitle: const Text('Raduni, addestramento, socializzazione'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CreateEventScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           Icon(Icons.calendar_today, size: 64, color: Colors.grey.shade400),
           const SizedBox(height: 16),
           Text(
            'Nessuna attività in programma',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
           ),
           const SizedBox(height: 8),
           const Text('Sii il primo ad organizzarne una!', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _WalkCard extends StatelessWidget {
  final WalkModel walk;
  const _WalkCard({required this.walk});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, HH:mm', 'it_IT');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => WalkDetailScreen(walk: walk)));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   Container(
                     padding: const EdgeInsets.all(8),
                     decoration: BoxDecoration(
                       color: Colors.green.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(8),
                     ),
                     child: const Icon(Icons.directions_walk, color: Colors.green),
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           walk.title,
                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                         ),
                         Text(
                           dateFormat.format(walk.date),
                           style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                         ),
                       ],
                     ),
                   ),
                   if (walk.participants.isNotEmpty)
                     Chip(
                       label: Text('${walk.participants.length}'),
                       avatar: const Icon(Icons.people, size: 14),
                       visualDensity: VisualDensity.compact,
                       backgroundColor: Colors.green.shade50,
                     ),
                ],
              ),
              const SizedBox(height: 12),
               Row(
                 children: [
                   const Icon(Icons.location_on, size: 16, color: Colors.grey),
                   const SizedBox(width: 4),
                   Expanded(
                     child: Text(
                       walk.meetingPoint.address,
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                       style: TextStyle(color: Colors.grey.shade700),
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

class _EventCard extends StatelessWidget {
  final EventModel event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, HH:mm', 'it_IT');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)));
        },
        child: Column(
          children: [
            // Colored stripe on top to distinguish
             Container(
               height: 6,
               width: double.infinity,
               color: Colors.deepPurple,
             ),
             Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                       Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(
                           color: Colors.deepPurple.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(8),
                         ),
                         child: Icon(_getIconForType(event.type), color: Colors.deepPurple),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               event.title,
                               style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                             ),
                             Text(
                               '${event.type.displayName} • ${dateFormat.format(event.date)}',
                               style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                             ),
                           ],
                         ),
                       ),
                    ],
                  ),
                  const SizedBox(height: 12),
                   Row(
                     children: [
                       const Icon(Icons.location_on, size: 16, color: Colors.grey),
                       const SizedBox(width: 4),
                       Expanded(
                         child: Text(
                           event.locationName,
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis,
                           style: TextStyle(color: Colors.grey.shade700),
                         ),
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
  
  IconData _getIconForType(EventType type) {
    switch (type) {
      case EventType.walk:
        return Icons.directions_walk;
      case EventType.training:
        return Icons.sports_baseball;
      case EventType.social:
        return Icons.coffee;
      case EventType.other:
        return Icons.event;
      case EventType.litter:
        return Icons.cleaning_services;
    }
  }
}
