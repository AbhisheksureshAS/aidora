import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Stream for authentication state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  static Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Create user account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user profile in Firestore
      if (userCredential.user != null) {
        await _createUserProfile(userCredential.user!, name);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e);
    }
  }

  // Sign in with email and password
  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last active timestamp
      if (userCredential.user != null) {
        await _updateLastActive(userCredential.user!.uid);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e);
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw 'Error signing out: $e';
    }
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e);
    }
  }

  // Get user profile from Firestore
  static Future<UserModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirebase(doc.data() as Map<String, dynamic>, uid);
      }
      return null;
    } catch (e) {
      throw 'Error fetching user profile: $e';
    }
  }

  // Update user profile
  static Future<void> updateUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update(user.toFirebase());
    } catch (e) {
      throw 'Error updating user profile: $e';
    }
  }

  // Check if user exists
  static Future<bool> userExists(String email) async {
    try {
      // Alternative approach: try to get user data from Firestore
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Delete user account
  static Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Delete user data from Firestore
        await _firestore.collection('users').doc(user.uid).delete();
        
        // Delete user authentication
        await user.delete();
      }
    } catch (e) {
      throw 'Error deleting account: $e';
    }
  }

  // Change password
  static Future<void> changePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
      }
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e);
    }
  }

  // Update email
  static Future<void> updateEmail(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Note: updateEmail might require re-authentication
        await user.verifyBeforeUpdateEmail(newEmail);
        
        // Update email in Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'email': newEmail,
        });
      }
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e);
    }
  }

  // Private helper methods

  static Future<void> _createUserProfile(User user, String name) async {
    final userModel = UserModel(
      uid: user.uid,
      email: user.email ?? '',
      name: name,
      createdAt: DateTime.now(),
      lastActive: DateTime.now(),
      isHelperEnabled: false,
      rating: 0.0,
      totalRatings: 0,
      skills: [],
      bio: '',
      latitude: null,
      longitude: null,
      locationName: '',
      profileImageUrl: '',
    );

    await _firestore.collection('users').doc(user.uid).set(userModel.toFirebase());
  }

  static Future<void> _updateLastActive(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'lastActive': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'invalid-credential':
        return 'The email or password is incorrect.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  // Get authentication status
  static bool get isAuthenticated => currentUser != null;

  // Get user display name
  static String get displayName => 
      currentUser?.displayName ?? 
      currentUser?.email?.split('@')[0] ?? 
      'User';

  // Get user email
  static String get userEmail => currentUser?.email ?? '';

  // Check if email is verified
  static bool get isEmailVerified => currentUser?.emailVerified ?? false;

  // Send email verification
  static Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      throw 'Error sending verification email: $e';
    }
  }

  // Reload user data
  static Future<void> reloadUser() async {
    try {
      await currentUser?.reload();
    } catch (e) {
      throw 'Error reloading user data: $e';
    }
  }
}
