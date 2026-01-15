import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/department.dart';
import '../firestore/firestore_data_schema.dart';

/// Firebase service for admin operations and management
/// Provides high-level administrative functions for the department app
class FirebaseAdminService {
  static final FirebaseAdminService _instance = FirebaseAdminService._internal();
  factory FirebaseAdminService() => _instance;
  FirebaseAdminService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current admin user information
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;

  /// Initialize admin service and ensure collections exist
  Future<void> initialize() async {
    try {
      print('Initializing Firebase Admin Service...');
      
      // Ensure Firestore is properly initialized
      await _firestore.waitForPendingWrites();
      
      // Create initial app settings if they don't exist
      await _initializeAppSettings();
      
      print('Firebase Admin Service initialized successfully');
    } catch (e) {
      print('Error initializing Firebase Admin Service: $e');
    }
  }

  /// Initialize default app settings
  Future<void> _initializeAppSettings() async {
    try {
      final settingsCollection = FirestoreDataSchema.appSettingsRef;
      
      // Check if app version setting exists
      final appVersionDoc = await settingsCollection.doc('app_version').get();
      if (!appVersionDoc.exists) {
        await settingsCollection.doc('app_version').set(
          FirestoreDataSchema.createAppSettingDocument(
            key: 'app_version',
            value: '1.0.0',
            description: 'Current version of the department app',
            updatedBy: currentUser?.uid,
          )
        );
      }

      // Check if maintenance mode setting exists
      final maintenanceDoc = await settingsCollection.doc('maintenance_mode').get();
      if (!maintenanceDoc.exists) {
        await settingsCollection.doc('maintenance_mode').set(
          FirestoreDataSchema.createAppSettingDocument(
            key: 'maintenance_mode',
            value: false,
            description: 'Whether the app is in maintenance mode',
            updatedBy: currentUser?.uid,
          )
        );
      }
    } catch (e) {
      print('Error initializing app settings: $e');
    }
  }

  /// Bulk import departments from a list
  Future<bool> bulkImportDepartments(List<Department> departments) async {
    if (departments.isEmpty) return false;

    try {
      final batch = _firestore.batch();
      final collection = FirestoreDataSchema.departmentsRef;

      for (final department in departments) {
        final docRef = collection.doc(department.id);
        final data = FirestoreDataSchema.createDepartmentDocument(department);
        batch.set(docRef, data);
      }

      await batch.commit();
      
      // Log the operation
      await _logAdminActivity(
        'bulk_import_departments',
        'Imported ${departments.length} departments',
      );

      print('Successfully imported ${departments.length} departments');
      return true;
    } catch (e) {
      print('Error importing departments: $e');
      return false;
    }
  }

  /// Get comprehensive dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final departments = FirestoreDataSchema.departmentsRef;
      
      // Get all departments at once to avoid multiple queries
      final allDepartmentsSnapshot = await departments.get();
      final allDepartments = allDepartmentsSnapshot.docs;

      final activeDepartments = allDepartments.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['isActive'] == true;
      }).toList();
      
      final popularDepartments = allDepartments.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['isPopular'] == true;
      }).toList();

      final inactiveDepartments = allDepartments.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['isActive'] == false;
      }).toList();

      // Category breakdown
      final categoryStats = <String, int>{};
      for (final doc in activeDepartments) {
        final data = doc.data() as Map<String, dynamic>?;
        final category = data?['category'] as String?;
        if (category != null) {
          categoryStats[category] = (categoryStats[category] ?? 0) + 1;
        }
      }

      // Recently updated (last 7 days)
      final weekAgo = DateTime.now().subtract(Duration(days: 7));
      final recentlyUpdated = allDepartments.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        final lastUpdated = data?['lastUpdated'] as Timestamp?;
        return lastUpdated != null && 
               lastUpdated.toDate().isAfter(weekAgo);
      }).length;

      return {
        'totals': {
          'total_departments': allDepartments.length,
          'active_departments': activeDepartments.length,
          'inactive_departments': inactiveDepartments.length,
          'popular_departments': popularDepartments.length,
          'recently_updated': recentlyUpdated,
        },
        'categories': categoryStats,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return {'error': e.toString()};
    }
  }

  /// Mark departments as popular/unpopular in bulk
  Future<bool> bulkUpdatePopularStatus(List<String> departmentIds, bool isPopular) async {
    if (departmentIds.isEmpty) return false;

    try {
      final batch = _firestore.batch();
      final collection = FirestoreDataSchema.departmentsRef;

      for (final id in departmentIds) {
        final docRef = collection.doc(id);
        batch.update(docRef, {
          'isPopular': isPopular,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Log the operation
      await _logAdminActivity(
        'bulk_update_popular',
        '${isPopular ? "Marked" : "Unmarked"} ${departmentIds.length} departments as popular',
      );

      return true;
    } catch (e) {
      print('Error updating popular status: $e');
      return false;
    }
  }

  /// Archive/unarchive departments in bulk
  Future<bool> bulkArchiveDepartments(List<String> departmentIds, bool archive) async {
    if (departmentIds.isEmpty) return false;

    try {
      final batch = _firestore.batch();
      final collection = FirestoreDataSchema.departmentsRef;

      for (final id in departmentIds) {
        final docRef = collection.doc(id);
        batch.update(docRef, {
          'isActive': !archive,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Log the operation
      await _logAdminActivity(
        'bulk_archive',
        '${archive ? "Archived" : "Unarchived"} ${departmentIds.length} departments',
      );

      return true;
    } catch (e) {
      print('Error archiving departments: $e');
      return false;
    }
  }

  /// Delete departments permanently (use with caution)
  Future<bool> bulkDeleteDepartments(List<String> departmentIds) async {
    if (departmentIds.isEmpty) return false;

    try {
      final batch = _firestore.batch();
      final collection = FirestoreDataSchema.departmentsRef;

      for (final id in departmentIds) {
        final docRef = collection.doc(id);
        batch.delete(docRef);
      }

      await batch.commit();

      // Log the operation
      await _logAdminActivity(
        'bulk_delete',
        'Permanently deleted ${departmentIds.length} departments',
      );

      return true;
    } catch (e) {
      print('Error deleting departments: $e');
      return false;
    }
  }

  /// Create or update an admin user
  Future<bool> createAdminUser({
    required String uid,
    required String email,
    String? displayName,
    String role = 'admin',
    List<String> permissions = const ['read', 'write'],
  }) async {
    try {
      final adminDoc = FirestoreDataSchema.adminUsersRef.doc(uid);
      final adminData = FirestoreDataSchema.createAdminUserDocument(
        uid: uid,
        email: email,
        displayName: displayName,
        role: role,
        permissions: permissions,
      );

      await adminDoc.set(adminData, SetOptions(merge: true));
      
      // Log the operation
      await _logAdminActivity(
        'create_admin_user',
        'Created admin user: $email',
      );

      return true;
    } catch (e) {
      print('Error creating admin user: $e');
      return false;
    }
  }

  /// Get all admin users
  Future<List<Map<String, dynamic>>> getAdminUsers() async {
    try {
      final snapshot = await FirestoreDataSchema.adminUsersRef
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting admin users: $e');
      return [];
    }
  }

  /// Update app setting
  Future<bool> updateAppSetting(String key, dynamic value, [String? description]) async {
    try {
      final settingData = FirestoreDataSchema.createAppSettingDocument(
        key: key,
        value: value,
        description: description,
        updatedBy: currentUser?.uid,
      );

      await FirestoreDataSchema.appSettingsRef.doc(key).set(settingData);
      
      // Log the operation
      await _logAdminActivity(
        'update_app_setting',
        'Updated app setting: $key = $value',
      );

      return true;
    } catch (e) {
      print('Error updating app setting: $e');
      return false;
    }
  }

  /// Get all app settings
  Future<Map<String, dynamic>> getAppSettings() async {
    try {
      final snapshot = await FirestoreDataSchema.appSettingsRef.get();
      
      final settings = <String, dynamic>{};
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        settings[doc.id] = data['value'];
      }
      
      return settings;
    } catch (e) {
      print('Error getting app settings: $e');
      return {};
    }
  }

  /// Export all departments as JSON
  Future<List<Map<String, dynamic>>> exportDepartmentsAsJson() async {
    try {
      final snapshot = await FirestoreDataSchema.departmentsRef
          .orderBy('name')
          .get();

      final departments = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        // Convert Timestamps to ISO strings for JSON export
        if (data['createdAt'] is Timestamp) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        if (data['lastUpdated'] is Timestamp) {
          data['lastUpdated'] = (data['lastUpdated'] as Timestamp).toDate().toIso8601String();
        }
        
        return data;
      }).toList();

      // Log the operation
      await _logAdminActivity(
        'export_departments',
        'Exported ${departments.length} departments as JSON',
      );

      return departments;
    } catch (e) {
      print('Error exporting departments: $e');
      return [];
    }
  }

  /// Log admin activities for audit trail
  Future<void> _logAdminActivity(String action, String description) async {
    try {
      if (currentUser == null) return;

      await _firestore.collection('admin_activities').add({
        'action': action,
        'description': description,
        'adminUid': currentUser!.uid,
        'adminEmail': currentUser!.email,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging admin activity: $e');
    }
  }

  /// Get recent admin activities (for audit log)
  Future<List<Map<String, dynamic>>> getRecentAdminActivities({int limit = 50}) async {
    try {
      final snapshot = await _firestore.collection('admin_activities')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting admin activities: $e');
      return [];
    }
  }

  /// Validate Firestore connection and rules
  Future<Map<String, dynamic>> validateFirestoreSetup() async {
    try {
      final results = <String, dynamic>{};
      
      // Test read access
      try {
        final testSnapshot = await FirestoreDataSchema.departmentsRef.limit(1).get();
        results['read_access'] = true;
        results['read_test'] = 'Success';
      } catch (e) {
        results['read_access'] = false;
        results['read_error'] = e.toString();
      }

      // Test write access (if authenticated)
      if (isAuthenticated) {
        try {
          final testDoc = FirestoreDataSchema.departmentsRef.doc('_test_doc_');
          await testDoc.set({'test': true, 'timestamp': FieldValue.serverTimestamp()});
          await testDoc.delete();
          results['write_access'] = true;
          results['write_test'] = 'Success';
        } catch (e) {
          results['write_access'] = false;
          results['write_error'] = e.toString();
        }
      } else {
        results['write_access'] = false;
        results['write_error'] = 'Not authenticated';
      }

      // Check if indexes are needed
      try {
        await FirestoreDataSchema.getPopularDepartments().limit(1).get();
        results['popular_index'] = true;
      } catch (e) {
        results['popular_index'] = false;
        results['popular_index_error'] = 'Index may be needed for popular departments query';
      }

      results['timestamp'] = DateTime.now().toIso8601String();
      return results;
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}