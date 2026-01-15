// Web stub implementation for AdManager
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AdManager {
  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;
  AdManager._internal();

  // Initialize method for compatibility
  Future<void> initialize() async {
    if (kDebugMode) {
      print('AdManager: initialize called on web (no-op)');
    }
  }

  // No-op implementations for web
  Future<void> loadAppOpenAd() async {
    if (kDebugMode) {
      print('AdManager: loadAppOpenAd called on web (no-op)');
    }
  }

  Future<void> showAppOpenAd() async {
    if (kDebugMode) {
      print('AdManager: showAppOpenAd called on web (no-op)');
    }
  }

  // Show app open ad with completion callback (web version)
  Future<bool> showAppOpenAdWithCallback({VoidCallback? onCompleted}) async {
    if (kDebugMode) {
      print('AdManager: showAppOpenAdWithCallback called on web (no-op)');
    }
    onCompleted?.call();
    return false;
  }

  Future<void> loadInterstitialAd() async {
    if (kDebugMode) {
      print('AdManager: loadInterstitialAd called on web (no-op)');
    }
  }

  bool canShowInterstitialAd() => false;

  Future<void> showInterstitialAd() async {
    if (kDebugMode) {
      print('AdManager: showInterstitialAd called on web (no-op)');
    }
  }

  void dispose() {
    if (kDebugMode) {
      print('AdManager: dispose called on web (no-op)');
    }
  }
}