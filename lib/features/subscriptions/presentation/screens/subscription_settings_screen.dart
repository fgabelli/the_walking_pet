import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/purchase_service.dart';

class SubscriptionSettingsScreen extends ConsumerStatefulWidget {
  const SubscriptionSettingsScreen({super.key});

  @override
  ConsumerState<SubscriptionSettingsScreen> createState() => _SubscriptionSettingsScreenState();
}

class _SubscriptionSettingsScreenState extends ConsumerState<SubscriptionSettingsScreen> {
  bool _isLoading = false;
  CustomerInfo? _customerInfo;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionInfo();
  }

  Future<void> _loadSubscriptionInfo() async {
    setState(() => _isLoading = true);
    final info = await ref.read(purchaseServiceProvider).getCustomerInfo();
    if (mounted) {
      setState(() {
        _customerInfo = info;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Abbonamento')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final purchaseService = ref.read(purchaseServiceProvider);
    final entitlement = _customerInfo != null 
        ? purchaseService.getActiveEntitlement(_customerInfo!) 
        : null;
        
    final isActive = entitlement?.isActive ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Il mio Abbonamento')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isActive ? Icons.verified : Icons.cancel,
                            color: isActive ? Colors.green : Colors.grey,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isActive 
                                  ? (entitlement?.identifier == 'business_pro' ? 'Business Pro' : 'Premium')
                                  : 'Piano Gratuito',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              isActive ? 'Attivo' : 'Nessun abbonamento attivo',
                              style: TextStyle(
                                color: isActive ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (isActive && entitlement != null) ...[
                      const Divider(height: 32),
                      _buildInfoRow(
                        'Data inizio:', 
                        DateFormat('dd/MM/yyyy').format(DateTime.parse(entitlement.originalPurchaseDate))
                      ),
                      const SizedBox(height: 12),
                      if (entitlement.expirationDate != null)
                        _buildInfoRow(
                          'Rinnovo/Scadenza:', 
                          DateFormat('dd/MM/yyyy').format(DateTime.parse(entitlement.expirationDate!))
                        )
                      else
                        _buildInfoRow('Scadenza:', 'Mai (A vita)'),
                        
                      const SizedBox(height: 12),
                      _buildInfoRow('Store:', entitlement.store.name),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Actions
            if (isActive) ...[
              const Text(
                'Gestione',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              Card(
                child: ListTile(
                  leading: const Icon(Icons.settings, color: AppColors.primary),
                  title: const Text('Gestisci o Annulla Abbonamento'),
                  subtitle: const Text('Verrai reindirizzato allo store'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () async {
                    final url = await purchaseService.getManagementURL();
                    if (url != null) {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                         await launchUrl(uri);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Impossibile aprire lo store.')),
                          );
                        }
                      }
                    } else {
                       if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Impossibile trovare il link di gestione.')),
                          );
                       }
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nota: La disattivazione del rinnovo automatico manterrà le funzionalità attive fino alla data di scadenza.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ] else ...[
               const Text(
                'Nessun abbonamento attivo. Passa a Premium per sbloccare funzionalità esclusive!',
                textAlign: TextAlign.center,
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
