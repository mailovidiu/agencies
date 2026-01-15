import 'package:flutter/foundation.dart';

// Stub for web platform since ATT is iOS-only
enum TrackingStatus {
  notDetermined,
  restricted,
  denied,
  authorized,
}

class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  bool get hasRequestedPermission => true;
  TrackingStatus get trackingStatus => TrackingStatus.authorized;
  bool get isTrackingAllowed => true;

  /// Web doesn't need ATT - always return authorized
  Future<TrackingStatus> requestTrackingAuthorization() async {
    debugPrint('🔒 Web platform - tracking authorization not required');
    return TrackingStatus.authorized;
  }

  /// Web doesn't need ATT - always return authorized
  Future<TrackingStatus> getTrackingAuthorizationStatus() async {
    return TrackingStatus.authorized;
  }

  /// Web doesn't have IDFA
  Future<String?> getAdvertisingIdentifier() async {
    return null;
  }
}