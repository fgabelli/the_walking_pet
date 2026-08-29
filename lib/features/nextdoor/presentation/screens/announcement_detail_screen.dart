import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/announcement_model.dart';
import '../../../../shared/models/user_model.dart';
import 'create_announcement_screen.dart';
import '../providers/nextdoor_provider.dart';
import '../../../../core/services/user_service.dart';
import '../../../../shared/presentation/widgets/user_profile_bottom_sheet.dart';
import 'package:the_walking_pet/features/auth/presentation/providers/auth_provider.dart';

class AnnouncementDetailScreen extends ConsumerStatefulWidget {
  final AnnouncementModel announcement;

  const AnnouncementDetailScreen({super.key, required this.announcement});

  @override
  ConsumerState<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends ConsumerState<AnnouncementDetailScreen> {
  final _commentController = TextEditingController();
  Stream<DocumentSnapshot>? _announcementStream;

  @override
  void initState() {
    super.initState();
    // Listen to the announcement document directly for real-time comment updates
    _announcementStream = FirebaseFirestore.instance
        .collection('announcements')
        .doc(widget.announcement.id)
        .snapshots();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsViewed();
    });
  }

  void _markAsViewed() {
    final currentUser = ref.read(authServiceProvider).currentUser;
    if (currentUser == null) return;

    // Check if user already viewed (is in responses with type watching)
    final alreadyViewed = widget.announcement.responses.any(
      (r) => r.userId == currentUser.uid && r.type == ResponseType.watching
    );

    if (!alreadyViewed) {
      ref.read(nextdoorControllerProvider.notifier).addResponse(
        widget.announcement.id,
        ResponseType.watching,
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    FocusScope.of(context).unfocus();

    await ref.read(nextdoorControllerProvider.notifier).addResponse(
          widget.announcement.id,
          ResponseType.message,
          message: text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.read(authServiceProvider).currentUser;

    // Use StreamBuilder for real-time updates directly from Firestore
    // This ensures comments are visible even when navigating from SOS card
    return StreamBuilder<DocumentSnapshot>(
      stream: _announcementStream,
      builder: (context, snapshot) {
        AnnouncementModel updatedAnnouncement;
        if (snapshot.hasData && snapshot.data!.exists) {
          updatedAnnouncement = AnnouncementModel.fromFirestore(snapshot.data!);
        } else {
          // Fallback: try provider, then widget
          final nextdoorState = ref.watch(nextdoorControllerProvider);
          updatedAnnouncement = nextdoorState.announcements.firstWhere(
            (a) => a.id == widget.announcement.id,
            orElse: () => widget.announcement,
          );
        }

        final comments = updatedAnnouncement.responses
            .where((r) => r.type == ResponseType.message)
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return Scaffold(
      appBar: AppBar(
        title: const Text('Dettagli Annuncio'),
        centerTitle: true,
        actions: [
          if (updatedAnnouncement.userId == ref.read(authServiceProvider).currentUser?.uid)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateAnnouncementScreen(
                        announcementToEdit: updatedAnnouncement,
                      ),
                    ),
                  );
                } else if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Elimina Annuncio'),
                      content: const Text('Sei sicuro di voler eliminare questo annuncio?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Annulla'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(foregroundColor: AppColors.error),
                          child: const Text('Elimina'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await ref.read(nextdoorControllerProvider.notifier).deleteAnnouncement(updatedAnnouncement.id);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Annuncio eliminato')),
                      );
                    }
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: AppColors.textPrimary),
                      SizedBox(width: 8),
                      Text('Modifica'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Elimina', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // Share implementation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Funzionalità di condivisione in arrivo!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        FutureBuilder<UserModel?>(
                          future: UserService().getUserById(updatedAnnouncement.userId),
                          builder: (context, snapshot) {
                            final author = snapshot.data;
                            return InkWell(
                              onTap: author != null
                                  ? () => showUserProfileBottomSheet(context, author)
                                  : null,
                              child: CircleAvatar(
                                backgroundColor: AppColors.surfaceVariant,
                                backgroundImage: updatedAnnouncement.authorPhotoUrl != null
                                    ? NetworkImage(updatedAnnouncement.authorPhotoUrl!)
                                    : null,
                                child: updatedAnnouncement.authorPhotoUrl == null
                                    ? const Icon(Icons.person, color: AppColors.primary)
                                    : null,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    updatedAnnouncement.authorName,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Close Friends Star
                                  FutureBuilder<UserModel?>(
                                    future: UserService().getUserById(ref.read(authServiceProvider).currentUser?.uid ?? ''),
                                    builder: (context, snapshot) {
                                      final currentUser = snapshot.data;
                                      if (currentUser?.closeFriends.contains(updatedAnnouncement.userId) ?? false) {
                                        return const Icon(Icons.star, size: 16, color: Colors.amber);
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  // User average rating stars
                                  FutureBuilder<UserModel?>(
                                    future: UserService().getUserById(updatedAnnouncement.userId),
                                    builder: (context, snapshot) {
                                      final avgRating = snapshot.data?.averageRating ?? 0.0;
                                      if (avgRating == 0.0) return const SizedBox.shrink();
                                      
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star_rate_rounded, color: Colors.amber, size: 14),
                                          Text(
                                            avgRating.toStringAsFixed(1),
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                '${updatedAnnouncement.zone} • ${timeago.format(updatedAnnouncement.createdAt, locale: 'it')}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        // Category Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: updatedAnnouncement.category.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(updatedAnnouncement.category.icon, size: 12, color: updatedAnnouncement.category.color),
                              const SizedBox(width: 4),
                              Text(
                                updatedAnnouncement.category.displayName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: updatedAnnouncement.category.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),


                  // Message
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      updatedAnnouncement.message,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Image
                  if (updatedAnnouncement.imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          updatedAnnouncement.imageUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 16),

                  // Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.pets, size: 14, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(
                              '${updatedAnnouncement.responses.where((r) => r.type == ResponseType.watching).length} zampate',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              '${comments.length} commenti',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(),

                  // Comments List
                  if (comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text('Nessun commento ancora. Sii il primo!'),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final response = comments[index]; // Use the filtered 'comments' list
                      if (response.type != ResponseType.message) return const SizedBox.shrink();

                        return ListTile(
                        leading: FutureBuilder<UserModel?>(
                          future: UserService().getUserById(response.userId),
                          builder: (context, snapshot) {
                            final user = snapshot.data;
                            return InkWell(
                              onTap: user != null
                                  ? () => showUserProfileBottomSheet(context, user)
                                  : null,
                              child: CircleAvatar(
                                backgroundColor: AppColors.surfaceVariant,
                                backgroundImage: response.userPhotoUrl != null
                                    ? NetworkImage(response.userPhotoUrl!)
                                    : null,
                                child: response.userPhotoUrl == null
                                    ? const Icon(Icons.person, size: 20, color: AppColors.textSecondary)
                                    : null,
                              ),
                            );
                          },
                        ),
                        title: Row(
                          children: [
                            Text(
                              response.userName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeago.format(response.timestamp, locale: 'it'),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                            ),
                          ],
                        ),
                        subtitle: Text(response.message ?? ''),
                      );
                      },
                    ),
                ],
              ),
            ),
          ),

          // Comment Input
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Scrivi un commento...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _submitComment,
                  icon: const Icon(Icons.send, color: AppColors.primary),
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
