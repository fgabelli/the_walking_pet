import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/health_service.dart';
import '../../../../shared/models/health_record_model.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../../core/theme/app_colors.dart';
import 'add_health_record_screen.dart';

class HealthRecordListScreen extends ConsumerWidget {
  final DogModel dog;
  final bool isOwner;

  const HealthRecordListScreen({
    super.key, 
    required this.dog, 
    this.isOwner = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthService = ref.watch(healthServiceProvider);
    
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Libretto Sanitario'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Vaccini'),
              Tab(text: 'Trattamenti'),
              Tab(text: 'Archivio/Note'),
            ],
          ),
        ),
        floatingActionButton: isOwner ? Builder(
          builder: (context) {
            return FloatingActionButton.extended(
              onPressed: () {
                HealthRecordType initialType = HealthRecordType.vaccine;
                final tabController = DefaultTabController.maybeOf(context);
                if (tabController != null) {
                  if (tabController.index == 1) initialType = HealthRecordType.treatment;
                  if (tabController.index == 2) initialType = HealthRecordType.other;
                }
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddHealthRecordScreen(
                      petId: dog.id,
                      pet: dog,
                      initialType: initialType,
                    ),
                  ),
                );
              },
              label: const Text('Aggiungi Documento'),
              icon: const Icon(Icons.add),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            );
          }
        ) : null,
        body: Column(
          children: [
            // Dati Base Card
            _buildBaseDataCard(context),
            
            // Tabs Content
            Expanded(
              child: StreamBuilder<List<HealthRecordModel>>(
                stream: healthService.getHealthRecordsStream(dog.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Errore: ${snapshot.error}'));
                  }

                  final records = snapshot.data ?? [];
                  
                  final vaccines = records.where((r) => r.type == HealthRecordType.vaccine).toList();
                  final treatments = records.where((r) => r.type == HealthRecordType.treatment).toList();
                  final others = records.where((r) => r.type != HealthRecordType.vaccine && r.type != HealthRecordType.treatment).toList();

                  return TabBarView(
                    children: [
                      _buildVaccineList(context, vaccines, ref),
                      _buildList(context, treatments, ref, "Nessun trattamento registrato"),
                      _buildList(context, others, ref, "Nessun documento o visita"),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBaseDataCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  backgroundImage: dog.photoUrl != null ? NetworkImage(dog.photoUrl!) : null,
                  child: dog.photoUrl == null ? const Icon(Icons.pets, size: 30, color: AppColors.primary) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dog.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${dog.breed} • ${dog.age} anni', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(Icons.monitor_weight, 'Peso', dog.weight != null ? '${dog.weight} kg' : 'N.D.'),
                _buildInfoItem(Icons.qr_code, 'Microchip', dog.microchipNumber ?? 'Non inserito'),
                _buildInfoItem(Icons.bloodtype, 'Sangue', dog.bloodType ?? 'N.D.'),
              ],
            ),
            if (dog.allergies.isNotEmpty || dog.pathologies.isNotEmpty) ...[
              const Divider(height: 24),
              if (dog.allergies.isNotEmpty)
                _buildTagRow('Allergie:', dog.allergies, Colors.orange),
              if (dog.pathologies.isNotEmpty)
                _buildTagRow('Patologie:', dog.pathologies, Colors.red),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildTagRow(String label, List<String> tags, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: tags.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.5)),
              ),
              child: Text(t, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildVaccineList(BuildContext context, List<HealthRecordModel> vaccines, WidgetRef ref) {
    if (vaccines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.vaccines, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Nessun vaccino registrato', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final in30Days = now.add(const Duration(days: 30));

    final overdue = vaccines.where((r) =>
      r.nextDueDate != null && r.nextDueDate!.isBefore(now),
    ).toList();

    final upcoming = vaccines.where((r) =>
      r.nextDueDate != null &&
      !r.nextDueDate!.isBefore(now) &&
      r.nextDueDate!.isBefore(in30Days),
    ).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (overdue.isNotEmpty)
          _buildExpiryBanner(
            icon: Icons.warning_amber_rounded,
            color: Colors.red,
            title: '${overdue.length} ${overdue.length == 1 ? 'vaccino scaduto' : 'vaccini scaduti'}',
            names: overdue.map((r) => r.specificName ?? r.title).toList(),
          ),
        if (upcoming.isNotEmpty)
          _buildExpiryBanner(
            icon: Icons.schedule,
            color: Colors.orange,
            title: '${upcoming.length} ${upcoming.length == 1 ? 'vaccino in scadenza' : 'vaccini in scadenza'}',
            names: upcoming.map((r) => r.specificName ?? r.title).toList(),
          ),
        ...vaccines.map((record) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _HealthRecordCard(record: record, isOwner: isOwner),
        )),
      ],
    );
  }

  Widget _buildExpiryBanner({
    required IconData icon,
    required Color color,
    required String title,
    required List<String> names,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  names.join(', '),
                  style: TextStyle(fontSize: 13, color: color.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<HealthRecordModel> records, WidgetRef ref, String emptyMessage) {
    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_information, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(emptyMessage, style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _HealthRecordCard(record: records[index], isOwner: isOwner);
      },
    );
  }
}

class _HealthRecordCard extends ConsumerWidget {
  final HealthRecordModel record;
  final bool isOwner;

  const _HealthRecordCard({required this.record, required this.isOwner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    
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
        icon = Icons.folder;
        color = Colors.grey;
        break;
    }

    // Check if overdue
    bool isOverdue = record.nextDueDate != null && record.nextDueDate!.isBefore(DateTime.now());

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isOverdue ? Colors.red.shade200 : Colors.transparent)),
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
                        record.specificName ?? record.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (record.specificName != null) 
                        Text(record.title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                if (!record.isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
                    child: const Text('DA FARE', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                if (isOwner)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') _confirmDelete(context, ref, record.id);
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
                 Text('Fatto il: ${dateFormat.format(record.date)}', style: const TextStyle(fontSize: 13)),
                 if (record.nextDueDate != null) ...[
                   const SizedBox(width: 16),
                   Icon(Icons.event_repeat, size: 16, color: isOverdue ? Colors.red : Colors.green),
                   const SizedBox(width: 4),
                   Text(
                     'Scade: ${dateFormat.format(record.nextDueDate!)}',
                     style: TextStyle(
                       color: isOverdue ? Colors.red : Colors.green,
                       fontWeight: FontWeight.bold,
                       fontSize: 13,
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
                   Text('Vet: ${record.veterinarianName}', style: const TextStyle(fontSize: 13)),
                 ],
               ),
            ],
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(record.notes!, style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade800, fontSize: 13)),
              ),
            ],
            if (record.attachmentUrl != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {}, // TODO: Visualizza allegato
                icon: const Icon(Icons.image, size: 16),
                label: const Text('Visualizza Foto Documento'),
              )
            ]
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
        content: const Text('Sicuro di voler eliminare questo documento dal libretto?'),
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
