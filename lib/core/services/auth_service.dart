import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Interface for Authentication Service to enforce OOP principles
abstract class IAuthService extends ChangeNotifier {
  Future<bool> signIn(String email, String password);
  Future<bool> register(String email, String password, {String? displayName});
  Future<void> signOut();
  Future<bool> checkAuthStatus();
  bool get isAuthenticated;
  User? get currentUser;
  Future<String?> signInWithGoogle();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> deleteCurrentUser();
  Future<void> reauthenticateWithPassword(String password);
  Future<void> reauthenticateWithGoogle();
}

/// Concrete implementation of IAuthService using Firebase Auth
class AuthService extends ChangeNotifier implements IAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _webClientId =
      '231431315497-21t67q3me6h4r28iufgjr92tttmv1c0d.apps.googleusercontent.com';

  AuthService() {
    // Web requires bypassing the local GoogleSignIn plugin initialization
    // to prevent infinite hangs.
    if (!kIsWeb) {
      GoogleSignIn.instance.initialize(
        serverClientId: _webClientId,
      );
    }
    
    // Listen to auth state changes to auto-update the UI and provision profile
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _syncUserProfile(user);
      }
      notifyListeners();
    });
  }

  @override
  bool get isAuthenticated => _auth.currentUser != null;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<String?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web uses popup to avoid DWDS hangs and manual client ID config
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        await _auth.signInWithPopup(authProvider);
      } else {
        // Ensure GoogleSignIn is initialized with the project's Web Client ID
        await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
        final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        
        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        
        await _auth.signInWithCredential(credential);
      }
      return null; // Success
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      return e.toString();
    }
  }

  @override
  Future<bool> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return true;
    } catch (e) {
      debugPrint('Email Sign-In Error: $e');
      return false;
    }
  }

  @override
  Future<bool> register(String email, String password, {String? displayName}) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        final cleanName = displayName?.trim();
        if (cleanName != null && cleanName.isNotEmpty) {
          try {
            await user.updateDisplayName(cleanName);
          } catch (nameError) {
            debugPrint('Notice: user.updateDisplayName failed: $nameError');
          }
        }
        await _syncUserProfile(user, initialDisplayName: cleanName);
      }
      return true;
    } catch (e) {
      debugPrint('Email Registration Error: $e');
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn.instance.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      debugPrint("Error signing out: $e");
    }
  }

  @override
  Future<bool> checkAuthStatus() async {
    // FirebaseAuth automatically restores session if available.
    // We just return the current status.
    return isAuthenticated;
  }

  Future<void> _syncUserProfile(User user, {String? initialDisplayName}) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final doc = await userRef.get();
      if (!doc.exists) {
        final resolvedName = (initialDisplayName != null && initialDisplayName.isNotEmpty)
            ? initialDisplayName
            : ((user.displayName != null && user.displayName!.isNotEmpty)
                ? user.displayName!
                : (user.email?.split('@').first ?? 'Learner'));

        await userRef.set({
          'displayName': resolvedName,
          'name': resolvedName,
          'email': user.email ?? '',
          'photoUrl': user.photoURL,
          'score': 0,
          'streakCount': 0,
          'totalCardsStudied': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'lastStudyDate': null,
          'unlockedAchievements': <String>[],
        });
        debugPrint('Provisioned new Firestore profile for user ${user.uid} ($resolvedName)');
      }
    } catch (e) {
      debugPrint('Error syncing user profile to Firestore: $e');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      if (!kIsWeb) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {}
      }
      await user.delete();
      debugPrint('[AuthService] Successfully deleted user credentials.');
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] FirebaseAuthException during user deletion: ${e.code}');
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] Unexpected error deleting user: $e');
      rethrow;
    }
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No authenticated user with email found to reauthenticate.');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password.trim(),
    );
    await user.reauthenticateWithCredential(credential);
    debugPrint('[AuthService] Successfully reauthenticated with email/password.');
  }

  @override
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found to reauthenticate.');
    }

    if (kIsWeb) {
      final authProvider = GoogleAuthProvider();
      await user.reauthenticateWithPopup(authProvider);
    } else {
      await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    }
    debugPrint('[AuthService] Successfully reauthenticated with Google.');
  }
}
