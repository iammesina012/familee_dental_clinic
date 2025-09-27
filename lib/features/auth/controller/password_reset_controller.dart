// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PasswordResetController {
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;

  String? passwordError;
  String? confirmPasswordError;
  bool hasPasswordError = false;
  bool hasConfirmPasswordError = false;
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

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
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return _AnimatedSuccessNotification(
          title: title,
          message: message,
          onDismiss: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            Navigator.of(context).pushReplacementNamed('/login');
          },
        );
      },
    );
  }

  /// Validate password strength
  bool _isValidPassword(String password) {
    // At least 8 characters
    if (password.length < 8) return false;

    // At least one uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) return false;

    // At least one lowercase letter
    if (!password.contains(RegExp(r'[a-z]'))) return false;

    // At least one digit
    if (!password.contains(RegExp(r'[0-9]'))) return false;

    return true;
  }

  /// Update password in Supabase (simplified approach)
  Future<void> _updatePassword(String newPassword) async {
    try {
      // For mobile-only apps, we'll use a simpler approach
      // The user will need to be logged in to change their password
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw AuthException(
            'You need to be logged in to change your password. Please log in first.');
      }

      // Update password using the current session
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      print('Error updating password: $e');
      rethrow;
    }
  }

  /// Main method to handle password reset
  Future<void> handlePasswordReset(
    BuildContext context,
    VoidCallback onStateUpdate,
  ) async {
    // Reset error states
    passwordError = null;
    confirmPasswordError = null;
    hasPasswordError = false;
    hasConfirmPasswordError = false;
    isLoading = true;
    onStateUpdate();

    final passwordText = password.text.trim();
    final confirmPasswordText = confirmPassword.text.trim();

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
          "Password must be at least 8 characters with uppercase, lowercase, and number";
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
      // Update password
      await _updatePassword(passwordText);

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

      _showErrorDialog(context, "Error", errorMessage);
    }
  }

  void dispose() {
    password.dispose();
    confirmPassword.dispose();
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

/// Animated notification widget for success messages
class _AnimatedSuccessNotification extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback onDismiss;

  const _AnimatedSuccessNotification({
    required this.title,
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_AnimatedSuccessNotification> createState() =>
      _AnimatedSuccessNotificationState();
}

class _AnimatedSuccessNotificationState
    extends State<_AnimatedSuccessNotification> with TickerProviderStateMixin {
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
                    maxWidth: 350, minHeight: 60, maxHeight: 100),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4AA), Color(0xFF00B894)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D4AA).withOpacity(0.3),
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
                        Icons.check_circle_outline,
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
