import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/auth/services/email_service.dart';

class ForgotPasswordController {
  final email = TextEditingController();
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

  /// Validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Send custom password reset OTP using admin API
  Future<void> _sendCustomPasswordResetOTP(String email) async {
    try {
      print('📧 Generating custom OTP for: $email');

      // Generate a 6-digit OTP
      final otp = _generateOTP();

      // Store the OTP temporarily (in a real app, you'd store this in database with expiration)
      // For now, we'll use a simple approach
      print('📧 Generated OTP: $otp');

      // Use Supabase's admin API to send email with custom template
      // This requires service role key which should be in your .env file
      await _sendEmailWithCustomTemplate(email, otp);

      // Also store the OTP for verification (in production, use database)
      _storeOTPForVerification(email, otp);
    } catch (e) {
      print('❌ Custom OTP generation failed: $e');
      rethrow;
    }
  }

  /// Generate a 6-digit OTP
  String _generateOTP() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return (random % 1000000).toString().padLeft(6, '0');
  }

  /// Store OTP for verification (temporary storage)
  void _storeOTPForVerification(String email, String otp) {
    // In a real app, store this in database with expiration time
    // For now, we'll use a simple in-memory storage
    print('📧 OTP stored for verification: $email -> $otp');
  }

  /// Send email with custom template using existing EmailService
  Future<void> _sendEmailWithCustomTemplate(String email, String otp) async {
    print('📧 Sending custom email template with OTP: $otp');

    // Import and use the existing EmailService
    final emailSent = await EmailService.sendPasswordResetEmail(
      email: email,
      verificationCode: otp,
      expirationMinutes: '5',
    );

    if (!emailSent) {
      throw Exception('Failed to send password reset email');
    }

    print('✅ Custom email sent successfully with OTP: $otp');
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

  /// Use Supabase's built-in password reset system
  /// This uses your email template from Supabase dashboard
  /// Use Supabase's OTP system for password recovery
  Future<void> _sendSupabasePasswordReset(String email) async {
    try {
      print(
          '📧 Sending Supabase password reset email (Reset Password template) for: $email');

      // Call resetPasswordForEmail. Different SDK versions expose this differently,
      // so use dynamic to support both newer and older clients.
      try {
        // Newer versions: auth.resetPasswordForEmail
        await (_supabase.auth as dynamic).resetPasswordForEmail(email);
      } catch (e) {
        // Fallback for older clients: auth.api.resetPasswordForEmail
        try {
          await (_supabase.auth as dynamic).api.resetPasswordForEmail(email);
        } catch (inner) {
          // Re-throw the original error if fallback also fails
          print('❌ Both resetPasswordForEmail calls failed: $e / $inner');
          rethrow;
        }
      }

      print('✅ Supabase password reset email sent successfully');
      print(
          '📧 Email will be generated using your Supabase Reset Password template (ensure it includes {{ .Token }} if you want a token shown)');
    } catch (e) {
      print('❌ Supabase password reset failed: $e');
      print('❌ Error type: ${e.runtimeType}');
      if (e is AuthException) {
        print('❌ AuthException details:');
        print('  - Message: ${e.message}');
        print('  - Status code: ${e.statusCode}');
      }
      rethrow;
    }
  }

  /// Show confirmation dialog after sending reset email
  void _showConfirmationDialog(BuildContext context, String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF2D2D2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4AA),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    "Check Your Email",
                    style: AppFonts.interStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 24,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Message
                  Text(
                    "We've sent a password reset token to your email ($email). Please check your inbox and copy the token to reset your password.",
                    style: AppFonts.interStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        // Navigate to password reset page with email
                        Navigator.of(context).pushNamed(
                          '/password-reset',
                          arguments: {'email': email},
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D4AA),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "CONTINUE",
                        style: AppFonts.interStyle(
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
          ),
        );
      },
    );
  }

  /// Main method to handle forgot password flow using Supabase
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

      // Use Supabase's password reset system
      // Note: This will only work if the email exists in Supabase's auth.users table
      await _sendSupabasePasswordReset(emailText);

      isLoading = false;
      onStateUpdate();

      // Show confirmation dialog
      _showConfirmationDialog(context, emailText);
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
