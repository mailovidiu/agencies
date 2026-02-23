import 'dart:async';
import 'dart:convert';
import '../models/department.dart';
import 'department_repository.dart';
import 'firebase_department_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WriteSyncStatus { synced, pending }

enum _PendingOperationType { addOrUpdate, delete }

class _PendingDepartmentOperation {
  final String departmentId;
  final _PendingOperationType type;
  final Map<String, dynamic>? department;
  final int attempts;
  final int nextRetryAtMillis;
  final int updatedAtMillis;

  const _PendingDepartmentOperation({
    required this.departmentId,
    required this.type,
    required this.department,
    required this.attempts,
    required this.nextRetryAtMillis,
    required this.updatedAtMillis,
  });

  _PendingDepartmentOperation copyWith({
    int? attempts,
    int? nextRetryAtMillis,
    int? updatedAtMillis,
  }) {
    return _PendingDepartmentOperation(
      departmentId: departmentId,
      type: type,
      department: department,
      attempts: attempts ?? this.attempts,
      nextRetryAtMillis: nextRetryAtMillis ?? this.nextRetryAtMillis,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'departmentId': departmentId,
      'type': type.name,
      'department': department,
      'attempts': attempts,
      'nextRetryAtMillis': nextRetryAtMillis,
      'updatedAtMillis': updatedAtMillis,
    };
  }

  static _PendingDepartmentOperation fromJson(Map<String, dynamic> json) {
    final typeName =
        json['type'] as String? ?? _PendingOperationType.addOrUpdate.name;
    final resolvedType = _PendingOperationType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => _PendingOperationType.addOrUpdate,
    );

    return _PendingDepartmentOperation(
      departmentId: json['departmentId'] as String,
      type: resolvedType,
      department: json['department'] as Map<String, dynamic>?,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      nextRetryAtMillis: (json['nextRetryAtMillis'] as num?)?.toInt() ?? 0,
      updatedAtMillis: (json['updatedAtMillis'] as num?)?.toInt() ?? 0,
    );
  }
}

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
  static const String _pendingOpsKey = 'departments_pending_ops_v1';
  static const Duration _syncRetryInterval = Duration(seconds: 20);

  final List<_PendingDepartmentOperation> _pendingOperations = [];
  bool _isProcessingPendingOperations = false;
  Timer? _pendingOpsTimer;
  WriteSyncStatus _lastWriteSyncStatus = WriteSyncStatus.synced;
  String? _lastWriteSyncMessage;

  /// Initialize the hybrid repository
  Future<void> initialize() async {
    try {
      // Initialize SharedPreferences for local caching
      _prefs = await SharedPreferences.getInstance();
      print('Local storage initialized successfully');

      await _loadPendingOperations();

      // Try to initialize Firebase
      if (Firebase.apps.isNotEmpty) {
        _firebaseRepo = FirebaseDepartmentRepository();
        _isFirebaseAvailable = true;
        print('Firebase repository initialized successfully');

        // Try to sync from Firebase to local cache
        await _syncFromFirebaseToLocal();
        await _processPendingOperations();
      } else {
        print('Firebase not available, using local storage only');
      }
    } catch (e) {
      print('Hybrid repository initialization warning: $e');
      _isFirebaseAvailable = false;
    }

    // Ensure we have some sample data if nothing exists locally
    await _ensureSampleData();
    _startPendingOpsTimer();
  }

  void _startPendingOpsTimer() {
    _pendingOpsTimer?.cancel();
    _pendingOpsTimer = Timer.periodic(_syncRetryInterval, (_) {
      unawaited(_processPendingOperations());
    });
  }

  Future<void> _loadPendingOperations() async {
    if (_prefs == null) return;

    try {
      _pendingOperations.clear();
      final raw = _prefs!.getString(_pendingOpsKey);
      if (raw == null || raw.isEmpty) {
        _setSyncedState();
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _setSyncedState();
        return;
      }

      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          _pendingOperations.add(_PendingDepartmentOperation.fromJson(item));
        } else if (item is Map) {
          _pendingOperations.add(
            _PendingDepartmentOperation.fromJson(
                Map<String, dynamic>.from(item)),
          );
        }
      }

      if (_pendingOperations.isNotEmpty) {
        _setPendingState(
          'Saved locally. ${_pendingOperations.length} change(s) pending sync.',
        );
      } else {
        _setSyncedState();
      }
    } catch (e) {
      print('Failed to load pending operations: $e');
      _pendingOperations.clear();
      _setSyncedState();
    }
  }

  Future<void> _persistPendingOperations() async {
    if (_prefs == null) return;

    try {
      final raw = jsonEncode(
        _pendingOperations.map((operation) => operation.toJson()).toList(),
      );
      await _prefs!.setString(_pendingOpsKey, raw);
    } catch (e) {
      print('Failed to persist pending operations: $e');
    }
  }

  Duration _buildBackoffDuration(int attempts) {
    final exponent = attempts < 6 ? attempts : 6;
    final seconds = 1 << exponent;
    return Duration(seconds: seconds);
  }

  void _setSyncedState() {
    _lastWriteSyncStatus = WriteSyncStatus.synced;
    _lastWriteSyncMessage = null;
  }

  void _setPendingState(String message) {
    _lastWriteSyncStatus = WriteSyncStatus.pending;
    _lastWriteSyncMessage = message;
  }

  Future<void> _enqueuePendingOperation(
      _PendingDepartmentOperation operation) async {
    _pendingOperations
        .removeWhere((item) => item.departmentId == operation.departmentId);
    _pendingOperations.add(operation);
    _setPendingState(
      'Saved locally. ${_pendingOperations.length} change(s) pending sync.',
    );
    await _persistPendingOperations();
  }

  List<Department> _applyOperationToList(
    List<Department> source,
    _PendingDepartmentOperation operation,
  ) {
    final departments = List<Department>.from(source);
    final index =
        departments.indexWhere((dept) => dept.id == operation.departmentId);

    if (operation.type == _PendingOperationType.delete) {
      departments.removeWhere((dept) => dept.id == operation.departmentId);
      return departments;
    }

    if (operation.department == null) {
      return departments;
    }

    final mappedDepartment = Department.fromJson(operation.department!);
    if (index == -1) {
      departments.add(mappedDepartment);
    } else {
      departments[index] = mappedDepartment;
    }

    return departments;
  }

  List<Department> _applyPendingOperations(List<Department> source) {
    var departments = List<Department>.from(source);
    for (final operation in _pendingOperations) {
      departments = _applyOperationToList(departments, operation);
    }
    return departments;
  }

  Future<void> _processPendingOperations() async {
    if (_isProcessingPendingOperations) return;
    if (!_isFirebaseAvailable || _firebaseRepo == null) return;
    if (_pendingOperations.isEmpty) {
      _setSyncedState();
      return;
    }

    _isProcessingPendingOperations = true;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      var changed = false;

      for (int i = _pendingOperations.length - 1; i >= 0; i--) {
        final operation = _pendingOperations[i];
        if (operation.nextRetryAtMillis > now) {
          continue;
        }

        try {
          await _executeRemoteOperation(operation);
          _pendingOperations.removeAt(i);
          changed = true;
        } catch (e) {
          final attempts = operation.attempts + 1;
          final delay = _buildBackoffDuration(attempts);
          _pendingOperations[i] = operation.copyWith(
            attempts: attempts,
            nextRetryAtMillis: DateTime.now().add(delay).millisecondsSinceEpoch,
            updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
          );
          changed = true;
          print('Pending operation retry scheduled: $e');
        }
      }

      if (changed) {
        await _persistPendingOperations();
      }

      if (_pendingOperations.isEmpty) {
        _setSyncedState();
        await _syncFromFirebaseToLocal();
      } else {
        _setPendingState(
          'Saved locally. ${_pendingOperations.length} change(s) pending sync.',
        );
      }
    } finally {
      _isProcessingPendingOperations = false;
    }
  }

  Future<void> _executeRemoteOperation(
      _PendingDepartmentOperation operation) async {
    if (_firebaseRepo == null) {
      throw Exception('Firebase repository unavailable');
    }

    if (operation.type == _PendingOperationType.delete) {
      await _firebaseRepo!.deleteDepartment(operation.departmentId);
      return;
    }

    if (operation.department == null) {
      throw Exception('Missing department payload');
    }

    final department = Department.fromJson(operation.department!);
    try {
      await _firebaseRepo!.addDepartment(department);
    } catch (_) {
      await _firebaseRepo!.updateDepartment(department);
    }
  }

  Future<void> _applyLocalAndScheduleSync(
    _PendingDepartmentOperation operation,
  ) async {
    final localDepartments = await _loadFromLocalCache();
    final updatedLocalDepartments =
        _applyOperationToList(localDepartments, operation);
    await _saveToLocalCache(updatedLocalDepartments);

    if (_isFirebaseAvailable && _firebaseRepo != null) {
      try {
        await _executeRemoteOperation(operation);
        _pendingOperations
            .removeWhere((item) => item.departmentId == operation.departmentId);
        await _persistPendingOperations();

        if (_pendingOperations.isEmpty) {
          _setSyncedState();
        } else {
          _setPendingState(
            'Saved locally. ${_pendingOperations.length} change(s) pending sync.',
          );
        }
        return;
      } catch (e) {
        print('Remote write failed, queueing for retry: $e');
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await _enqueuePendingOperation(
      operation.copyWith(
        attempts: 0,
        nextRetryAtMillis: now,
        updatedAtMillis: now,
      ),
    );
    unawaited(_processPendingOperations());
  }

  /// Sync data from Firebase to local cache
  Future<void> _syncFromFirebaseToLocal() async {
    if (!_isFirebaseAvailable || _firebaseRepo == null) return;

    try {
      final remoteDepartments = await _firebaseRepo!.getDepartments();
      final mergedDepartments = _applyPendingOperations(remoteDepartments);
      await _saveToLocalCache(mergedDepartments);
      print(
          'Synced ${mergedDepartments.length} departments from Firebase to local cache');
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
      return jsonList
          .map((json) => Department.fromJson(json as Map<String, dynamic>))
          .toList();
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
        await _processPendingOperations();
        final departments = await _firebaseRepo!.getDepartments();
        final mergedDepartments = _applyPendingOperations(departments);
        // Update local cache with fresh data
        await _saveToLocalCache(mergedDepartments);
        return mergedDepartments;
      } catch (e) {
        print('Firebase read failed, falling back to local cache: $e');
      }
    }

    // Fall back to local cache
    return await _loadFromLocalCache();
  }

  @override
  Future<List<Department>> getDepartmentsByCategory(
      DepartmentCategory category) async {
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
    return departments
        .where((dept) =>
            dept.name.toLowerCase().contains(lowerQuery) ||
            dept.shortName.toLowerCase().contains(lowerQuery) ||
            dept.description.toLowerCase().contains(lowerQuery) ||
            dept.services
                .any((service) => service.toLowerCase().contains(lowerQuery)) ||
            dept.keywords
                .any((keyword) => keyword.toLowerCase().contains(lowerQuery)) ||
            dept.tags.any((tag) => tag.toLowerCase().contains(lowerQuery)))
        .toList();
  }

  @override
  Future<List<Department>> getDepartmentsByTag(String tag) async {
    final departments = await getDepartments();
    return departments.where((dept) => dept.tags.contains(tag)).toList();
  }

  @override
  Future<void> addDepartment(Department department) async {
    final operation = _PendingDepartmentOperation(
      departmentId: department.id,
      type: _PendingOperationType.addOrUpdate,
      department: department.toJson(),
      attempts: 0,
      nextRetryAtMillis: 0,
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    await _applyLocalAndScheduleSync(operation);
  }

  @override
  Future<void> updateDepartment(Department department) async {
    final operation = _PendingDepartmentOperation(
      departmentId: department.id,
      type: _PendingOperationType.addOrUpdate,
      department: department.toJson(),
      attempts: 0,
      nextRetryAtMillis: 0,
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    await _applyLocalAndScheduleSync(operation);
  }

  @override
  Future<void> deleteDepartment(String id) async {
    final operation = _PendingDepartmentOperation(
      departmentId: id,
      type: _PendingOperationType.delete,
      department: null,
      attempts: 0,
      nextRetryAtMillis: 0,
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    await _applyLocalAndScheduleSync(operation);
  }

  @override
  Future<void> createDepartments(List<Department> departments) async {
    for (final department in departments) {
      final operation = _PendingDepartmentOperation(
        departmentId: department.id,
        type: _PendingOperationType.addOrUpdate,
        department: department.toJson(),
        attempts: 0,
        nextRetryAtMillis: 0,
        updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
      await _applyLocalAndScheduleSync(operation);
    }
  }

  @override
  Future<List<Department>> getPopularDepartments() async {
    // Try Firebase first for optimized query
    if (_isFirebaseAvailable && _firebaseRepo != null) {
      try {
        final popularDepartments = await _firebaseRepo!.getPopularDepartments();
        return popularDepartments;
      } catch (e) {
        print(
            'Firebase popular departments query failed, falling back to local: $e');
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
        final childDepartments =
            await _firebaseRepo!.getDepartmentsByParent(parentId);
        return childDepartments;
      } catch (e) {
        print(
            'Firebase parent departments query failed, falling back to local: $e');
      }
    }

    // Fall back to local cache
    final departments = await _loadFromLocalCache();
    return departments
        .where((dept) => dept.parentDepartmentId == parentId)
        .toList();
  }

  @override
  Future<List<Department>> getActiveDepartments() async {
    final departments = await getDepartments();
    return departments.where((dept) => dept.isActive).toList();
  }

  /// Force sync from Firebase (manual sync)
  Future<void> forceSyncFromFirebase() async {
    if (_isFirebaseAvailable && _firebaseRepo != null) {
      await _processPendingOperations();
      await _syncFromFirebaseToLocal();
    }
  }

  /// Manually retry pending writes.
  Future<void> flushPendingOperations() async {
    await _processPendingOperations();
  }

  /// Check if Firebase is available
  bool get isFirebaseAvailable => _isFirebaseAvailable;

  /// Whether there are writes waiting to sync to Firebase.
  bool get hasPendingWrites => _pendingOperations.isNotEmpty;

  /// Number of pending writes queued for sync.
  int get pendingWritesCount => _pendingOperations.length;

  /// Most recent write sync status.
  WriteSyncStatus get lastWriteSyncStatus => _lastWriteSyncStatus;

  /// Additional context for the last sync status.
  String? get lastWriteSyncMessage => _lastWriteSyncMessage;

  /// Get connection status
  String get connectionStatus {
    final backend =
        _isFirebaseAvailable ? 'Firebase + Local Cache' : 'Local Cache Only';
    if (_pendingOperations.isEmpty) {
      return '$backend (Synced)';
    }
    return '$backend (${_pendingOperations.length} Pending Write(s))';
  }

  /// Sample departments for initial data
  List<Department> _getSampleDepartments() {
    return [
      Department(
        id: 'hhs-001',
        name: 'Department of Health and Human Services',
        shortName: 'HHS',
        description:
            'The United States Department of Health and Human Services (HHS) is a cabinet-level executive branch department of the U.S. federal government created to protect the health of all Americans and provide essential human services.',
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
        tags: [
          'health',
          'medicare',
          'medicaid',
          'public-health',
          'social-services'
        ],
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
        description:
            'The United States Department of Education is a Cabinet-level department of the United States government. It began operating on May 4, 1980, having been created after the Department of Health, Education, and Welfare was split into the Department of Education and the Department of Health and Human Services.',
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
        description:
            'The Environmental Protection Agency (EPA) is an independent executive agency of the United States federal government tasked with environmental protection matters.',
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
        tags: [
          'environment',
          'pollution',
          'air-quality',
          'water-quality',
          'climate'
        ],
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
