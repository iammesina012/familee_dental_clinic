import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:projects/features/auth/services/auth_service.dart';
import 'package:projects/features/auth/pages/password_reset_confirmation_page.dart';

class ForgotPasswordController {
  final email = TextEditingController();
  final auth = AuthService();
  final SupabaseClient _supabase = Supabase.instance.client;

  String? emailError;
  bool hasEmailError = false;
  bool isLoading = false;

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
          },
        );
      },
    );
  }

  /// Check if email exists in the user_roles table
  Future<bool> _checkEmailExists(String email) async {
    try {
      final userQuery = await _supabase
          .from('user_roles')
          .select('email')
          .eq('email', email.toLowerCase())
          .limit(1);

      return userQuery.isNotEmpty;
    } catch (e) {
      print('Error checking email existence: $e');
      return false;
    }
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Send password reset email with deep link
  Future<void> _sendPasswordResetEmail(String email) async {
    try {
      // Use the app's package name for deep linking
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.example.projects://reset-password', // Use package name
      );
    } catch (e) {
      print('Error sending password reset email: $e');
      rethrow;
    }
  }

  /// Main method to handle forgot password flow
  Future<void> handleForgotPassword(
    BuildContext context,
    VoidCallback onStateUpdate,
  ) async {
    // Reset error states
    emailError = null;
    hasEmailError = false;
    isLoading = true;
    onStateUpdate();

    final emailText = email.text.trim();

    // Validate email format
    if (emailText.isEmpty) {
      emailError = "Email is required";
      hasEmailError = true;
      isLoading = false;
      onStateUpdate();
      return;
    }

    if (!_isValidEmail(emailText)) {
      emailError = "Please enter a valid email address";
      hasEmailError = true;
      isLoading = false;
      onStateUpdate();
      return;
    }

    try {
      // Check if email exists in database
      final emailExists = await _checkEmailExists(emailText);

      if (!emailExists) {
        emailError = "This email does not exist in our system";
        hasEmailError = true;
        isLoading = false;
        onStateUpdate();
        return;
      }

      // Send password reset email with deep link
      await _sendPasswordResetEmail(emailText);

      isLoading = false;
      onStateUpdate();

      // Navigate to confirmation page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PasswordResetConfirmationPage(email: emailText),
        ),
      );
    } catch (e) {
      isLoading = false;
      onStateUpdate();

      String errorMessage =
          "An error occurred while sending the reset email. Please try again.";

      if (e is AuthException) {
        errorMessage = e.message;
      }

      _showErrorDialog(context, "Error", errorMessage);
    }
  }

  void dispose() {
    email.dispose();
  }
}

/// Animated notification widget for errors (matching login page style)
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
