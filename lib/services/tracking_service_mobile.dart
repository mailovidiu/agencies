import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  bool _hasRequestedPermission = false;
  TrackingStatus _trackingStatus = TrackingStatus.notDetermined;

  bool get hasRequestedPermission => _hasRequestedPermission;
  TrackingStatus get trackingStatus => _trackingStatus;
  bool get isTrackingAllowed => _trackingStatus == TrackingStatus.authorized;

  /// Request app tracking transparency permission
  Future<TrackingStatus> requestTrackingAuthorization() async {
    if (!Platform.isIOS) {
      // Android doesn't need ATT
      _trackingStatus = TrackingStatus.authorized;
      return _trackingStatus;
    }

    if (_hasRequestedPermission) {
      return _trackingStatus;
    }

    try {
      // Check if we can request permission
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      debugPrint('🔒 Current tracking status: $status');

      if (status == TrackingStatus.notDetermined) {
        debugPrint('🔒 Requesting tracking authorization...');
        _trackingStatus = await AppTrackingTransparency.requestTrackingAuthorization();
        debugPrint('🔒 Tracking authorization result: $_trackingStatus');
      } else {
        _trackingStatus = status;
      }

      _hasRequestedPermission = true;
      return _trackingStatus;
    } catch (e) {
      debugPrint('🔒 Error requesting tracking authorization: $e');
      // Fallback to denied on error
      _trackingStatus = TrackingStatus.denied;
      _hasRequestedPermission = true;
      return _trackingStatus;
    }
  }

  /// Get current tracking status without requesting
  Future<TrackingStatus> getTrackingAuthorizationStatus() async {
    if (!Platform.isIOS) {
      return TrackingStatus.authorized;
    }

    try {
      _trackingStatus = await AppTrackingTransparency.trackingAuthorizationStatus;
      return _trackingStatus;
    } catch (e) {
      debugPrint('🔒 Error getting tracking status: $e');
      return TrackingStatus.notDetermined;
    }
  }

  /// Get the advertising identifier (IDFA)
  Future<String?> getAdvertisingIdentifier() async {
    if (!Platform.isIOS) {
      return null; // Android uses advertising ID differently
    }

    try {
      if (_trackingStatus == TrackingStatus.authorized) {
        return await AppTrackingTransparency.getAdvertisingIdentifier();
      }
      return null;
    } catch (e) {
      debugPrint('🔒 Error getting advertising identifier: $e');
      return null;
    }
  }
}