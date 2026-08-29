import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ActivitiesEventsWidget extends StatefulWidget {
  const ActivitiesEventsWidget({super.key});

  @override
  State<ActivitiesEventsWidget> createState() => _ActivitiesEventsWidgetState();
}

class _ActivitiesEventsWidgetState extends State<ActivitiesEventsWidget> {
  String _tab = 'events'; // events, walks

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab Selector
        Row(
          children: [
            _TabButton(label: 'Eventi & Raduni', value: 'events', selected: _tab, onTap: (v) => setState(() => _tab = v)),
            const SizedBox(width: 12),
            _TabButton(label: 'Passeggiate di Gruppo', value: 'walks', selected: _tab, onTap: (v) => setState(() => _tab = v)),
          ],
        ),
        const SizedBox(height: 20),
        
        Expanded(
          child: _tab == 'events' ? _buildEventsTab() : _buildWalksTab(),
        ),
      ],
    );
  }

  Widget _buildEventsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .orderBy('date', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Errore: ${snapshot.error}', style: TextStyle(color: Colors.red[400])));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _emptyState(Icons.event_busy, 'Nessun evento trovato');
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
              columns: const [
                DataColumn(label: Text('Titolo', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Creatore', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Data', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Partecipanti', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Stato', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Azioni', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                // EventModel uses 'date' field
                final eventDate = (data['date'] as Timestamp?)?.toDate();
                final dateStr = eventDate != null
                    ? '${eventDate.day}/${eventDate.month}/${eventDate.year}'
                    : '—';
                // EventModel uses 'attendees' not 'participants'
                final attendees = (data['attendees'] as List?)?.length ?? 0;
                final isActive = eventDate != null && eventDate.isAfter(DateTime.now());
                // EventModel uses 'creatorId'
                final creatorId = data['creatorId'] ?? '—';
                final eventType = data['type'] ?? '';
                // Parse type label (format: "EventType.social" -> "social")
                final typeLabel = eventType.toString().contains('.') 
                    ? eventType.toString().split('.').last 
                    : eventType.toString();

                return DataRow(cells: [
                  DataCell(
                    SizedBox(
                      width: 180,
                      child: Text(data['title'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  DataCell(
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(creatorId).get(),
                      builder: (context, snap) {
                        if (snap.hasData && snap.data!.exists) {
                          final userData = snap.data!.data() as Map<String, dynamic>;
                          return Text('${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(), style: const TextStyle(fontSize: 13));
                        }
                        return Text(_truncate(creatorId, 12), style: TextStyle(fontSize: 11, color: Colors.grey[400], fontFamily: 'monospace'));
                      },
                    ),
                  ),
                  DataCell(Text(dateStr)),
                  DataCell(Text('$attendees')),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(4)),
                    child: Text(typeLabel, style: TextStyle(fontSize: 11, color: Colors.purple[700], fontWeight: FontWeight.w600)),
                  )),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isActive ? 'Attivo' : 'Passato',
                      style: TextStyle(fontSize: 12, color: isActive ? Colors.green[700] : Colors.grey[600], fontWeight: FontWeight.bold),
                    ),
                  )),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        tooltip: 'Elimina',
                        onPressed: () => _confirmDelete(context, 'events', doc.id, data['title'] ?? 'questo evento'),
                      ),
                    ],
                  )),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWalksTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('group_walks')
          .orderBy('date', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Errore: ${snapshot.error}', style: TextStyle(color: Colors.red[400])));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _emptyState(Icons.directions_walk, 'Nessuna passeggiata di gruppo trovata');
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
              columns: const [
                DataColumn(label: Text('Titolo', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Creatore', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Data', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Partecipanti', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Stato', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Azioni', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                // WalkModel uses 'date' field
                final walkDate = (data['date'] as Timestamp?)?.toDate();
                final dateStr = walkDate != null
                    ? '${walkDate.day}/${walkDate.month}/${walkDate.year}'
                    : '—';
                final participants = (data['participants'] as List?)?.length ?? 0;
                final maxPart = data['maxParticipants'] as int?;
                final status = data['status'] ?? 'upcoming';
                final isActive = status == 'upcoming' || status == 'ongoing';
                final creatorId = data['creatorId'] ?? '—';

                return DataRow(cells: [
                  DataCell(
                    SizedBox(
                      width: 180,
                      child: Text(data['title'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  DataCell(
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(creatorId).get(),
                      builder: (context, snap) {
                        if (snap.hasData && snap.data!.exists) {
                          final userData = snap.data!.data() as Map<String, dynamic>;
                          return Text('${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(), style: const TextStyle(fontSize: 13));
                        }
                        return Text(_truncate(creatorId, 12), style: TextStyle(fontSize: 11, color: Colors.grey[400], fontFamily: 'monospace'));
                      },
                    ),
                  ),
                  DataCell(Text(dateStr)),
                  DataCell(Text(maxPart != null ? '$participants/$maxPart' : '$participants')),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.blue[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _walkStatusLabel(status),
                      style: TextStyle(fontSize: 12, color: isActive ? Colors.blue[700] : Colors.grey[600], fontWeight: FontWeight.bold),
                    ),
                  )),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        tooltip: 'Elimina',
                        onPressed: () => _confirmDelete(context, 'group_walks', doc.id, data['title'] ?? 'questa passeggiata'),
                      ),
                    ],
                  )),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  String _walkStatusLabel(String status) {
    switch (status) {
      case 'upcoming': return 'In Programma';
      case 'ongoing': return 'In Corso';
      case 'completed': return 'Conclusa';
      case 'cancelled': return 'Annullata';
      default: return status;
    }
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String collection, String docId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma Eliminazione'),
        content: Text('Vuoi davvero eliminare "$name"? Questa azione è irreversibile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eliminato con successo.')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
        }
      }
    }
  }

  String _truncate(String s, int max) => s.length > max ? '${s.substring(0, max)}...' : s;
}

class _TabButton extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final Function(String) onTap;

  const _TabButton({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? Colors.indigo : Colors.grey[300]!),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w600)),
      ),
    );
  }
}
