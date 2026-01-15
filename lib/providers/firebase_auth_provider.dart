import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

/// Firebase-specific authentication provider that manages user authentication state
/// and integrates with Firestore for user profile management
class FirebaseAuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  
  StreamSubscription<User?>? _authSubscription;
  User? _user;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _isLoading = false;
  Map<String, dynamic>? _userProfile;
  List<String> _favoriteIds = [];

  // Getters
  User? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get userProfile => _userProfile;
  List<String> get favoriteIds => _favoriteIds;
  bool get isAdmin => _firebaseService.isAdmin();

  /// Initialize the auth provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Ensure Firebase service is initialized
      final initialized = await _firebaseService.initialize();
      if (!initialized) {
        throw Exception('Firebase service initialization failed');
      }

      // Set up auth state listener
      _authSubscription = _firebaseService.authStateChanges.listen(
        _onAuthStateChanged,
        onError: (error) {
          _setError('Auth state error: $error');
        },
      );

      _isInitialized = true;
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to initialize auth provider: $e');
    }
  }

  /// Handle auth state changes
  Future<void> _onAuthStateChanged(User? user) async {
    _user = user;
    
    if (user != null) {
      try {
        // Load or create user profile
        await _loadUserProfile(user);
        
        // Load user's favorites
        await _loadFavorites(user.uid);
        
        _clearError();
      } catch (e) {
        print('Error loading user data: $e');
        _setError('Failed to load user data: $e');
      }
    } else {
      // Clear user data on sign out
      _userProfile = null;
      _favoriteIds.clear();
    }
    
    notifyListeners();
  }

  /// Load or create user profile
  Future<void> _loadUserProfile(User user) async {
    try {
      // Try to get existing profile
      _userProfile = await _firebaseService.getUserProfile(user.uid);
      
      if (_userProfile == null) {
        // Create new user profile
        await _firebaseService.createUserProfile(
          userId: user.uid,
          email: user.email!,
          displayName: user.displayName,
          additionalData: {
            'photoURL': user.photoURL,
            'emailVerified': user.emailVerified,
          },
        );
        
        // Load the newly created profile
        _userProfile = await _firebaseService.getUserProfile(user.uid);
      } else {
        // Update last login time
        await _firebaseService.updateUserProfile(
          userId: user.uid,
          data: {
            'lastLoginAt': DateTime.now().toIso8601String(),
            'emailVerified': user.emailVerified,
          },
        );
      }
    } catch (e) {
      print('Error managing user profile: $e');
      // Don't throw - app can work without profile
    }
  }

  /// Load user's favorite department IDs
  Future<void> _loadFavorites(String userId) async {
    try {
      _favoriteIds = await _firebaseService.getFavoriteIds(userId);
    } catch (e) {
      print('Error loading favorites: $e');
      _favoriteIds = [];
    }
  }

  /// Sign in with email and password
  Future<bool> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _firebaseService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Create account with email and password
  Future<bool> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _firebaseService.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail({required String email}) async {
    _setLoading(true);
    _clearError();

    try {
      await _firebaseService.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _setLoading(true);
    
    try {
      await _firebaseService.signOut();
      _clearError();
    } catch (e) {
      _setError('Failed to sign out: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Add department to favorites
  Future<bool> addToFavorites(String departmentId) async {
    if (!isSignedIn) return false;

    try {
      await _firebaseService.addToFavorites(
        userId: _user!.uid,
        departmentId: departmentId,
      );
      
      // Update local state
      if (!_favoriteIds.contains(departmentId)) {
        _favoriteIds.add(departmentId);
        notifyListeners();
      }
      
      // Track interaction
      await _firebaseService.trackDepartmentInteraction(
        userId: _user!.uid,
        departmentId: departmentId,
        interactionType: 'favorite_add',
      );
      
      return true;
    } catch (e) {
      _setError('Failed to add to favorites: $e');
      return false;
    }
  }

  /// Remove department from favorites
  Future<bool> removeFromFavorites(String departmentId) async {
    if (!isSignedIn) return false;

    try {
      await _firebaseService.removeFromFavorites(
        userId: _user!.uid,
        departmentId: departmentId,
      );
      
      // Update local state
      _favoriteIds.remove(departmentId);
      notifyListeners();
      
      // Track interaction
      await _firebaseService.trackDepartmentInteraction(
        userId: _user!.uid,
        departmentId: departmentId,
        interactionType: 'favorite_remove',
      );
      
      return true;
    } catch (e) {
      _setError('Failed to remove from favorites: $e');
      return false;
    }
  }

  /// Check if department is in favorites
  bool isFavorite(String departmentId) {
    return _favoriteIds.contains(departmentId);
  }

  /// Track department view
  Future<void> trackDepartmentView(String departmentId) async {
    if (!isSignedIn) return;

    try {
      await _firebaseService.trackDepartmentInteraction(
        userId: _user!.uid,
        departmentId: departmentId,
        interactionType: 'view',
      );
    } catch (e) {
      print('Error tracking department view: $e');
      // Don't show error for analytics
    }
  }

  /// Track search query
  Future<void> trackSearch(String query, int resultCount) async {
    if (!isSignedIn) return;

    try {
      await _firebaseService.trackDepartmentInteraction(
        userId: _user!.uid,
        departmentId: 'search',
        interactionType: 'search',
        metadata: {
          'query': query,
          'resultCount': resultCount,
        },
      );
    } catch (e) {
      print('Error tracking search: $e');
      // Don't show error for analytics
    }
  }

  /// Save AI chat interaction
  Future<void> saveChatHistory({
    required String departmentId,
    required String question,
    required String answer,
  }) async {
    if (!isSignedIn) return;

    try {
      await _firebaseService.saveChatHistory(
        userId: _user!.uid,
        departmentId: departmentId,
        question: question,
        answer: answer,
      );
    } catch (e) {
      print('Error saving chat history: $e');
      // Don't show error for chat history
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? displayName,
    String? photoURL,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!isSignedIn) return false;

    _setLoading(true);
    
    try {
      // Update Firebase Auth profile if needed
      if (displayName != null || photoURL != null) {
        await _user!.updateDisplayName(displayName);
        if (photoURL != null) {
          await _user!.updatePhotoURL(photoURL);
        }
        await _user!.reload();
      }

      // Update Firestore profile
      final updateData = <String, dynamic>{};
      if (displayName != null) updateData['displayName'] = displayName;
      if (photoURL != null) updateData['photoURL'] = photoURL;
      if (additionalData != null) updateData.addAll(additionalData);
      
      if (updateData.isNotEmpty) {
        await _firebaseService.updateUserProfile(
          userId: _user!.uid,
          data: updateData,
        );
        
        // Refresh profile data
        await _loadUserProfile(_user!);
      }
      
      return true;
    } catch (e) {
      _setError('Failed to update profile: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}