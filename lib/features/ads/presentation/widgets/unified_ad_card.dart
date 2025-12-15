import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../shared/models/ad_campaign_model.dart';
import '../../../../core/theme/app_colors.dart';

/// Provider for AdService
final adServiceProvider = Provider<AdService>((ref) => AdService());

class UnifiedAdCard extends ConsumerStatefulWidget {
  final String zone; // e.g. 'nextdoor_feed', 'activities_list'

  const UnifiedAdCard({super.key, required this.zone});

  @override
  ConsumerState<UnifiedAdCard> createState() => _UnifiedAdCardState();
}

class _UnifiedAdCardState extends ConsumerState<UnifiedAdCard> {
  AdCampaignModel? _internalAd;
  bool _isLoading = true;
  
  // AdMob
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadAds() async {
    final adService = ref.read(adServiceProvider);
    
    // 1. Try fetch Internal Ad First
    final ad = await adService.fetchNativeAd(widget.zone);
    
    if (mounted) {
      if (ad != null) {
        // Internal Ad Found
        setState(() {
          _internalAd = ad;
          _isLoading = false;
        });
        adService.recordImpression(ad.id);
      } else {
         // 2. Fallback to AdMob
        _loadBannerAd();
      }
    }
  }

  void _loadBannerAd() {
    // Determine AdUnitId based on Platform (Test ID for now)
    // iOS Test ID: ca-app-pub-3940256099942544/2934735716
    // Android Test ID: ca-app-pub-3940256099942544/6300978111
    
    // Check if web (not supported for mobile ads sdk usually, or needs specific plugin)
    // MobileAds.instance.initialize is no-op on web usually but safe.
    
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/2934735716', // iOS Test ID
      request: const AdRequest(),
      size: AdSize.mediumRectangle, // Fits well in feed
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
             setState(() {
              _isBannerAdReady = true;
              _isLoading = false;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('AdMob Failed: $err');
          ad.dispose();
          if (mounted) {
             setState(() {
              _isLoading = false; // Stop loading but show nothing
            });
          }
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();

    // 1. Show Internal Ad
    if (_internalAd != null) {
      return _buildProprietaryAd(_internalAd!);
    }

    // 2. Show AdMob Banner
    if (_isBannerAdReady && _bannerAd != null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildProprietaryAd(AdCampaignModel ad) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                bottomRight: Radius.circular(11),
              ),
            ),
            child: const Text(
              'Sponsorizzato',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (ad.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      ad.imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Icon(Icons.store, color: Colors.grey),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ad.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ad.body,
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // CTA Button
          if (ad.ctaLink.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _handleClick(ad),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(ad.ctaText.toUpperCase()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleClick(AdCampaignModel ad) async {
    ref.read(adServiceProvider).recordClick(ad.id);
    
    // Check if internal route
    if (ad.ctaLink.startsWith('/')) {
        // Simple internal nav if using named routes, or handle specifically
        // Navigator.pushNamed(context, ad.ctaLink);
    } else {
      // External launch
      final uri = Uri.tryParse(ad.ctaLink);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }
}
