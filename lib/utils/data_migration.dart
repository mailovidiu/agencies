import 'dart:convert';
import '../models/department.dart';
import '../repositories/firebase_department_repository.dart';
import '../utils/sample_data.dart';
import '../utils/firebase_data_seeder.dart';
import 'package:flutter/foundation.dart';
import 'data_migration_web.dart' if (dart.library.io) 'data_migration_mobile.dart';

/// Utility class for migrating data from local storage to Firebase
/// and loading sample data if no data exists
class DataMigrationUtility {
  static const String _localStorageKey = 'departments_data';
  final FirebaseDepartmentRepository _repository;
  late final LocalStorageHelper _storageHelper;

  DataMigrationUtility(this._repository) {
    _storageHelper = LocalStorageHelper();
  }

  /// Check if there's any data in Firebase
  Future<bool> hasFirebaseData() async {
    final departments = await _repository.getDepartments();
    return departments.isNotEmpty;
  }

  /// Check if there's data in local storage
  Future<bool> hasLocalStorageData() async {
    final storedData = await _storageHelper.getString(_localStorageKey);
    return storedData != null && storedData.isNotEmpty;
  }

  /// Migrate data from local storage to Firebase
  Future<void> migrateFromLocalStorage() async {
    try {
      final storedData = await _storageHelper.getString(_localStorageKey);
      if (storedData != null && storedData.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(storedData);
        final departments = jsonList.map((json) => Department.fromJson(json)).toList();
        
        print('Migrating ${departments.length} departments from local storage to Firebase...');
        await _repository.createDepartments(departments);
        
        // Clear local storage after successful migration
        await _storageHelper.remove(_localStorageKey);
        print('Migration completed successfully!');
      }
    } catch (e) {
      print('Error migrating from local storage: $e');
      throw Exception('Failed to migrate data from local storage to Firebase');
    }
  }

  /// Load sample data into Firebase if no data exists
  Future<void> loadSampleData() async {
    try {
      // Use the new Firebase data seeder for comprehensive data setup
      final seeder = FirebaseDataSeeder();
      await seeder.seedDatabase();
      print('Sample data loaded successfully using Firebase seeder!');
    } catch (e) {
      print('Error loading sample data with seeder, falling back to legacy method: $e');
      
      // Fallback to legacy method
      try {
        final List<dynamic> jsonList = json.decode(SampleDataHelper.sampleJsonStructure);
        final departments = jsonList.map((json) => Department.fromJson(json)).toList();
        
        print('Loading ${departments.length} sample departments into Firebase...');
        await _repository.createDepartments(departments);
        print('Sample data loaded successfully with legacy method!');
      } catch (e2) {
        print('Error with legacy method too: $e2');
        throw Exception('Failed to load sample data into Firebase');
      }
    }
  }

  /// Initialize Firebase data - migrate from local storage if available, 
  /// otherwise load sample data
  Future<void> initializeFirebaseData() async {
    try {
      // Check if Firebase already has data
      if (await hasFirebaseData()) {
        print('Firebase already contains data. No initialization needed.');
        return;
      }

      // Try to migrate from local storage first
      if (await hasLocalStorageData()) {
        await migrateFromLocalStorage();
      } else {
        // Load sample data if no existing data found
        await loadSampleData();
      }
    } catch (e) {
      print('Error initializing Firebase data: $e');
      // Don't throw here - let the app continue with empty data
    }
  }
}