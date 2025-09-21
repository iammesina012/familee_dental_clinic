import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:projects/features/dashboard/pages/dashboard_page.dart';
import 'package:projects/features/auth/services/auth_service.dart';
import 'package:projects/features/activity_log/controller/login_activity_controller.dart';

class LoginController {
  final email = TextEditingController();
  final password = TextEditingController();
  final auth = AuthService();

  String? emailError;
  String? passwordError;
  bool obscure = true;
  bool hasEmailError = false;
  bool hasPasswordError = false;
  bool isUsernameLogin = false; // Toggle between email and username login

  Future<void> loadRememberedCredentials() async {
    final rememberedEmail = await auth.getRememberedEmail();
    if (rememberedEmail != null) {
      email.text = rememberedEmail;
    }
  }

  void toggleLoginMode() {
    isUsernameLogin = !isUsernameLogin;
    // Clear the email field when switching modes
    email.clear();
  }

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

  Future<void> handleLogin(BuildContext context, VoidCallback onStateUpdate,
      {bool rememberMe = false}) async {
    // Reset error states
    emailError = null;
    passwordError = null;
    hasEmailError = false;
    hasPasswordError = false;
    onStateUpdate();

    final emailText = email.text.trim();
    final passText = password.text;

    if (emailText.isEmpty) {
      hasEmailError = true;
      onStateUpdate();
      _showErrorDialog(
          context, "Input Required", "Please enter an email or username.");
      return;
    }
    if (passText.isEmpty) {
      hasPasswordError = true;
      onStateUpdate();
      _showErrorDialog(
          context, "Password Required", "Please enter a password.");
      return;
    }

    try {
      // Auto-detect if input is email or username
      final isEmail = emailText.contains('@');

      if (isEmail) {
        // Login with email
        await auth.login(
            email: emailText, password: passText, rememberMe: rememberMe);
      } else {
        // Login with username
        await auth.loginWithUsername(
            username: emailText, password: passText, rememberMe: rememberMe);
      }

      // Log successful login
      await LoginActivityController().logLogin();

      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Dashboard()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String title = "Login Failed";
      String message = "";

      if (e.code == 'invalid-email') {
        hasEmailError = true;
        message = "Enter a valid email or username.";
      } else if (e.code == 'user-disabled') {
        hasEmailError = true;
        hasPasswordError = true;
        title = "Login Denied";
        message = "This account is currently deactivated.";
      } else if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        hasEmailError = true;
        hasPasswordError = true;
        message = "Incorrect email/username or password.";
      } else {
        hasEmailError = true;
        hasPasswordError = true;
        message = "Login failed. Check your connection.";
      }

      onStateUpdate();
      _showErrorDialog(context, title, message);
    }
  }
}

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

    // Slide animation controller
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Fade animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Slide animation from top
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -2.0), // Start further above
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.bounceOut,
    ));

    // Fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _slideController.forward();
    _fadeController.forward();

    // Auto fade out after 3.5 seconds
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        _fadeOut();
      }
    });
  }

  void _fadeOut() async {
    await _fadeController.reverse();
    if (mounted) {
      widget.onDismiss();
    }
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
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        // Error Icon
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Text Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                widget.message,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Close Button
                        GestureDetector(
                          onTap: _fadeOut,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
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
      ),
    );
  }
}
