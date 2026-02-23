import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_helper.dart';
import '../services/consent_service.dart';
import '../services/tracking_service.dart';

class AdManager {
  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;
  AdManager._internal();

  AppOpenAd? _appOpenAd;
  InterstitialAd? _interstitialAd;
  bool _isShowingAppOpenAd = false;
  DateTime? _appOpenAdLoadTime;
  DateTime? _lastInterstitialShow;
  DateTime? _lastAppOpenShow;
  bool _isInitialized = false;
  int _interactionsSinceLastInterstitial = 0;
  bool _isLoadingInterstitial = false;
  Timer? _interstitialRetryTimer;

  static const int _minInteractionsBetweenInterstitials = 5;
  static const Duration _interstitialRetryDelay = Duration(seconds: 30);

  // Initialize ads based on consent
  Future<void> initialize() async {
    if (_isInitialized) return;

    final consentService = ConsentService.instance;
    if (!consentService.shouldShowAds) {
      if (kDebugMode) {
        print('Ads disabled by user consent');
      }
      return;
    }

    try {
      // Request tracking authorization for iOS
      if (Platform.isIOS) {
        final trackingService = TrackingService();
        final trackingStatus =
            await trackingService.requestTrackingAuthorization();
        if (kDebugMode) {
          print('🔒 Tracking authorization status: $trackingStatus');
        }
      }

      // Configure ad request based on consent
      final requestConfiguration = RequestConfiguration(
        testDeviceIds: kDebugMode ? ['YOUR_TEST_DEVICE_ID'] : null,
      );

      // Set non-personalized ads if user chose that option
      if (!consentService.canShowPersonalizedAds) {
        // This will be handled by UMP SDK automatically
      }

      await MobileAds.instance.updateRequestConfiguration(requestConfiguration);
      await MobileAds.instance.initialize();

      _isInitialized = true;

      // Load initial ads
      await loadAppOpenAd();
      await loadInterstitialAd();

      if (kDebugMode) {
        print('AdManager initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing AdManager: $e');
      }
    }
  }

  // App Open Ad Management
  Future<void> loadAppOpenAd() async {
    if (!_isInitialized || !ConsentService.instance.shouldShowAds) return;
    try {
      await AppOpenAd.load(
        adUnitId: AdHelper.appOpenAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpenAd = ad;
            _appOpenAdLoadTime = DateTime.now();
            if (kDebugMode) {
              print('App open ad loaded successfully');
            }
          },
          onAdFailedToLoad: (error) {
            if (kDebugMode) {
              print('Failed to load app open ad: $error');
            }
          },
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error loading app open ad: $e');
      }
    }
  }

  bool _isAppOpenAdAvailable() {
    return _appOpenAd != null &&
        _appOpenAdLoadTime != null &&
        DateTime.now().difference(_appOpenAdLoadTime!).inMilliseconds <
            4 * 60 * 60 * 1000; // 4 hours
  }

  Future<void> showAppOpenAd() async {
    if (!_isInitialized ||
        !ConsentService.instance.shouldShowAds ||
        _isShowingAppOpenAd ||
        !_isAppOpenAdAvailable()) {
      return;
    }

    // Don't show app open ad if an interstitial was shown recently (within 2 minutes)
    if (_lastInterstitialShow != null) {
      final timeSinceInterstitial =
          DateTime.now().difference(_lastInterstitialShow!);
      if (timeSinceInterstitial.inMinutes < 2) {
        if (kDebugMode) {
          print(
              'Skipping app open ad - interstitial shown recently (${timeSinceInterstitial.inSeconds}s ago)');
        }
        return;
      }
    }

    // Don't show app open ad too frequently (minimum 30 seconds between app open ads)
    if (_lastAppOpenShow != null) {
      final timeSinceLastAppOpen = DateTime.now().difference(_lastAppOpenShow!);
      if (timeSinceLastAppOpen.inSeconds < 30) {
        if (kDebugMode) {
          print('Skipping app open ad - shown too recently');
        }
        return;
      }
    }

    _isShowingAppOpenAd = true;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (kDebugMode) {
          print('App open ad showed');
        }
        _lastAppOpenShow = DateTime.now();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        if (kDebugMode) {
          print('Failed to show app open ad: $error');
        }
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
      onAdDismissedFullScreenContent: (ad) {
        if (kDebugMode) {
          print('App open ad dismissed');
        }
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
    );

    await _appOpenAd!.show();
  }

  // Show app open ad with completion callback
  Future<bool> showAppOpenAdWithCallback({VoidCallback? onCompleted}) async {
    if (!_isInitialized ||
        !ConsentService.instance.shouldShowAds ||
        _isShowingAppOpenAd ||
        !_isAppOpenAdAvailable()) {
      onCompleted?.call();
      return false;
    }

    // Don't show app open ad if an interstitial was shown recently (within 2 minutes)
    if (_lastInterstitialShow != null) {
      final timeSinceInterstitial =
          DateTime.now().difference(_lastInterstitialShow!);
      if (timeSinceInterstitial.inMinutes < 2) {
        if (kDebugMode) {
          print(
              'Skipping app open ad - interstitial shown recently (${timeSinceInterstitial.inSeconds}s ago)');
        }
        onCompleted?.call();
        return false;
      }
    }

    // Don't show app open ad too frequently (minimum 30 seconds between app open ads)
    if (_lastAppOpenShow != null) {
      final timeSinceLastAppOpen = DateTime.now().difference(_lastAppOpenShow!);
      if (timeSinceLastAppOpen.inSeconds < 30) {
        if (kDebugMode) {
          print('Skipping app open ad - shown too recently');
        }
        onCompleted?.call();
        return false;
      }
    }

    _isShowingAppOpenAd = true;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (kDebugMode) {
          print('App open ad showed');
        }
        _lastAppOpenShow = DateTime.now();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        if (kDebugMode) {
          print('Failed to show app open ad: $error');
        }
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
        onCompleted?.call();
      },
      onAdDismissedFullScreenContent: (ad) {
        if (kDebugMode) {
          print('App open ad dismissed');
        }
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
        onCompleted?.call();
      },
    );

    await _appOpenAd!.show();
    return true;
  }

  // Interstitial Ad Management
  Future<void> loadInterstitialAd() async {
    if (!_isInitialized || !ConsentService.instance.shouldShowAds) return;
    if (_interstitialAd != null || _isLoadingInterstitial) return;

    _isLoadingInterstitial = true;
    try {
      await InterstitialAd.load(
        adUnitId: AdHelper.interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isLoadingInterstitial = false;
            _interstitialRetryTimer?.cancel();
            _interstitialRetryTimer = null;
            if (kDebugMode) {
              print('Interstitial ad loaded successfully');
            }
          },
          onAdFailedToLoad: (error) {
            _isLoadingInterstitial = false;
            _scheduleInterstitialRetry();
            if (kDebugMode) {
              print('Failed to load interstitial ad: $error');
            }
          },
        ),
      );
    } catch (e) {
      _isLoadingInterstitial = false;
      _scheduleInterstitialRetry();
      if (kDebugMode) {
        print('Error loading interstitial ad: $e');
      }
    }
  }

  void _scheduleInterstitialRetry() {
    if (_interstitialRetryTimer != null ||
        !_isInitialized ||
        !ConsentService.instance.shouldShowAds) {
      return;
    }

    _interstitialRetryTimer = Timer(_interstitialRetryDelay, () {
      _interstitialRetryTimer = null;
      loadInterstitialAd();
    });
  }

  bool canShowInterstitialAd() {
    if (!_isInitialized ||
        !ConsentService.instance.shouldShowAds ||
        _interstitialAd == null) {
      return false;
    }

    // Prevent showing interstitials too frequently (min 60 seconds apart)
    if (_lastInterstitialShow != null) {
      final difference = DateTime.now().difference(_lastInterstitialShow!);
      if (difference.inSeconds < 60) {
        return false;
      }
    }

    return true;
  }

  Future<void> showInterstitialAd() async {
    _interactionsSinceLastInterstitial++;
    if (kDebugMode) {
      print(
          'Interactions since last interstitial: $_interactionsSinceLastInterstitial');
    }

    // Only allow interstitial after enough user interactions.
    if (_interactionsSinceLastInterstitial <
        _minInteractionsBetweenInterstitials) {
      if (kDebugMode) {
        print(
          'Skipping interstitial ad - waiting for $_minInteractionsBetweenInterstitials interactions',
        );
      }
      return;
    }

    if (!canShowInterstitialAd()) {
      if (_interstitialAd == null) {
        loadInterstitialAd();
      }
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (kDebugMode) {
          print('Interstitial ad showed');
        }
        _lastInterstitialShow = DateTime.now();
        _interactionsSinceLastInterstitial = 0;
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        if (kDebugMode) {
          print('Failed to show interstitial ad: $error');
        }
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
      },
      onAdDismissedFullScreenContent: (ad) {
        if (kDebugMode) {
          print('Interstitial ad dismissed');
        }
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
      },
    );

    await _interstitialAd!.show();
  }

  // Dispose method for cleanup
  void dispose() {
    _appOpenAd?.dispose();
    _interstitialAd?.dispose();
    _interstitialRetryTimer?.cancel();
    _interstitialRetryTimer = null;
  }
}
