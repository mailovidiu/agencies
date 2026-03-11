import 'dart:io';
import 'package:flutter/foundation.dart';
import 'consent_service.dart';
import 'tracking_service.dart';
import '../ads/ad_manager.dart';
import '../utils/app_logger.dart';

class AppInitializationService {
  static final AppInitializationService _instance =
      AppInitializationService._internal();
  factory AppInitializationService() => _instance;
  AppInitializationService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      logVerbose('🚀 Starting app initialization...');

      // Step 1: Initialize consent service
      await ConsentService.instance.initialize();
      logVerbose('✅ Consent service initialized');

      // Step 2: Request ATT permission on iOS (this should show the popup)
      if (!kIsWeb && Platform.isIOS) {
        logVerbose('🔒 Requesting App Tracking Transparency permission...');
        final trackingService = TrackingService();
        final status = await trackingService.requestTrackingAuthorization();
        logVerbose('🔒 ATT Permission result: $status');

        // Small delay to ensure the permission dialog is fully handled
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Step 3: Initialize ads if consent is granted
      if (!kIsWeb && ConsentService.instance.shouldShowAds) {
        logVerbose('📱 Initializing ads with consent...');
        await AdManager().syncConsentState();
        logVerbose('📱 Ads initialized successfully');
      } else {
        logVerbose(
            '📱 Ads initialization skipped - no consent or web platform');
      }

      _isInitialized = true;
      logVerbose('🚀 App initialization complete');
    } catch (e) {
      logError('❌ App initialization error: $e');
      // Continue even if initialization fails
      _isInitialized = true;
    }
  }

  bool get isInitialized => _isInitialized;
}
