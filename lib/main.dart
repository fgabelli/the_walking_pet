import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'core/services/purchase_service.dart'; // Import PurchaseService Provider
// ... other imports

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();

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
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TheWalkingPetApp(),
    ),
  );
}
