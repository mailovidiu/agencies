import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;

class ConsentService extends ChangeNotifier {
  static final ConsentService _instance = ConsentService._internal();
  static ConsentService get instance => _instance;
  ConsentService._internal();

  bool _isInitialized = false;
  bool _canRequestAds = false;
  gma.ConsentStatus _consentStatus = gma.ConsentStatus.unknown;
  gma.PrivacyOptionsRequirementStatus _privacyOptionsRequirementStatus =
      gma.PrivacyOptionsRequirementStatus.unknown;
  String? _lastErrorMessage;
  final Completer<void> _initializationCompleter = Completer<void>();

  bool get isInitialized => _isInitialized;
  bool get shouldShowAds => !kIsWeb && _canRequestAds;
  bool get canRequestAds => !kIsWeb && _canRequestAds;
  bool get isPrivacyOptionsRequired =>
      _privacyOptionsRequirementStatus ==
      gma.PrivacyOptionsRequirementStatus.required;
  gma.ConsentStatus get consentStatus => _consentStatus;
  gma.PrivacyOptionsRequirementStatus get privacyOptionsRequirementStatus =>
      _privacyOptionsRequirementStatus;
  String? get lastErrorMessage => _lastErrorMessage;

  Future<void> waitForInitialization() async {
    if (_isInitialized) return;
    return _initializationCompleter.future;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔒 Initializing UMP consent flow...');

      if (kIsWeb) {
        _canRequestAds = false;
        _consentStatus = gma.ConsentStatus.notRequired;
        _privacyOptionsRequirementStatus =
            gma.PrivacyOptionsRequirementStatus.notRequired;
      } else {
        await _requestConsentUpdateAndShowFormIfNeeded();
      }
    } catch (e) {
      debugPrint('🔒 Error initializing consent flow: $e');
      _lastErrorMessage = e.toString();
      await _syncConsentStateFromSdk();
    } finally {
      _isInitialized = true;
      _notifyStateChanged();
      _completeInitializationIfNeeded();
    }
  }

  Future<bool> showPrivacyOptionsForm() async {
    if (kIsWeb) return false;

    await waitForInitialization();
    await _syncConsentStateFromSdk();

    if (!isPrivacyOptionsRequired) {
      return false;
    }

    try {
      await gma.ConsentForm.showPrivacyOptionsForm((formError) {
        if (formError != null) {
          _lastErrorMessage = formError.message;
          debugPrint(
            '🔒 Privacy options form dismissed with error: ${formError.message}',
          );
        } else {
          _lastErrorMessage = null;
        }
      });
    } catch (e) {
      _lastErrorMessage = e.toString();
      debugPrint('🔒 Failed to show privacy options form: $e');
    }

    await _syncConsentStateFromSdk();
    _notifyStateChanged();
    return true;
  }

  Future<void> resetConsentForTesting() async {
    if (kIsWeb) return;

    await gma.ConsentInformation.instance.reset();
    _canRequestAds = false;
    _consentStatus = gma.ConsentStatus.unknown;
    _privacyOptionsRequirementStatus =
        gma.PrivacyOptionsRequirementStatus.unknown;
    _lastErrorMessage = null;
    _isInitialized = false;
    _notifyStateChanged();

    if (!_initializationCompleter.isCompleted) {
      _completeInitializationIfNeeded();
    }
  }

  String getConsentChoiceDisplayText() {
    switch (_consentStatus) {
      case gma.ConsentStatus.obtained:
        return isPrivacyOptionsRequired
            ? 'Ads enabled. Privacy options available.'
            : 'Ads enabled.';
      case gma.ConsentStatus.notRequired:
        return 'Ads available without additional consent.';
      case gma.ConsentStatus.required:
        return 'Consent is required before ads can be requested.';
      case gma.ConsentStatus.unknown:
        return 'Consent status unavailable.';
    }
  }

  Future<void> _requestConsentUpdateAndShowFormIfNeeded() async {
    final completer = Completer<void>();
    final params = gma.ConsentRequestParameters(
      tagForUnderAgeOfConsent: false,
    );

    gma.ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          _lastErrorMessage = null;
          await _syncConsentStateFromSdk();
          await gma.ConsentForm.loadAndShowConsentFormIfRequired((formError) {
            if (formError != null) {
              _lastErrorMessage = formError.message;
              debugPrint(
                '🔒 Consent form dismissed with error: ${formError.message}',
              );
            }
          });
          await _syncConsentStateFromSdk();
          _notifyStateChanged();
        } catch (e) {
          _lastErrorMessage = e.toString();
          debugPrint('🔒 Error during consent form flow: $e');
          await _syncConsentStateFromSdk();
        } finally {
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      },
      (formError) async {
        _lastErrorMessage = formError.message;
        debugPrint(
          '🔒 Consent info update failed: ${formError.errorCode} ${formError.message}',
        );
        try {
          await _syncConsentStateFromSdk();
          _notifyStateChanged();
        } finally {
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      },
    );

    await completer.future;
  }

  Future<void> _syncConsentStateFromSdk() async {
    if (kIsWeb) {
      return;
    }

    try {
      _canRequestAds = await gma.ConsentInformation.instance.canRequestAds();
      _consentStatus = await gma.ConsentInformation.instance.getConsentStatus();
      _privacyOptionsRequirementStatus = await gma.ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
    } catch (e) {
      debugPrint('🔒 Failed to sync consent state from SDK: $e');
    }
  }

  void _notifyStateChanged() {
    if (hasListeners) {
      notifyListeners();
    }
  }

  void _completeInitializationIfNeeded() {
    if (!_initializationCompleter.isCompleted) {
      _initializationCompleter.complete();
    }
  }
}
