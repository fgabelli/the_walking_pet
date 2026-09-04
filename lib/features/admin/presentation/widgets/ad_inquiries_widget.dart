import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../screens/create_campaign_web_screen.dart';

/// Model for ad inquiry from landing page
class AdInquiry {
  final String id;
  final String businessName;
  final String businessType;
  final String contactName;
  final String city;
  final String email;
  final String phone;
  final String? piva;
  final String? website;
  final String? message;
  final String status; // pending, contacted, converted, rejected
  final DateTime createdAt;

  AdInquiry({
    required this.id,
    required this.businessName,
    required this.businessType,
    required this.contactName,
    required this.city,
    required this.email,
    required this.phone,
    this.piva,
    this.website,
    this.message,
    required this.status,
    required this.createdAt,
  });

  factory AdInquiry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdInquiry(
      id: doc.id,
      businessName: data['businessName'] ?? '',
      businessType: data['businessType'] ?? '',
      contactName: data['contactName'] ?? '',
      city: data['city'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      piva: data['piva'],
      website: data['website'],
      message: data['message'],
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

/// Widget for displaying and managing ad inquiries in the admin panel
class AdInquiriesWidget extends ConsumerWidget {
  const AdInquiriesWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ad_inquiries')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Errore: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final inquiries = snapshot.data!.docs
            .map((doc) => AdInquiry.fromFirestore(doc))
            .toList();

        if (inquiries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('Nessuna richiesta pubblicitaria',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                    'Le richieste dal form di dogzn.com appariranno qui',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: inquiries.length,
          itemBuilder: (context, index) {
            final inquiry = inquiries[index];
            return _InquiryCard(inquiry: inquiry);
          },
        );
      },
    );
  }
}

class _InquiryCard extends StatelessWidget {
  final AdInquiry inquiry;
  const _InquiryCard({required this.inquiry});

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'contacted':
        return Colors.blue;
      case 'converted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '⏳ In attesa';
      case 'contacted':
        return '📞 Contattato';
      case 'converted':
        return '✅ Convertito';
      case 'rejected':
        return '❌ Rifiutato';
      default:
        return status;
    }
  }

  String _businessTypeLabel(String type) {
    switch (type) {
      case 'veterinario':
        return '🏥 Veterinario';
      case 'negozio':
        return '🏪 Negozio di Animali';
      case 'toelettatore':
        return '✂️ Toelettatore';
      case 'dog_sitter':
        return '🐕 Dog Sitter';
      case 'educatore':
        return '🎓 Educatore Cinofilo';
      case 'pensione':
        return '🏠 Pensione per Animali';
      case 'ristorante_petfriendly':
        return '🍽️ Ristorante Pet-Friendly';
      default:
        return '📦 $type';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(inquiry.status);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inquiry.businessName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _businessTypeLabel(inquiry.businessType),
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color),
                  ),
                  child: Text(
                    _statusLabel(inquiry.status),
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  tooltip: 'Modifica',
                  onPressed: () => _showEditDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info grid
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _InfoChip(icon: Icons.person, label: inquiry.contactName),
                _InfoChip(icon: Icons.location_city, label: inquiry.city),
                _InfoChip(icon: Icons.email, label: inquiry.email),
                _InfoChip(icon: Icons.phone, label: inquiry.phone),
                if (inquiry.piva != null && inquiry.piva!.isNotEmpty)
                  _InfoChip(icon: Icons.business, label: inquiry.piva!),
                if (inquiry.website != null && inquiry.website!.isNotEmpty)
                  _InfoChip(icon: Icons.language, label: inquiry.website!),
                _InfoChip(
                  icon: Icons.calendar_today,
                  label: DateFormat('dd MMM yyyy, HH:mm')
                      .format(inquiry.createdAt),
                ),
              ],
            ),

            // Message
            if (inquiry.message != null && inquiry.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Messaggio:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Text(inquiry.message!,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],

            if (inquiry.status == 'pending' || inquiry.status == 'contacted') ...[
              const SizedBox(height: 16),
              // Action buttons
              Row(
                children: [
                  if (inquiry.status == 'pending') ...[
                    ElevatedButton.icon(
                      onPressed: () => _updateStatus(context, inquiry.id, 'contacted'),
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text('Contattato'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton.icon(
                    onPressed: () =>
                        _convertToCampaign(context, inquiry),
                    icon: const Icon(Icons.campaign, size: 16),
                    label: const Text('Crea Campagna'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _updateStatus(context, inquiry.id, 'rejected'),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Rifiuta'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _updateStatus(BuildContext context, String id, String newStatus) {
    FirebaseFirestore.instance
        .collection('ad_inquiries')
        .doc(id)
        .update({'status': newStatus});
  }

  void _convertToCampaign(BuildContext context, AdInquiry inquiry) {
    // Navigate to CreateCampaignScreen with pre-filled data
    Navigator.push(
      context,
      MaterialPageRoute(
            settings: const RouteSettings(name: 'create_campaign'),
        builder: (_) => CreateCampaignScreen(
          prefillBusinessName: inquiry.businessName,
          prefillCity: inquiry.city,
        ),
      ),
    ).then((_) {
      // Mark inquiry as converted after returning
      _updateStatus(context, inquiry.id, 'converted');
    });
  }

  void _showEditDialog(BuildContext context) {
    final businessController = TextEditingController(text: inquiry.businessName);
    final emailController = TextEditingController(text: inquiry.email);
    final phoneController = TextEditingController(text: inquiry.phone);
    String selectedStatus = inquiry.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Modifica Richiesta'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: businessController,
                    decoration: const InputDecoration(labelText: 'Attività', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Telefono', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Stato', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('In attesa')),
                      DropdownMenuItem(value: 'contacted', child: Text('Contattato')),
                      DropdownMenuItem(value: 'converted', child: Text('Convertito')),
                      DropdownMenuItem(value: 'rejected', child: Text('Rifiutato')),
                    ],
                    onChanged: (v) => setState(() => selectedStatus = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
              ElevatedButton(
                onPressed: () {
                  FirebaseFirestore.instance.collection('ad_inquiries').doc(inquiry.id).update({
                    'businessName': businessController.text,
                    'email': emailController.text,
                    'phone': phoneController.text,
                    'status': selectedStatus,
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Salva'),
              ),
            ],
          );
        }
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
      ],
    );
  }
}
