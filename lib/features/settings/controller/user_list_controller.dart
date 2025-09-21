import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// UserListController
///
/// Purpose: Encapsulate all backend/data operations related to User Management.
/// - Firebase/Supabase reads and writes for user data
/// - User creation, deletion, and modification
/// - User role management
///
/// The UI page should use this controller for data access and mutations,
/// keeping all non-UI logic out of the widget layer.
class UserListController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all Firebase Auth users
  /// Note: This requires Firebase Admin SDK in a real app
  /// For now, we'll get the current user and simulate the list
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      // Ensure admin user exists in Firestore
      await _ensureAdminUserExists();

      // Get all users from Firestore user_roles collection (active and inactive)
      final querySnapshot = await _firestore.collection('user_roles').get();

      List<Map<String, dynamic>> users = [];

      for (var doc in querySnapshot.docs) {
        final userData = doc.data();
        final user = {
          'uid': doc.id,
          'email': userData['email'] ?? '',
          'displayName': userData['name'] ?? 'User',
          'name': userData['name'] ?? 'User',
          'username': userData['username'] ?? '',
          'role': userData['role'] ?? 'Staff',
          'isActive': userData['isActive'] ?? true,
          'createdAt': userData['createdAt'],
          'updatedAt': userData['updatedAt'],
        };
        users.add(user);
      }

      // Sort: Admin accounts first, then by name A-Z
      users.sort((a, b) {
        final aIsAdmin = (a['role'] == 'Admin');
        final bIsAdmin = (b['role'] == 'Admin');
        if (aIsAdmin != bIsAdmin) {
          return aIsAdmin ? -1 : 1;
        }
        final aName = (a['name'] ?? '').toString().toLowerCase();
        final bName = (b['name'] ?? '').toString().toLowerCase();
        return aName.compareTo(bName);
      });

      return users;
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  /// Ensure admin user exists in Firestore
  Future<void> _ensureAdminUserExists() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final doc =
          await _firestore.collection('user_roles').doc(currentUser.uid).get();

      if (!doc.exists) {
        // Create admin user record in Firestore
        await _firestore.collection('user_roles').doc(currentUser.uid).set({
          'name': 'Michael William Mesina',
          'username': 'iammesina012',
          'email': currentUser.email,
          'firebaseAuthEmail': currentUser.email,
          'role': 'Admin',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error ensuring admin user exists: $e');
    }
  }

  /// Load users with error handling
  Future<Map<String, dynamic>> loadUsers() async {
    try {
      final users = await getUsers();
      return {
        'success': true,
        'users': users,
        'error': null,
      };
    } catch (e) {
      return {
        'success': false,
        'users': <Map<String, dynamic>>[],
        'error': e.toString(),
      };
    }
  }

  /// Get user role from Firestore (if stored there)
  Future<String> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('user_roles').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['role'] ?? 'Staff';
      }
      return 'Staff'; // Default role
    } catch (e) {
      print('Error getting user role: $e');
      return 'Staff';
    }
  }

  /// Update user role in Firestore
  Future<bool> updateUserRole(String uid, String role) async {
    try {
      await _firestore.collection('user_roles').doc(uid).set({
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating user role: $e');
      return false;
    }
  }

  /// Get duplicate users (same email or username)
  Future<List<Map<String, dynamic>>> getDuplicateUsers() async {
    try {
      final users = await getUsers();
      List<Map<String, dynamic>> duplicates = [];

      // Group by email
      Map<String, List<Map<String, dynamic>>> emailGroups = {};
      for (var user in users) {
        String email = user['email'] ?? '';
        if (email.isNotEmpty) {
          emailGroups[email] = emailGroups[email] ?? [];
          emailGroups[email]!.add(user);
        }
      }

      // Find duplicates
      for (var entry in emailGroups.entries) {
        if (entry.value.length > 1) {
          duplicates.addAll(entry.value);
        }
      }

      return duplicates;
    } catch (e) {
      print('Error getting duplicate users: $e');
      return [];
    }
  }
}
