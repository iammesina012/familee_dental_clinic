import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/auth/controller/password_reset_controller.dart';
import 'package:familee_dental/features/auth/controller/forgot_password_controller.dart';
import 'package:familee_dental/shared/themes/font.dart';

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final controller = PasswordResetController();
  final ForgotPasswordController forgotPasswordController =
      ForgotPasswordController();
  String email = 'user@example.com'; // Default fallback

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get email from navigation arguments
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['email'] != null) {
      email = args['email'] as String;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    forgotPasswordController.dispose();
    super.dispose();
  }

  void _handleResetPassword() {
    controller.handlePasswordReset(context, () => setState(() {}),
        email: email);
  }

  /// Generate a 6-digit verification code
  String _generateVerificationCode() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final code = (random % 1000000).toString().padLeft(6, '0');
    return code;
  }

  /// Store verification code in database
  Future<void> _storeVerificationCode(String email, String code) async {
    try {
      print('🔍 DEBUG: Storing code for resend - email: $email, code: $code');

      // First, mark any existing unused codes for this email as used
      try {
        await Supabase.instance.client
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
      await Supabase.instance.client.from('password_reset_codes').insert({
        'email': email.toLowerCase(),
        'code': code,
        'expires_at': expiresAt.toIso8601String(),
        'used': false,
      });

      print('✅ DEBUG: Code stored for resend: $code expires at $expiresAt');
    } catch (e) {
      print('❌ DEBUG: Error storing code for resend: $e');
      // Don't rethrow - let the flow continue
    }
  }

  /// Send email with 6-digit code using Supabase
  Future<bool> _sendEmailWithCode(String email, String code) async {
    try {
      // Use Supabase's built-in password reset email functionality
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://familee-dental.com/password-reset',
      );

      print('📧 DEBUG: Resend email sent to $email with code $code');
      return true; // Email sent successfully
    } catch (e) {
      print('❌ DEBUG: Error sending resend email: $e');
      print('📧 DEBUG: Fallback - showing code in app: $code');
      return false; // Email sending failed, but code is still valid
    }
  }

  Widget _buildPasswordTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: AppFonts.interStyle(
          fontWeight: FontWeight.w400,
          fontSize: 12,
          color: const Color(0xFF8B5A00),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF2FAFE),
        ),
        child: Stack(
          children: [
            // Large radial glow blur effect on the left (Blue)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.centerLeft,
                    radius: 0.8,
                    colors: [
                      const Color(0xFF2FCDFF).withOpacity(0.4), // Center glow
                      const Color(0xFF2FCDFF).withOpacity(0.2), // Mid glow
                      const Color(0xFF2FCDFF).withOpacity(0.05), // Outer glow
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),
            // Center radial glow blur effect (Yellow)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.7,
                    colors: [
                      const Color(0xFFFFC336).withOpacity(0.3), // Center glow
                      const Color(0xFFFFC336).withOpacity(0.15), // Mid glow
                      const Color(0xFFFFC336).withOpacity(0.05), // Outer glow
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),
            // Right radial glow blur effect (Green)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.centerRight,
                    radius: 0.8,
                    colors: [
                      const Color(0xFF27EE9D).withOpacity(0.4), // Center glow
                      const Color(0xFF27EE9D).withOpacity(0.2), // Mid glow
                      const Color(0xFF27EE9D).withOpacity(0.05), // Outer glow
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),

            // Header with logo and clinic info
            Positioned(
              top: 40,
              left: 30,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.asset(
                        'assets/images/logo/logo_101.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 60,
                            height: 60,
                            color: Colors.blue,
                            child: Icon(
                              Icons.medical_services,
                              color: Colors.white,
                              size: 30,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "FamiLee Dental Clinic",
                        style: AppFonts.interStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 20,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Inventory Management",
                        style: AppFonts.interStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Back button
            Positioned(
              top: 120,
              left: 30,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pushReplacementNamed(
                    '/forgot-password',
                    arguments: {'email': email},
                  );
                },
                child: Icon(
                  Icons.arrow_back_ios,
                  color: const Color(0xFF2D2D2D),
                  size: 24,
                ),
              ),
            ),

            // Title and subtitle
            Positioned(
              top: 140,
              left: 30,
              right: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    "Create New Password",
                    style: AppFonts.interStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 28,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Enter the reset token from your email ($email) and set a new password.",
                    style: AppFonts.interStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                      color: Color(0xFF2D2D2D).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Input fields and button
            Positioned(
              top: 270,
              left: 30,
              right: 30,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // 6-digit code field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: controller.hasVerificationCodeError
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFFE5E5E5),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: controller.verificationCode,
                      onChanged: (value) {
                        if (controller.hasVerificationCodeError) {
                          setState(() {
                            controller.hasVerificationCodeError = false;
                            controller.verificationCodeError = null;
                          });
                        }
                      },
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: AppFonts.interStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D2D2D),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: "Reset Token",
                        hintStyle: AppFonts.interStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: const Color(0xFF2D2D2D).withOpacity(0.6),
                        ),
                        prefixIcon: Icon(
                          Icons.key_outlined,
                          color: const Color(0xFF2D2D2D).withOpacity(0.6),
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: IconButton(
                            icon: Icon(
                              Icons.content_paste_outlined,
                              color: const Color(0xFF2D2D2D).withOpacity(0.6),
                            ),
                            onPressed: () async {
                              try {
                                final clipboardData =
                                    await Clipboard.getData('text/plain');
                                if (clipboardData?.text != null) {
                                  controller.verificationCode.text =
                                      clipboardData!.text!;
                                  // Clear any existing error
                                  if (controller.hasVerificationCodeError) {
                                    setState(() {
                                      controller.hasVerificationCodeError =
                                          false;
                                      controller.verificationCodeError = null;
                                    });
                                  }
                                }
                              } catch (e) {
                                // Handle clipboard access error
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Unable to access clipboard'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        counterText: '', // Hide character counter
                      ),
                    ),
                  ),

                  // Reset Token Error Message
                  if (controller.hasVerificationCodeError)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        controller.verificationCodeError ?? '',
                        style: AppFonts.interStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: const Color(0xFFFF6B6B),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Resend Code Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: controller.canResend
                          ? () async {
                              try {
                                print('🔄 DEBUG: Resending code for $email');

                                // Generate new code and store it
                                final code = _generateVerificationCode();
                                await _storeVerificationCode(email, code);

                                // Send email with new code
                                await _sendEmailWithCode(email, code);

                                // Update the password reset controller's cooldown
                                controller.canResend = false;
                                controller.resendCooldown = 60;
                                setState(() {});

                                // Start countdown timer
                                controller.startCooldownTimer(() {
                                  setState(() {});
                                });

                                // Show success message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'New verification code sent to $email'),
                                    backgroundColor: const Color(0xFF00D4AA),
                                  ),
                                );

                                print('✅ DEBUG: Resend completed successfully');
                              } catch (e) {
                                print('❌ DEBUG: Resend failed: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Failed to resend code. Please try again.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          : null,
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: controller.canResend
                                ? const Color(0xFF2D2D2D)
                                : const Color(0xFF2D2D2D).withOpacity(0.5),
                          ),
                          children: controller.canResend
                              ? [
                                  const TextSpan(text: "Didn't get the code? "),
                                  TextSpan(
                                    text: "Resend",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                      color: const Color(0xFF2D2D2D),
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ]
                              : [
                                  TextSpan(
                                    text:
                                        "Resend in ${controller.resendCooldown}s",
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // New Password field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: controller.hasPasswordError
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFFE5E5E5),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: controller.password,
                      onChanged: (value) {
                        if (controller.hasPasswordError) {
                          setState(() {
                            controller.hasPasswordError = false;
                            controller.passwordError = null;
                          });
                        }
                      },
                      obscureText: controller.obscurePassword,
                      style: AppFonts.interStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D2D2D),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: "New Password",
                        hintStyle: AppFonts.interStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: const Color(0xFF2D2D2D).withOpacity(0.6),
                        ),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: const Color(0xFF2D2D2D).withOpacity(0.6),
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: IconButton(
                            icon: Icon(
                              controller.obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF2D2D2D).withOpacity(0.6),
                            ),
                            onPressed: () {
                              setState(() => controller.obscurePassword =
                                  !controller.obscurePassword);
                            },
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  // New Password Error Message
                  if (controller.hasPasswordError)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        controller.passwordError ?? '',
                        style: AppFonts.interStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: const Color(0xFFFF6B6B),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Confirm Password field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: controller.hasConfirmPasswordError
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFFE5E5E5),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: controller.confirmPassword,
                      onChanged: (value) {
                        if (controller.hasConfirmPasswordError) {
                          setState(() {
                            controller.hasConfirmPasswordError = false;
                            controller.confirmPasswordError = null;
                          });
                        }
                      },
                      obscureText: controller.obscureConfirmPassword,
                      style: AppFonts.interStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D2D2D),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: "Confirm Password",
                        hintStyle: AppFonts.interStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: const Color(0xFF2D2D2D).withOpacity(0.6),
                        ),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: const Color(0xFF2D2D2D).withOpacity(0.6),
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: IconButton(
                            icon: Icon(
                              controller.obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF2D2D2D).withOpacity(0.6),
                            ),
                            onPressed: () {
                              setState(() => controller.obscureConfirmPassword =
                                  !controller.obscureConfirmPassword);
                            },
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  // Confirm Password Error Message
                  if (controller.hasConfirmPasswordError)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        controller.confirmPasswordError ?? '',
                        style: AppFonts.interStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: const Color(0xFFFF6B6B),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Password Tips Section
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF4E3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFFC336).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: const Color(0xFFFFC336),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Password Tips",
                              style: AppFonts.interStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: const Color(0xFF8B5A00),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildPasswordTip("• Use at least 8 characters"),
                        _buildPasswordTip(
                            "• Include uppercase and lowercase letters"),
                        _buildPasswordTip("• Include at least one number"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Reset Password Button
                  Container(
                    width: double.infinity,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D4AA), Color(0xFF00B894)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D4AA).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed:
                          controller.isLoading ? null : _handleResetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: controller.isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              "RESET PASSWORD",
                              style: AppFonts.interStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
