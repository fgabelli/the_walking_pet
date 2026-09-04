import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/user_model.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/social/presentation/screens/post_detail_screen.dart';
import '../../core/providers/ad_readiness_provider.dart';

class NotificationRouter {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static WidgetRef? ref;

  static void navigate(String type, Map<String, dynamic> data) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    print("Navigating to notification of type: $type with data: $data");

    switch (type) {
      case 'chat_message':
      case 'message':
        final chatId = data['chatId'];
        if (chatId != null) {
          try {
            final myUid = FirebaseAuth.instance.currentUser?.uid;
            if (myUid == null) return;
            final uids = chatId.toString().split('_');
            final otherUserId = uids.firstWhere((id) => id != myUid, orElse: () => uids.first);

            final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
            if (userDoc.exists) {
              final otherUser = UserModel.fromFirestore(userDoc);
              navigatorKey.currentState?.push(
                MaterialPageRoute(
            settings: const RouteSettings(name: 'chat'),
                  builder: (context) => ChatScreen(chatId: chatId, otherUser: otherUser),
                ),
              );
            }
          } catch (e) {
            print("Error navigating to chat: $e");
          }
        }
        break;

      case 'pet_match':
        if (ref != null) {
          ref!.read(activeTabProvider.notifier).state = 2;
        }
        break;

      case 'radar_ping':
        if (ref != null) {
          ref!.read(activeTabProvider.notifier).state = 1;
        }
        break;

      case 'social_like':
      case 'social_comment':
      case 'like':
      case 'comment':
        final postId = data['postId'] ?? data['id'];
        if (postId != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
            settings: const RouteSettings(name: 'post_detail'),
              builder: (context) => PostDetailScreen(postId: postId),
            ),
          );
        } else {
          if (ref != null) {
            ref!.read(activeTabProvider.notifier).state = 0;
          }
        }
        break;

      case 'announcement_comment':
      case 'announcement_watching':
        if (ref != null) {
          ref!.read(activeTabProvider.notifier).state = 0;
        }
        break;

      case 'friend_request':
      case 'friend_accepted':
      default:
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            settings: const RouteSettings(name: 'notifications'),
            builder: (context) => const NotificationsScreen(),
          ),
        );
        break;
    }
  }
}
