
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'app.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:facebook_app_events/facebook_app_events.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'core/services/purchase_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/consent_service.dart';
import 'core/providers/ad_readiness_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Facebook App Events for Meta ad attribution
  try {
    await FacebookAppEvents().setAdvertiserTracking(enabled: true);
  } catch (e) {
    debugPrint('Facebook App Events Init Error: $e');
  }

  // Set the background messaging handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Date Formatting
  try {
    await initializeDateFormatting(null, null);
  } catch (e) {
    debugPrint('Date Formatting Init Error: $e');
  }
  
  // Initialize Timeago
  timeago.setLocaleMessages('it', timeago.ItMessages());

  // Create the ProviderContainer early so we can set adMobReadyProvider
  final container = ProviderContainer();

  // Initialize AdMob & Consent (GDPR/UMP) — MUST come BEFORE ATT
  // Apple Guideline 5.1.1: show GDPR/UMP consent first, then ATT.
  // Consent + SDK init are now SEQUENTIAL and BLOCKING so that no ad is
  // ever loaded before the SDK is ready. This eliminates the race condition
  // that was causing loaded-but-not-shown ads.
  try {
    final consentService = ConsentService();
    await consentService.requestConsent();
    await MobileAds.instance.initialize();
    container.read(adMobReadyProvider.notifier).state = true;
    debugPrint('✅ AdMob SDK initialized and consent obtained');
  } catch (e) {
    debugPrint('AdMob/Consent Init Error: $e');
    // Even on error, mark as ready so ads can attempt to load
    // (Google will serve non-personalized ads if consent was denied)
    container.read(adMobReadyProvider.notifier).state = true;
  }

  // Initialize ATT — AFTER GDPR/UMP consent flow completes
  // Delay slightly to ensure the app UI is visible (Apple requirement)
  Future.delayed(const Duration(milliseconds: 500), () async {
    try {
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (e) {
      debugPrint('Error requesting tracking authorization: $e');
    }
  });

  // Initialize Providers & Services
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


