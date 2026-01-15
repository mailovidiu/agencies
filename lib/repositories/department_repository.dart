import '../models/department.dart';

/// Abstract repository interface for department data access
abstract class DepartmentRepository {
  Future<List<Department>> getDepartments();
  Future<Department?> getDepartmentById(String id);
  Future<void> addDepartment(Department department);
  Future<void> updateDepartment(Department department);
  Future<void> deleteDepartment(String id);
  Future<List<Department>> searchDepartments(String query);
  Future<List<Department>> getDepartmentsByCategory(DepartmentCategory category);
  Future<List<Department>> getDepartmentsByTag(String tag);
  Future<void> createDepartments(List<Department> departments);
  
  // Additional methods for enhanced functionality
  Future<List<Department>> getPopularDepartments();
  Future<List<Department>> getDepartmentsByParent(String? parentId);
  Future<List<Department>> getActiveDepartments();
}



/// Web-compatible local repository implementation (Hive temporarily disabled)
/// TODO: Re-enable Hive when web compatibility is resolved
class HiveDepartmentRepository implements DepartmentRepository {
  List<Department> _departments = [];
  bool _initialized = false;

  /// Initialize repository with empty data
  Future<void> initialize() async {
    if (!_initialized) {
      _departments = [];
      _initialized = true;
    }
  }

  @override
  Future<List<Department>> getDepartments() async {
    await Future.delayed(const Duration(milliseconds: 100));
    final sortedDepartments = List<Department>.from(_departments);
    sortedDepartments.sort((a, b) => a.name.compareTo(b.name));
    return sortedDepartments;
  }

  @override
  Future<Department?> getDepartmentById(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    try {
      return _departments.firstWhere((dept) => dept.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> addDepartment(Department department) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _departments.add(department);
  }

  @override
  Future<void> updateDepartment(Department department) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final index = _departments.indexWhere((dept) => dept.id == department.id);
    if (index != -1) {
      _departments[index] = department;
    }
  }

  @override
  Future<void> deleteDepartment(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _departments.removeWhere((dept) => dept.id == id);
  }

  @override
  Future<List<Department>> searchDepartments(String query) async {
    if (query.isEmpty) return getDepartments();
    
    final departments = await getDepartments();
    final lowercaseQuery = query.toLowerCase();
    
    return departments.where((dept) {
      return dept.name.toLowerCase().contains(lowercaseQuery) ||
             dept.shortName.toLowerCase().contains(lowercaseQuery) ||
             dept.description.toLowerCase().contains(lowercaseQuery) ||
             dept.services.any((service) => service.toLowerCase().contains(lowercaseQuery)) ||
             dept.keywords.any((keyword) => keyword.toLowerCase().contains(lowercaseQuery)) ||
             dept.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  @override
  Future<List<Department>> getDepartmentsByCategory(DepartmentCategory category) async {
    final departments = await getDepartments();
    return departments.where((dept) => dept.category == category).toList();
  }

  /// Get departments by parent department
  Future<List<Department>> getDepartmentsByParent(String? parentId) async {
    final departments = await getDepartments();
    return departments.where((dept) => dept.parentDepartmentId == parentId).toList();
  }

  /// Get departments with specific tags
  Future<List<Department>> getDepartmentsByTags(List<String> tags) async {
    final departments = await getDepartments();
    return departments.where((dept) {
      return tags.any((tag) => dept.tags.contains(tag));
    }).toList();
  }

  @override
  Future<List<Department>> getDepartmentsByTag(String tag) async {
    final departments = await getDepartments();
    return departments.where((dept) => dept.tags.contains(tag)).toList();
  }

  @override
  Future<void> createDepartments(List<Department> departments) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _departments.addAll(departments);
  }

  @override
  Future<List<Department>> getPopularDepartments() async {
    final departments = await getDepartments();
    return departments.where((dept) => dept.isPopular).toList();
  }

  @override  
  Future<List<Department>> getActiveDepartments() async {
    final departments = await getDepartments();
    return departments.where((dept) => dept.isActive).toList();
  }
}

