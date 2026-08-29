import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/reel_service.dart';
import '../../../../shared/models/reel_model.dart';
import '../../../../shared/models/ad_campaign_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../ads/presentation/widgets/unified_ad_card.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/utils/share_content_helper.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../../core/constants/ad_constants.dart';
import '../../../../core/providers/ad_readiness_provider.dart';

/// Full-screen vertical Reels viewer (TikTok/Instagram Reels style)
class ReelsScreen extends ConsumerStatefulWidget {
  final bool embedded;
  final List<ReelModel>? initialReels;
  final int initialIndex;
  const ReelsScreen({
    super.key,
    this.embedded = false,
    this.initialReels,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> with AutomaticKeepAliveClientMixin {
  late final PageController _pageController;
  late int _currentPage;
  late final Stream<List<ReelModel>> _reelsStream;
  AdCampaignModel? _reelsAd;
  NativeAd? _adMobNativeAd;
  bool _isAdMobNativeAdLoaded = false;
  bool _adMobAdLoadedAttempted = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _reelsStream = ref.read(reelServiceProvider).getReelsFeed();
    _loadReelsAd();
  }

  void _maybeLoadAdMobNativeAd() {
    if (_adMobAdLoadedAttempted || !mounted) return;

    final isReady = ref.read(adMobReadyProvider);
    final activeTab = ref.read(activeTabProvider);
    final isTabActive = !widget.embedded || activeTab == 0;

    if (isReady && isTabActive) {
      _adMobAdLoadedAttempted = true;
      debugPrint('📢 ReelsScreen: Loading AdMob NativeAd (SDK ready, tab active)');
      _loadAdMobNativeAd();
    }
  }

  Future<void> _loadReelsAd() async {
    try {
      final profile = ref.read(currentUserProfileProvider).value;
      final ad = await ref.read(adServiceProvider).fetchNativeAd(
        'reels_feed',
        userCity: profile?.city,
        userRegion: profile?.region,
        userLatitude: profile?.homeLatitude,
        userLongitude: profile?.homeLongitude,
      );
      if (ad != null && ad.videoUrl != null && ad.videoUrl!.isNotEmpty) {
        if (mounted) {
          setState(() {
            _reelsAd = ad;
          });
        }
      }
    } catch (_) {}
  }

  void _loadAdMobNativeAd() {
    _adMobNativeAd = NativeAd(
      adUnitId: AdConstants.nativeAdUnitId,
      factoryId: 'reelsNativeAd',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ ReelsScreen: AdMob NativeAd loaded successfully');
          if (mounted) {
            setState(() {
              _isAdMobNativeAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ ReelsScreen: AdMob NativeAd failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _adMobNativeAd = null;
              _isAdMobNativeAdLoaded = false;
            });
          }
        },
        onAdImpression: (ad) {
          debugPrint('👁️ ReelsScreen: AdMob NativeAd impression recorded');
        },
      ),
    );
    _adMobNativeAd!.load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _adMobNativeAd?.dispose();
    super.dispose();
  }

  Widget _buildReelsList(List<ReelModel> reels) {
    final items = <dynamic>[...reels];
    
    final List<dynamic> loadedAds = [];
    if (_reelsAd != null) {
      loadedAds.add(_reelsAd);
    }
    if (_isAdMobNativeAdLoaded && _adMobNativeAd != null) {
      loadedAds.add(_adMobNativeAd);
    }

    if (loadedAds.isNotEmpty) {
      int insertIndex = 4;
      int adCursor = 0;
      while (insertIndex < items.length) {
        final adToInsert = loadedAds[adCursor % loadedAds.length];
        items.insert(insertIndex, adToInsert);
        adCursor++;
        insertIndex += 5;
      }
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: items.length,
          onPageChanged: (i) => setState(() => _currentPage = i),
          itemBuilder: (context, index) {
            final item = items[index];
            if (item is AdCampaignModel) {
              return _ReelAdPlayer(
                ad: item,
                isActive: index == _currentPage,
              );
            } else if (item is NativeAd) {
              return _ReelAdMobPlayer(
                ad: item,
                isActive: index == _currentPage,
              );
            }
            return _ReelPlayer(
              reel: item as ReelModel,
              isActive: index == _currentPage,
            );
          },
        ),
        // Upload FAB — prominent, bottom-right
        if (widget.embedded)
          Positioned(
            bottom: 24,
            right: 16,
            child: GestureDetector(
              onTap: () => _showUploadSheet(context),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.videocam, color: Colors.white, size: 28),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    ref.listen(adMobReadyProvider, (prev, next) {
      if (next) _maybeLoadAdMobNativeAd();
    });
    ref.listen(activeTabProvider, (prev, next) {
      if (next == 0) _maybeLoadAdMobNativeAd();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeLoadAdMobNativeAd();
    });

    if (widget.initialReels != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: widget.embedded
            ? null
            : AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: const Text('Reels', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                leading: widget.embedded ? null : const BackButton(color: Colors.white),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.videocam_outlined, color: Colors.white, size: 28),
                    onPressed: () => _showUploadSheet(context),
                  ),
                ],
              ),
        body: _buildReelsList(widget.initialReels!),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('Reels', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.videocam_outlined, color: Colors.white, size: 28),
                  onPressed: () => _showUploadSheet(context),
                ),
              ],
            ),
      body: StreamBuilder<List<ReelModel>>(
        stream: _reelsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          final reels = snapshot.data ?? [];
          if (reels.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam_off_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Nessun reel ancora', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showUploadSheet(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Crea il primo reel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ],
              ),
            );
          }

          return _buildReelsList(reels);
        },
      ),
    );
  }

  void _showUploadSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _UploadReelSheet(),
    );
  }
}

/// Individual reel player with video, overlay info, and actions
class _ReelPlayer extends ConsumerStatefulWidget {
  final ReelModel reel;
  final bool isActive;

  const _ReelPlayer({required this.reel, required this.isActive});

  @override
  ConsumerState<_ReelPlayer> createState() => _ReelPlayerState();
}

class _ReelPlayerState extends ConsumerState<_ReelPlayer> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _paused = false;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.reel.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.setLooping(true);
          _updatePlaybackState();
          if (widget.isActive) {
            ref.read(reelServiceProvider).incrementView(widget.reel.id);
          }
        }
      });
  }

  @override
  void didUpdateWidget(covariant _ReelPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      _updatePlaybackState();
      if (widget.isActive) {
        ref.read(reelServiceProvider).incrementView(widget.reel.id);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      _updatePlaybackState();
    }
  }

  void _updatePlaybackState({int? activeTab, int? communityTab, bool? isMuted}) {
    if (!_initialized || !mounted) return;

    final currentActiveTab = activeTab ?? ref.read(activeTabProvider);
    final currentCommunityTab = communityTab ?? ref.read(communityTabProvider);
    final bool currentMuted = isMuted ?? ref.read(reelsMutedProvider);

    final isVisible = widget.isActive &&
                      currentActiveTab == 0 &&
                      currentCommunityTab == 1;

    _controller.setVolume(currentMuted ? 0.0 : 1.0);

    if (isVisible) {
      if (!_paused) {
        _controller.play();
      } else {
        _controller.pause();
      }
    } else {
      _controller.pause();
    }
  }

  void _togglePlay() {
    setState(() {
      _paused = !_paused;
      _paused ? _controller.pause() : _controller.play();
    });
  }

  void _doubleTapLike() {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    if (!widget.reel.isLikedBy(user.uid)) {
      ref.read(reelServiceProvider).toggleLike(widget.reel.id, user.uid);
    }
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(activeTabProvider, (prev, next) {
      _updatePlaybackState(activeTab: next);
    });
    ref.listen<int>(communityTabProvider, (prev, next) {
      _updatePlaybackState(communityTab: next);
    });
    ref.listen<bool>(reelsMutedProvider, (prev, next) {
      _updatePlaybackState(isMuted: next);
    });

    final isMuted = ref.watch(reelsMutedProvider);
    final user = ref.watch(authServiceProvider).currentUser;
    final isLiked = user != null ? widget.reel.isLikedBy(user.uid) : false;
    final isOwner = user != null && user.uid == widget.reel.authorId;

    return GestureDetector(
      onTap: _togglePlay,
      onDoubleTap: _doubleTapLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          if (_initialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),

          // Pause icon
          if (_paused)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
              ),
            ),

          // Double-tap heart
          if (_showHeart)
            const Center(
              child: Icon(Icons.favorite, size: 100, color: Colors.white),
            ),

          // Right action bar
          Positioned(
            right: 12,
            bottom: 100,
            child: Column(
              children: [
                // Like (Icon + Text separate tap actions)
                Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (user != null) ref.read(reelServiceProvider).toggleLike(widget.reel.id, user.uid);
                      },
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () => _showLikers(context, ref, widget.reel.likes),
                      child: Text(
                        '${widget.reel.likeCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Views
                _ActionButton(
                  icon: Icons.remove_red_eye_outlined,
                  label: '${widget.reel.viewCount}',
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                // Mute/Unmute
                _ActionButton(
                  icon: isMuted ? Icons.volume_off : Icons.volume_up,
                  label: '',
                  onTap: () {
                    ref.read(reelsMutedProvider.notifier).state = !isMuted;
                  },
                ),
                const SizedBox(height: 20),
                // Comments
                _ActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: '${widget.reel.commentCount}',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Commenti ai reel in arrivo!'), duration: Duration(seconds: 2)),
                    );
                  },
                ),
                const SizedBox(height: 20),
                // Share / Direct
                _ActionButton(
                  icon: Icons.send,
                  label: '',
                  onTap: () async {
                    if (user == null || widget.reel.authorId == user.uid) return;
                    final chatId = await ref.read(chatControllerProvider.notifier).createChat(widget.reel.authorId);
                    if (chatId != null && context.mounted) {
                      final otherUser = await ref.read(userServiceProvider).getUserById(widget.reel.authorId);
                      if (otherUser != null && context.mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId, otherUser: otherUser)));
                      }
                    }
                  },
                ),
                const SizedBox(height: 20),
                // Share
                _ActionButton(
                  icon: Icons.ios_share,
                  label: '',
                  onTap: () => ShareContentHelper.shareReel(
                    context: context,
                    videoUrl: widget.reel.videoUrl,
                    authorName: widget.reel.authorName,
                    caption: widget.reel.caption,
                  ),
                ),
                const SizedBox(height: 20),
                // Delete (owner only)
                if (isOwner)
                  _ActionButton(
                    icon: Icons.delete_outline,
                    label: '',
                    color: Colors.red.shade300,
                    onTap: () => _confirmDelete(context),
                  ),
              ],
            ),
          ),

          // Bottom info overlay
          Positioned(
            left: 12,
            right: 80,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.reel.authorId)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white24,
                        backgroundImage: widget.reel.authorPhotoUrl != null
                            ? NetworkImage(widget.reel.authorPhotoUrl!)
                            : null,
                        child: widget.reel.authorPhotoUrl == null
                            ? Text(
                                widget.reel.authorName.isNotEmpty ? widget.reel.authorName[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.reel.authorName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (widget.reel.caption != null && widget.reel.caption!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.reel.caption!,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Progress bar at bottom
          if (_initialized)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }

  void _showLikers(BuildContext context, WidgetRef ref, List<String> likerIds) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Piace a', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black)),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: likerIds.isEmpty
                  ? const Center(child: Text('Nessun like ancora', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: likerIds.length,
                      itemBuilder: (context, index) {
                        final uid = likerIds[index];
                        return FutureBuilder<UserModel?>(
                          future: ref.read(userServiceProvider).getUserById(uid),
                          builder: (context, snap) {
                            final user = snap.data;
                            if (user == null) {
                              return const ListTile(
                                leading: CircleAvatar(backgroundColor: Colors.grey, radius: 20),
                                title: Text('...'),
                              );
                            }
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                                backgroundColor: AppColors.surfaceVariant,
                                child: user.photoUrl == null
                                    ? Text(
                                        user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
                                      )
                                    : null,
                              ),
                              title: Text(
                                '${user.firstName} ${user.lastName}'.trim(),
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
                              ),
                              subtitle: user.zone.isNotEmpty
                                  ? Text(
                                      user.zone,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    )
                                  : null,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ProfileScreen(userId: uid)),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Reel'),
        content: const Text('Sei sicuro di voler eliminare questo reel?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(reelServiceProvider).deleteReel(widget.reel.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

/// Action button on the right side of the reel
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.color = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

/// Upload reel bottom sheet
class _UploadReelSheet extends ConsumerStatefulWidget {
  const _UploadReelSheet();

  @override
  ConsumerState<_UploadReelSheet> createState() => _UploadReelSheetState();
}

class _UploadReelSheetState extends ConsumerState<_UploadReelSheet> {
  File? _videoFile;
  final _captionController = TextEditingController();
  bool _isUploading = false;
  String? _error;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 60),
    );
    if (picked != null) {
      setState(() {
        _videoFile = File(picked.path);
        _error = null;
      });
    }
  }

  Future<void> _upload() async {
    if (_videoFile == null) return;

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final profile = ref.read(currentUserProfileProvider).value;
    final reelService = ref.read(reelServiceProvider);

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      // Check daily limit
      final isPremium = profile?.isPremium ?? false;
      final canUpload = await reelService.canUploadReel(user.uid, isPremium);
      if (!canUpload) {
        setState(() {
          _error = 'Hai raggiunto il limite giornaliero. Passa a Premium per reel illimitati!';
          _isUploading = false;
        });
        return;
      }

      final displayName = profile != null
          ? '${profile.firstName} ${profile.lastName}'.trim()
          : (user.displayName ?? 'Utente');

      final reel = ReelModel(
        id: '',
        authorId: user.uid,
        authorName: displayName,
        authorPhotoUrl: profile?.photoUrl ?? user.photoURL,
        videoUrl: '',
        caption: _captionController.text.trim().isNotEmpty ? _captionController.text.trim() : null,
        createdAt: DateTime.now(),
      );

      await reelService.createReel(reel, _videoFile!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Reel caricato! Sarà visibile dopo la revisione AI 🛡️')),
              ],
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Errore durante il caricamento: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Nuovo Reel', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Max 60 secondi', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 20),

              // Video picker
              if (_videoFile != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Video selezionato',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green.shade700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() => _videoFile = null),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _PickerButton(
                        icon: Icons.video_library,
                        label: 'Galleria',
                        onTap: () => _pickVideo(ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickerButton(
                        icon: Icons.videocam,
                        label: 'Registra',
                        onTap: () => _pickVideo(ImageSource.camera),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Caption
              TextField(
                controller: _captionController,
                maxLines: 2,
                maxLength: 150,
                decoration: InputDecoration(
                  hintText: 'Aggiungi una descrizione...',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],

              const SizedBox(height: 20),

              // Upload button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isUploading || _videoFile == null) ? null : _upload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: _isUploading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Pubblica Reel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.accent),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _ReelAdPlayer extends ConsumerStatefulWidget {
  final AdCampaignModel ad;
  final bool isActive;

  const _ReelAdPlayer({required this.ad, required this.isActive});

  @override
  ConsumerState<_ReelAdPlayer> createState() => _ReelAdPlayerState();
}

class _ReelAdPlayerState extends ConsumerState<_ReelAdPlayer> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.ad.videoUrl!))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.setLooping(true);
          _updatePlaybackState();
          if (widget.isActive) {
            ref.read(adServiceProvider).recordImpression(widget.ad.id);
          }
        }
      });
  }

  @override
  void didUpdateWidget(covariant _ReelAdPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      _updatePlaybackState();
      if (widget.isActive) {
        ref.read(adServiceProvider).recordImpression(widget.ad.id);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      _updatePlaybackState();
    }
  }

  void _updatePlaybackState({int? activeTab, int? communityTab, bool? isMuted}) {
    if (!_initialized || !mounted) return;

    final currentActiveTab = activeTab ?? ref.read(activeTabProvider);
    final currentCommunityTab = communityTab ?? ref.read(communityTabProvider);
    final bool currentMuted = isMuted ?? ref.read(reelsMutedProvider);

    final isVisible = widget.isActive &&
                      currentActiveTab == 0 &&
                      currentCommunityTab == 1;

    _controller.setVolume(currentMuted ? 0.0 : 1.0);

    if (isVisible) {
      if (!_paused) {
        _controller.play();
      } else {
        _controller.pause();
      }
    } else {
      _controller.pause();
    }
  }

  void _togglePlay() {
    setState(() {
      _paused = !_paused;
      _paused ? _controller.pause() : _controller.play();
    });
  }

  Future<void> _handleCtaTap() async {
    ref.read(adServiceProvider).recordClick(widget.ad.id);
    final link = widget.ad.ctaLink;
    if (link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(activeTabProvider, (prev, next) {
      _updatePlaybackState(activeTab: next);
    });
    ref.listen<int>(communityTabProvider, (prev, next) {
      _updatePlaybackState(communityTab: next);
    });
    ref.listen<bool>(reelsMutedProvider, (prev, next) {
      _updatePlaybackState(isMuted: next);
    });

    final isMuted = ref.watch(reelsMutedProvider);

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player
          if (_initialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),

          // Floating Mute Button for Ad
          Positioned(
            right: 16,
            top: 50,
            child: GestureDetector(
              onTap: () {
                ref.read(reelsMutedProvider.notifier).state = !isMuted;
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          // Pause Overlay Icon
          if (_paused)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
              ),
            ),

          // Bottom Info Overlay
          Positioned(
            left: 12,
            right: 12,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Business/Sponsor Name & Badge
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white24,
                      backgroundImage: widget.ad.imageUrl.isNotEmpty
                          ? NetworkImage(widget.ad.imageUrl)
                          : null,
                      child: widget.ad.imageUrl.isEmpty
                          ? const Icon(Icons.business, color: Colors.white, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.ad.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Sponsorizzato',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.ad.body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.ad.body,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                
                // CTA Action Button (Immersive style)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _handleCtaTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.ad.ctaText.isNotEmpty ? widget.ad.ctaText : 'Scopri di più',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.open_in_new, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progress indicator at the bottom
          if (_initialized)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.accent,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}

class _ReelAdMobPlayer extends StatelessWidget {
  final NativeAd ad;
  final bool isActive;

  const _ReelAdMobPlayer({required this.ad, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AdWidget(ad: ad),
    );
  }
}
