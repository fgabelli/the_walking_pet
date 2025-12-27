import 'dart:io';
import 'package:flutter/foundation.dart';

class AdConstants {
  static String get appId {
    if (kDebugMode) {
      if (Platform.isIOS) return 'ca-app-pub-3940256099942544~1458002511';
      if (Platform.isAndroid) return 'ca-app-pub-3940256099942544~3347511713';
    }
    
    if (Platform.isIOS) {
      return 'ca-app-pub-5244139045429351~2945059589'; // iOS Production App ID
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544~3347511713'; // Android Test App ID
    }
    return '';
  }

  static String get bannerAdUnitId {
    if (kDebugMode) {
      if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';
      if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/6300978111';
    }

    if (Platform.isIOS) {
      return 'ca-app-pub-5244139045429351/4066569568'; // iOS Production Banner ID
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Android Test Banner ID
    }
    return '';
  }
}
