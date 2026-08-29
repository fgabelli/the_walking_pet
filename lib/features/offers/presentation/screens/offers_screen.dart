import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/models/offer_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import 'create_offer_screen.dart';

// Reuse the provider from CreateOfferScreen or define here if global
final offersStreamProvider = StreamProvider<List<OfferModel>>((ref) {
  return ref.watch(offersServiceProvider).getOffers();
});

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(offersStreamProvider);
    final currentUser = ref.watch(currentUserProfileProvider).value;

    return Scaffold(
      body: offersAsync.when(
        data: (offers) {
          if (offers.isEmpty) {
            return const Center(child: Text('Nessuna offerta disponibile al momento.'));
          }

          // Count recent offers (last 24 hours)
          final now = DateTime.now();
          final recentOffers = offers.where(
            (o) => now.difference(o.createdAt).inHours < 24,
          ).length;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: offers.length + (recentOffers > 0 ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              // Banner for new offers
              if (recentOffers > 0 && index == 0) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade600, Colors.orange.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.local_offer, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$recentOffers ${recentOffers == 1 ? 'nuova offerta' : 'nuove offerte'} vicino a te!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pubblicate nelle ultime 24 ore',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_downward_rounded,
                        color: Colors.white.withOpacity(0.7),
                        size: 18,
                      ),
                    ],
                  ),
                );
              }

              final offerIndex = recentOffers > 0 ? index - 1 : index;
              final offer = offers[offerIndex];
              final isNew = now.difference(offer.createdAt).inHours < 24;

              return Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    Stack(
                      children: [
                         Image.network(
                          offer.imageUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, _, __) => Container(
                            height: 180, 
                            color: Colors.grey[200], 
                            child: const Center(child: Icon(Icons.shopping_bag, size: 50, color: Colors.grey)),
                          ),
                        ),
                        if (offer.discountPercentage != null)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '-${offer.discountPercentage!.toInt()}%',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        if (isNew)
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade600,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fiber_new, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'NUOVA',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer.partnerName,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            offer.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            offer.description,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          
                          // Code & Button Row
                          if (offer.type == OfferType.discountCode && offer.discountCode != null) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          offer.discountCode!,
                                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                                        ),
                                        InkWell(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(text: offer.discountCode!));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Codice copiato!')),
                                            );
                                          },
                                          child: const Icon(Icons.copy, size: 20, color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Optional link even for code offers if needed, 
                                // but for now we prioritize copy code
                              ],
                            ),
                          ] else if (offer.type == OfferType.externalLink && offer.affiliateLink != null) ...[
                             SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _launchUrl(offer.affiliateLink!),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Vedi Offerta'),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Errore: $e')),
      ),
      floatingActionButton: (currentUser?.accountType == AccountType.business) 
          ? FloatingActionButton(
              onPressed: () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateOfferScreen()),
                );
              },
              backgroundColor: Colors.amber,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
