import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

enum AdConsentChoice {
  notSet,
  personalizedAds,
  nonPersonalizedAds,
  declined
}

enum ConsentStatus {
  unknown,
  required,
  notRequired,
  obtained
}

class ConsentService {
  static final ConsentService _instance = ConsentService._internal();
  static ConsentService get instance => _instance;
  ConsentService._internal();

  static const String _keyAdConsentChoice = 'ad_consent_choice';
  static const String _keyConsentTimestamp = 'consent_timestamp';

  AdConsentChoice _userChoice = AdConsentChoice.notSet;
  ConsentStatus _consentStatus = ConsentStatus.unknown;
  bool _isInitialized = false;
  final Completer<void> _initializationCompleter = Completer<void>();

  AdConsentChoice get userChoice => _userChoice;
  ConsentStatus get consentStatus => _consentStatus;
  bool get isInitialized => _isInitialized;
  
  // Whether ads should be shown at all (now always true since we only have ad options)
  bool get shouldShowAds => _userChoice == AdConsentChoice.personalizedAds || 
                           _userChoice == AdConsentChoice.nonPersonalizedAds;
  
  // Whether personalized ads can be shown
  bool get canShowPersonalizedAds => _userChoice == AdConsentChoice.personalizedAds;

  Future<void> waitForInitialization() async {
    if (_isInitialized) return;
    return _initializationCompleter.future;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔒 Initializing ConsentService...');
      await _loadPreferences();
      
      // If user hasn't made a choice yet or previously chose declined, set to non-personalized ads as default
      if (_userChoice == AdConsentChoice.notSet || _userChoice == AdConsentChoice.declined) {
        debugPrint('🔒 First run or declined choice detected - setting default consent to non-personalized ads');
        _userChoice = AdConsentChoice.nonPersonalizedAds;
        await _savePreferences();
      }
      
      _consentStatus = _getConsentStatusFromChoice();
      _isInitialized = true;
      
      debugPrint('🔒 ConsentService initialized - choice: $_userChoice, shouldShowAds: $shouldShowAds');
      
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }
    } catch (e) {
      debugPrint('🔒 Error initializing ConsentService: $e');
      // Fallback to safe defaults
      _userChoice = AdConsentChoice.nonPersonalizedAds;
      _consentStatus = ConsentStatus.obtained;
      _isInitialized = true;
      
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }
    }
  }

  ConsentStatus _getConsentStatusFromChoice() {
    switch (_userChoice) {
      case AdConsentChoice.personalizedAds:
      case AdConsentChoice.nonPersonalizedAds:
        return ConsentStatus.obtained;
      case AdConsentChoice.declined:
        return ConsentStatus.obtained; // Treat legacy declined as obtained (will be migrated)
      case AdConsentChoice.notSet:
        return ConsentStatus.required;
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final choiceIndex = prefs.getInt(_keyAdConsentChoice);
    
    if (choiceIndex != null && choiceIndex >= 0 && choiceIndex < AdConsentChoice.values.length) {
      _userChoice = AdConsentChoice.values[choiceIndex];
      debugPrint('🔒 Loaded user consent choice: $_userChoice');
    } else {
      _userChoice = AdConsentChoice.notSet;
      debugPrint('🔒 No previous consent choice found');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyAdConsentChoice, _userChoice.index);
      await prefs.setInt(_keyConsentTimestamp, DateTime.now().millisecondsSinceEpoch);
      debugPrint('🔒 Saved consent choice: $_userChoice');
    } catch (e) {
      debugPrint('🔒 Error saving consent preferences: $e');
    }
  }

  Future<void> updateConsentChoice(AdConsentChoice choice) async {
    debugPrint('🔒 Updating consent choice to: $choice');
    
    _userChoice = choice;
    _consentStatus = _getConsentStatusFromChoice();
    await _savePreferences();
    
    debugPrint('🔒 Consent updated - shouldShowAds: $shouldShowAds, canShowPersonalizedAds: $canShowPersonalizedAds');
  }

  Future<void> resetConsent() async {
    debugPrint('🔒 Resetting consent preferences');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAdConsentChoice);
      await prefs.remove(_keyConsentTimestamp);
      
      _userChoice = AdConsentChoice.notSet;
      _consentStatus = ConsentStatus.unknown;
      
      debugPrint('🔒 Consent preferences reset');
    } catch (e) {
      debugPrint('🔒 Error resetting consent: $e');
    }
  }

  String getConsentChoiceDisplayText() {
    switch (_userChoice) {
      case AdConsentChoice.personalizedAds:
        return 'Personalized ads';
      case AdConsentChoice.nonPersonalizedAds:
        return 'Non-personalized ads';
      case AdConsentChoice.declined:
        return 'Non-personalized ads'; // Fallback for legacy declined users
      case AdConsentChoice.notSet:
        return 'Non-personalized ads'; // Fallback for unset users
    }
  }
}