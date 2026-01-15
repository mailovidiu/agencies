import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'ad_manager.dart';
import '../services/consent_service.dart';

class AppLifecycleManager with WidgetsBindingObserver {
  final AdManager _adManager = AdManager();
  static final AppLifecycleManager _instance = AppLifecycleManager._internal();
  factory AppLifecycleManager() => _instance;
  AppLifecycleManager._internal();
  
  DateTime? _lastPausedTime;
  bool _isFirstLaunch = true;

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Skip ad operations on web platform
    if (kIsWeb) return;
    
    // Only show ads if user has consented
    if (!ConsentService.instance.shouldShowAds) return;
    
    switch (state) {
      case AppLifecycleState.resumed:
        // Don't show app open ad on first launch (handled by OpenAdScreen)
        if (_isFirstLaunch) {
          _isFirstLaunch = false;
          break;
        }
        
        // Only show app open ad if app was actually in background for a meaningful time
        if (_lastPausedTime != null) {
          final timeInBackground = DateTime.now().difference(_lastPausedTime!);
          if (timeInBackground.inSeconds > 10) { // Increased from 5 to 10 seconds
            // Add a small delay to ensure any previous ad operations have completed
            Future.delayed(const Duration(milliseconds: 500), () {
              _adManager.showAppOpenAd();
            });
          } else {
            if (kDebugMode) {
              print('App was only backgrounded briefly (${timeInBackground.inSeconds}s), skipping app open ad');
            }
          }
        }
        break;
      case AppLifecycleState.paused:
        _lastPausedTime = DateTime.now();
        // App is going to background - prepare next app open ad
        Future.delayed(const Duration(milliseconds: 200), () {
          _adManager.loadAppOpenAd();
        });
        break;
      default:
        break;
    }
    
    if (kDebugMode) {
      print('App lifecycle state changed to: $state');
    }
  }
}