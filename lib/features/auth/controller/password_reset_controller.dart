// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PasswordResetController {
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final token =
      TextEditingController(); // Changed from verificationCode to token

  String? passwordError;
  String? confirmPasswordError;
  String? tokenError;
  bool hasPasswordError = false;
  bool hasConfirmPasswordError = false;
  bool hasTokenError = false;
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  // Resend functionality
  bool canResend = true; // Allow resend immediately on password reset page
  int resendCooldown = 0;
  Timer? _cooldownTimer;

  // Token expiry functionality (separate from resend cooldown)
  int tokenExpiryRemaining = 0;
  Timer? _expiryTimer;

  // Getter to check if resend timer is running
  bool get isResendTimerRunning => _cooldownTimer != null;

  // Getter to check if token expiry timer is running
  bool get isTokenTimerRunning => _expiryTimer != null;

  // Backwards-compatible getter used by UI before: consider timer running if either exists
  bool get isTimerRunning => (_cooldownTimer != null) || (_expiryTimer != null);

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return _AnimatedNotification(
          title: title,
          message: message,
          onDismiss: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF2D2D2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4AA),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Message
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Back to Login Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pushReplacementNamed('/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4AA),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "BACK TO LOGIN",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Validate password strength (matching Supabase requirements)
  bool _isValidPassword(String password) {
    // Removed verbose debug prints

    // At least 8 characters
    if (password.length < 8) {
      print('❌ DEBUG: Password too short (${password.length} < 8)');
      return false;
    }

    // At least one uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) {
      print('❌ DEBUG: No uppercase letter found');
      return false;
    }

    // At least one lowercase letter
    if (!password.contains(RegExp(r'[a-z]'))) {
      print('❌ DEBUG: No lowercase letter found');
      return false;
    }

    // At least one digit
    if (!password.contains(RegExp(r'[0-9]'))) {
      print('❌ DEBUG: No digit found');
      return false;
    }

    // Disallow special characters: only allow letters and digits
    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(password)) {
      print('❌ DEBUG: Special characters detected (not allowed)');
      return false;
    }

    print('✅ DEBUG: Password validation passed');
    return true;
  }

  /// Verify custom token and update password using Supabase Admin API
  Future<void> _updatePasswordWithToken(
      String email, String token, String newPassword) async {
    try {
      // Token verification in progress

      // Use Supabase's verifyOTP method to verify the OTP token
      final response = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.email,
        token: token,
        email: email,
      );

      if (response.user != null) {
        print('✅ DEBUG: OTP verified successfully');

        // Update password using Supabase's updateUser method
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );

        print('✅ DEBUG: Password updated successfully');
      } else {
        print('❌ DEBUG: OTP verification failed');
        throw AuthException('Invalid or expired token');
      }
    } catch (e) {
      print('❌ DEBUG: Error updating password: $e');
      rethrow;
    }
  }

  /// Main method to handle password reset with Supabase token
  Future<void> handlePasswordReset(
    BuildContext context,
    VoidCallback onStateUpdate, {
    required String email,
  }) async {
    // Reset error states
    passwordError = null;
    confirmPasswordError = null;
    tokenError = null;
    hasPasswordError = false;
    hasConfirmPasswordError = false;
    hasTokenError = false;
    isLoading = true;
    onStateUpdate();

    final passwordText = password.text.trim();
    final confirmPasswordText = confirmPassword.text.trim();
    final tokenText = token.text.trim();

    // Validate token
    if (tokenText.isEmpty) {
      tokenError = "Token is required";
      hasTokenError = true;
      isLoading = false;
      onStateUpdate();
      return;
    }

    // Validate password
    if (passwordText.isEmpty) {
      passwordError = "Password is required";
      hasPasswordError = true;
      isLoading = false;
      onStateUpdate();
      return;
    }

    if (!_isValidPassword(passwordText)) {
      passwordError =
          "Password must be at least 8 characters with uppercase, lowercase, and number. No symbols and whitespaces allowed.";
      hasPasswordError = true;
      isLoading = false;
      onStateUpdate();
      return;
    }

    // Validate confirm password
    if (confirmPasswordText.isEmpty) {
      confirmPasswordError = "Please confirm your password";
      hasConfirmPasswordError = true;
      isLoading = false;
      onStateUpdate();
      return;
    }

    if (passwordText != confirmPasswordText) {
      confirmPasswordError = "Passwords do not match";
      hasConfirmPasswordError = true;
      isLoading = false;
      onStateUpdate();
      return;
    }

    try {
      // Quick client-side check: ensure the new password is not the same as the existing password.
      // We do a temporary sign-in with the provided email and new password. If sign-in succeeds,
      // that means the new password is identical to the old password and we should show an inline error
      // without calling verifyOTP (which would consume the OTP).
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: passwordText,
        );

        // If sign-in succeeded and returned a user/session, treat it as 'password matches current'
        if (Supabase.instance.client.auth.currentUser != null) {
          passwordError =
              'New password should be different from your old password';
          hasPasswordError = true;
          isLoading = false;
          onStateUpdate();

          // Sign out the temporary session to avoid leaving the user logged in
          try {
            await Supabase.instance.client.auth.signOut();
          } catch (_) {}

          return;
        }
      } catch (signInError) {
        // Temporary sign-in check failed (expected when new password != old)
        // Continue with verifyOTP + update flow.
        print(
            '🔍 DEBUG: Temporary sign-in check failed (expected if new password != old): $signInError');
      }

      // Update password using Supabase token
      await _updatePasswordWithToken(email, tokenText, passwordText);

      isLoading = false;
      onStateUpdate();

      // Show success dialog
      _showSuccessDialog(
        context,
        "Password Reset Successful",
        "Your password has been successfully updated. You can now log in with your new password.",
      );
    } catch (e) {
      isLoading = false;
      onStateUpdate();

      String errorMessage =
          "An error occurred while updating your password. Please try again.";

      if (e is AuthException) {
        errorMessage = e.message;
      }

      // If the error is about the token (invalid/expired) or verification, show dialog
      final lower = errorMessage.toLowerCase();
      final isTokenError = lower.contains('invalid') ||
          lower.contains('expired') ||
          lower.contains('token') ||
          lower.contains('otp') ||
          lower.contains('verification');

      // If the error is about the new password being the same as the old one,
      // surface it inline under the password field instead of showing the dialog.
      final isPasswordInlineError = lower.contains('different from the old') ||
          lower.contains('same as the old') ||
          lower.contains('must be different');

      if (isPasswordInlineError) {
        passwordError = errorMessage;
        hasPasswordError = true;
        // keep token states unchanged
        onStateUpdate();
        return;
      }

      if (isTokenError) {
        _showErrorDialog(context, "Error", errorMessage);
        return;
      }

      // Fallback: show dialog for any other unexpected errors
      _showErrorDialog(context, "Error", errorMessage);
    }
  }

  /// Start cooldown timer for resend functionality
  void startCooldownTimer(VoidCallback onStateUpdate, {int seconds = 60}) {
    canResend = false;
    resendCooldown = seconds; // configurable cooldown in seconds

    // Cancel any existing timer before starting a new one
    _cooldownTimer?.cancel();

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      resendCooldown--;
      if (resendCooldown <= 0) {
        canResend = true;
        _cooldownTimer?.cancel();
        _cooldownTimer = null;
      }
      onStateUpdate(); // This will trigger UI updates
    });
  }

  /// Start token expiry timer (separate from resend cooldown)
  void startTokenExpiryTimer(VoidCallback onStateUpdate, {int seconds = 300}) {
    tokenExpiryRemaining = seconds;

    // Cancel existing expiry timer
    _expiryTimer?.cancel();

    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      tokenExpiryRemaining--;
      if (tokenExpiryRemaining <= 0) {
        _expiryTimer?.cancel();
        _expiryTimer = null;
      }
      onStateUpdate();
    });
  }

  /// Resend password reset email
  Future<void> resendPasswordReset(
      String email, VoidCallback onStateUpdate) async {
    try {
      print('📧 Resending password reset email to: $email');

      // Use Supabase's reset password API so the Reset Password template is used
      try {
        // Newer clients: auth.resetPasswordForEmail
        await (Supabase.instance.client.auth as dynamic)
            .resetPasswordForEmail(email);
      } catch (e) {
        // Fallback for older clients: auth.api.resetPasswordForEmail
        try {
          await (Supabase.instance.client.auth as dynamic)
              .api
              .resetPasswordForEmail(email);
        } catch (inner) {
          print('❌ Both resetPasswordForEmail calls failed: $e / $inner');
          rethrow;
        }
      }

      // Start cooldown timer with state update callback
      // Use 60 second cooldown (1 minute)
      startCooldownTimer(onStateUpdate, seconds: 60);
      // Restart token expiry timer (e.g., 5 minutes)
      startTokenExpiryTimer(onStateUpdate, seconds: 300);

      print('✅ Resend password reset email sent successfully');
      print(
          '📧 Email will use your Supabase Reset Password template (include {{ .Token }} to show token)');
    } catch (e) {
      print('❌ Resend password reset failed: $e');
      rethrow;
    }
  }

  void dispose() {
    password.dispose();
    confirmPassword.dispose();
    token.dispose();
    _cooldownTimer?.cancel();
    _expiryTimer?.cancel();
  }
}

/// Animated notification widget for errors
class _AnimatedNotification extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback onDismiss;

  const _AnimatedNotification({
    required this.title,
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_AnimatedNotification> createState() => _AnimatedNotificationState();
}

class _AnimatedNotificationState extends State<_AnimatedNotification>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 50,
            left: 16,
            right: 16,
          ),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                constraints: const BoxConstraints(
                    maxWidth: 350, minHeight: 60, maxHeight: 80),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFEE5A52)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B6B).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onDismiss,
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
