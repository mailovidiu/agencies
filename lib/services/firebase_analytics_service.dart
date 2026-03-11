import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:govt_departments_and_agencies/models/department.dart';

/// Service for analytics and reporting (fallback implementation)
///
/// Provides methods to track app usage, generate reports,
/// and analyze department data.
class FirebaseAnalyticsService {
  FirebaseAnalyticsService._();
  static final FirebaseAnalyticsService instance = FirebaseAnalyticsService._();
  factory FirebaseAnalyticsService() => instance;

  Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: _sanitizeParameters(parameters),
      );
    } catch (e) {
      debugPrint('Analytics logEvent failed for $name: $e');
    }
  }

  /// Get total count of departments
  Future<int> getTotalDepartmentsCount() async {
    // Fallback implementation - return a dummy count
    await Future.delayed(Duration(milliseconds: 200)); // Simulate network delay
    return 0;
  }

  /// Get department count by category
  Future<Map<DepartmentCategory, int>> getDepartmentCountByCategory() async {
    await Future.delayed(Duration(milliseconds: 200)); // Simulate network delay
    return {for (final category in DepartmentCategory.values) category: 0};
  }

  /// Get departments created in the last N days
  Future<List<Department>> getRecentlyCreatedDepartments(
      {int days = 30}) async {
    await Future.delayed(Duration(milliseconds: 200)); // Simulate network delay
    return [];
  }

  /// Get departments modified in the last N days
  Future<List<Department>> getRecentlyModifiedDepartments(
      {int days = 7}) async {
    await Future.delayed(Duration(milliseconds: 200)); // Simulate network delay
    return [];
  }

  /// Get most popular tags based on usage
  Future<Map<String, int>> getPopularTags({int limit = 20}) async {
    await Future.delayed(Duration(milliseconds: 200)); // Simulate network delay
    return {};
  }

  /// Get departments without parent (top-level departments)
  Future<List<Department>> getTopLevelDepartments() async {
    await Future.delayed(Duration(milliseconds: 200)); // Simulate network delay
    return [];
  }

  /// Get departments with the most services
  Future<List<Department>> getDepartmentsWithMostServices(
      {int limit = 10}) async {
    await Future.delayed(Duration(milliseconds: 200)); // Simulate network delay
    return [];
  }

  /// Log user activity (for analytics purposes)
  Future<void> logActivity({
    required String action,
    String? departmentId,
    Map<String, dynamic>? metadata,
  }) async {
    final parameters = <String, dynamic>{
      if (departmentId != null) 'department_id': departmentId,
      ...?metadata,
    };
    await logEvent(
      name: action,
      parameters: parameters.isEmpty ? null : parameters,
    );
  }

  Future<void> logCrossPromoAdImpression({
    required String adId,
    required String adTitle,
    required String sourceAppId,
    required String placement,
  }) async {
    await FirebaseAnalytics.instance.logEvent(
      name: 'cross_promo_ad_impression',
      parameters: {
        'ad_id': adId,
        'ad_title': adTitle,
        'source_app_id': sourceAppId,
        'placement': placement,
      },
    );
  }

  Future<void> logCrossPromoAdClick({
    required String adId,
    required String adTitle,
    required String sourceAppId,
    required String placement,
  }) async {
    await FirebaseAnalytics.instance.logEvent(
      name: 'cross_promo_ad_click',
      parameters: {
        'ad_id': adId,
        'ad_title': adTitle,
        'source_app_id': sourceAppId,
        'placement': placement,
      },
    );
  }

  /// Get app statistics
  Future<Map<String, dynamic>> getAppStatistics() async {
    await Future.delayed(Duration(milliseconds: 200)); // Simulate network delay

    return {
      'totalDepartments': 0,
      'departmentsByCategory': {
        for (final category in DepartmentCategory.values)
          category.toString().split('.').last: 0
      },
      'popularTags': {},
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Clean up old activities (for maintenance)
  Future<void> cleanupOldActivities({int daysToKeep = 90}) async {
    // Fallback - no-op
    await Future.delayed(Duration(milliseconds: 100));
  }

  Map<String, Object>? _sanitizeParameters(Map<String, dynamic>? parameters) {
    if (parameters == null || parameters.isEmpty) {
      return null;
    }

    final sanitized = <String, Object>{};
    parameters.forEach((key, value) {
      final normalized = _normalizeValue(value);
      if (normalized != null) {
        sanitized[key] = normalized;
      }
    });
    return sanitized.isEmpty ? null : sanitized;
  }

  Object? _normalizeValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String || value is int || value is double || value is bool) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return value.toString();
  }
}
