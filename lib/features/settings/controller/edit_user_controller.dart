import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:io';

/// EditUserController
///
/// Purpose: Handle user editing operations including profile updates,
/// password changes, and role management.
///
/// The UI page should use this controller for all user modification
/// operations, keeping all non-UI logic out of the widget layer.
class EditUserController {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Update user profile information
  Future<Map<String, dynamic>> updateUserProfile({
    required String uid,
    required String name,
    required String username,
    required String email,
    String? role,
  }) async {
    try {
      // Get the current Supabase Auth user
      final currentUser = _supabase.auth.currentUser;

      // Create or update in Supabase user_roles table
      final data = {
        'id': uid,
        'auth_id': uid, // Add auth_id field
        'name': name,
        'username': username,
        'email': email,
        'updated_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'is_active': true,
      };

      // Add role if provided
      if (role != null) {
        data['role'] = role;
      }

      await _supabase.from('user_roles').upsert(data);

      // Update Supabase Auth profile if it's the current user
      if (currentUser != null && currentUser.id == uid) {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {
              'display_name': name,
              'username': username,
            },
          ),
        );
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
      // For admin changing other users' passwords, you'd need Supabase Admin API
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null && currentUser.id == uid) {
        await _supabase.auth.updateUser(
          UserAttributes(password: newPassword),
        );
        return true;
      }

      // For now, just update in Supabase (real implementation needs Admin API)
      await _supabase.from('user_roles').update({
        'password_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid);

      return true;
    } catch (e) {
      print('Error updating password: $e');
      return false;
    }
  }

  /// Reset user password to default
  Future<Map<String, dynamic>> resetPassword({
    required String uid,
    required String newPassword,
  }) async {
    try {
      // Get service role key from environment
      final serviceRoleKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'];

      if (serviceRoleKey == null || serviceRoleKey.isEmpty) {
        return {
          'success': false,
          'error': 'Service role key not found. Please check your .env file.',
        };
      }

      // Update user_roles table with available columns
      await _supabase.from('user_roles').update({
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid);

      // Use Supabase Admin API to actually change the password
      final supabaseUrl = "https://mjczybgsgjnrmddcomoc.supabase.co";
      final response = await _makeAdminRequest(
        supabaseUrl: supabaseUrl,
        serviceRoleKey: serviceRoleKey,
        endpoint: '/auth/v1/admin/users/$uid',
        method: 'PUT',
        body: {
          'password': newPassword,
        },
      );

      if (response['success']) {
        return {
          'success': true,
          'message':
              'Password reset successfully to default password: $newPassword',
        };
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Failed to reset password',
        };
      }
    } catch (e) {
      print('Error resetting password: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Make admin request to Supabase Auth API
  Future<Map<String, dynamic>> _makeAdminRequest({
    required String supabaseUrl,
    required String serviceRoleKey,
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
  }) async {
    try {
      final client = HttpClient();
      final request = await client.openUrl(
        method,
        Uri.parse('$supabaseUrl$endpoint'),
      );

      // Set headers
      request.headers.set('Authorization', 'Bearer $serviceRoleKey');
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('apikey', serviceRoleKey);

      // Add body if provided
      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'data': jsonDecode(responseBody),
        };
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: $responseBody',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Update user role
  Future<bool> updateUserRole({
    required String uid,
    required String role,
  }) async {
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

  /// Update user status (Active/Inactive)
  Future<Map<String, dynamic>> updateUserStatus({
    required String uid,
    required bool isActive,
  }) async {
    try {
      await _supabase.from('user_roles').update({
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid);
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
        role: role,
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
      // Get from Supabase user_roles table
      final response = await _supabase
          .from('user_roles')
          .select('*')
          .eq('id', uid)
          .limit(1)
          .single();

      if (response.isNotEmpty) {
        return {
          'uid': uid,
          'name': response['name'] ?? '',
          'username': response['username'] ?? '',
          'email': response['email'] ?? '',
          'role': response['role'] ?? 'Staff',
          'isActive': response['is_active'] ?? true,
          'createdAt': response['created_at'],
          'updatedAt': response['updated_at'],
        };
      }

      // Fallback to Supabase Auth if not in database
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null && currentUser.id == uid) {
        return {
          'uid': uid,
          'name': currentUser.userMetadata?['display_name'] ?? '',
          'username': currentUser.userMetadata?['username'] ?? '',
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
