import 'dart:io';
import 'package:flutter/foundation.dart';

class AdConstants {
  static String get appId {
    if (kDebugMode) {
      if (Platform.isIOS) return 'ca-app-pub-3940256099942544~1458002511';
      if (Platform.isAndroid) return 'ca-app-pub-3940256099942544~3347511713';
    }
    
    if (Platform.isIOS) {
      return 'ca-app-pub-9742953793397431~6887145034'; // iOS Production App ID
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-9742953793397431~3308038853'; // Android Production App ID
    }
    return '';
  }

  static String get bannerAdUnitId {
    if (kDebugMode) {
      if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';
      if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/6300978111';
    }

    if (Platform.isIOS) {
      return 'ca-app-pub-9742953793397431/9270811973'; // iOS Production Banner ID
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-9742953793397431/3135602285'; // Android Production Banner ID
    }
    return '';
  }

  static String get nativeAdUnitId {
    if (kDebugMode) {
      if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2521693316'; // iOS Native Video Test ID
      if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/1044960115'; // Android Native Video Test ID
    }

    if (Platform.isIOS) {
      return 'ca-app-pub-9742953793397431/3492364893'; // iOS Production Native ID
    } else if (Platform.isAndroid) {
      return 'ca-app-pub-9742953793397431/4537516547'; // Android Production Native ID
    }
    return '';
  }
}
