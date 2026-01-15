// Stub implementation for web platform where AdMob is not available
import 'package:flutter/foundation.dart';

class AdHelper {
  static bool get isTestMode => kDebugMode;

  // Application IDs (not used on web)
  static String get appId => '';
  static String get appOpenAdUnitId => '';
  static String get interstitialAdUnitId => '';
  static String get nativeAdUnitId => '';

  // Initialize Mobile Ads SDK (no-op on web)
  static Future<void> initializeAds() async {
    if (kDebugMode) {
      print('AdMob is not supported on web platform, skipping initialization');
    }
  }
}