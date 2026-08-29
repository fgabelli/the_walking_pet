import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/chat_service.dart';
import '../../features/profile/presentation/providers/profile_provider.dart';
import '../../shared/models/chat_model.dart';
import '../../shared/models/user_model.dart';
import '../../core/theme/app_colors.dart';

/// Helper class for sharing social content (posts & reels) with DOGZN branding.
class ShareContentHelper {
  static const _shareText =
      'Scoperto su DOGZN 🐾 L\'app per chi ama i cani! 📲 https://dogzn.com';

  // ---------------------------------------------------------------------------
  // PUBLIC API
  // ---------------------------------------------------------------------------

  /// Share a post image with a watermark overlay (🐾 DOGZN + @username).
  static Future<void> sharePost({
    required BuildContext context,
    required String imageUrl,
    required String authorName,
    String? caption,
  }) async {
    final loading = _LoadingOverlay(context);
    try {
      loading.show('Preparazione immagine…');

      // 1. Download the original image
      final imageBytes = await _downloadFile(imageUrl);

      // 2. Decode to ui.Image
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      final originalImage = frame.image;

      // 3. Draw watermark overlay using Canvas
      final watermarkedBytes =
          await _addWatermarkToImage(originalImage, authorName);
      originalImage.dispose();

      // 4. Save to temp file
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/dogzn_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(watermarkedBytes);

      // 5. Dismiss loading
      loading.dismiss();
      await Future.delayed(const Duration(milliseconds: 200));

      // 6. Show custom share sheet
      final shareText = caption != null && caption.isNotEmpty
          ? '$caption\n\n$_shareText'
          : _shareText;

      if (context.mounted) {
        _showShareSheet(context, file.path, shareText);
      }
    } catch (e) {
      loading.dismiss();
      if (context.mounted) {
        _showError(context, 'Impossibile condividere il post: $e');
      }
    }
  }

  /// Share a reel video after cloud-side watermarking.
  static Future<void> shareReel({
    required BuildContext context,
    required String videoUrl,
    required String authorName,
    String? caption,
  }) async {
    final loading = _LoadingOverlay(context);
    try {
      loading.show('Preparazione video…\nPotrebbe richiedere qualche secondo');

      // 1. Call Cloud Function to watermark the video
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('watermarkVideo');

      final result = await callable.call<Map<String, dynamic>>({
        'videoUrl': videoUrl,
        'username': authorName,
        'type': 'reel',
      });

      final watermarkedUrl = result.data['downloadUrl'] as String?;
      if (watermarkedUrl == null || watermarkedUrl.isEmpty) {
        throw Exception('URL video watermarked non ricevuto');
      }

      // 2. Download watermarked video
      final videoBytes = await _downloadFile(watermarkedUrl);

      // 3. Save to temp file
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/dogzn_reel_${DateTime.now().millisecondsSinceEpoch}.mp4');
      await file.writeAsBytes(videoBytes);

      // 4. Dismiss loading
      loading.dismiss();
      await Future.delayed(const Duration(milliseconds: 200));

      // 5. Show custom share sheet
      final shareText = caption != null && caption.isNotEmpty
          ? '$caption\n\n$_shareText'
          : _shareText;

      if (context.mounted) {
        _showShareSheet(context, file.path, shareText);
      }
    } catch (e) {
      loading.dismiss();
      if (context.mounted) {
        _showError(context, 'Impossibile condividere il reel: $e');
      }
    }
  }

  /// Share a local image file (e.g. walk card screenshot) without watermarking.
  static Future<void> shareLocalImage({
    required BuildContext context,
    required File imageFile,
    String? caption,
  }) async {
    try {
      final shareText = caption != null && caption.isNotEmpty
          ? '$caption\n\n$_shareText'
          : _shareText;

      if (context.mounted) {
        _showShareSheet(context, imageFile.path, shareText);
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Impossibile condividere: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PRIVATE — Custom Share Sheet (TikTok-style)
  // ---------------------------------------------------------------------------

  static void _showShareSheet(
      BuildContext context, String filePath, String shareText) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _ShareSheetContent(filePath: filePath, shareText: shareText);
      },
    );
  }

  static Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: FaIcon(icon, color: color, size: 24),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Performs the actual native share using a screen-center rect.
  static Future<void> _doNativeShare(
      String filePath, String shareText) async {
    try {
      final view =
          WidgetsBinding.instance.platformDispatcher.views.first;
      final screenSize = view.physicalSize / view.devicePixelRatio;
      final shareRect = Rect.fromCenter(
        center: Offset(screenSize.width / 2, screenSize.height / 2),
        width: 100,
        height: 100,
      );

      await Share.shareXFiles(
        [XFile(filePath)],
        text: shareText,
        sharePositionOrigin: shareRect,
      );
    } catch (e) {
      debugPrint('Native share error: $e');
      // Last resort fallback: text-only share
      try {
        await Share.share(shareText);
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // PRIVATE — Image watermarking
  // ---------------------------------------------------------------------------

  static Future<Uint8List> _addWatermarkToImage(
      ui.Image image, String username) async {
    final width = image.width.toDouble();
    final height = image.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // Draw original image
    canvas.drawImage(image, Offset.zero, Paint());

    // Load DOGZN logo from assets
    final logoData = await rootBundle.load('assets/images/dogzn/dogzn_splash_logo.png');
    final logoCodec = await ui.instantiateImageCodec(
      logoData.buffer.asUint8List(),
    );
    final logoFrame = await logoCodec.getNextFrame();
    final logoImage = logoFrame.image;

    // Scale logo to ~12% of image width
    final logoTargetWidth = width * 0.12;
    final logoScale = logoTargetWidth / logoImage.width;
    final logoTargetHeight = logoImage.height * logoScale;

    // Build @username paragraph
    final userText = '@$username';
    final userParagraph = _buildParagraph(
      userText,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.white.withOpacity(0.85),
      maxWidth: logoTargetWidth + 32,
    );

    // Pill dimensions: logo + username + padding
    final pillPadH = 16.0;
    final pillPadV = 10.0;
    final logoUserGap = 6.0;
    final pillWidth = _maxOf(logoTargetWidth, userParagraph.longestLine) + pillPadH * 2;
    final pillHeight = logoTargetHeight + logoUserGap + userParagraph.height + pillPadV * 2;

    final pillLeft = width - pillWidth - 16;
    final pillTop = height - pillHeight - 16;

    // Draw semi-transparent rounded rect
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pillLeft, pillTop, pillWidth, pillHeight),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.black.withOpacity(0.5),
    );

    // Draw logo centered in pill
    final logoLeft = pillLeft + (pillWidth - logoTargetWidth) / 2;
    final logoTop = pillTop + pillPadV;

    canvas.save();
    canvas.translate(logoLeft, logoTop);
    canvas.scale(logoScale);
    canvas.drawImage(logoImage, Offset.zero, Paint()..filterQuality = FilterQuality.high);
    canvas.restore();

    // Draw @username centered below logo
    final userLeft = pillLeft + (pillWidth - userParagraph.longestLine) / 2;
    canvas.drawParagraph(
      userParagraph,
      Offset(userLeft, logoTop + logoTargetHeight + logoUserGap),
    );

    logoImage.dispose();

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(width.toInt(), height.toInt());
    final byteData =
        await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose();
    picture.dispose();

    return byteData!.buffer.asUint8List();
  }

  static ui.Paragraph _buildParagraph(
    String text, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    required double maxWidth,
  }) {
    final style = ui.TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.left,
      maxLines: 1,
    ))
      ..pushStyle(style)
      ..addText(text);
    final paragraph = builder.build();
    paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
    return paragraph;
  }

  static double _maxOf(double a, double b) => a > b ? a : b;

  static Future<Uint8List> _downloadFile(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Download fallito (status ${response.statusCode})');
    }
    return response.bodyBytes;
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WIDGETS
// ---------------------------------------------------------------------------

class _ShareSheetContent extends ConsumerStatefulWidget {
  final String filePath;
  final String shareText;

  const _ShareSheetContent({
    required this.filePath,
    required this.shareText,
  });

  @override
  ConsumerState<_ShareSheetContent> createState() => _ShareSheetContentState();
}

class _ShareSheetContentState extends ConsumerState<_ShareSheetContent> {
  final Set<String> _sentFriendIds = {};

  Future<void> _sendToFriend(String friendId, String currentUserId) async {
    try {
      final chatService = ChatService();
      final participants = [currentUserId, friendId];
      final chatId = await chatService.createChat(participants, currentUserId);

      final message = MessageModel(
        id: '',
        senderId: currentUserId,
        text: widget.shareText,
        timestamp: DateTime.now(),
        type: MessageType.text,
      );

      await chatService.sendMessage(chatId, message);

      setState(() {
        _sentFriendIds.add(friendId);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossibile inviare: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(currentUserProfileProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Invia a un amico su DOGZN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Friends list horizontal
              userProfileAsync.when(
                data: (user) {
                  if (user == null || user.friends.isEmpty) {
                    return const SizedBox(
                      height: 110,
                      child: Center(
                        child: Text(
                          'Aggiungi amici per condividere direttamente!',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    );
                  }

                  final friendIds = user.friends;
                  final friendsListAsync = ref.watch(usersByIdsProvider(friendIds));

                  return friendsListAsync.when(
                    data: (friends) {
                      if (friends.isEmpty) {
                        return const SizedBox(
                          height: 110,
                          child: Center(
                            child: Text(
                              'Nessun amico trovato',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ),
                        );
                      }

                      return SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: friends.length,
                          itemBuilder: (context, index) {
                            final friend = friends[index];
                            final hasSent = _sentFriendIds.contains(friend.uid);

                            return Container(
                              width: 80,
                              margin: const EdgeInsets.only(right: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage: friend.photoUrl != null
                                        ? NetworkImage(friend.photoUrl!)
                                        : null,
                                    backgroundColor: AppColors.surfaceVariant,
                                    child: friend.photoUrl == null
                                        ? Text(
                                            friend.firstName.isNotEmpty
                                                ? friend.firstName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black87),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    friend.firstName,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 24,
                                    child: TextButton(
                                      onPressed: hasSent
                                          ? null
                                          : () => _sendToFriend(friend.uid, user.uid),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 0),
                                        backgroundColor: hasSent
                                            ? Colors.grey.shade200
                                            : AppColors.primary.withOpacity(0.1),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        hasSent ? 'Inviato' : 'Invia',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: hasSent
                                              ? Colors.grey
                                              : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const SizedBox(
                      height: 120,
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (err, _) => SizedBox(
                      height: 120,
                      child: Center(
                          child: Text('Errore: $err',
                              style: const TextStyle(color: Colors.red))),
                    ),
                  );
                },
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (err, _) => SizedBox(
                  height: 120,
                  child: Center(
                      child: Text('Errore: $err',
                          style: const TextStyle(color: Colors.red))),
                ),
              ),

              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade200),
              const SizedBox(height: 12),

              // Share options
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ShareContentHelper._buildShareOption(
                      icon: FontAwesomeIcons.whatsapp,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: () async {
                        Navigator.pop(context);
                        final url =
                            'https://wa.me/?text=${Uri.encodeComponent(widget.shareText)}';
                        try {
                          await launchUrl(Uri.parse(url),
                              mode: LaunchMode.externalApplication);
                        } catch (_) {
                          ShareContentHelper._showError(
                              context, 'WhatsApp non è installato');
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    ShareContentHelper._buildShareOption(
                      icon: FontAwesomeIcons.telegram,
                      label: 'Telegram',
                      color: const Color(0xFF0088CC),
                      onTap: () async {
                        Navigator.pop(context);
                        final url =
                            'https://t.me/share/url?url=${Uri.encodeComponent('https://dogzn.com')}&text=${Uri.encodeComponent(widget.shareText)}';
                        try {
                          await launchUrl(Uri.parse(url),
                              mode: LaunchMode.externalApplication);
                        } catch (_) {
                          ShareContentHelper._showError(
                              context, 'Telegram non è installato');
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    ShareContentHelper._buildShareOption(
                      icon: Icons.link_rounded,
                      label: 'Copia Link',
                      color: Colors.grey.shade600,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.shareText));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle_outline,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text('Link copiato! 🔗'),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    ShareContentHelper._buildShareOption(
                      icon: Icons.ios_share,
                      label: 'Altre app',
                      color: const Color(0xFF1B3A5C),
                      onTap: () async {
                        Navigator.pop(context);
                        await Future.delayed(
                            const Duration(milliseconds: 150));
                        await ShareContentHelper._doNativeShare(
                            widget.filePath, widget.shareText);
                      },
                    ),
                  ],
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

/// A lifecycle-aware loading overlay that uses OverlayEntry to avoid
/// pushing routes (which would conflict with native share sheets).
class _LoadingOverlay {
  final BuildContext context;
  OverlayEntry? _entry;
  bool _dismissed = false;

  _LoadingOverlay(this.context);

  void show(String message) {
    if (_dismissed) return;

    _entry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          // Semi-transparent barrier that blocks interaction
          ModalBarrier(
            color: Colors.black54,
            dismissible: false,
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 48),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_entry!);
  }

  void dismiss() {
    _dismissed = true;
    if (_entry != null) {
      _entry!.remove();
      _entry = null;
    }
  }
}
