import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordController {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
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

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      await user.updatePassword(newPassword);

      return {
        'success': true,
        'message': 'Password updated successfully.',
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Unable to update password.';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Current password is incorrect.';
      } else if (e.code == 'weak-password') {
        message = 'New password is too weak.';
      } else if (e.code == 'requires-recent-login') {
        message = 'Please sign in again and retry.';
      }
      return {
        'success': false,
        'message': message,
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Unable to update password right now.',
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
