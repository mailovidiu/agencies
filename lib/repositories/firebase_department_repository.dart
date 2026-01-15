import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/department.dart';
import 'department_repository.dart';

/// Firebase implementation of the department repository
/// Stores data in Firestore, accessible to all app users
class FirebaseDepartmentRepository implements DepartmentRepository {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final String _collection = 'departments';

  @override
  Future<List<Department>> getDepartments() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => Department.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting departments: $e');
      return [];
    }
  }

  @override
  Future<Department?> getDepartmentById(String id) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(id)
          .get();

      if (doc.exists) {
        return Department.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting department by ID: $e');
      return null;
    }
  }

  @override
  Future<void> addDepartment(Department department) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(department.id)
          .set(department.toFirestore());
    } catch (e) {
      print('Error adding department: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateDepartment(Department department) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(department.id)
          .update(department.toFirestore());
    } catch (e) {
      print('Error updating department: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteDepartment(String id) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .delete();
    } catch (e) {
      print('Error deleting department: $e');
      rethrow;
    }
  }

  @override
  Future<List<Department>> searchDepartments(String query) async {
    if (query.isEmpty) return getDepartments();

    try {
      // Get all departments first, then filter
      // Note: Firestore doesn't support complex text search natively
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
    } catch (e) {
      print('Error searching departments: $e');
      return [];
    }
  }

  @override
  Future<List<Department>> getDepartmentsByCategory(DepartmentCategory category) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('category', isEqualTo: category.name)
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => Department.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting departments by category: $e');
      return [];
    }
  }

  @override
  Future<List<Department>> getDepartmentsByTag(String tag) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('tags', arrayContains: tag)
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => Department.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting departments by tag: $e');
      return [];
    }
  }

  @override
  Future<void> createDepartments(List<Department> departments) async {
    try {
      final batch = _firestore.batch();
      
      for (final department in departments) {
        final docRef = _firestore.collection(_collection).doc(department.id);
        batch.set(docRef, department.toFirestore());
      }
      
      await batch.commit();
    } catch (e) {
      print('Error creating departments: $e');
      rethrow;
    }
  }

  @override
  Future<List<Department>> getPopularDepartments() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isPopular', isEqualTo: true)
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => Department.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting popular departments: $e');
      return [];
    }
  }

  @override
  Future<List<Department>> getDepartmentsByParent(String? parentId) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .orderBy('name');

      if (parentId != null) {
        query = query.where('parentDepartmentId', isEqualTo: parentId);
      } else {
        query = query.where('parentDepartmentId', isNull: true);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => Department.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting departments by parent: $e');
      return [];
    }
  }

  @override
  Future<List<Department>> getActiveDepartments() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => Department.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting active departments: $e');
      return [];
    }
  }

  /// Get recently updated departments (for admin dashboard)
  Future<List<Department>> getRecentlyUpdatedDepartments({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('lastUpdated', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Department.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting recently updated departments: $e');
      return [];
    }
  }

  /// Get department statistics
  Future<Map<String, int>> getDepartmentStats() async {
    try {
      final allDepts = await _firestore.collection(_collection).get();
      final activeDepts = allDepts.docs.where((doc) => doc.data()['isActive'] == true);
      final popularDepts = allDepts.docs.where((doc) => doc.data()['isPopular'] == true);
      
      final categoryStats = <String, int>{};
      for (final doc in activeDepts) {
        final category = doc.data()['category'] as String?;
        if (category != null) {
          categoryStats[category] = (categoryStats[category] ?? 0) + 1;
        }
      }

      return {
        'total': allDepts.docs.length,
        'active': activeDepts.length,
        'popular': popularDepts.length,
        ...categoryStats,
      };
    } catch (e) {
      print('Error getting department stats: $e');
      return {};
    }
  }
}