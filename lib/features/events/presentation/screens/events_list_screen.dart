import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/event_service.dart';
import '../../../../shared/models/event_model.dart';
import 'create_event_screen.dart';
import 'event_detail_screen.dart';
import '../../../../core/theme/app_colors.dart';

class EventsListScreen extends ConsumerWidget {
  const EventsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventService = ref.watch(eventServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventi & Raduni'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateEventScreen()),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<EventModel>>(
        stream: eventService.getUpcomingEventsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          }

          final events = snapshot.data ?? [];

          if (events.isEmpty) {
            return const Center(
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
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final event = events[index];
              return _EventCard(event: event);
            },
          );
        },
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
                        backgroundColor: AppColors.primary,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
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
    }
  }
}
