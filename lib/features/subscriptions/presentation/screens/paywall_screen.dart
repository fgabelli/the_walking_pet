import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart'; // Added
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../core/services/purchase_service.dart'; // Added provider definition here

class PaywallScreen extends ConsumerStatefulWidget {
  final String offeringId; // 'default' or 'business_pro'

  const PaywallScreen({super.key, this.offeringId = 'default'});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isLoading = false;
  List<Package> _packages = []; // Changed from _mockProducts
  
  @override
  void initState() {
    super.initState();
    _fetchOfferings();
  }

  Future<void> _fetchOfferings() async {
    setState(() => _isLoading = true);
    try {
      final offerings = await ref.read(purchaseServiceProvider).getOfferings();
      print('--- DEBUG PAYWALL ---');
      print('Requested Offering ID: ${widget.offeringId}');
      if (offerings == null) {
        print('Offerings response is NULL');
      } else {
         print('Available Offerings Keys: ${offerings.all.keys.toList()}');
         print('Current Offering: ${offerings.current?.identifier}');
         
         final offering = offerings.all[widget.offeringId] ?? offerings.current;
         if (offering != null) {
           print('Found Offering: ${offering.identifier}');
           print('Packages count: ${offering.availablePackages.length}');
           for(var p in offering.availablePackages) {
             print('Package: ${p.identifier} - Product: ${p.storeProduct.identifier}');
           }
           setState(() {
            _packages = offering.availablePackages;
           });
         } else {
           print('Offering ${widget.offeringId} NOT FOUND in response');
         }
      }
    } catch (e) {
      print('Error fetching offerings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Background Image / Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    backgroundColor,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Close Button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        // Icon/Illustration
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star_rounded, size: 60, color: AppColors.primary),
                        ),
                        const SizedBox(height: 24),
                        
                        Text(
                          widget.offeringId == 'business_pro' 
                              ? 'Passa a Business' 
                              : 'Passa a Premium',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sblocca tutte le funzionalità e goditi al massimo le tue passeggiate.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        
                        // Benefits
                        _buildBenefitRow(context, Icons.filter_list, 'Filtri Avanzati', 'Cerca compagni per razza, taglia e sesso'),
                        _buildBenefitRow(context, Icons.visibility_off, 'Ghost Mode', 'Naviga la mappa senza essere visto'),
                        _buildBenefitRow(context, Icons.pets, 'Icona Dorata', 'Distinguiti sulla mappa con un pin esclusivo'),
                        _buildBenefitRow(context, Icons.block, 'Zero Pubblicità', 'Navigazione pulita e senza interruzioni'),
                        
                        const SizedBox(height: 48),
                        
                        // Products
                        if (_packages.isEmpty && !_isLoading)
                           const Text('Nessuna offerta disponibile al momento.'),
                        ..._packages.map((p) => _buildProductCard(context, p)),
                        
                        const SizedBox(height: 24),
                        
                        Text(
                          'L\'abbonamento si rinnova automaticamente. Puoi disdire in qualsiasi momento dalle impostazioni del tuo store.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                         const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(BuildContext context, IconData icon, String title, String subtitle) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Package package) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.grey[800] : Colors.white;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final product = package.storeProduct;

    return GestureDetector(
      onTap: () => _purchase(package),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(
            color: AppColors.primary,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title, // RevenueCat Title
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        product.priceString, // RevenueCat Price
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: AppColors.primary,
                        ),
                      ),
                       const SizedBox(width: 8),
                      // Text(
                      //   package.packageType == PackageType.annual ? '/ anno' : '/ mese',
                      //   style: TextStyle(
                      //     color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      //     fontSize: 16,
                      //   ),
                      // ),
                    ],
                  ),
                ],
              ),
            ),
            // Savings badge logic could be added here if needed
          ],
        ),
      ),
    );
  }

  Future<void> _purchase(Package package) async {
    setState(() => _isLoading = true);
    
    try {
      final success = await ref.read(purchaseServiceProvider).purchasePackage(package);
      
      if (!mounted) return;

      if (success) {
         // Refresh profile entitlement status
         await ref.read(profileControllerProvider.notifier).refreshEntitlements();
         
         if (!mounted) return;

         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Acquisto completato con successo! 🎉')),
         );
         Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'acquisto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
