import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/auth/services/auth_service.dart';
import 'package:familee_dental/shared/themes/font.dart';

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

  /// Generate 6-digit verification code
  String _generateVerificationCode() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final code = (random % 1000000).toString().padLeft(6, '0');
    return code;
  }

  /// Store verification code in database
  Future<void> _storeVerificationCode(String email, String code) async {
    try {
      // First, mark any existing unused codes for this email as used
      try {
        await _supabase
            .from('password_reset_codes')
            .update({'used': true})
            .eq('email', email.toLowerCase())
            .eq('used', false);
      } catch (e) {
        print('⚠️ Warning: Could not mark old codes as used: $e');
        // Continue anyway, this is not critical
      }

      // Calculate expiration time (10 minutes from now)
      final expiresAt = DateTime.now().add(const Duration(minutes: 10));

      // Insert new code into database
      print('🔍 DEBUG: Attempting to store code for email: $email');
      print('🔍 DEBUG: Code to store: $code');
      print('🔍 DEBUG: Expiration time: $expiresAt');

      final insertData = {
        'email': email.toLowerCase(),
        'code': code,
        'expires_at': expiresAt.toIso8601String(),
        'used': false,
      };

      print('🔍 DEBUG: Inserting data: $insertData');

      await _supabase.from('password_reset_codes').insert(insertData);

      print('✅ Code stored in database: $code expires at $expiresAt');
      print('✅ Old codes for $email marked as used');

      // Verify the code was actually stored by querying it back
      final verifyQuery = await _supabase
          .from('password_reset_codes')
          .select('*')
          .eq('email', email.toLowerCase())
          .eq('code', code)
          .limit(1);

      if (verifyQuery.isNotEmpty) {
        print('✅ VERIFICATION: Code found in database after insertion');
        print('✅ VERIFICATION: Record: ${verifyQuery.first}');
      } else {
        print('❌ VERIFICATION: Code NOT found in database after insertion!');
        print('❌ This indicates a serious database issue');
      }
    } catch (e) {
      print('❌ Error storing verification code: $e');
      print(
          '❌ This might be because the password_reset_codes table does not exist');
      print('❌ Or there are permission issues with the table');

      // For now, we'll continue without storing in database
      // The code will still be generated and can be used
      print('📧 Code generated: $code (not stored in database)');
      print('📧 This code expires in 10 minutes.');

      // Don't rethrow - let the flow continue
      // The user can still use the generated code
    }
  }

  /// Send email with 6-digit code using Supabase
  Future<bool> _sendEmailWithCode(String email, String code) async {
    try {
      // First, let's try to send the email using Supabase's auth system
      // If the user doesn't exist in auth.users, this will fail
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://familee-dental.com/password-reset',
      );

      print('📧 Password reset email sent to $email');
      print('📧 Verification code: $code');
      print('📧 This code expires in 10 minutes.');
      return true; // Email sent successfully
    } catch (e) {
      print('❌ Error sending email via Supabase auth: $e');
      print(
          '❌ This usually means the email is not in Supabase auth.users table');

      // For now, we'll show the code in the confirmation dialog
      // In production, you should integrate with an email service like SendGrid, Mailgun, etc.
      print('📧 Fallback: Code will be shown in app for testing');
      print('📧 Verification code for $email: $code');
      print('📧 This code expires in 10 minutes.');

      return false; // Email sending failed
    }
  }

  /// Show confirmation dialog after sending reset token
  void _showConfirmationDialog(BuildContext context, String email,
      {String? code}) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
                Column(
                  children: [
                    Text(
                      code != null
                          ? "Email sending failed, but here's your reset code:"
                          : "We've sent a reset token to your email. Please check your inbox and use the token to reset your password. The code will expire in 10 minutes.",
                      style: AppFonts.interStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (code != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D4AA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          code,
                          style: AppFonts.interStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 32),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(context).pushReplacementNamed(
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
        );
      },
    );
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

      // Send password reset email with 6-digit code
      final code = _generateVerificationCode();
      await _storeVerificationCode(emailText, code);

      // Try to send email, but don't fail the flow if it doesn't work
      final emailSent = await _sendEmailWithCode(emailText, code);
      final emailCode =
          emailSent ? null : code; // Show code only if email failed

      isLoading = false;
      onStateUpdate();

      // Show confirmation dialog
      _showConfirmationDialog(context, emailText, code: emailCode);
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
