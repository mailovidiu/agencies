import '../models/department.dart';
import '../repositories/department_repository.dart';
import '../repositories/firebase_department_repository.dart';
import '../repositories/hybrid_department_repository.dart';

/// Service layer for handling business logic related to departments and agencies
class DepartmentService {
  final DepartmentRepository _repository;

  DepartmentService(this._repository);

  /// Get all departments
  Future<List<Department>> getAllDepartments() async {
    try {
      return await _repository.getDepartments();
    } catch (e) {
      throw ServiceException('Failed to fetch departments: $e');
    }
  }

  /// Get departments by category
  Future<List<Department>> getDepartmentsByCategory(DepartmentCategory category) async {
    try {
      return await _repository.getDepartmentsByCategory(category);
    } catch (e) {
      throw ServiceException('Failed to fetch departments by category: $e');
    }
  }

  /// Search departments by name or description
  Future<List<Department>> searchDepartments(String query) async {
    try {
      return await _repository.searchDepartments(query);
    } catch (e) {
      throw ServiceException('Failed to search departments: $e');
    }
  }

  /// Add a new department
  Future<void> addDepartment(Department department) async {
    try {
      // Validate department data
      _validateDepartment(department);
      
      // Check if department with same ID already exists
      final existing = await _repository.getDepartmentById(department.id);
      if (existing != null) {
        throw ServiceException('Department with ID ${department.id} already exists');
      }
      
      // Add timestamp
      final departmentToAdd = department.copyWith(lastUpdated: DateTime.now());
      await _repository.addDepartment(departmentToAdd);
    } catch (e) {
      if (e is ServiceException) rethrow;
      throw ServiceException('Failed to add department: $e');
    }
  }

  /// Update an existing department
  Future<void> updateDepartment(Department department) async {
    try {
      _validateDepartment(department);
      
      // Check if department exists
      final existing = await _repository.getDepartmentById(department.id);
      if (existing == null) {
        throw ServiceException('Department with ID ${department.id} does not exist');
      }
      
      // Update with new timestamp
      final departmentToUpdate = department.copyWith(lastUpdated: DateTime.now());
      await _repository.updateDepartment(departmentToUpdate);
    } catch (e) {
      if (e is ServiceException) rethrow;
      throw ServiceException('Failed to update department: $e');
    }
  }

  /// Delete a department
  Future<void> deleteDepartment(String id) async {
    try {
      // Check if department exists
      final existing = await _repository.getDepartmentById(id);
      if (existing == null) {
        throw ServiceException('Department with ID $id does not exist');
      }
      
      await _repository.deleteDepartment(id);
    } catch (e) {
      if (e is ServiceException) rethrow;
      throw ServiceException('Failed to delete department: $e');
    }
  }

  /// Generate a unique ID for new departments
  String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Validate department data
  void _validateDepartment(Department department) {
    if (department.name.trim().isEmpty) {
      throw ServiceException('Department name cannot be empty');
    }
    if (department.shortName.trim().isEmpty) {
      throw ServiceException('Department short name cannot be empty');
    }
    if (department.description.trim().isEmpty) {
      throw ServiceException('Department description cannot be empty');
    }
    if (department.contactInfo.email.isNotEmpty && !_isValidEmail(department.contactInfo.email)) {
      throw ServiceException('Invalid email format');
    }
  }

  /// Simple email validation
  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  /// Get department details by ID
  Future<Department?> getDepartmentById(String id) async {
    try {
      return await _repository.getDepartmentById(id);
    } catch (e) {
      throw ServiceException('Failed to fetch department details: $e');
    }
  }

  /// Get favorite departments
  Future<List<Department>> getFavoriteDepartments(List<String> favoriteIds) async {
    try {
      final departments = await _repository.getDepartments();
      return departments.where((dept) => favoriteIds.contains(dept.id)).toList();
    } catch (e) {
      throw ServiceException('Failed to fetch favorite departments: $e');
    }
  }

  /// Get popular departments
  Future<List<Department>> getPopularDepartments() async {
    try {
      // Use repository's optimized getPopularDepartments method if available
      if (_repository is FirebaseDepartmentRepository) {
        final firebaseRepo = _repository as FirebaseDepartmentRepository;
        return await firebaseRepo.getPopularDepartments();
      } else if (_repository.runtimeType.toString().contains('HybridDepartmentRepository')) {
        // Use the hybrid repository's method
        final hybridRepo = _repository as dynamic;
        return await hybridRepo.getPopularDepartments();
      } else {
        // Fallback for other repositories
        final departments = await _repository.getDepartments();
        return departments.where((dept) => dept.isPopular).toList();
      }
    } catch (e) {
      throw ServiceException('Failed to fetch popular departments: $e');
    }
  }

  /// Create multiple departments (for batch import)
  Future<void> createDepartments(List<Department> departments) async {
    try {
      // Validate each department
      for (final department in departments) {
        _validateDepartment(department);
      }
      
      // Add timestamps and create departments
      final departmentsToAdd = departments.map((dept) => 
        dept.copyWith(lastUpdated: DateTime.now())
      ).toList();
      
      await _repository.createDepartments(departmentsToAdd);
    } catch (e) {
      if (e is ServiceException) rethrow;
      throw ServiceException('Failed to create departments: $e');
    }
  }
}

/// Custom exception for service layer errors
class ServiceException implements Exception {
  final String message;
  ServiceException(this.message);

  @override
  String toString() => 'ServiceException: $message';
}