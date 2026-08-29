import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/services/ad_service.dart';
import '../../../../shared/models/ad_campaign_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/ad_constants.dart';
import '../../../../core/providers/ad_readiness_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

/// Provider for AdService
final adServiceProvider = Provider<AdService>((ref) => AdService());

class UnifiedAdCard extends ConsumerStatefulWidget {
  final String zone; // e.g. 'nextdoor_feed', 'activities_list'
  final AdSize? adSize; // Optional, defaults to mediumRectangle

  const UnifiedAdCard({
    super.key, 
    required this.zone,
    this.adSize,
  });

  @override
  ConsumerState<UnifiedAdCard> createState() => _UnifiedAdCardState();
}

class _UnifiedAdCardState extends ConsumerState<UnifiedAdCard> {
  AdCampaignModel? _internalAd;
  bool _isLoadingInternal = true;
  
  // AdMob
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  NativeAd? _nativeAd;
  bool _isNativeAdReady = false;
  bool _isLoadingAdMob = true;
  
  Timer? _rotationTimer;
  bool _showInternalAd = false; // Default to AdMob first
  bool _adMobAdsLoaded = false; // Guard against double-loading

  // Map zone names to their parent tab index (for lazy loading)
  static const _zoneToTab = <String, int>{
    'social_feed': 0, 'nextdoor_feed': 0, 'nextdoor_empty': 0,
    'activities_top': 0, 'activities_list': 0, 'activities_empty': 0,
    'events_top': 0, 'events_list': 0, 'events_empty': 0,
    'map_banner': 1,
    'dating_deck': 2,
  };

  @override
  void initState() {
    super.initState();
    // Start loading internal ads immediately (they don't need AdMob SDK)
    _fetchNewInternalAd();
    // AdMob ads are loaded lazily — see _maybeLoadAdMobAds()
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _bannerAd?.dispose();
    _nativeAd?.dispose();
    super.dispose();
  }

  /// Load AdMob ads only when:
  /// 1. The SDK is initialized (adMobReadyProvider == true)
  /// 2. The owning tab is currently active (activeTabProvider matches)
  /// 3. We haven't already loaded (guard against double-loading)
  void _maybeLoadAdMobAds() {
    if (_adMobAdsLoaded || !mounted) return;

    final isReady = ref.read(adMobReadyProvider);
    final activeTab = ref.read(activeTabProvider);
    final myTab = _zoneToTab[widget.zone] ?? 0;

    if (isReady && activeTab == myTab) {
      _adMobAdsLoaded = true;
      debugPrint('📢 Loading AdMob ad for zone: ${widget.zone} (tab $myTab)');
      if (widget.zone == 'social_feed') {
        _loadNativeAd();
      } else {
        _loadBannerAd();
      }
      _startRotationTimer();
    }
  }

  void _startRotationTimer() {
    // Rotate every 30 seconds (was 12s — too aggressive)
    _rotationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted) return;
      
      // Attempt to get a fresh internal ad
      await _fetchNewInternalAd();
      
      final bool hasInternal = _internalAd != null;
      final bool hasAdMob = (widget.zone == 'social_feed')
          ? (_isNativeAdReady && _nativeAd != null)
          : (_isBannerAdReady && _bannerAd != null);
      
      if (hasInternal && hasAdMob) {
        setState(() {
          // 80% AdMob, 20% internal — prioritize AdMob revenue
          _showInternalAd = Random().nextInt(5) == 0;
        });
        
        // Record impression when showing internal ad
        if (_showInternalAd && _internalAd != null) {
          ref.read(adServiceProvider).recordImpression(_internalAd!.id);
        }
      } else if (hasInternal) {
         setState(() {
          _showInternalAd = true;
         });
         ref.read(adServiceProvider).recordImpression(_internalAd!.id);
      } else if (hasAdMob) {
         setState(() {
          _showInternalAd = false;
         });
      }
    });
  }

  Future<void> _fetchNewInternalAd() async {
    final userProfile = ref.read(currentUserProfileProvider).value;
    final ad = await ref.read(adServiceProvider).fetchNativeAd(
      widget.zone,
      userCity: userProfile?.city,
      userRegion: userProfile?.region,
    );
    if (mounted) {
      if (ad != null && _internalAd == null) {
        // Only record first impression instantly if it's the very first load
        if (_showInternalAd) {
          ref.read(adServiceProvider).recordImpression(ad.id);
        }
      }
      setState(() {
        _internalAd = ad;
        _isLoadingInternal = false;
      });
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AdConstants.bannerAdUnitId,
      request: const AdRequest(),
      size: widget.adSize ?? AdSize.mediumRectangle,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('✅ AdMob Banner loaded for zone: ${widget.zone}');
          if (mounted) {
             setState(() {
              _isBannerAdReady = true;
              _isLoadingAdMob = false;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('❌ AdMob Banner failed for zone: ${widget.zone} — $err');
          ad.dispose();
          if (mounted) {
             setState(() {
              _isLoadingAdMob = false;
            });
          }
        },
        onAdImpression: (_) {
          debugPrint('👁️ AdMob Banner impression for zone: ${widget.zone}');
        },
      ),
    );

    _bannerAd!.load();
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: AdConstants.nativeAdUnitId,
      factoryId: 'socialFeedNativeAd',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          debugPrint('✅ AdMob Native loaded for zone: ${widget.zone}');
          if (mounted) {
            setState(() {
              _isNativeAdReady = true;
              _isLoadingAdMob = false;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('❌ AdMob Native failed for zone: ${widget.zone} — $err');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isLoadingAdMob = false;
            });
          }
        },
        onAdImpression: (_) {
          debugPrint('👁️ AdMob Native impression for zone: ${widget.zone}');
        },
      ),
    );

    _nativeAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers to trigger ad loading when SDK is ready and tab is active
    ref.listen(adMobReadyProvider, (prev, next) {
      if (next) _maybeLoadAdMobAds();
    });
    ref.listen(activeTabProvider, (prev, next) {
      _maybeLoadAdMobAds();
    });
    // Also try on every build in case providers are already set
    _maybeLoadAdMobAds();

    final bool hasInternal = _internalAd != null;
    final bool hasAdMob = (widget.zone == 'social_feed')
        ? (_isNativeAdReady && _nativeAd != null)
        : (_isBannerAdReady && _bannerAd != null);
    final bool isLoading = _isLoadingInternal || _isLoadingAdMob;

    Widget? activeAd;

    Widget buildProprietary() {
      if (widget.zone == 'dating_deck') {
        return _buildDatingDeckAd(_internalAd!);
      }
      return _buildProprietaryAd(_internalAd!);
    }

    Widget buildAdMob() {
      if (widget.zone == 'social_feed' && _isNativeAdReady && _nativeAd != null) {
        return _buildAdMobNativeCard();
      }
      if (widget.zone == 'dating_deck') {
        return _buildDatingAdMobCard();
      }
      return _buildAdMobBanner();
    }

    if (hasInternal && hasAdMob) {
      activeAd = _showInternalAd ? buildProprietary() : buildAdMob();
    } else if (hasInternal) {
      activeAd = buildProprietary();
    } else if (hasAdMob) {
      activeAd = buildAdMob();
    }

    if (activeAd != null) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey(activeAd.runtimeType.toString() + (_showInternalAd ? '1' : '0')),
          child: activeAd,
        ),
      );
    }

    if (isLoading) {
      return const SizedBox.shrink();
    }

    // Fallback placeholder
    return _buildPlaceholder();
  }

  Widget _buildAdMobNativeCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: double.infinity,
          height: 380,
          child: AdWidget(ad: _nativeAd!),
        ),
      ),
    );
  }

  Widget _buildAdMobBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }

  Widget _buildDatingAdMobCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.surface,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Sponsorizzato da Google',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _buildAdMobBanner(),
        ],
      ),
    );
  }

  Widget _buildDatingDeckAd(AdCampaignModel ad) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image or Video
            if (ad.videoUrl != null && ad.videoUrl!.isNotEmpty)
              _AdVideoPlayer(videoUrl: ad.videoUrl!, cover: true)
            else if (ad.imageUrl.isNotEmpty)
              Image.network(
                ad.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surfaceVariant,
                  child: const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2C3E50), Color(0xFF000000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),

            // Top Badge "Sponsorizzato"
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Sponsorizzato',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // Bottom Gradient & Content Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.7],
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ad.body,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    if (ad.ctaLink.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => _handleClick(ad),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            ad.ctaText.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.zone == 'dating_deck') {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ads_click, color: AppColors.textSecondary.withOpacity(0.4), size: 48),
            const SizedBox(height: 12),
            const Text(
              'Contenuto Sponsorizzato',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      height: widget.adSize?.height.toDouble() ?? 100,
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.ads_click, color: Colors.grey[400], size: 24),
          const SizedBox(height: 4),
          Text(
            'In attesa di contenuti pubblicitari...',
            style: TextStyle(color: Colors.grey[500], fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildProprietaryAd(AdCampaignModel ad) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hasVideo = ad.videoUrl != null && ad.videoUrl!.isNotEmpty;

    if (hasVideo) {
      // Instagram-style video ad!
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with advertiser profile style
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: const Icon(Icons.campaign, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ad.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Sponsorizzato',
                          style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Video Player
            ClipRect(
              child: _AdVideoPlayer(videoUrl: ad.videoUrl!),
            ),

            // Text copy below
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                ad.body,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                  fontSize: 14,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // CTA Button Bar
            if (ad.ctaLink.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _handleClick(ad),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ad.ctaText.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.open_in_new, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
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

class _AdVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool cover;
  
  const _AdVideoPlayer({
    required this.videoUrl,
    this.cover = false,
  });

  @override
  State<_AdVideoPlayer> createState() => _AdVideoPlayerState();
}

class _AdVideoPlayerState extends State<_AdVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _playing = true; // Auto-play by default for ads

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      })
      ..setLooping(true)
      ..setVolume(0); // Muted by default like Instagram/Tinder ads
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_playing) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() => _playing = !_playing);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        color: Colors.black12,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    Widget videoWidget = VideoPlayer(_controller);

    if (widget.cover) {
      videoWidget = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      );
    } else {
      videoWidget = AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      );
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          videoWidget,
          if (!_playing)
            Container(
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
            ),
          Positioned(
            bottom: 12,
            right: 12,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _controller.setVolume(_controller.value.volume == 0 ? 1 : 0);
                });
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(6),
                child: Icon(
                  _controller.value.volume == 0 ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
