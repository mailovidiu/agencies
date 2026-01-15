import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/department.dart';
import '../repositories/firebase_department_repository.dart';
import '../utils/data_migration.dart';

/// Comprehensive Firebase service that manages all Firebase operations
/// including authentication, Firestore data, and service initialization
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  
  late final FirebaseDepartmentRepository _departmentRepository;
  late final DataMigrationUtility _migrationUtility;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  String? _connectionError;
  String? get connectionError => _connectionError;

  /// Initialize Firebase services
  Future<bool> initialize() async {
    try {
      if (_isInitialized) return true;

      // Check if Firebase is already initialized
      if (Firebase.apps.isEmpty) {
        throw Exception('Firebase not initialized. Please initialize Firebase first.');
      }

      // Initialize repository and migration utility
      _departmentRepository = FirebaseDepartmentRepository();
      _migrationUtility = DataMigrationUtility(_departmentRepository);

      // Test connectivity
      await _testFirebaseConnection();
      
      _isInitialized = true;
      _connectionError = null;
      
      print('Firebase service initialized successfully');
      return true;
    } catch (e) {
      _connectionError = e.toString();
      print('Firebase service initialization failed: $e');
      return false;
    }
  }

  /// Test Firebase connection
  Future<void> _testFirebaseConnection() async {
    try {
      // Test Firestore connectivity
      await _firestore.enableNetwork();
      await _firestore.collection('_test').limit(1).get();
      
      // Test Auth connectivity
      await _auth.authStateChanges().first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
      
      print('Firebase connectivity test passed');
    } catch (e) {
      throw Exception('Firebase connectivity test failed: $e');
    }
  }

  /// Get department repository
  FirebaseDepartmentRepository get departmentRepository {
    if (!_isInitialized) {
      throw Exception('Firebase service not initialized');
    }
    return _departmentRepository;
  }

  /// Migrate data and ensure initial setup
  Future<void> initializeData() async {
    if (!_isInitialized) {
      throw Exception('Firebase service not initialized');
    }
    
    try {
      await _migrationUtility.initializeFirebaseData();
      print('Firebase data initialization completed');
    } catch (e) {
      print('Firebase data initialization failed: $e');
      // Don't throw - let app continue with empty data
    }
  }

  // AUTHENTICATION METHODS
  
  /// Current user
  User? get currentUser => _auth.currentUser;

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Create user with email and password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Check if current user is admin
  bool isAdmin() {
    final user = currentUser;
    if (user == null) return false;
    
    const adminEmails = <String>[
      "ovi@ovi.ro", // Add your admin emails here
    ];
    
    return adminEmails.contains(user.email?.toLowerCase());
  }

  // USER DATA METHODS

  /// Create user profile in Firestore
  Future<void> createUserProfile({
    required String userId,
    required String email,
    String? displayName,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_isInitialized) {
      throw Exception('Firebase service not initialized');
    }

    try {
      await _firestore.collection('users').doc(userId).set({
        'email': email,
        'displayName': displayName ?? email.split('@').first,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isActive': true,
        ...?additionalData,
      });
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  /// Update user profile
  Future<void> updateUserProfile({
    required String userId,
    Map<String, dynamic>? data,
  }) async {
    if (!_isInitialized) {
      throw Exception('Firebase service not initialized');
    }

    try {
      await _firestore.collection('users').doc(userId).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        ...?data,
      });
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    if (!_isInitialized) {
      throw Exception('Firebase service not initialized');
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // USER FAVORITES METHODS

  /// Add department to user's favorites
  Future<void> addToFavorites({
    required String userId,
    required String departmentId,
  }) async {
    if (!_isInitialized) {
      throw Exception('Firebase service not initialized');
    }

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(departmentId)
          .set({
        'departmentId': departmentId,
        'addedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add to favorites: $e');
    }
  }

  /// Remove department from user's favorites
  Future<void> removeFromFavorites({
    required String userId,
    required String departmentId,
  }) async {
    if (!_isInitialized) {
      throw Exception('Firebase service not initialized');
    }

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(departmentId)
          .delete();
    } catch (e) {
      throw Exception('Failed to remove from favorites: $e');
    }
  }

  /// Get user's favorite department IDs
  Future<List<String>> getFavoriteIds(String userId) async {
    if (!_isInitialized) {
      throw Exception('Firebase service not initialized');
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();
      
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('Error getting favorite IDs: $e');
      return [];
    }
  }

  /// Check if department is in user's favorites
  Future<bool> isFavorite({
    required String userId,
    required String departmentId,
  }) async {
    if (!_isInitialized) {
      throw Exception('Firebase service not initialized');
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(departmentId)
          .get();
      
      return doc.exists;
    } catch (e) {
      print('Error checking favorite status: $e');
      return false;
    }
  }

  // ANALYTICS METHODS

  /// Track user interaction with department
  Future<void> trackDepartmentInteraction({
    required String userId,
    required String departmentId,
    required String interactionType, // 'view', 'search', 'favorite', etc.
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) return; // Don't throw for analytics

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('interactions')
          .add({
        'departmentId': departmentId,
        'type': interactionType,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
      });
    } catch (e) {
      print('Error tracking interaction: $e');
      // Don't throw for analytics failures
    }
  }

  /// Save AI chat history
  Future<void> saveChatHistory({
    required String userId,
    required String departmentId,
    required String question,
    required String answer,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) return; // Don't throw for chat history

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('chatHistory')
          .add({
        'departmentId': departmentId,
        'question': question,
        'answer': answer,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
      });
    } catch (e) {
      print('Error saving chat history: $e');
      // Don't throw for chat history failures
    }
  }

  // ADMIN METHODS

  /// Get app-wide statistics (admin only)
  Future<Map<String, dynamic>?> getAppStatistics() async {
    if (!_isInitialized || !isAdmin()) {
      throw Exception('Unauthorized access to app statistics');
    }

    try {
      // Get department stats from repository
      final deptStats = await _departmentRepository.getDepartmentStats();
      
      // Get user count
      final usersSnapshot = await _firestore.collection('users').get();
      
      // Get interactions count
      final interactionsQuery = await _firestore
          .collectionGroup('interactions')
          .orderBy('timestamp', descending: true)
          .limit(1000)
          .get();
      
      return {
        'departments': deptStats,
        'users': {
          'total': usersSnapshot.docs.length,
          'active': usersSnapshot.docs
              .where((doc) => doc.data()['isActive'] == true)
              .length,
        },
        'interactions': {
          'total': interactionsQuery.docs.length,
          'recent': interactionsQuery.docs.take(10).map((doc) => {
            'type': doc.data()['type'],
            'timestamp': doc.data()['timestamp'],
            'departmentId': doc.data()['departmentId'],
          }).toList(),
        },
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to get app statistics: $e');
    }
  }

  /// Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }
}

/// Exception class for Firebase service errors
class FirebaseServiceException implements Exception {
  final String message;
  final String? code;
  
  const FirebaseServiceException(this.message, [this.code]);
  
  @override
  String toString() => 'FirebaseServiceException: $message${code != null ? ' (Code: $code)' : ''}';
}