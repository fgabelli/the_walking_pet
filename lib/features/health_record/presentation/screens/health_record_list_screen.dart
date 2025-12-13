import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/health_service.dart';
import '../../../../shared/models/health_record_model.dart';
import '../../../../core/theme/app_colors.dart';
import 'add_health_record_screen.dart';

class HealthRecordListScreen extends ConsumerWidget {
  final String petId;
  final String petName;
  final bool isOwner;

  const HealthRecordListScreen({
    super.key, 
    required this.petId, 
    required this.petName,
    this.isOwner = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthService = ref.watch(healthServiceProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Libretto Sanitario di $petName'),
      ),
      floatingActionButton: isOwner ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddHealthRecordScreen(petId: petId),
            ),
          );
        },
        label: const Text('Aggiungi'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ) : null,
      body: StreamBuilder<List<HealthRecordModel>>(
        stream: healthService.getHealthRecordsStream(petId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Errore: ${snapshot.error}'));
          }

          final records = snapshot.data ?? [];

          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey.shade400),
                   const SizedBox(height: 16),
                   const Text(
                    'Nessun dato sanitario',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                   ),
                   if (isOwner)
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddHealthRecordScreen(petId: petId),
                          ),
                        );
                      },
                      child: const Text('Aggiungi il primo vaccino o visita'),
                    ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final record = records[index];
              return _HealthRecordCard(record: record, isOwner: isOwner);
            },
          );
        },
      ),
    );
  }
}

class _HealthRecordCard extends ConsumerWidget {
  final HealthRecordModel record;
  final bool isOwner; // For editing/deleting

  const _HealthRecordCard({required this.record, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    // Determine icon based on type
    IconData icon;
    Color color;
    switch (record.type) {
      case HealthRecordType.vaccine:
        icon = Icons.vaccines;
        color = Colors.teal;
        break;
      case HealthRecordType.treatment:
        icon = Icons.medication;
        color = Colors.orange;
        break;
      case HealthRecordType.surgery:
        icon = Icons.local_hospital;
        color = Colors.red;
        break;
      case HealthRecordType.visit:
        icon = Icons.medical_services;
        color = Colors.blue;
        break;
      case HealthRecordType.other:
        icon = Icons.info;
        color = Colors.grey;
        break;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        record.type.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _confirmDelete(context, ref, record.id);
                      }
                      // Implement edit if needed
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                         value: 'delete',
                         child: Row(
                           children: [
                             Icon(Icons.delete, color: Colors.red, size: 20),
                             SizedBox(width: 8),
                             Text('Elimina', style: TextStyle(color: Colors.red)),
                           ],
                         ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                 const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                 const SizedBox(width: 4),
                 Text('Data: ${dateFormat.format(record.date)}'),
                 if (record.nextDueDate != null) ...[
                   const SizedBox(width: 16),
                   Icon(Icons.event_repeat, size: 16, color: record.nextDueDate!.isBefore(DateTime.now()) ? Colors.red : Colors.green),
                   const SizedBox(width: 4),
                   Text(
                     'Scadenza: ${dateFormat.format(record.nextDueDate!)}',
                     style: TextStyle(
                       color: record.nextDueDate!.isBefore(DateTime.now()) ? Colors.red : Colors.green,
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                 ],
              ],
            ),
            if (record.veterinarianName != null && record.veterinarianName!.isNotEmpty) ...[
               const SizedBox(height: 8),
               Row(
                 children: [
                   const Icon(Icons.person, size: 16, color: Colors.grey),
                   const SizedBox(width: 4),
                   Text('Vet: ${record.veterinarianName}'),
                 ],
               ),
            ],
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                record.notes!,
                style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String recordId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina'),
        content: const Text('Sicuro di voler eliminare questo record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              ref.read(healthServiceProvider).deleteHealthRecord(recordId);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}
