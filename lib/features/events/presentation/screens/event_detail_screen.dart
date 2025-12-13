import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/event_service.dart';
import '../../../../shared/models/event_model.dart';
import '../../../../shared/models/event_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors.dart';

class EventDetailScreen extends ConsumerWidget {
  final EventModel event;

  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('EEEE d MMMM yyyy, HH:mm', 'it_IT');
    final currentUser = ref.watch(authServiceProvider).currentUser;
    final isParticipating = currentUser != null && event.attendees.contains(currentUser.uid);
    final isCreator = currentUser != null && event.creatorId == currentUser.uid;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(event.title, 
                  style: const TextStyle(
                    color: Colors.white, 
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)]
                  )),
              background: event.imageUrl != null
                  ? Image.network(event.imageUrl!, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.primary.withOpacity(0.8),
                      child: const Center(
                        child: Icon(Icons.event, size: 64, color: Colors.white),
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta Info Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          event.type.displayName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.people, color: Colors.grey.shade600, size: 20),
                      const SizedBox(width: 4),
                      Text('${event.attendees.length} Partecipanti'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Date & Location Section
                  _InfoRow(
                    icon: Icons.calendar_today, 
                    title: 'Quando', 
                    content: dateFormat.format(event.date)
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.location_on, 
                    title: 'Dove', 
                    content: event.locationName
                  ),
                  
                  const Divider(height: 32),
                  
                  // Description
                  const Text(
                    'Descrizione',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: isCreator 
                        ? OutlinedButton.icon(
                            onPressed: () => _confirmDelete(context, ref),
                            icon: const Icon(Icons.delete),
                            label: const Text('Annulla Evento'),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          )
                        : ElevatedButton(
                            onPressed: () async {
                              if (currentUser == null) return;
                              
                              if (isParticipating) {
                                await ref.read(eventServiceProvider).leaveEvent(event.id, currentUser.uid);
                              } else {
                                await ref.read(eventServiceProvider).joinEvent(event.id, currentUser.uid);
                              }
                              // Force pop since we modified stream data
                              if (context.mounted) Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isParticipating ? Colors.grey : AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(isParticipating ? 'Annulla Partecipazione' : 'Partecipa'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annulla Evento'),
        content: const Text('Sei sicuro di voler annullare questo evento?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
          TextButton(
            onPressed: () async {
              await ref.read(eventServiceProvider).deleteEvent(event.id);
              if (context.mounted) {
                Navigator.pop(context); // Dialog
                Navigator.pop(context); // Screen
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Si, Annulla'),
          ),
        ],
      ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(height: 2),
              Text(content, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
