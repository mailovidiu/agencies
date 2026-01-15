import 'dart:io';
import 'package:flutter/foundation.dart';
import 'consent_service.dart';
import 'tracking_service.dart';
import '../ads/ad_manager.dart';
import '../ads/ad_helper.dart';

class AppInitializationService {
  static final AppInitializationService _instance = AppInitializationService._internal();
  factory AppInitializationService() => _instance;
  AppInitializationService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🚀 Starting app initialization...');
      
      // Step 1: Initialize consent service
      await ConsentService.instance.initialize();
      debugPrint('✅ Consent service initialized');

      // Step 2: Request ATT permission on iOS (this should show the popup)
      if (!kIsWeb && Platform.isIOS) {
        debugPrint('🔒 Requesting App Tracking Transparency permission...');
        final trackingService = TrackingService();
        final status = await trackingService.requestTrackingAuthorization();
        debugPrint('🔒 ATT Permission result: $status');
        
        // Small delay to ensure the permission dialog is fully handled
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Step 3: Initialize ads if consent is granted
      if (!kIsWeb && ConsentService.instance.shouldShowAds) {
        debugPrint('📱 Initializing ads with consent...');
        await AdHelper.initializeAds();
        await AdManager().initialize();
        debugPrint('📱 Ads initialized successfully');
      } else {
        debugPrint('📱 Ads initialization skipped - no consent or web platform');
      }

      _isInitialized = true;
      debugPrint('🚀 App initialization complete');

    } catch (e) {
      debugPrint('❌ App initialization error: $e');
      // Continue even if initialization fails
      _isInitialized = true;
    }
  }

  bool get isInitialized => _isInitialized;
}