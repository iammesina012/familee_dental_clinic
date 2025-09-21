import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// AddUserController
///
/// Purpose: Handle user creation operations including profile setup,
/// role assignment, and user management.
///
/// The UI page should use this controller for all user creation
/// operations, keeping all non-UI logic out of the widget layer.
class AddUserController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new user profile
  Future<Map<String, dynamic>> createUser({
    required String name,
    required String username,
    required String email,
    required String password,
    required String role,
    required bool isActive,
  }) async {
    try {
      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return {
          'success': false,
          'error': 'Failed to create user in Firebase Auth',
        };
      }

      // Update display name in Firebase Auth
      await user.updateDisplayName(name);

      // Create user profile in Firestore
      await _firestore.collection('user_roles').doc(user.uid).set({
        'name': name,
        'username': username,
        'email': email,
        'firebaseAuthEmail': email, // Store the Firebase Auth email
        'role': role,
        'isActive': isActive,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'error': null,
        'user': {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Check if username is already taken
  Future<bool> isUsernameTaken(String username) async {
    try {
      final query = await _firestore
          .collection('user_roles')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      return false; // Assume available if error occurs
    }
  }

  /// Check if email is already taken
  Future<bool> isEmailTaken(String email) async {
    try {
      final query = await _firestore
          .collection('user_roles')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      return false; // Assume available if error occurs
    }
  }

  /// Validate email format
  bool isEmailValid(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate password strength
  bool isPasswordValid(String password) {
    return password.length >= 6;
  }

  /// Get available roles
  List<String> getAvailableRoles() {
    return ['Admin', 'Staff'];
  }
}
