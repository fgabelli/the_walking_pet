import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../features/ads/presentation/widgets/unified_ad_card.dart'; // Ensure exported
import '../../../../core/services/ad_service.dart';
import '../../../../shared/models/ad_campaign_model.dart';

class AdsTableWidget extends ConsumerWidget {
  const AdsTableWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adService = ref.watch(adServiceProvider);
    
    return StreamBuilder<List<AdCampaignModel>>(
      stream: adService.getAllAdsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Errore: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final ads = snapshot.data!;

        if (ads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.campaign_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Nessuna campagna attiva'),
              ],
            ),
          );
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
          child: SingleChildScrollView(
            child: DataTable(
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('Anteprima')),
                DataColumn(label: Text('Titolo')),
                DataColumn(label: Text('Zona')),
                DataColumn(label: Text('Impression')),
                DataColumn(label: Text('Click')),
                DataColumn(label: Text('CTR')),
                DataColumn(label: Text('Stato')),
                DataColumn(label: Text('Azioni')),
              ],
              rows: ads.map((ad) {
                 final ctr = ad.impressions > 0 ? (ad.clicks / ad.impressions * 100).toStringAsFixed(1) : '0.0';
                 final isExpired = ad.expiresAt.isBefore(DateTime.now());

                 return DataRow(
                  cells: [
                    DataCell(
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: ad.imageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(ad.imageUrl), fit: BoxFit.cover) : null,
                          color: Colors.grey[200],
                        ),
                      ),
                    ),
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(ad.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(DateFormat('dd MMM yyyy').format(ad.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    DataCell(Chip(label: Text(ad.targetZone), visualDensity: VisualDensity.compact, backgroundColor: Colors.blue.shade50)),
                    DataCell(Text(ad.impressions.toString())),
                    DataCell(Text(ad.clicks.toString())),
                    DataCell(Text('$ctr%')),
                    DataCell(
                      _StatusChip(isActive: ad.isActive, isExpired: isExpired),
                    ),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(ad.isActive ? Icons.pause_circle : Icons.play_circle),
                            color: ad.isActive ? Colors.orange : Colors.green,
                            tooltip: ad.isActive ? 'Pausa' : 'Attiva',
                            onPressed: () => adService.toggleAdStatus(ad.id, !ad.isActive),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                             tooltip: 'Elimina',
                            onPressed: () => _confirmDelete(context, adService, ad.id),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, AdService service, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare campagna?'),
        content: const Text('Questa azione non può essere annullata.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          TextButton(
            onPressed: () {
              service.deleteAd(id);
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

class _StatusChip extends StatelessWidget {
  final bool isActive;
  final bool isExpired;

  const _StatusChip({required this.isActive, required this.isExpired});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    if (isExpired) {
      color = Colors.grey;
      label = 'Scaduta';
    } else if (isActive) {
      color = Colors.green;
      label = 'Attiva';
    } else {
      color = Colors.orange;
      label = 'In Pausa';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
