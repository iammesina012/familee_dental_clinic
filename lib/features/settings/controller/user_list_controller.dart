import 'package:supabase_flutter/supabase_flutter.dart';

/// UserListController
///
/// Purpose: Encapsulate all backend/data operations related to User Management.
/// - Supabase reads and writes for user data
/// - User creation, deletion, and modification
/// - User role management
///
/// The UI page should use this controller for data access and mutations,
/// keeping all non-UI logic out of the widget layer.
class UserListController {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all Supabase users
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      // Ensure admin user exists in Supabase
      await _ensureAdminUserExists();

      // Get all users from Supabase user_roles table (active and inactive)
      final response = await _supabase.from('user_roles').select('*');

      List<Map<String, dynamic>> users = [];

      for (var userData in response) {
        final user = {
          'uid': userData['id'] ?? '',
          'email': userData['email'] ?? '',
          'displayName': userData['name'] ?? 'User',
          'name': userData['name'] ?? 'User',
          'username': userData['username'] ?? '',
          'role': userData['role'] ?? 'Staff',
          'isActive': userData['is_active'] ?? true,
          'createdAt': userData['created_at'],
          'updatedAt': userData['updated_at'],
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

  /// Ensure admin user exists in Supabase
  Future<void> _ensureAdminUserExists() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      final response = await _supabase
          .from('user_roles')
          .select('id')
          .eq('id', currentUser.id)
          .limit(1);

      if (response.isEmpty) {
        // Create admin user record in Supabase
        await _supabase.from('user_roles').insert({
          'id': currentUser.id,
          'name': 'Michael William Mesina',
          'username': 'iammesina012',
          'email': currentUser.email,
          'role': 'Admin',
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
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

  /// Get user role from Supabase (if stored there)
  Future<String> getUserRole(String uid) async {
    try {
      final response = await _supabase
          .from('user_roles')
          .select('role')
          .eq('id', uid)
          .limit(1)
          .single();

      return response['role'] ?? 'Staff';
    } catch (e) {
      print('Error getting user role: $e');
      return 'Staff';
    }
  }

  /// Update user role in Supabase
  Future<bool> updateUserRole(String uid, String role) async {
    try {
      await _supabase.from('user_roles').update({
        'role': role,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid);
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
