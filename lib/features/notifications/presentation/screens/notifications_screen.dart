import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/services/friend_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../core/services/notification_router.dart';

/// Provider for Firestore-based in-app notifications
final inAppNotificationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList());
});

/// Provider for unread notification count
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .where('read', isEqualTo: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
});

/// Provider for friend requests (kept from original)
final friendRequestsProvider = FutureProvider<List<UserModel>>((ref) async {
  final currentUserState = ref.watch(currentUserProfileProvider);
  final userModel = currentUserState.value;

  if (userModel == null || userModel.friendRequests.isEmpty) return [];

  final userService = UserService();
  final requests = <UserModel>[];

  for (final uid in userModel.friendRequests) {
    final sender = await userService.getUserById(uid);
    if (sender != null) requests.add(sender);
  }

  return requests;
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendRequests = ref.watch(friendRequestsProvider);
    final notifications = ref.watch(inAppNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifiche'),
        actions: [
          TextButton(
            onPressed: () => _markAllAsRead(context, ref),
            child: const Text('Segna lette', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ── Friend Requests Section ──
          friendRequests.when(
            data: (requests) {
              if (requests.isEmpty) return const SliverToBoxAdapter();
              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      icon: Icons.person_add,
                      title: 'Richieste di amicizia',
                      count: requests.length,
                      color: AppColors.primary,
                    ),
                    ...requests.map((user) => _FriendRequestTile(user: user)),
                    const Divider(height: 1),
                  ],
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(),
            error: (_, __) => const SliverToBoxAdapter(),
          ),

          // ── In-app Notifications Section ──
          notifications.when(
            data: (notifs) {
              if (notifs.isEmpty) {
                return friendRequests.when(
                  data: (requests) {
                    if (requests.isEmpty) {
                      return SliverFillRemaining(
                        child: _EmptyState(),
                      );
                    }
                    return const SliverToBoxAdapter();
                  },
                  loading: () => const SliverToBoxAdapter(),
                  error: (_, __) => const SliverToBoxAdapter(),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final notif = notifs[index];
                    return _NotificationTile(notification: notif);
                  },
                  childCount: notifs.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(child: Text('Errore: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAllAsRead(BuildContext context, WidgetRef ref) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      // Reset iOS app icon badge since all notifications are now read
      await ref.read(notificationServiceProvider).resetBadge();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tutte le notifiche segnate come lette')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }
}

// ── Section Header ──────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Friend Request Tile ──────────────────────────────────

class _FriendRequestTile extends ConsumerWidget {
  final UserModel user;

  const _FriendRequestTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage:
                user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            backgroundColor: AppColors.primary.withOpacity(0.2),
            child: user.photoUrl == null
                ? Text(user.firstName[0],
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.primary))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const Text(
                  'Vuole essere tuo amico',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: AppColors.primary),
            onPressed: () async {
              await FriendService().acceptFriendRequest(user.uid);
              ref.invalidate(friendRequestsProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.grey),
            onPressed: () async {
              await FriendService().declineFriendRequest(user.uid);
              ref.invalidate(friendRequestsProvider);
            },
          ),
        ],
      ),
    );
  }
}

// ── Notification Tile ────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final type = notification['type'] as String? ?? 'generic';
    final title = notification['title'] as String? ?? 'Notifica';
    final body = notification['body'] as String? ?? '';
    final isRead = notification['read'] as bool? ?? false;
    final createdAt = notification['createdAt'] as Timestamp?;
    final notifId = notification['id'] as String?;

    final icon = _getNotificationIcon(type);
    final iconColor = _getNotificationColor(type);

    return Dismissible(
      key: Key(notifId ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        if (notifId != null) {
          _deleteNotification(notifId);
        }
      },
      child: InkWell(
        onTap: () {
          if (notifId != null && !isRead) {
            _markAsRead(notifId);
          }
          final Map<String, dynamic> payloadData = Map<String, dynamic>.from(notification['data'] ?? {});
          NotificationRouter.navigate(type, payloadData);
        },
        child: Container(
          color: isRead ? Colors.transparent : AppColors.primary.withOpacity(0.04),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _formatTimestamp(createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Unread dot
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'content_removed':
        return Icons.warning_amber;
      case 'moderation_warning':
        return Icons.gavel;
      case 'account_suspended':
        return Icons.block;
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.chat_bubble;
      case 'friend_accepted':
        return Icons.people;
      case 'message':
        return Icons.mail;
      case 'walk_complete':
        return Icons.directions_walk;
      case 'radar_ping':
        return Icons.radar;
      case 'announcement_comment':
      case 'social_comment':
        return Icons.chat_bubble_outline;
      case 'announcement_watching':
        return Icons.pets;
      case 'social_like':
        return Icons.favorite_border;
      case 'friend_request':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'content_removed':
        return Colors.red;
      case 'moderation_warning':
        return Colors.orange;
      case 'account_suspended':
        return Colors.red.shade800;
      case 'like':
        return Colors.pink;
      case 'comment':
        return Colors.blue;
      case 'friend_accepted':
        return Colors.green;
      case 'message':
        return Colors.indigo;
      case 'walk_complete':
        return Colors.teal;
      case 'radar_ping':
        return Colors.deepPurple;
      case 'announcement_comment':
      case 'social_comment':
        return Colors.blue;
      case 'announcement_watching':
        return AppColors.primary;
      case 'social_like':
        return Colors.pink;
      case 'friend_request':
        return Colors.green;
      default:
        return AppColors.primary;
    }
  }

  String _formatTimestamp(Timestamp ts) {
    final date = ts.toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Adesso';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
    if (diff.inHours < 24) return '${diff.inHours} ore fa';
    if (diff.inDays < 7) return '${diff.inDays} giorni fa';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _markAsRead(String notifId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notifId)
        .update({'read': true});
  }

  void _deleteNotification(String notifId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notifId)
        .delete();
  }
}

// ── Empty State ──────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.08),
            ),
            child: Icon(
              Icons.notifications_none,
              size: 56,
              color: AppColors.primary.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nessuna notifica',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Qui vedrai like, commenti, messaggi\ne avvisi di moderazione',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textTertiary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
