import 'dart:convert';
import '../models/department.dart';
import 'department_repository.dart';
import 'firebase_department_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hybrid repository that combines Firebase (for global access) and local storage (for reliability)
/// 
/// Strategy:
/// 1. Always try to use Firebase first for read/write operations
/// 2. Cache data locally for offline access and backup
/// 3. Sync local cache with Firebase when available
/// 4. Fall back to local cache if Firebase fails
class HybridDepartmentRepository implements DepartmentRepository {
  FirebaseDepartmentRepository? _firebaseRepo;
  SharedPreferences? _prefs;
  bool _isFirebaseAvailable = false;
  static const String _localDataKey = 'departments_cache';
  
  /// Initialize the hybrid repository
  Future<void> initialize() async {
    try {
      // Initialize SharedPreferences for local caching
      _prefs = await SharedPreferences.getInstance();
      print('Local storage initialized successfully');
      
      // Try to initialize Firebase
      if (Firebase.apps.isNotEmpty) {
        _firebaseRepo = FirebaseDepartmentRepository();
        _isFirebaseAvailable = true;
        print('Firebase repository initialized successfully');
        
        // Try to sync from Firebase to local cache
        await _syncFromFirebaseToLocal();
      } else {
        print('Firebase not available, using local storage only');
      }
    } catch (e) {
      print('Hybrid repository initialization warning: $e');
      _isFirebaseAvailable = false;
    }
    
    // Ensure we have some sample data if nothing exists locally
    await _ensureSampleData();
  }
  
  /// Sync data from Firebase to local cache
  Future<void> _syncFromFirebaseToLocal() async {
    if (!_isFirebaseAvailable || _firebaseRepo == null) return;
    
    try {
      final departments = await _firebaseRepo!.getDepartments();
      await _saveToLocalCache(departments);
      print('Synced ${departments.length} departments from Firebase to local cache');
    } catch (e) {
      print('Failed to sync from Firebase: $e');
    }
  }
  
  /// Save departments to local cache
  Future<void> _saveToLocalCache(List<Department> departments) async {
    if (_prefs == null) return;
    
    try {
      final jsonList = departments.map((dept) => dept.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await _prefs!.setString(_localDataKey, jsonString);
    } catch (e) {
      print('Failed to save to local cache: $e');
    }
  }
  
  /// Load departments from local cache
  Future<List<Department>> _loadFromLocalCache() async {
    if (_prefs == null) return [];
    
    try {
      final jsonString = _prefs!.getString(_localDataKey);
      if (jsonString == null || jsonString.isEmpty) return [];
      
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => Department.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Failed to load from local cache: $e');
      return [];
    }
  }
  
  /// Ensure we have sample data if nothing exists
  Future<void> _ensureSampleData() async {
    final existingDepartments = await _loadFromLocalCache();
    if (existingDepartments.isEmpty) {
      print('No data found, loading sample departments');
      final sampleDepartments = _getSampleDepartments();
      await _saveToLocalCache(sampleDepartments);
    }
  }
  
  @override
  Future<List<Department>> getDepartments() async {
    // Try Firebase first
    if (_isFirebaseAvailable && _firebaseRepo != null) {
      try {
        final departments = await _firebaseRepo!.getDepartments();
        // Update local cache with fresh data
        await _saveToLocalCache(departments);
        return departments;
      } catch (e) {
        print('Firebase read failed, falling back to local cache: $e');
      }
    }
    
    // Fall back to local cache
    return await _loadFromLocalCache();
  }
  
  @override
  Future<List<Department>> getDepartmentsByCategory(DepartmentCategory category) async {
    final departments = await getDepartments();
    return departments.where((dept) => dept.category == category).toList();
  }
  
  @override
  Future<Department?> getDepartmentById(String id) async {
    final departments = await getDepartments();
    try {
      return departments.firstWhere((dept) => dept.id == id);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<List<Department>> searchDepartments(String query) async {
    final departments = await getDepartments();
    final lowerQuery = query.toLowerCase();
    return departments.where((dept) =>
      dept.name.toLowerCase().contains(lowerQuery) ||
      dept.shortName.toLowerCase().contains(lowerQuery) ||
      dept.description.toLowerCase().contains(lowerQuery) ||
      dept.services.any((service) => service.toLowerCase().contains(lowerQuery)) ||
      dept.keywords.any((keyword) => keyword.toLowerCase().contains(lowerQuery)) ||
      dept.tags.any((tag) => tag.toLowerCase().contains(lowerQuery))
    ).toList();
  }
  
  @override
  Future<List<Department>> getDepartmentsByTag(String tag) async {
    final departments = await getDepartments();
    return departments.where((dept) => dept.tags.contains(tag)).toList();
  }
  
  @override
  Future<void> addDepartment(Department department) async {
    // Try Firebase first
    if (_isFirebaseAvailable && _firebaseRepo != null) {
      try {
        await _firebaseRepo!.addDepartment(department);
        print('Department added to Firebase successfully');
      } catch (e) {
        print('Failed to add department to Firebase: $e');
      }
    }
    
    // Always update local cache
    final departments = await _loadFromLocalCache();
    departments.add(department);
    await _saveToLocalCache(departments);
    print('Department added to local cache');
  }
  
  @override
  Future<void> updateDepartment(Department department) async {
    // Try Firebase first
    if (_isFirebaseAvailable && _firebaseRepo != null) {
      try {
        await _firebaseRepo!.updateDepartment(department);
        print('Department updated in Firebase successfully');
      } catch (e) {
        print('Failed to update department in Firebase: $e');
      }
    }
    
    // Always update local cache
    final departments = await _loadFromLocalCache();
    final index = departments.indexWhere((dept) => dept.id == department.id);
    if (index != -1) {
      departments[index] = department;
      await _saveToLocalCache(departments);
      print('Department updated in local cache');
    }
  }
  
  @override
  Future<void> deleteDepartment(String id) async {
    // Try Firebase first
    if (_isFirebaseAvailable && _firebaseRepo != null) {
      try {
        await _firebaseRepo!.deleteDepartment(id);
        print('Department deleted from Firebase successfully');
      } catch (e) {
        print('Failed to delete department from Firebase: $e');
      }
    }
    
    // Always update local cache
    final departments = await _loadFromLocalCache();
    departments.removeWhere((dept) => dept.id == id);
    await _saveToLocalCache(departments);
    print('Department deleted from local cache');
  }
  
  @override
  Future<void> createDepartments(List<Department> departments) async {
    // Try Firebase first
    if (_isFirebaseAvailable && _firebaseRepo != null) {
      try {
        await _firebaseRepo!.createDepartments(departments);
        print('${departments.length} departments created in Firebase successfully');
      } catch (e) {
        print('Failed to create departments in Firebase: $e');
      }
    }
    
    // Always update local cache
    final existingDepartments = await _loadFromLocalCache();
    existingDepartments.addAll(departments);
    await _saveToLocalCache(existingDepartments);
    print('${departments.length} departments created in local cache');
  }
  
  @override
  Future<List<Department>> getPopularDepartments() async {
    // Try Firebase first for optimized query
    if (_isFirebaseAvailable && _firebaseRepo != null) {
      try {
        final popularDepartments = await _firebaseRepo!.getPopularDepartments();
        return popularDepartments;
      } catch (e) {
        print('Firebase popular departments query failed, falling back to local: $e');
      }
    }
    
    // Fall back to local cache
    final departments = await _loadFromLocalCache();
    return departments.where((dept) => dept.isPopular).toList();
  }

  @override
  Future<List<Department>> getDepartmentsByParent(String? parentId) async {
    // Try Firebase first for optimized query
    if (_isFirebaseAvailable && _firebaseRepo != null) {
      try {
        final childDepartments = await _firebaseRepo!.getDepartmentsByParent(parentId);
        return childDepartments;
      } catch (e) {
        print('Firebase parent departments query failed, falling back to local: $e');
      }
    }
    
    // Fall back to local cache
    final departments = await _loadFromLocalCache();
    return departments.where((dept) => dept.parentDepartmentId == parentId).toList();
  }

  @override
  Future<List<Department>> getActiveDepartments() async {
    final departments = await getDepartments();
    return departments.where((dept) => dept.isActive).toList();
  }
  
  /// Force sync from Firebase (manual sync)
  Future<void> forceSyncFromFirebase() async {
    if (_isFirebaseAvailable && _firebaseRepo != null) {
      await _syncFromFirebaseToLocal();
    }
  }
  
  /// Check if Firebase is available
  bool get isFirebaseAvailable => _isFirebaseAvailable;
  
  /// Get connection status
  String get connectionStatus {
    if (_isFirebaseAvailable) return 'Firebase + Local Cache';
    return 'Local Cache Only';
  }
  
  /// Sample departments for initial data
  List<Department> _getSampleDepartments() {
    return [
      Department(
        id: 'hhs-001',
        name: 'Department of Health and Human Services',
        shortName: 'HHS',
        description: 'The United States Department of Health and Human Services (HHS) is a cabinet-level executive branch department of the U.S. federal government created to protect the health of all Americans and provide essential human services.',
        category: DepartmentCategory.health,
        isPopular: true,
        lastUpdated: DateTime.now(),
        contactInfo: ContactInfo(
          email: 'info@hhs.gov',
          phone: '1-877-696-6775',
          website: 'https://www.hhs.gov',
          address: '200 Independence Avenue, S.W., Washington, D.C. 20201',
        ),
        services: [
          'Medicare and Medicaid administration',
          'Centers for Disease Control and Prevention (CDC)',
          'Food and Drug Administration (FDA)',
          'National Institutes of Health (NIH)',
          'Administration for Children and Families',
          'Substance Abuse and Mental Health Services',
        ],
        keywords: [
          'healthcare',
          'medicare',
          'medicaid',
          'CDC',
          'FDA',
          'NIH',
          'public health'
        ],
        tags: ['health', 'medicare', 'medicaid', 'public-health', 'social-services'],
        location: Location(
          address: '200 Independence Avenue SW',
          city: 'Washington',
          state: 'DC',
          zipCode: '20201',
          country: 'United States',
          latitude: 38.8877,
          longitude: -77.0166,
        ),
        officeHours: OfficeHours(
          weeklyHours: {
            'monday': '08:00 - 17:00',
            'tuesday': '08:00 - 17:00',
            'wednesday': '08:00 - 17:00',
            'thursday': '08:00 - 17:00',
            'friday': '08:00 - 17:00',
          },
        ),
      ),
      Department(
        id: 'ed-001',
        name: 'Department of Education',
        shortName: 'ED',
        description: 'The United States Department of Education is a Cabinet-level department of the United States government. It began operating on May 4, 1980, having been created after the Department of Health, Education, and Welfare was split into the Department of Education and the Department of Health and Human Services.',
        category: DepartmentCategory.education,
        isPopular: true,
        lastUpdated: DateTime.now(),
        contactInfo: ContactInfo(
          email: 'info@ed.gov',
          phone: '1-800-872-5327',
          website: 'https://www.ed.gov',
          address: '400 Maryland Avenue, S.W., Washington, D.C. 20202',
        ),
        services: [
          'Federal Student Aid administration',
          'Elementary and secondary education oversight',
          'Higher education policy and funding',
          'Special education and rehabilitative services',
          'Educational research and statistics',
          'Civil rights enforcement in education',
        ],
        keywords: [
          'education',
          'schools',
          'student aid',
          'financial aid',
          'teachers',
          'students',
          'special education'
        ],
        tags: ['education', 'schools', 'students', 'financial-aid', 'teachers'],
        location: Location(
          address: '400 Maryland Avenue SW',
          city: 'Washington',
          state: 'DC',
          zipCode: '20202',
          country: 'United States',
          latitude: 38.8846,
          longitude: -77.0179,
        ),
        officeHours: OfficeHours(
          weeklyHours: {
            'monday': '08:00 - 17:00',
            'tuesday': '08:00 - 17:00',
            'wednesday': '08:00 - 17:00',
            'thursday': '08:00 - 17:00',
            'friday': '08:00 - 17:00',
          },
        ),
      ),
      Department(
        id: 'epa-001',
        name: 'Environmental Protection Agency',
        shortName: 'EPA',
        description: 'The Environmental Protection Agency (EPA) is an independent executive agency of the United States federal government tasked with environmental protection matters.',
        category: DepartmentCategory.environment,
        isPopular: false,
        lastUpdated: DateTime.now(),
        contactInfo: ContactInfo(
          email: 'info@epa.gov',
          phone: '1-202-272-0167',
          website: 'https://www.epa.gov',
          address: '1200 Pennsylvania Avenue, N.W., Washington, D.C. 20460',
        ),
        services: [
          'Air quality regulation and monitoring',
          'Water pollution control',
          'Chemical safety oversight',
          'Waste management and cleanup',
          'Climate change mitigation',
          'Environmental justice initiatives',
        ],
        keywords: [
          'environment',
          'air quality',
          'water protection',
          'pollution',
          'climate change',
          'chemicals',
          'cleanup'
        ],
        tags: ['environment', 'pollution', 'air-quality', 'water-quality', 'climate'],
        location: Location(
          address: '1200 Pennsylvania Avenue NW',
          city: 'Washington',
          state: 'DC',
          zipCode: '20460',
          country: 'United States',
          latitude: 38.8951,
          longitude: -77.0367,
        ),
        officeHours: OfficeHours(
          weeklyHours: {
            'monday': '09:00 - 17:00',
            'tuesday': '09:00 - 17:00',
            'wednesday': '09:00 - 17:00',
            'thursday': '09:00 - 17:00',
            'friday': '09:00 - 17:00',
          },
        ),
      ),
    ];
  }
}