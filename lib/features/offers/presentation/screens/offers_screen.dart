import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/models/offer_model.dart';
import '../../../../core/theme/app_colors.dart';

class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  static const List<OfferModel> _mockOffers = [
    OfferModel(
      id: '1',
      title: 'Cibo Premium per Cani',
      description: 'Ricevi il 20% di sconto sul tuo primo ordine di crocchette naturali e bilanciate.',
      imageUrl: 'https://images.unsplash.com/photo-1589924696552-96091917dd15?auto=format&fit=crop&q=80',
      discountCode: 'WALKING20',
      affiliateLink: 'https://www.google.com', // Placeholder
      partnerName: 'DogFoodCo',
      discountPercentage: 20,
    ),
    OfferModel(
      id: '2',
      title: 'Assicurazione Veterinaria',
      description: 'Proteggi il tuo amico a 4 zampe con una copertura completa. Primo mese gratis!',
      imageUrl: 'https://images.unsplash.com/photo-1628009368231-760335298450?auto=format&fit=crop&q=80',
      affiliateLink: 'https://www.google.com',
      partnerName: 'PetSafe Assicurazioni',
    ),
    OfferModel(
      id: '3',
      title: 'Box Giochi Mensile',
      description: 'Una scatola piena di nuovi giochi e snack ogni mese direttamente a casa tua.',
      imageUrl: 'https://images.unsplash.com/photo-1576201836106-db1758fd1c97?auto=format&fit=crop&q=80',
      discountCode: 'HAPPYDOG',
      affiliateLink: 'https://www.google.com',
      partnerName: 'HappyTailBox',
      discountPercentage: 15,
    ),
  ];

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _mockOffers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final offer = _mockOffers[index];
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
                    Row(
                      children: [
                        if (offer.discountCode != null) ...[
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
                        ],
                        
                        Expanded(
                          flex: offer.discountCode != null ? 1 : 2,
                          child: ElevatedButton(
                            onPressed: () => _launchUrl(offer.affiliateLink),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Vedi Offerta'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
