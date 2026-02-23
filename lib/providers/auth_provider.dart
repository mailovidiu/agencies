import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

// Firebase auth provider
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  StreamSubscription<User?>? _authSubscription;
  User? _user;
  bool _isAdmin = false;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authSubscription = _authService.authStateChanges.listen((User? user) {
      unawaited(_handleAuthStateChanged(user));
    });
    unawaited(_handleAuthStateChanged(_authService.currentUser));
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    _user = user;
    _isAdmin = await _authService.hasAdminAccess(
      user: user,
      forceRefreshToken: true,
    );
    notifyListeners();
  }

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _isAdmin;

  // Sign in
  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.signInWithEmailAndPassword(
          email: email, password: password);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Create account
  Future<bool> createAccount(
      {required String email, required String password}) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.createUserWithEmailAndPassword(
          email: email, password: password);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _authService.signOut();
  }

  // Reset password
  Future<bool> resetPassword({required String email}) async {
    try {
      await _authService.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  void clearError() {
    _clearError();
  }

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
