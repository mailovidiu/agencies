import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Sign in with email and password
  Future<String?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user?.email;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Create account with email and password
  Future<String?> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user?.email;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // Reset password
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Resolve admin access from secure server-side signals.
  // Priority:
  // 1. Firebase custom claim: admin=true or role in {admin, super_admin}
  // 2. Firestore admin_users/{uid} with isActive=true
  Future<bool> hasAdminAccess({
    User? user,
    bool forceRefreshToken = false,
  }) async {
    final resolvedUser = user ?? currentUser;
    if (resolvedUser == null) return false;

    try {
      final tokenResult =
          await resolvedUser.getIdTokenResult(forceRefreshToken);
      final claims = tokenResult.claims;
      final hasAdminClaim = claims?['admin'] == true ||
          claims?['role'] == 'admin' ||
          claims?['role'] == 'super_admin';

      if (hasAdminClaim) {
        return true;
      }
    } catch (_) {
      // Continue with Firestore fallback.
    }

    try {
      final adminDoc = await _firestore
          .collection('admin_users')
          .doc(resolvedUser.uid)
          .get();
      if (!adminDoc.exists) return false;

      final data = adminDoc.data();
      return data?['isActive'] == true;
    } catch (_) {
      return false;
    }
  }

  // Handle Firebase Auth exceptions
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
      default:
        return 'An error occurred: ${e.message}';
    }
  }
}
