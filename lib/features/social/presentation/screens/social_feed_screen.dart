import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import '../../../../core/services/social_feed_service.dart';
import '../../../../core/services/reel_service.dart';
import '../../../../core/services/blog_service.dart';
import '../../../../core/services/user_service.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/social_post_model.dart';
import '../../../../shared/models/reel_model.dart';
import '../../../../shared/models/blog_article_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../../shared/utils/share_content_helper.dart';
import '../../../ads/presentation/widgets/unified_ad_card.dart';
import '../widgets/blog_feed_card.dart';

/// Unified feed item wrapper for mixed post+reel feed
enum FeedItemType { post, reel, ad, blog }

class FeedItem {
  final FeedItemType type;
  final SocialPostModel? post;
  final ReelModel? reel;
  final BlogArticleModel? blogArticle;
  final DateTime createdAt;

  FeedItem.fromPost(SocialPostModel p)
      : type = FeedItemType.post, post = p, reel = null, blogArticle = null, createdAt = p.createdAt;
  FeedItem.fromReel(ReelModel r)
      : type = FeedItemType.reel, post = null, reel = r, blogArticle = null, createdAt = r.createdAt;
  FeedItem.fromAd(DateTime date)
      : type = FeedItemType.ad, post = null, reel = null, blogArticle = null, createdAt = date;
  FeedItem.fromBlog(BlogArticleModel b, DateTime date)
      : type = FeedItemType.blog, post = null, reel = null, blogArticle = b, createdAt = date;
}

class SocialFeedScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const SocialFeedScreen({super.key, this.embedded = false});

  @override
  ConsumerState<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends ConsumerState<SocialFeedScreen> {
  @override
  Widget build(BuildContext context) {
    final feedService = ref.watch(socialFeedServiceProvider);
    final reelService = ref.watch(reelServiceProvider);
    final blogService = ref.watch(blogServiceProvider);

    final body = StreamBuilder<List<FeedItem>>(
      stream: _combinedFeedStream(feedService, reelService, blogService),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyFeed();
        }

        final items = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {}); // Trigger rebuild
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item.type == FeedItemType.ad) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: UnifiedAdCard(zone: 'social_feed'),
                );
              }
              if (item.type == FeedItemType.blog) {
                return BlogFeedCard(article: item.blogArticle!);
              }
              if (item.type == FeedItemType.reel) {
                return _ReelFeedCard(reel: item.reel!);
              }
              return PostCard(post: item.post!);
            },
          ),
        );
      },
    );

    final fab = FloatingActionButton(
      heroTag: 'social_feed_fab',
      onPressed: () => _showCreatePostSheet(context),
      backgroundColor: AppColors.accent,
      child: const Icon(Icons.camera_alt, color: Colors.white),
    );

    if (widget.embedded) {
      return Scaffold(
        body: body,
        floatingActionButton: fab,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: () => _showCreatePostSheet(context),
          ),
        ],
      ),
      body: body,
      floatingActionButton: fab,
    );
  }

  Widget _buildEmptyFeed() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withOpacity(0.1),
            ),
            child: const Icon(Icons.photo_camera, size: 48, color: AppColors.accent),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nessun post ancora',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sii il primo a condividere\nun momento con il tuo pet! 🐾',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Crea un post'),
            onPressed: () => _showCreatePostSheet(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  /// Combines posts, reels, and blog articles into a single mixed feed sorted by date
  Stream<List<FeedItem>> _combinedFeedStream(SocialFeedService feedService, ReelService reelService, BlogService blogService) {
    List<FeedItem> latestPosts = [];
    List<FeedItem> latestReels = [];
    List<BlogArticleModel> blogArticles = [];
    final controller = StreamController<List<FeedItem>>.broadcast();

    void emit() {
      final combined = [...latestPosts, ...latestReels];
      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      final List<FeedItem> mixed = [];
      int organicSinceLastAd = 0;
      int organicSinceLastBlog = 0;
      int blogIndex = 0;
      for (int i = 0; i < combined.length; i++) {
        mixed.add(combined[i]);
        organicSinceLastAd++;
        organicSinceLastBlog++;

        // Insert ad after 1st item, then every 5 organic items
        if (i == 0 || organicSinceLastAd == 5) {
          DateTime adTime;
          if (i < combined.length - 1) {
            final current = combined[i].createdAt;
            final next = combined[i + 1].createdAt;
            adTime = current.subtract(Duration(milliseconds: current.difference(next).inMilliseconds ~/ 2));
          } else {
            adTime = combined[i].createdAt.subtract(const Duration(seconds: 1));
          }
          mixed.add(FeedItem.fromAd(adTime));
          organicSinceLastAd = 0;
        }
        // Insert blog article every 8 organic items (offset from ads)
        else if (organicSinceLastBlog >= 8 && blogArticles.isNotEmpty) {
          final article = blogArticles[blogIndex % blogArticles.length];
          final blogTime = combined[i].createdAt.subtract(const Duration(milliseconds: 500));
          mixed.add(FeedItem.fromBlog(article, blogTime));
          blogIndex++;
          organicSinceLastBlog = 0;
        }
      }
      controller.add(mixed);
    }

    // Fetch blog articles once
    blogService.getArticles().then((articles) {
      blogArticles = articles;
      emit();
    });

    final sub1 = feedService.getFeedStream().listen((posts) {
      latestPosts = posts.map((p) => FeedItem.fromPost(p)).toList();
      emit();
    });

    final sub2 = reelService.getReelsFeed().listen((reels) {
      latestReels = reels.map((r) => FeedItem.fromReel(r)).toList();
      emit();
    });

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
      controller.close();
    };

    return controller.stream;
  }

  void _showCreatePostSheet(BuildContext context) {
    showCreatePostSheet(context);
  }
}

/// Reel card displayed inline in the unified "Per te" feed
class _ReelFeedCard extends ConsumerStatefulWidget {
  final ReelModel reel;
  const _ReelFeedCard({required this.reel});

  @override
  ConsumerState<_ReelFeedCard> createState() => _ReelFeedCardState();
}

class _ReelFeedCardState extends ConsumerState<_ReelFeedCard> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.reel.videoUrl))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      })
      ..setLooping(true)
      ..setVolume(0); // Muted by default in feed
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
      _controller.setVolume(1);
    }
    setState(() => _playing = !_playing);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    final reel = widget.reel;
    final isLiked = user != null && reel.likes.contains(user.uid);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AUTHOR HEADER
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: reel.authorId))),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    backgroundImage: reel.authorPhotoUrl != null ? NetworkImage(reel.authorPhotoUrl!) : null,
                    child: reel.authorPhotoUrl == null
                        ? Text(reel.authorName.isNotEmpty ? reel.authorName[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent))
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: reel.authorId))),
                    child: Row(
                      children: [
                        Flexible(child: Text(reel.authorName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Reel', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // VIDEO PLAYER
          GestureDetector(
            onTap: _togglePlay,
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_initialized)
                    ClipRRect(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: Colors.black,
                      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                    ),
                  // Play/Pause overlay
                  if (!_playing)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                    ),
                ],
              ),
            ),
          ),

          // ACTION BUTTONS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 24, color: isLiked ? Colors.red : null),
                  onPressed: () {
                    if (user != null) ref.read(reelServiceProvider).toggleLike(reel.id, user.uid);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, size: 24),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Commenti ai reel in arrivo!'), duration: Duration(seconds: 2)),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.send_outlined, size: 24),
                  onPressed: () async {
                    if (user == null || reel.authorId == user.uid) return;
                    final chatId = await ref.read(chatControllerProvider.notifier).createChat(reel.authorId);
                    if (chatId != null && context.mounted) {
                      final otherUser = await ref.read(userServiceProvider).getUserById(reel.authorId);
                      if (otherUser != null && context.mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId, otherUser: otherUser)));
                      }
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.ios_share, size: 22),
                  onPressed: () => ShareContentHelper.shareReel(
                    context: context,
                    videoUrl: reel.videoUrl,
                    authorName: reel.authorName,
                    caption: reel.caption,
                  ),
                ),
                const Spacer(),
                _BookmarkButton(postId: reel.id),
              ],
            ),
          ),

          // LIKES
          if (reel.likeCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('${reel.likeCount} Mi piace', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),

          // CAPTION
          if (reel.caption != null && reel.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: RichText(
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(text: '${reel.authorName} ', style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: reel.caption!),
                  ],
                ),
              ),
            ),

          // TIMESTAMP
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Text(timeago.format(reel.createdAt, locale: 'it'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ),
        ],
      ),
    );
  }
}

/// Public function to show create post sheet from anywhere
void showCreatePostSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _CreatePostSheet(),
  );
}

class _CreatePostSheet extends ConsumerStatefulWidget {
  const _CreatePostSheet();

  @override
  ConsumerState<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<_CreatePostSheet> {
  final _textController = TextEditingController();
  File? _selectedImage;
  File? _selectedVideo;
  bool _isPosting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1080, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _selectedVideo = null; // Clear video
      });
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 30),
    );
    if (picked != null) {
      setState(() {
        _selectedVideo = File(picked.path);
        _selectedImage = null; // Clear image
      });
    }
  }

  Future<void> _submitPost() async {
    if (_textController.text.trim().isEmpty && _selectedImage == null && _selectedVideo == null) return;

    setState(() => _isPosting = true);

    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;

      final profile = ref.read(currentUserProfileProvider).value;

      final displayName = profile != null
          ? '${profile.firstName} ${profile.lastName}'.trim()
          : (user.displayName ?? 'Utente');

      final post = SocialPostModel(
        id: '',
        authorId: user.uid,
        authorName: displayName,
        authorPhotoUrl: profile?.photoUrl ?? user.photoURL,
        text: _textController.text.trim().isNotEmpty ? _textController.text.trim() : null,
        type: _selectedVideo != null ? PostType.video : PostType.photo,
        createdAt: DateTime.now(),
      );

      await ref.read(socialFeedServiceProvider).createPost(
        post, 
        imageFile: _selectedImage,
        videoFile: _selectedVideo,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Nuovo Post',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Text field
              TextField(
                controller: _textController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Racconta la tua avventura con il tuo pet...',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.accent, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),

              // Image preview or picker
              // Media preview or picker
              if (_selectedImage != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        _selectedImage!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImage = null),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                )
              else if (_selectedVideo != null)
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam, color: Colors.white, size: 48),
                            SizedBox(height: 8),
                            Text(
                              'Video Selezionato',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedVideo = null),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aggiungi un contenuto multimediale:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ImagePickerButton(
                            icon: Icons.photo_library,
                            label: 'Foto Galleria',
                            onTap: () => _pickImage(ImageSource.gallery),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ImagePickerButton(
                            icon: Icons.video_library,
                            label: 'Video Galleria',
                            onTap: () => _pickVideo(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ImagePickerButton(
                            icon: Icons.camera_alt,
                            label: 'Scatta Foto',
                            onTap: () => _pickImage(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ImagePickerButton(
                            icon: Icons.videocam,
                            label: 'Registra Video',
                            onTap: () => _pickVideo(ImageSource.camera),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Specifiche del contenuto
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 20, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Caratteristiche del video:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '• Formato supportato: MP4, MOV\n'
                                  '• Durata massima: 30 secondi\n'
                                  '• Risoluzione ideale: 1080p (FHD)\n'
                                  '• Dimensione massima: 15 MB\n'
                                  '• Proporzioni: 1:1 (quadrato) o 9:16 (verticale)',
                                  style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // Post button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isPosting ? null : _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                  child: _isPosting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Pubblica',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
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

class _ImagePickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImagePickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppColors.accent),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PostCard extends ConsumerStatefulWidget {
  final SocialPostModel post;
  const PostCard({required this.post});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> with SingleTickerProviderStateMixin {
  bool _showHeart = false;
  late AnimationController _heartAnimController;
  late Animation<double> _heartScale;

  SocialPostModel get post => widget.post;

  @override
  void initState() {
    super.initState();
    _heartAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _heartScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _heartAnimController, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _heartAnimController.dispose();
    super.dispose();
  }

  void _doubleTapLike() {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    if (!post.isLikedBy(user.uid)) {
      ref.read(socialFeedServiceProvider).toggleLike(post.id, user.uid);
    }
    setState(() => _showHeart = true);
    _heartAnimController.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _showHeart = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    final isLiked = user != null ? post.isLikedBy(user.uid) : false;
    final isOwner = user != null && user.uid == post.authorId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => openAuthorProfile(context, ref, post.authorId),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [AppColors.accent, AppColors.primary]),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    backgroundImage: post.authorPhotoUrl != null ? NetworkImage(post.authorPhotoUrl!) : null,
                    child: post.authorPhotoUrl == null
                        ? Text(post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent))
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => openAuthorProfile(context, ref, post.authorId),
                  child: Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'delete') _confirmDelete(context, ref);
                  else if (v == 'report') _showReportDialog(context, ref);
                },
                itemBuilder: (_) => [
                  if (isOwner) const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 20), SizedBox(width: 8), Text('Elimina', style: TextStyle(color: Colors.red))])),
                  if (!isOwner) const PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag_outlined, color: Colors.orange, size: 20), SizedBox(width: 8), Text('Segnala')])),
                ],
              ),
            ],
          ),
        ),

        // MEDIA (Image or Video)
        if (post.imageUrl != null)
          GestureDetector(
            onDoubleTap: _doubleTapLike,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (post.type == PostType.video)
                  _PostVideoPlayer(videoUrl: post.imageUrl!)
                else
                  Image.network(
                    post.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: Colors.grey[100],
                      child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                if (_showHeart)
                  ScaleTransition(
                    scale: _heartScale,
                    child: const Icon(Icons.favorite, size: 80, color: Colors.white),
                  ),
              ],
            ),
          ),

        // ACTIONS BAR (Instagram-style)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : null, size: 26),
                onPressed: () { if (user != null) ref.read(socialFeedServiceProvider).toggleLike(post.id, user.uid); },
              ),
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, size: 24),
                onPressed: () => showComments(context, ref, post.id),
              ),
              IconButton(
                icon: const Icon(Icons.send_outlined, size: 24),
                onPressed: () async {
                  if (user == null || post.authorId == user.uid) return;
                  final chatId = await ref.read(chatControllerProvider.notifier).createChat(post.authorId);
                  if (chatId != null && context.mounted) {
                    final userService = ref.read(userServiceProvider);
                    final otherUser = await userService.getUserById(post.authorId);
                    if (otherUser != null && context.mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId, otherUser: otherUser)));
                    }
                  }
                },
              ),
              if (post.imageUrl != null)
                IconButton(
                  icon: const Icon(Icons.ios_share, size: 22),
                  onPressed: () => ShareContentHelper.sharePost(
                    context: context,
                    imageUrl: post.imageUrl!,
                    authorName: post.authorName,
                    caption: post.text,
                  ),
                ),
              const Spacer(),
              _BookmarkButton(postId: post.id),
            ],
          ),
        ),

        // LIKES COUNT — tappable to show who liked
        if (post.likeCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: GestureDetector(
              onTap: () => _showLikers(context, ref, post.likes),
              child: Text('${post.likeCount} Mi piace', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),

        // CAPTION (bold name + text)
        if (post.text != null && post.text!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: RichText(
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14, height: 1.3),
                children: [
                  TextSpan(text: '${post.authorName} ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: post.text!),
                ],
              ),
            ),
          ),

        // COMMENTS PREVIEW
        if (post.commentCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: GestureDetector(
              onTap: () => showComments(context, ref, post.id),
              child: Text(
                'Vedi tutti i ${post.commentCount} commenti',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ),

        // TIMESTAMP
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          child: Text(_formatTimeAgo(post.createdAt), style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        ),

        // Separator
        Divider(height: 1, color: Colors.grey.shade200),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Elimina post'),
        content: const Text('Sei sicuro di voler eliminare questo post? L\'azione è irreversibile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(socialFeedServiceProvider).deletePost(post.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post eliminato')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Errore: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context, WidgetRef ref) {
    String? selectedReason;
    final detailsController = TextEditingController();

    final reasons = [
      'Contenuto inappropriato',
      'Spam o pubblicità',
      'Molestie o bullismo',
      'Violenza',
      'Maltrattamento animali',
      'Altro',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.flag, color: Colors.orange),
              SizedBox(width: 8),
              Text('Segnala post'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Perché vuoi segnalare questo post?'),
                const SizedBox(height: 12),
                ...reasons.map((reason) => RadioListTile<String>(
                  title: Text(reason, style: const TextStyle(fontSize: 14)),
                  value: reason,
                  groupValue: selectedReason,
                  dense: true,
                  onChanged: (val) => setState(() => selectedReason = val),
                  activeColor: AppColors.accent,
                )),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Dettagli aggiuntivi (opzionale)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      try {
                        final user = ref.read(authServiceProvider).currentUser;
                        if (user == null) return;
                        final profile = ref.read(currentUserProfileProvider).value;
                        final name = profile != null
                            ? '${profile.firstName} ${profile.lastName}'.trim()
                            : (user.displayName ?? 'Utente');

                        await ref.read(socialFeedServiceProvider).reportPost(
                          postId: post.id,
                          reporterId: user.uid,
                          reporterName: name,
                          reason: selectedReason!,
                          details: detailsController.text.trim().isNotEmpty
                              ? detailsController.text.trim()
                              : null,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Segnalazione inviata. Grazie per il tuo aiuto!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Errore: $e')),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              child: const Text('Invia segnalazione'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    try {
      return timeago.format(dateTime, locale: 'it');
    } catch (_) {
      final diff = DateTime.now().difference(dateTime);
      if (diff.inMinutes < 1) return 'ora';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}g';
    }
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
            Text('Piace a', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
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
                              ? Text(user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                                  style: const TextStyle(fontWeight: FontWeight.w700))
                              : null,
                        ),
                        title: Text('${user.firstName} ${user.lastName}'.trim(), style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: user.zone.isNotEmpty ? Text(user.zone, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)) : null,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: uid)));
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
}

// =============================================================================
// Funzioni Globali Social
// =============================================================================

/// Opens the full profile screen for a post/comment author
void openAuthorProfile(BuildContext context, WidgetRef ref, String authorId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProfileScreen(userId: authorId),
    ),
  );
}

void showComments(BuildContext context, WidgetRef ref, String postId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CommentsSheet(postId: postId),
  );
}

/// Bookmark toggle button with real Firestore persistence
class _BookmarkButton extends ConsumerStatefulWidget {
  final String postId;
  const _BookmarkButton({required this.postId});

  @override
  ConsumerState<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends ConsumerState<_BookmarkButton> {
  bool _isBookmarked = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _checkBookmark();
  }

  Future<void> _checkBookmark() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    final result = await ref.read(socialFeedServiceProvider).isBookmarked(widget.postId, user.uid);
    if (mounted) setState(() { _isBookmarked = result; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    return IconButton(
      icon: Icon(
        _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
        size: 24,
        color: _isBookmarked ? AppColors.primary : null,
      ),
      onPressed: () async {
        if (user == null) return;
        setState(() => _isBookmarked = !_isBookmarked);
        await ref.read(socialFeedServiceProvider).toggleBookmark(widget.postId, user.uid);
      },
    );
  }
}

class CommentsSheet extends ConsumerStatefulWidget {
  final String postId;
  const CommentsSheet({required this.postId});

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSending = true);

    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;

      final profile = ref.read(currentUserProfileProvider).value;

      final commentDisplayName = profile != null
          ? '${profile.firstName} ${profile.lastName}'.trim()
          : (user.displayName ?? 'Utente');

      final comment = PostCommentModel(
        id: '',
        authorId: user.uid,
        authorName: commentDisplayName,
        authorPhotoUrl: profile?.photoUrl ?? user.photoURL,
        text: _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      await ref.read(socialFeedServiceProvider).addComment(widget.postId, comment);
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Commenti',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1),

          // Comments list
          Expanded(
            child: StreamBuilder<List<PostCommentModel>>(
              stream: ref.read(socialFeedServiceProvider).getCommentsStream(widget.postId),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('Nessun commento\nSii il primo! 💬', textAlign: TextAlign.center),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final comment = snapshot.data![index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => _openCommentAuthorProfile(context, comment.authorId),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.accent.withOpacity(0.2),
                              backgroundImage: comment.authorPhotoUrl != null
                                  ? NetworkImage(comment.authorPhotoUrl!)
                                  : null,
                              child: comment.authorPhotoUrl == null
                                  ? Text(
                                      comment.authorName.isNotEmpty
                                          ? comment.authorName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accent,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => _openCommentAuthorProfile(context, comment.authorId),
                                  child: Text(
                                    comment.authorName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  comment.text,
                                  style: const TextStyle(fontSize: 14, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Scrivi un commento...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: AppColors.accent),
                  onPressed: _isSending ? null : _sendComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the full profile screen for a comment author
  void _openCommentAuthorProfile(BuildContext context, String authorId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: authorId),
      ),
    );
  }
}

class _PostVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _PostVideoPlayer({required this.videoUrl});

  @override
  State<_PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<_PostVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      })
      ..setLooping(true)
      ..setVolume(0); // Muted by default like Instagram
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
    return GestureDetector(
      onTap: _togglePlay,
      child: AspectRatio(
        aspectRatio: _initialized ? _controller.value.aspectRatio : 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_initialized)
              VideoPlayer(_controller)
            else
              Container(
                color: Colors.black12,
                child: const Center(child: CircularProgressIndicator()),
              ),
            // Play/Pause icon overlay
            if (!_playing && _initialized)
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
              ),
            // Mute/unmute indicator overlay
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
      ),
    );
  }
}
