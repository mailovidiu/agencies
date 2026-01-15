import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  static bool get isTestMode => const bool.fromEnvironment('dart.vm.product') == false;

  // Application IDs
  static String get appId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-6899384815833400~9723672151';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-6899384815833400~9905180144';
    }
    throw UnsupportedError('Unsupported platform');
  }

  // App Open Ad Unit IDs
  static String get appOpenAdUnitId {
    if (isTestMode) {
      return 'ca-app-pub-3940256099942544/9257395921'; // Test ID
    }
    
    if (Platform.isAndroid) {
      return 'ca-app-pub-6899384815833400/6918600557';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-6899384815833400/7051845380';
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Interstitial Ad Unit IDs
  static String get interstitialAdUnitId {
    if (isTestMode) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Test ID
    }
    
    if (Platform.isAndroid) {
      return 'ca-app-pub-6899384815833400/6253769034';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-6899384815833400/3686513620';
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Native Ad Unit IDs  
  static String get nativeAdUnitId {
    if (isTestMode) {
      return 'ca-app-pub-3940256099942544/2247696110'; // Test ID
    }
    
    if (Platform.isAndroid) {
      return 'ca-app-pub-6899384815833400/6970571441';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-6899384815833400/8364927056';
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Initialize Mobile Ads SDK
  static Future<void> initializeAds() async {
    if (kDebugMode) {
      print('Checking platform: kIsWeb = $kIsWeb');
    }
    
    // Skip AdMob initialization on web platform
    if (kIsWeb) {
      if (kDebugMode) {
        print('AdMob is not supported on web platform, skipping initialization');
      }
      return;
    }
    
    if (kDebugMode) {
      print('Initializing AdMob for mobile platform');
    }
    
    await MobileAds.instance.initialize();
  }

  // Request configuration for better ad performance
  static RequestConfiguration get requestConfiguration => RequestConfiguration(
    testDeviceIds: isTestMode ? ['test-device-id'] : null,
  );
}