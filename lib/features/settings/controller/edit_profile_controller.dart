import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileController {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword, // Still required for function signature
    required String newPassword,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'Not signed in.',
        };
      }

      if (user.email == null || user.email!.isEmpty) {
        return {
          'success': false,
          'message': 'Account has no email address set.',
        };
      }

      try {
        // Update password using Supabase Auth
        await _supabase.auth.updateUser(
          UserAttributes(password: newPassword),
        );
        return {
          'success': true,
          'message': 'Password updated successfully.',
        };
      } catch (e) {
        if (e.toString().contains('weak-password')) {
          return {
            'success': false,
            'message': 'New password is too weak. Use at least 6 characters.',
          };
        } else if (e.toString().contains('requires-recent-login')) {
          return {
            'success': false,
            'message':
                'Security: Please sign out and sign in again, then try changing your password.',
          };
        } else {
          return {
            'success': false,
            'message': 'Unable to update password: ${e.toString()}',
          };
        }
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  bool isPasswordValid(String password) {
    if (password.length < 8) return false;
    if (!RegExp(r'[A-Za-z]').hasMatch(password)) return false;
    if (!RegExp(r'[A-Z]').hasMatch(password)) return false; // Require uppercase
    if (!RegExp(r'[0-9]').hasMatch(password)) return false;
    return true;
  }
}
