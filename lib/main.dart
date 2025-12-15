import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:timeago/timeago.dart' as timeago;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Date Formatting
  await initializeDateFormatting(null, null);
  
  // Initialize Timeago
  timeago.setLocaleMessages('it', timeago.ItMessages());

  // Initialize AdMob (Fail silently if not supported on platform e.g. web/macos yet)
  try {
     MobileAds.instance.initialize();
  } catch (e) {
     debugPrint('AdMob Init Error: $e');
  }
  
  runApp(
    const ProviderScope(
      child: TheWalkingPetApp(),
    ),
  );
}
