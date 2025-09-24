import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordController {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword, // Still required for function signature
    required String newPassword,
  }) async {
    try {
      await _auth.currentUser?.reload();
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'Not signed in.',
        };
      }

      final providerIds = user.providerData.map((p) => p.providerId).toList();
      final usesEmailPassword = providerIds.contains('password');
      if (!usesEmailPassword) {
        return {
          'success': false,
          'message': 'Password change requires email/password sign-in.',
        };
      }

      if (user.email == null || user.email!.isEmpty) {
        return {
          'success': false,
          'message': 'Account has no email address set.',
        };
      }

      // TEMPORARY WORKAROUND: Try to update password directly
      // This might fail with 'requires-recent-login' error
      try {
        await user.updatePassword(newPassword);
        return {
          'success': true,
          'message': 'Password updated successfully.',
        };
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          return {
            'success': false,
            'message':
                'Security: Please sign out and sign in again, then try changing your password.',
          };
        } else if (e.code == 'weak-password') {
          return {
            'success': false,
            'message': 'New password is too weak. Use at least 6 characters.',
          };
        } else {
          return {
            'success': false,
            'message': 'Unable to update password: ${e.message}',
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
    if (!RegExp(r'[0-9]').hasMatch(password)) return false;
    return true;
  }
}
