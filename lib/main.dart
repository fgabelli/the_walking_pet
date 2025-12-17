
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart'; // Added
import 'app.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'core/services/purchase_service.dart'; // Import PurchaseService Provider
import 'core/services/notification_service.dart'; // Import NotificationService
// ... other imports

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize ATT
  // We wait a brief moment to ensure the app is visible before requesting permission
  // or checks if it's already determined.
  // Note: On Android this plugin returns "notSupported" which is fine.
  try {
    await Future.delayed(const Duration(milliseconds: 200));
    await AppTrackingTransparency.requestTrackingAuthorization();
  } catch (e) {
    debugPrint('Error requesting tracking authorization: $e');
  }
  
  // Set the background messaging handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Date Formatting
  await initializeDateFormatting(null, null);
  
  // Initialize Timeago
  timeago.setLocaleMessages('it', timeago.ItMessages());

  // Initialize AdMob
  try {
     MobileAds.instance.initialize();
  } catch (e) {
     debugPrint('AdMob Init Error: $e');
  }

  // Initialize Providers & Services using ProviderContainer
  // This ensures services like RevenueCat are ready before UI
  final container = ProviderContainer();
  try {
    await container.read(purchaseServiceProvider).init();
  } catch (e) {
    debugPrint('PurchaseService Init Error: $e');
  }

  // Initialize Notification Service
  try {
     await container.read(notificationServiceProvider).initialize();
  } catch (e) {
     debugPrint('NotificationService Init Error: $e');
  }
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TheWalkingPetApp(),
    ),
  );
}
