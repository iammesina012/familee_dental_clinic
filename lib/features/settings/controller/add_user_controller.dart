import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:projects/shared/providers/user_role_provider.dart';

/// AddUserController
///
/// Purpose: Handle user creation operations including profile setup,
/// role assignment, and user management.
///
/// The UI page should use this controller for all user creation
/// operations, keeping all non-UI logic out of the widget layer.
class AddUserController {
  final SupabaseClient _supabase = Supabase.instance.client;

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
      // Use signUp instead of admin.createUser (client-safe approach)
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'display_name': name,
          'username': username,
        },
      );

      if (response.user == null) {
        return {
          'success': false,
          'error': 'Failed to create user in Supabase Auth',
        };
      }

      final user = response.user!;

      // Create user profile in Supabase
      await _supabase.from('user_roles').insert({
        'id': user.id,
        'auth_id': user.id, // Add auth_id field
        'name': name,
        'username': username,
        'email': email,
        'role': role,
        'is_active': isActive,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'error': null,
        'user': {
          'uid': user.id,
          'email': user.email,
          'displayName': name,
        },
      };
    } catch (e) {
      // Check if it's a rate limit error
      if (e.toString().contains('over_email_send_rate_limit') ||
          e.toString().contains('429') ||
          e.toString().contains('21 seconds')) {
        return {
          'success': false,
          'error':
              'Rate limit exceeded. Please wait 21 seconds before trying again.',
        };
      }

      // Check if it's a duplicate email error
      if (e.toString().contains('already registered') ||
          e.toString().contains('duplicate')) {
        return {
          'success': false,
          'error': 'Email is already registered. Please use a different email.',
        };
      }

      return {
        'success': false,
        'error': 'Failed to create user: ${e.toString()}',
      };
    }
  }

  /// Check if username is already taken
  Future<bool> isUsernameTaken(String username) async {
    try {
      final response = await _supabase
          .from('user_roles')
          .select('id')
          .eq('username', username)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      return false; // Assume available if error occurs
    }
  }

  /// Check if email is already taken
  Future<bool> isEmailTaken(String email) async {
    try {
      final response = await _supabase
          .from('user_roles')
          .select('id')
          .eq('email', email)
          .limit(1);

      return response.isNotEmpty;
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

  /// Get available roles based on current user's role hierarchy
  List<String> getAvailableRoles() {
    final userRoleProvider = UserRoleProvider();
    return userRoleProvider.getAvailableRolesToAssign();
  }

  /// Sync existing Supabase users with user_roles table
  Future<Map<String, dynamic>> syncExistingUsers() async {
    try {
      // Get all users from Supabase Auth (this requires admin privileges)
      final users = await _supabase.auth.admin.listUsers();

      int syncedCount = 0;
      List<String> errors = [];

      for (final user in users) {
        try {
          // Check if user already exists in user_roles table
          final existingUser = await _supabase
              .from('user_roles')
              .select('id')
              .eq('id', user.id)
              .limit(1);

          if (existingUser.isEmpty) {
            // User doesn't exist in user_roles, create profile
            await _supabase.from('user_roles').insert({
              'id': user.id,
              'auth_id': user.id, // Add auth_id field
              'name': user.userMetadata?['display_name'] ??
                  user.email?.split('@')[0] ??
                  'Unknown User',
              'username': user.userMetadata?['username'] ??
                  user.email?.split('@')[0] ??
                  'unknown',
              'email': user.email ?? '',
              'role': 'Staff', // Default role
              'is_active': true,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
            syncedCount++;
          }
        } catch (e) {
          errors.add('Failed to sync user ${user.email}: ${e.toString()}');
        }
      }

      return {
        'success': true,
        'synced_count': syncedCount,
        'total_users': users.length,
        'errors': errors,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to sync users: ${e.toString()}',
      };
    }
  }

  /// Add current user to user_roles table (no admin privileges needed)
  Future<Map<String, dynamic>> addCurrentUser() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return {
          'success': false,
          'error': 'No user is currently logged in',
        };
      }

      // Check if user already exists in user_roles table
      final existingUser = await _supabase
          .from('user_roles')
          .select('id')
          .eq('id', currentUser.id)
          .limit(1);

      if (existingUser.isNotEmpty) {
        return {
          'success': true,
          'message': 'User already exists in user list',
        };
      }

      // Add current user to user_roles table
      await _supabase.from('user_roles').insert({
        'id': currentUser.id,
        'auth_id': currentUser.id, // Add auth_id field
        'name': currentUser.userMetadata?['display_name'] ??
            currentUser.email?.split('@')[0] ??
            'Current User',
        'username': currentUser.userMetadata?['username'] ??
            currentUser.email?.split('@')[0] ??
            'current_user',
        'email': currentUser.email ?? '',
        'role': 'Admin', // Make current user admin
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'message': 'Current user added to user list',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to add current user: ${e.toString()}',
      };
    }
  }
}
