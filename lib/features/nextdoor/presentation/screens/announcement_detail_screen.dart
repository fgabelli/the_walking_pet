import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/announcement_model.dart';
import '../../../../shared/models/review_model.dart';
import '../../../../shared/models/user_model.dart';
import 'create_announcement_screen.dart';
import '../providers/nextdoor_provider.dart';
import '../../../reviews/presentation/screens/create_review_screen.dart';
import '../../../../core/services/review_service.dart';
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

  @override
  void initState() {
    super.initState();
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
    // We should watch the specific announcement to get updates on comments
    // But our provider returns a list.
    // We can find the updated announcement from the list.
    final nextdoorState = ref.watch(nextdoorControllerProvider);
    final updatedAnnouncement = nextdoorState.announcements.firstWhere(
      (a) => a.id == widget.announcement.id,
      orElse: () => widget.announcement,
    );

    final comments = updatedAnnouncement.responses
        .where((r) => r.type == ResponseType.message)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first

    final currentUser = ref.read(authServiceProvider).currentUser;
    print('DEBUG: Current User ID: ${currentUser?.uid}');
    print('DEBUG: Announcement User ID: ${updatedAnnouncement.userId}');

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
                                  const SizedBox(width: 8),
                                  // User average rating stars
                                  FutureBuilder<double>(
                                    future: ReviewService().getUserAverageRating(updatedAnnouncement.userId),
                                    builder: (context, snapshot) {
                                      final avgRating = snapshot.data ?? 0.0;
                                      if (avgRating == 0.0) return const SizedBox.shrink();
                                      
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 2),
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
                                'Vicino a ${updatedAnnouncement.zone} • ${timeago.format(updatedAnnouncement.createdAt, locale: 'it')}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        // Review Button
                        if (updatedAnnouncement.userId != ref.read(authServiceProvider).currentUser?.uid)
                          FutureBuilder<bool>(
                            future: ReviewService().hasUserReviewedAnnouncement(
                              ref.read(authServiceProvider).currentUser?.uid ?? '',
                              updatedAnnouncement.id,
                            ),
                            builder: (context, snapshot) {
                              final hasReviewed = snapshot.data ?? false;
                              
                              return TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CreateReviewScreen(
                                          announcementId: updatedAnnouncement.id,
                                          targetUserId: updatedAnnouncement.userId,
                                          announcementTitle: updatedAnnouncement.message.length > 50
                                            ? '${updatedAnnouncement.message.substring(0, 50)}...'
                                            : updatedAnnouncement.message,
                                      ),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  hasReviewed ? Icons.edit : Icons.star_rate_rounded,
                                  size: 18,
                                ),
                                label: Text(hasReviewed ? 'Modifica' : 'Recensisci'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              );
                            },
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
                    Image.network(
                      updatedAnnouncement.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  
                  const SizedBox(height: 16),

                  // Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${updatedAnnouncement.responses.where((r) => r.type == ResponseType.watching).length} stanno guardando',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '${comments.length} commenti',
                          style: Theme.of(context).textTheme.bodySmall,
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
                  // Reviews Section
                  const Divider(thickness: 8, color: Color(0xFFF5F5F5)),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Recensioni',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  StreamBuilder<List<ReviewModel>>(
                    stream: ReviewService().getReviewsForAnnouncement(updatedAnnouncement.id),
                    builder: (context, reviewSnapshot) {
                      if (reviewSnapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final reviews = reviewSnapshot.data ?? [];

                      if (reviews.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: Text('Nessuna recensione ancora. Sii il primo!'),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: reviews.length,
                        itemBuilder: (context, index) {
                          final review = reviews[index];
                          
                          return FutureBuilder<UserModel?>(
                            future: UserService().getUserById(review.authorId),
                            builder: (context, userSnapshot) {
                              final authorName = userSnapshot.data?.fullName ?? 'Utente';
                              final authorPhotoUrl = userSnapshot.data?.photoUrl;

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: userSnapshot.data != null
                                                ? () => showUserProfileBottomSheet(context, userSnapshot.data!)
                                                : null,
                                            child: CircleAvatar(
                                              radius: 20,
                                              backgroundColor: AppColors.surfaceVariant,
                                              backgroundImage: authorPhotoUrl != null
                                                  ? NetworkImage(authorPhotoUrl)
                                                  : null,
                                              child: authorPhotoUrl == null
                                                  ? const Icon(Icons.person, size: 20, color: AppColors.textSecondary)
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  authorName,
                                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                ),
                                                Text(
                                                  timeago.format(review.timestamp, locale: 'it'),
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                        color: AppColors.textSecondary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            children: List.generate(5, (i) {
                                              return Icon(
                                                i < review.rating ? Icons.star : Icons.star_border,
                                                color: Colors.amber,
                                                size: 18,
                                              );
                                            }),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        review.comment,
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
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
  }
}
