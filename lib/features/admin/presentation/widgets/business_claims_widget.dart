import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';

/// Widget for displaying and managing business claim requests in the admin panel
class BusinessClaimsWidget extends StatelessWidget {
  const BusinessClaimsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('business_claims')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'Nessuna richiesta di riscatto',
                  style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le richieste appariranno qui quando gli utenti riscatteranno un\'attività',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        final claims = snapshot.data!.docs;

        // Separate by status
        final pending = claims.where((d) => d['status'] == 'pending').toList();
        final approved = claims.where((d) => d['status'] == 'approved').toList();
        final rejected = claims.where((d) => d['status'] == 'rejected').toList();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats row
              Row(
                children: [
                  _buildStatCard('In attesa', pending.length, Colors.orange, Icons.hourglass_top),
                  const SizedBox(width: 16),
                  _buildStatCard('Approvate', approved.length, Colors.green, Icons.check_circle),
                  const SizedBox(width: 16),
                  _buildStatCard('Rifiutate', rejected.length, Colors.red, Icons.cancel),
                  const SizedBox(width: 16),
                  _buildStatCard('Totale', claims.length, AppColors.primary, Icons.storefront),
                ],
              ),
              const SizedBox(height: 32),

              // Pending claims (priority)
              if (pending.isNotEmpty) ...[
                _buildSectionTitle('⏳ In attesa di revisione', pending.length),
                const SizedBox(height: 12),
                ...pending.map((doc) => _ClaimCard(
                  doc: doc,
                  onApprove: () => _approveClaim(context, doc),
                  onReject: () => _showRejectDialog(context, doc),
                )),
                const SizedBox(height: 32),
              ],

              // Recent approved
              if (approved.isNotEmpty) ...[
                _buildSectionTitle('✅ Approvate', approved.length),
                const SizedBox(height: 12),
                ...approved.take(10).map((doc) => _ClaimCard(doc: doc)),
                const SizedBox(height: 32),
              ],

              // Recent rejected
              if (rejected.isNotEmpty) ...[
                _buildSectionTitle('❌ Rifiutate', rejected.length),
                const SizedBox(height: 12),
                ...rejected.take(10).map((doc) => _ClaimCard(doc: doc)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Future<void> _approveClaim(BuildContext context, DocumentSnapshot doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Approva richiesta'),
          ],
        ),
        content: Text(
          'Vuoi approvare la richiesta di riscatto per "${doc['businessName']}" '
          'da ${doc['ownerName']}?\n\n'
          'L\'attività verrà assegnata all\'utente e riceverà una notifica.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approva'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await doc.reference.update({'status': 'approved'});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Richiesta approvata! La Cloud Function assegnerà l\'attività.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showRejectDialog(BuildContext context, DocumentSnapshot doc) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text('Rifiuta richiesta'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stai rifiutando la richiesta per "${doc['businessName']}".'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Motivo del rifiuto (opzionale)',
                hintText: 'es. Documento non leggibile, P.IVA non corrispondente...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rifiuta'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await doc.reference.update({
        'status': 'rejected',
        'rejectionReason': reasonController.text.trim().isNotEmpty
            ? reasonController.text.trim()
            : null,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Richiesta rifiutata. L\'utente verrà notificato.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    reasonController.dispose();
  }
}

/// Individual claim card widget
class _ClaimCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _ClaimCard({required this.doc, this.onApprove, this.onReject});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'pending';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final proofPhotoUrl = data['proofPhotoUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == 'pending'
              ? Colors.orange.withOpacity(0.3)
              : status == 'approved'
                  ? Colors.green.withOpacity(0.3)
                  : Colors.red.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Status badge
                _buildStatusBadge(status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['businessName'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          _formatDate(createdAt),
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                    ],
                  ),
                ),
                // Actions
                if (status == 'pending' && onApprove != null && onReject != null) ...[
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                    tooltip: 'Approva',
                    onPressed: onApprove,
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                    tooltip: 'Rifiuta',
                    onPressed: onReject,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Info grid
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _buildInfoChip(Icons.person, 'Proprietario', data['ownerName'] ?? '-'),
                _buildInfoChip(Icons.badge, 'Ruolo', data['role'] ?? '-'),
                _buildInfoChip(Icons.phone, 'Telefono', data['phone'] ?? '-'),
                _buildInfoChip(Icons.email, 'Email', data['businessEmail'] ?? '-'),
                _buildInfoChip(Icons.business, 'P.IVA', data['piva'] ?? '-'),
                _buildInfoChip(Icons.fingerprint, 'User ID', _truncateUid(data['userId'] ?? '-')),
              ],
            ),

            // Notes
            if (data['notes'] != null && (data['notes'] as String).isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Note:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Text(data['notes'], style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],

            // Proof photo
            if (proofPhotoUrl != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.photo, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _showProofPhoto(context, proofPhotoUrl),
                    child: const Text(
                      'Visualizza foto di verifica',
                      style: TextStyle(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Rejection reason
            if (status == 'rejected' && data['rejectionReason'] != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Motivo: ${data['rejectionReason']}',
                        style: const TextStyle(fontSize: 13, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'approved':
        color = Colors.green;
        label = 'Approvata';
        icon = Icons.check;
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rifiutata';
        icon = Icons.close;
        break;
      default:
        color = Colors.orange;
        label = 'In attesa';
        icon = Icons.hourglass_top;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return SizedBox(
      width: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _truncateUid(String uid) {
    if (uid.length > 10) return '${uid.substring(0, 10)}...';
    return uid;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  void _showProofPhoto(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                width: 600,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (ctx, err, stack) => SizedBox(
                  height: 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('Errore caricamento immagine', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => launchUrl(Uri.parse(url)),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Apri originale'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Chiudi'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
