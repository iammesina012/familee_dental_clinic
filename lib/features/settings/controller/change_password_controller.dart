import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordController {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        return {
          'success': false,
          'message': 'Not signed in.',
        };
      }

      // Reauthenticate with current password
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);

      // Update password
      await user.updatePassword(newPassword);

      return {
        'success': true,
        'message': 'Password updated successfully.',
      };
    } on FirebaseAuthException catch (e) {
      String msg = 'Unable to update password.';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'Current password is incorrect.';
      } else if (e.code == 'weak-password') {
        msg = 'New password is too weak.';
      } else if (e.code == 'requires-recent-login') {
        msg = 'Please sign in again and retry.';
      }
      return {
        'success': false,
        'message': msg,
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
    if (!password.contains(RegExp(r'[A-Za-z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    return true;
  }
}
