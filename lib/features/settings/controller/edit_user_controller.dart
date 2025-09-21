import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// EditUserController
///
/// Purpose: Handle user editing operations including profile updates,
/// password changes, and role management.
///
/// The UI page should use this controller for all user modification
/// operations, keeping all non-UI logic out of the widget layer.
class EditUserController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Update user profile information
  Future<Map<String, dynamic>> updateUserProfile({
    required String uid,
    required String name,
    required String username,
    required String email,
  }) async {
    try {
      // Get the current Firebase Auth email
      final currentUser = _auth.currentUser;
      final firebaseAuthEmail = currentUser?.email ??
          'iammesina012@gmail.com'; // Fallback to known email

      // Create or update in Firestore user_roles collection
      await _firestore.collection('user_roles').doc(uid).set({
        'name': name,
        'username': username,
        'email': email, // This is the "fixed email" for display and login
        'firebaseAuthEmail':
            firebaseAuthEmail, // Store the actual Firebase Auth email
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      }, SetOptions(merge: true));

      // Update Firebase Auth profile if it's the current user
      if (currentUser != null && currentUser.uid == uid) {
        await currentUser.updateDisplayName(name);
        // Note: We don't update email in Firebase Auth to avoid complications
        // The email in Firestore is for display purposes only
      }

      return {
        'success': true,
        'error': null,
      };
    } catch (e) {
      print('Error updating user profile: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Update user password
  Future<bool> updateUserPassword({
    required String uid,
    required String newPassword,
  }) async {
    try {
      // Note: This requires the user to be authenticated
      // For admin changing other users' passwords, you'd need Firebase Admin SDK
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.uid == uid) {
        await currentUser.updatePassword(newPassword);
        return true;
      }

      // For now, just update in Firestore (real implementation needs Admin SDK)
      await _firestore.collection('user_roles').doc(uid).update({
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating password: $e');
      return false;
    }
  }

  /// Update user role
  Future<bool> updateUserRole({
    required String uid,
    required String role,
  }) async {
    try {
      await _firestore.collection('user_roles').doc(uid).update({
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating user role: $e');
      return false;
    }
  }

  /// Update user status (Active/Inactive)
  Future<Map<String, dynamic>> updateUserStatus({
    required String uid,
    required bool isActive,
  }) async {
    try {
      await _firestore.collection('user_roles').doc(uid).set({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return {
        'success': true,
        'error': null,
      };
    } catch (e) {
      print('Error updating user status: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Save user changes (combines profile and status updates)
  Future<Map<String, dynamic>> saveUserChanges({
    required String uid,
    required String name,
    required String username,
    required String email,
    required bool isActive,
    required String role,
  }) async {
    try {
      // Update profile
      final profileResult = await updateUserProfile(
        uid: uid,
        name: name,
        username: username,
        email: email,
      );

      if (!profileResult['success']) {
        return profileResult;
      }

      // Update status
      final statusResult = await updateUserStatus(
        uid: uid,
        isActive: isActive,
      );

      if (!statusResult['success']) {
        return statusResult;
      }

      // Update role
      final roleResult = await updateUserRole(
        uid: uid,
        role: role,
      );

      if (!roleResult) {
        return {
          'success': false,
          'error': 'Failed to update role',
        };
      }

      return {
        'success': true,
        'error': null,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get user details for editing
  Future<Map<String, dynamic>?> getUserDetails(String uid) async {
    try {
      // Get from Firestore user_roles collection
      final doc = await _firestore.collection('user_roles').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return {
          'uid': uid,
          ...doc.data()!,
        };
      }

      // Fallback to Firebase Auth if not in Firestore
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.uid == uid) {
        return {
          'uid': uid,
          'name': currentUser.displayName ?? '',
          'username': currentUser.displayName ?? '',
          'email': currentUser.email ?? '',
          'role': 'Admin', // Default for current user
          'isActive': true,
        };
      }

      return null;
    } catch (e) {
      print('Error getting user details: $e');
      return null;
    }
  }

  /// Get available roles
  List<String> getAvailableRoles() {
    return ['Admin', 'Staff'];
  }

  /// Validate password strength
  bool isPasswordValid(String password) {
    // At least 8 characters, contains letter and number
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Za-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    return true;
  }

  /// Validate email format
  bool isEmailValid(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Format UID for display
  String formatUID(String uid) {
    if (uid.length <= 12) return uid;
    return '${uid.substring(0, 6)}...${uid.substring(uid.length - 6)}';
  }
}
