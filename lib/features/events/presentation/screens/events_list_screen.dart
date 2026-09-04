import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/event_service.dart';
import '../../../../shared/models/event_model.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../ads/presentation/widgets/unified_ad_card.dart'; // Added
import '../../../profile/presentation/providers/profile_provider.dart'; // Added
import 'package:google_mobile_ads/google_mobile_ads.dart'; // Added

class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  EventType? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final eventService = ref.watch(eventServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventi & Raduni'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
            settings: const RouteSettings(name: 'create_event'),builder: (context) => const CreateEventScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuovo Evento', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Category Chips (Unified with Nextdoor)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Tutti'),
                  selected: _selectedCategory == null,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = null);
                  },
                  visualDensity: VisualDensity.compact,
                ),
                ...EventType.values.map((type) => Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: ChoiceChip(
                    label: Text(type.displayName),
                    selected: _selectedCategory == type,
                    onSelected: (selected) {
                      setState(() => _selectedCategory = selected ? type : null);
                    },
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(
                      type.icon, 
                      size: 14, 
                      color: _selectedCategory == type ? Colors.white : type.color
                    ),
                    selectedColor: type.color,
                    labelStyle: TextStyle(
                      color: _selectedCategory == type ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                )),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<EventModel>>(
        stream: eventService.getUpcomingEventsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          }

          final currentUserAsync = ref.watch(currentUserProfileProvider);
          final currentUser = currentUserAsync.value;
          final showAds = currentUser != null && !currentUser.isPremium;

          final events = (snapshot.data ?? []).where((e) {
            if (_selectedCategory == null) return true;
            return e.type == _selectedCategory;
          }).toList();

          if (events.isEmpty) {
            return Column(
              children: [
                if (showAds)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: UnifiedAdCard(
                      zone: 'events_empty',
                      adSize: AdSize.largeBanner,
                    ),
                  ),
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Nessun evento in programma',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text('Sii il primo ad organizzarne uno!', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
  


            return Column(
              children: [
                if (showAds && events.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: UnifiedAdCard(
                      zone: 'events_top',
                      adSize: AdSize.largeBanner,
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: showAds 
                        ? events.length + (events.length ~/ 4)
                        : events.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      if (showAds) {
                        // Ad Injection Logic (Every 4 items)
                        if (index > 0 && (index + 1) % 5 == 0) {
                          return UnifiedAdCard(
                            zone: 'events_list',
                            adSize: AdSize.largeBanner,
                          );
                        }
                        final itemIndex = index - (index ~/ 5);
                        if (itemIndex >= events.length) return const SizedBox.shrink();
                        return _EventCard(event: events[itemIndex]);
                      } else {
                        final event = events[index];
                        return _EventCard(event: event);
                      }
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  ),
);
}
}

class _EventCard extends StatelessWidget {
  final EventModel event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'it_IT');

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // For image clipping
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
            settings: const RouteSettings(name: 'event_detail'),
               builder: (context) => EventDetailScreen(event: event),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Image/Color
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                image: event.imageUrl != null 
                    ? DecorationImage(
                        image: NetworkImage(event.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: event.imageUrl == null 
                  ? Center(
                      child: Icon(
                        _getIconForType(event.type),
                        size: 48,
                        color: AppColors.primary.withOpacity(0.5),
                      ),
                    )
                  : null,
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        label: Text(
                          event.type.displayName,
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                        backgroundColor: event.type.color,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        avatar: Icon(event.type.icon, size: 12, color: Colors.white),
                      ),
                      Text(
                        dateFormat.format(event.date),
                         style: const TextStyle(
                           color: AppColors.primary,
                           fontWeight: FontWeight.bold,
                         ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.locationName,
                          style: TextStyle(color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                       const Icon(Icons.people, size: 16, color: Colors.grey),
                       const SizedBox(width: 4),
                       Text('${event.attendees.length} Partecipanti'),
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

  IconData _getIconForType(EventType type) => type.icon;
}
