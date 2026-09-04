import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/models/pet_business_model.dart';
import '../../../../core/services/pet_business_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../screens/pet_business_detail_screen.dart';

/// Shows a bottom sheet with details about a pet business
void showPetBusinessBottomSheet(BuildContext context, PetBusinessModel business) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _PetBusinessDetailSheet(business: business),
  );
}

class _PetBusinessDetailSheet extends StatefulWidget {
  final PetBusinessModel business;
  const _PetBusinessDetailSheet({required this.business});

  @override
  State<_PetBusinessDetailSheet> createState() => _PetBusinessDetailSheetState();
}

class _PetBusinessDetailSheetState extends State<_PetBusinessDetailSheet> {
  Map<String, dynamic>? _placeDetails;
  bool _loadingDetails = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (widget.business.googlePlaceId == null) return;
    setState(() => _loadingDetails = true);
    
    final details = await PetBusinessService().getPlaceDetails(widget.business.googlePlaceId!);
    if (mounted) {
      setState(() {
        _placeDetails = details;
        _loadingDetails = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final biz = widget.business;
    final phone = _placeDetails?['formatted_phone_number'] ?? biz.phone;
    final website = _placeDetails?['website'] ?? biz.website;
    final fullAddress = _placeDetails?['formatted_address'] ?? biz.address;
    final mapsUrl = _placeDetails?['url'];
    final openingHours = _placeDetails?['opening_hours']?['weekday_text'] as List?;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header: Category icon + Name
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _categoryColor(biz.category).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        biz.category.icon,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          biz.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _categoryColor(biz.category).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                biz.category.displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _categoryColor(biz.category),
                                ),
                              ),
                            ),
                            if (biz.isClaimed) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified, size: 14, color: Colors.green),
                                    SizedBox(width: 4),
                                    Text(
                                      'Verificato',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // Dog parks: public space badge
                            if (biz.category == PetBusinessCategory.dogPark || biz.category == PetBusinessCategory.petFriendlyBeach) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF43A047).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.nature_people, size: 14, color: Color(0xFF43A047)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Spazio pubblico',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF43A047),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Note: rating not shown here — will be pulled from DOGZN reviews in the detail screen

              // Open/Closed indicator
              if (biz.openNow != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: biz.openNow == 'Aperto'
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: biz.openNow == 'Aperto' ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        biz.openNow == 'Aperto' ? 'Aperto ora' : 'Chiuso',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: biz.openNow == 'Aperto' ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Divider
              Divider(color: Colors.grey[200]),
              const SizedBox(height: 12),

              // Address
              _buildInfoRow(Icons.location_on, fullAddress, onTap: () {
                if (mapsUrl != null) {
                  launchUrl(Uri.parse(mapsUrl));
                }
              }),

              // Phone
              if (phone != null) ...[
                const SizedBox(height: 12),
                _buildInfoRow(Icons.phone, phone, onTap: () {
                  launchUrl(Uri.parse('tel:$phone'));
                }),
              ],

              // Website
              if (website != null) ...[
                const SizedBox(height: 12),
                _buildInfoRow(Icons.language, website, onTap: () {
                  launchUrl(Uri.parse(website));
                }),
              ],

              // Opening hours
              if (openingHours != null) ...[
                const SizedBox(height: 16),
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 12),
                const Text(
                  'Orari di apertura',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                ...openingHours.map((day) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                )),
              ],

              // Description (for claimed businesses)
              if (biz.description != null && biz.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 12),
                const Text(
                  'Descrizione',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  biz.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],

              // Services (for claimed businesses)
              if (biz.services.isNotEmpty) ...[
                const SizedBox(height: 16),
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 12),
                const Text(
                  'Servizi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: biz.services.map((service) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Text(
                      service,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                ),
              ],

              // Loading indicator for details
              if (_loadingDetails) ...[
                const SizedBox(height: 16),
                const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  // Call Button
                  if (phone != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          launchUrl(Uri.parse('tel:$phone'));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.call, size: 20),
                        label: const Text('Chiama', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  if (phone != null && mapsUrl != null)
                    const SizedBox(width: 12),
                  // Directions Button
                  if (mapsUrl != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          launchUrl(Uri.parse(mapsUrl));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.directions, size: 20),
                        label: const Text('Indicazioni', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),

              // View Details & Reviews button
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close bottom sheet
                    Navigator.of(context).push(
                      MaterialPageRoute(
            settings: const RouteSettings(name: 'pet_business_detail'),
                        builder: (_) => PetBusinessDetailScreen(business: biz),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _categoryColor(biz.category),
                    side: BorderSide(color: _categoryColor(biz.category).withOpacity(0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.rate_review, size: 20),
                  label: const Text('Dettagli e Recensioni', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: onTap != null ? AppColors.primary : Colors.grey[700],
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(PetBusinessCategory category) {
    switch (category) {
      case PetBusinessCategory.vetClinic:
        return Colors.red;
      case PetBusinessCategory.petShop:
        return Colors.teal;
      case PetBusinessCategory.groomer:
        return Colors.purple;
      case PetBusinessCategory.petSitter:
        return Colors.blue;
      case PetBusinessCategory.dogTrainer:
        return Colors.orange;
      case PetBusinessCategory.petHotel:
        return Colors.indigo;
      case PetBusinessCategory.petFriendlyCafe:
        return Colors.brown;
      case PetBusinessCategory.petPharmacy:
        return Colors.cyan;
      case PetBusinessCategory.dogPark:
        return const Color(0xFF43A047);
      case PetBusinessCategory.petFriendlyBeach:
        return const Color(0xFFFFB300);
      case PetBusinessCategory.petFriendlyBathhouse:
        return const Color(0xFFFF8F00);
      case PetBusinessCategory.other:
        return Colors.grey;
    }
  }
}
