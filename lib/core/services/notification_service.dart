import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> initialize() async {
    // 1. Request Permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      
      // 2. Get and Save Token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token);
      }

      // 3. Listen for token refreshes
      _firebaseMessaging.onTokenRefresh.listen(_saveTokenToDatabase);

      // 4. Foreground Message Handling
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');

        if (message.notification != null) {
          print('Message also contained a notification: ${message.notification}');
          // You could show a local notification here using flutter_local_notifications if needed
          // For now, iOS handles foreground notifications if configured in Info.plist (presentation options)
          // But FirebaseMessaging doesn't show heads-up by default on foreground Android without local_notifications.
          // On iOS, we can set foregroundNotificationPresentationOptions.
        }
      });
      
      // 5. iOS Foreground Presentation Options
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } else {
      print('User declined or has not accepted permission');
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }
  
  // Clean up token on logout
  Future<void> deleteToken() async {
     try {
       String? token = await _firebaseMessaging.getToken();
       String? userId = _auth.currentUser?.uid;
       if (userId != null && token != null) {
         await _firestore.collection('users').doc(userId).update({
           'fcmTokens': FieldValue.arrayRemove([token]),
         });
       }
     } catch (_) {}
  }
}
