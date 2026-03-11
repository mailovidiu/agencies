import 'package:flutter/foundation.dart';
import '../models/department.dart';
import '../models/task_finder.dart';
import '../services/department_service.dart';

/// Provider for managing department and agency data and app state (fallback implementation)
class DepartmentProvider with ChangeNotifier {
  final DepartmentService _departmentService;

  DepartmentProvider(this._departmentService);

  // State variables
  List<Department> _departments = [];
  List<Department> _filteredDepartments = [];
  final List<String> _favoriteDepartmentIds = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  DepartmentCategory? _selectedCategory;

  // Getters
  List<Department> get departments => _filteredDepartments;
  List<Department> get allDepartments => _departments;
  List<String> get favoriteDepartmentIds => _favoriteDepartmentIds;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  DepartmentCategory? get selectedCategory => _selectedCategory;
  bool get hasPendingSyncWrites => _departmentService.hasPendingSyncWrites;
  int get pendingSyncWritesCount => _departmentService.pendingSyncWritesCount;
  String get writeSyncStatusLabel => _departmentService.writeSyncStatusLabel;
  String? get writeSyncMessage => _departmentService.lastWriteSyncMessage;

  List<String> get availableTags {
    final allTags = <String>{};
    for (final dept in _departments) {
      allTags.addAll(dept.tags);
    }
    return allTags.toList()..sort();
  }

  List<String> get taskFinderPromptChips {
    final chips = <String>{
      'Benefits',
      'Passport',
      'Student aid',
      'Jobs',
      'Housing',
      'Health',
      'Veterans',
    };

    for (final tag in availableTags) {
      if (chips.length >= 12) {
        break;
      }

      final normalizedTag = tag.trim();
      if (normalizedTag.isNotEmpty) {
        chips.add(normalizedTag);
      }
    }

    return chips.toList();
  }

  List<Department> get popularDepartments =>
      _departments.where((dept) => dept.isPopular).toList();

  List<Department> get favoriteDepartments => _departments
      .where((dept) => _favoriteDepartmentIds.contains(dept.id))
      .toList();

  // Additional getters for compatibility
  List<Department> get filteredDepartments => _filteredDepartments;

  // Methods for compatibility
  Future<void> initialize() async {
    await loadDepartments();
  }

  Future<void> refresh() async {
    await loadDepartments();
  }

  Future<Department?> getDepartmentById(String departmentId) async {
    for (final department in _departments) {
      if (department.id == departmentId) {
        return department;
      }
    }

    try {
      return await _departmentService.getDepartmentById(departmentId);
    } catch (e) {
      debugPrint('Failed to fetch department by ID ($departmentId): $e');
      return null;
    }
  }

  Department? getDepartmentByIdSync(String departmentId) {
    for (final department in _departments) {
      if (department.id == departmentId) {
        return department;
      }
    }
    return null;
  }

  Future<void> retryPendingSyncWrites() async {
    await _departmentService.retryPendingSyncWrites();
    await loadDepartments();
  }

  List<DepartmentCategory> getAvailableCategories() {
    return DepartmentCategory.values;
  }

  bool isFavorite(String departmentId) {
    return _favoriteDepartmentIds.contains(departmentId);
  }

  void selectDepartment(String departmentId) {
    // Log activity (no Firebase analytics, just print)
    debugPrint(
        'Activity logged: select_department (Department: $departmentId)');
  }

  String generateId() {
    // Generate a unique ID with timestamp + random component to avoid collisions
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random =
        (timestamp % 10000); // Use last 4 digits of timestamp for uniqueness
    return '${timestamp}_$random';
  }

  // Load departments
  Future<void> loadDepartments() async {
    _setLoading(true);
    try {
      _departments = await _departmentService.getAllDepartments();
      _applyFilters();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load departments: $e');
      _setLoading(false);
    }
  }

  // Add new department
  Future<void> addDepartment(Department department) async {
    try {
      await _departmentService.addDepartment(department);
      await loadDepartments(); // Reload to get updated list

      // Log activity (no Firebase analytics, just print)
      debugPrint(
          'Activity logged: add_department (Department: ${department.id})');
    } catch (e) {
      _setError('Failed to add department: $e');
    }
  }

  // Update department
  Future<void> updateDepartment(Department department) async {
    try {
      await _departmentService.updateDepartment(department);
      await loadDepartments(); // Reload to get updated list

      // Log activity (no Firebase analytics, just print)
      debugPrint(
          'Activity logged: update_department (Department: ${department.id})');
    } catch (e) {
      _setError('Failed to update department: $e');
    }
  }

  // Delete department
  Future<void> deleteDepartment(String id) async {
    try {
      await _departmentService.deleteDepartment(id);
      await loadDepartments(); // Reload to get updated list

      // Log activity (no Firebase analytics, just print)
      debugPrint('Activity logged: delete_department (Department: $id)');
    } catch (e) {
      _setError('Failed to delete department: $e');
    }
  }

  // Import departments from JSON
  Future<void> importDepartments(List<Department> departments) async {
    try {
      await _departmentService.createDepartments(departments);
      await loadDepartments(); // Reload to get updated list

      // Log activity (no Firebase analytics, just print)
      debugPrint(
          'Activity logged: import_departments (${departments.length} departments)');
    } catch (e) {
      _setError('Failed to import departments: $e');
    }
  }

  // Search departments
  void searchDepartments(String query) {
    _searchQuery = query;
    _applyFilters();

    // Log search activity (no Firebase analytics, just print)
    if (query.isNotEmpty) {
      debugPrint('Activity logged: search_departments (Query: $query)');
    }
  }

  // Filter by category
  void filterByCategory(DepartmentCategory? category) {
    _selectedCategory = category;
    _applyFilters();

    // Log filter activity (no Firebase analytics, just print)
    if (category != null) {
      debugPrint('Activity logged: filter_by_category (Category: $category)');
    }
  }

  // Clear filters
  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _applyFilters();

    // Log clear filters activity (no Firebase analytics, just print)
    debugPrint('Activity logged: clear_filters');
  }

  // Toggle favorite
  void toggleFavorite(String departmentId) {
    final wasFavorite = _favoriteDepartmentIds.contains(departmentId);

    if (wasFavorite) {
      _favoriteDepartmentIds.remove(departmentId);
    } else {
      _favoriteDepartmentIds.add(departmentId);
    }

    notifyListeners();

    // Log favorite activity (no Firebase analytics, just print)
    debugPrint(
        'Activity logged: ${wasFavorite ? 'remove_favorite' : 'add_favorite'} (Department: $departmentId)');
  }

  List<Department> getDepartmentsMatchingQuery(
    String query, {
    DepartmentCategory? category,
    List<Department>? sourceDepartments,
  }) {
    final departments = sourceDepartments ?? _departments;
    final normalizedQuery = query.trim().toLowerCase();
    final queryTokens = _tokenizeQuery(query);

    return departments.where((dept) {
      if (category != null && dept.category != category) {
        return false;
      }

      if (normalizedQuery.isEmpty) {
        return true;
      }

      return _matchesDepartmentQuery(
        dept,
        normalizedQuery: normalizedQuery,
        queryTokens: queryTokens,
      );
    }).toList();
  }

  TaskFinderSearchResponse findDepartmentsForTask(
    String query, {
    int limit = 6,
  }) {
    return _departmentService.findDepartmentsForTask(
      _departments,
      query,
      limit: limit,
    );
  }

  Future<TaskFinderResult?> refineTaskSearchWithAi({
    required String query,
    required List<TaskDepartmentMatch> matches,
  }) {
    return _departmentService.refineTaskSearchWithAi(
      query: query,
      matches: matches,
    );
  }

  // Apply current filters
  void _applyFilters() {
    _filteredDepartments = getDepartmentsMatchingQuery(
      _searchQuery,
      category: _selectedCategory,
      sourceDepartments: _departments,
    );

    notifyListeners();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  List<String> _tokenizeQuery(String input) {
    return input
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toList();
  }

  bool _matchesDepartmentQuery(
    Department department, {
    required String normalizedQuery,
    required List<String> queryTokens,
  }) {
    final searchableValues = [
      department.name,
      department.shortName,
      department.description,
      department.category.displayName,
      ...department.services,
      ...department.keywords,
      ...department.tags,
    ]
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toList();

    if (searchableValues.any((value) => value.contains(normalizedQuery))) {
      return true;
    }

    if (queryTokens.isEmpty) {
      return false;
    }

    return queryTokens.every(
      (token) => searchableValues.any((value) => value.contains(token)),
    );
  }
}
