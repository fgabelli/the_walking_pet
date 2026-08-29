import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdMobStatsWidget extends StatelessWidget {
  const AdMobStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ads')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        
        // Aggregate stats
        int totalImpressions = 0;
        int totalClicks = 0;
        int activeCampaigns = 0;
        int totalCampaigns = docs.length;
        
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalImpressions += (data['impressions'] as int? ?? 0);
          totalClicks += (data['clicks'] as int? ?? 0);
          if (data['isActive'] == true) activeCampaigns++;
        }
        
        final ctr = totalImpressions > 0
            ? (totalClicks / totalImpressions * 100).toStringAsFixed(2)
            : '0.00';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Cards Row
            Row(
              children: [
                _StatCard(
                  icon: Icons.visibility,
                  label: 'Impression Totali',
                  value: _formatNumber(totalImpressions),
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  icon: Icons.touch_app,
                  label: 'Click Totali',
                  value: _formatNumber(totalClicks),
                  color: Colors.green,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  icon: Icons.percent,
                  label: 'CTR Medio',
                  value: '$ctr%',
                  color: Colors.orange,
                ),
                const SizedBox(width: 16),
                _StatCard(
                  icon: Icons.campaign,
                  label: 'Campagne Attive',
                  value: '$activeCampaigns / $totalCampaigns',
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Per-campaign breakdown
            Text('Dettaglio per Campagna', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            Expanded(
              child: docs.isEmpty
                  ? const Center(child: Text('Nessuna campagna trovata.'))
                  : SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                        columns: const [
                          DataColumn(label: Text('Campagna', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Zona', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Stato', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Impression', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('Click', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('CTR', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        ],
                        rows: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final imp = data['impressions'] as int? ?? 0;
                          final cli = data['clicks'] as int? ?? 0;
                          final campCtr = imp > 0 ? (cli / imp * 100).toStringAsFixed(2) : '0.00';
                          final isActive = data['isActive'] == true;
                          
                          return DataRow(cells: [
                            DataCell(Text(data['title'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w500))),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(data['targetZone'] ?? '—', style: TextStyle(fontSize: 12, color: Colors.blue[700])),
                            )),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green[50] : Colors.red[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isActive ? 'Attiva' : 'Pausa',
                                style: TextStyle(fontSize: 12, color: isActive ? Colors.green[700] : Colors.red[700], fontWeight: FontWeight.bold),
                              ),
                            )),
                            DataCell(Text(_formatNumber(imp))),
                            DataCell(Text(_formatNumber(cli))),
                            DataCell(Text('$campCtr%')),
                          ]);
                        }).toList(),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  static String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
