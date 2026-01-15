import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/department.dart';

/// Defines the data schema and structure for Firestore collections
/// This file serves as documentation and reference for the database structure

class FirestoreDataSchema {
  /// Collection names used in Firestore
  static const String departmentsCollection = 'departments';
  static const String adminUsersCollection = 'admin_users';
  static const String appSettingsCollection = 'app_settings';

  /// Department document structure
  /// Collection: departments/{departmentId}
  static Map<String, dynamic> get departmentSchema => {
    'name': 'string',                    // Department full name (required)
    'shortName': 'string',               // Department abbreviation (required)
    'description': 'string',             // Detailed description (required)
    'category': 'string',                // DepartmentCategory enum value (required)
    'contactInfo': {                     // Contact information object (required)
      'phone': 'string',
      'email': 'string', 
      'website': 'string',
      'address': 'string',
      'fax': 'string?',                  // Optional
      'socialMedia': 'Map<String, String>?', // Optional
    },
    'services': 'List<String>',          // List of services provided (required)
    'keywords': 'List<String>',          // Search keywords (required)
    'isActive': 'bool',                  // Whether department is active (required)
    'lastUpdated': 'Timestamp?',         // Last modification time (optional)
    'createdAt': 'Timestamp?',           // Creation time (optional)
    'logoPath': 'string?',               // Path to department logo (optional)
    'parentDepartmentId': 'string?',     // Reference to parent department (optional)
    'tags': 'List<String>',              // Organizational tags (required, can be empty)
    'location': {                        // Location information (optional)
      'address': 'string',
      'city': 'string?',
      'state': 'string?',
      'zipCode': 'string?',
      'country': 'string?',
      'latitude': 'double?',
      'longitude': 'double?',
      'mapLink': 'string?',
    },
    'officeHours': {                     // Operating hours information (optional)
      'weeklyHours': 'Map<String, String>', // Day -> hours mapping
      'holidays': 'List<String>',
      'specialInstructions': 'string?',
      'isOpen24x7': 'bool',
      'emergencyContact': 'string?',
    },
    'isPopular': 'bool',                 // Whether department is marked as popular (required)
  };

  /// Admin user document structure
  /// Collection: admin_users/{userId}
  static Map<String, dynamic> get adminUserSchema => {
    'uid': 'string',                     // Firebase Auth UID
    'email': 'string',                   // Admin email address
    'displayName': 'string?',            // Optional display name
    'role': 'string',                    // Admin role (e.g., 'admin', 'super_admin')
    'permissions': 'List<String>',       // List of permissions
    'createdAt': 'Timestamp',            // Account creation time
    'lastActive': 'Timestamp?',          // Last activity timestamp
    'isActive': 'bool',                  // Whether admin account is active
  };

  /// App settings document structure
  /// Collection: app_settings/{settingKey}
  static Map<String, dynamic> get appSettingsSchema => {
    'key': 'string',                     // Setting key identifier
    'value': 'dynamic',                  // Setting value (can be any type)
    'description': 'string?',            // Optional description
    'lastUpdated': 'Timestamp',          // Last modification time
    'updatedBy': 'string?',              // UID of user who made the change
  };

  /// Sample department categories
  static List<String> get departmentCategories => [
    'health',
    'education', 
    'transportation',
    'finance',
    'security',
    'environment',
    'agriculture',
    'socialServices',
    'defense',
    'justice',
    'commerce',
    'labor',
    'energy',
    'housing',
    'veterans',
    'other',
  ];

  /// Common query patterns and their required indexes
  static Map<String, List<String>> get commonQueries => {
    'getDepartmentsByCategory': ['category', 'name'],
    'getDepartmentsByTag': ['tags', 'name'],  
    'getActiveDepartmentsByLastUpdated': ['isActive', 'lastUpdated'],
    'getDepartmentsByParent': ['parentDepartmentId', 'name'],
    'getActiveDepartmentsByCategory': ['isActive', 'category', 'name'],
    'getPopularDepartments': ['isPopular', 'name'],
    'getActiveDepartments': ['isActive', 'name'],
  };

  /// Validation rules for department data
  static bool validateDepartmentData(Map<String, dynamic> data) {
    // Required fields check
    final requiredFields = ['name', 'shortName', 'description', 'category', 
                           'contactInfo', 'services', 'keywords', 'isActive'];
    
    for (final field in requiredFields) {
      if (!data.containsKey(field)) return false;
    }

    // Type validation
    if (data['name'] is! String || (data['name'] as String).isEmpty) return false;
    if (data['shortName'] is! String || (data['shortName'] as String).isEmpty) return false;
    if (data['description'] is! String) return false;
    if (data['category'] is! String) return false;
    if (data['isActive'] is! bool) return false;
    if (data['services'] is! List) return false;
    if (data['keywords'] is! List) return false;

    // Category validation
    if (!departmentCategories.contains(data['category'])) return false;

    // Contact info validation
    if (data['contactInfo'] is! Map<String, dynamic>) return false;
    final contactInfo = data['contactInfo'] as Map<String, dynamic>;
    final requiredContactFields = ['phone', 'email', 'website', 'address'];
    for (final field in requiredContactFields) {
      if (!contactInfo.containsKey(field) || contactInfo[field] is! String) {
        return false;
      }
    }

    return true;
  }

  /// Helper to create a new department document with proper structure
  static Map<String, dynamic> createDepartmentDocument(Department department) {
    final data = department.toFirestore();
    
    // Ensure timestamps are properly set
    final now = Timestamp.now();
    data['lastUpdated'] = now;
    if (data['createdAt'] == null) {
      data['createdAt'] = now;
    }

    return data;
  }

  /// Helper to create admin user document
  static Map<String, dynamic> createAdminUserDocument({
    required String uid,
    required String email,
    String? displayName,
    String role = 'admin',
    List<String> permissions = const ['read', 'write'],
  }) {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role,
      'permissions': permissions,
      'createdAt': Timestamp.now(),
      'lastActive': Timestamp.now(),
      'isActive': true,
    };
  }

  /// Helper to create app setting document  
  static Map<String, dynamic> createAppSettingDocument({
    required String key,
    required dynamic value,
    String? description,
    String? updatedBy,
  }) {
    return {
      'key': key,
      'value': value,
      'description': description,
      'lastUpdated': Timestamp.now(),
      'updatedBy': updatedBy,
    };
  }

  /// Get Firestore collection references
  static CollectionReference get departmentsRef => 
      FirebaseFirestore.instance.collection(departmentsCollection);
  
  static CollectionReference get adminUsersRef => 
      FirebaseFirestore.instance.collection(adminUsersCollection);
  
  static CollectionReference get appSettingsRef => 
      FirebaseFirestore.instance.collection(appSettingsCollection);

  /// Common queries as methods
  static Query getDepartmentsByCategory(DepartmentCategory category) =>
      departmentsRef
          .where('category', isEqualTo: category.name)
          .orderBy('name');

  static Query getDepartmentsByTag(String tag) =>
      departmentsRef
          .where('tags', arrayContains: tag)
          .orderBy('name');

  static Query getActiveDepartments() =>
      departmentsRef
          .where('isActive', isEqualTo: true)
          .orderBy('name');

  static Query getPopularDepartments() =>
      departmentsRef
          .where('isPopular', isEqualTo: true)
          .orderBy('name');

  static Query getDepartmentsByParent(String? parentId) {
    if (parentId != null) {
      return departmentsRef
          .where('parentDepartmentId', isEqualTo: parentId)
          .orderBy('name');
    } else {
      return departmentsRef
          .where('parentDepartmentId', isNull: true)
          .orderBy('name');
    }
  }

  static Query getRecentlyUpdatedDepartments({int limit = 10}) =>
      departmentsRef
          .where('isActive', isEqualTo: true)
          .orderBy('lastUpdated', descending: true)
          .limit(limit);

  /// Aggregate queries
  static AggregateQuery getTotalDepartmentCount() =>
      departmentsRef.count();

  static AggregateQuery getActiveDepartmentCount() =>
      departmentsRef
          .where('isActive', isEqualTo: true)
          .count();

  static AggregateQuery getDepartmentCountByCategory(DepartmentCategory category) =>
      departmentsRef
          .where('category', isEqualTo: category.name)
          .where('isActive', isEqualTo: true)
          .count();
}