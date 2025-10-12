import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:familee_dental/features/auth/controller/password_reset_controller.dart';
import 'package:familee_dental/shared/themes/font.dart';

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final controller = PasswordResetController();
  String email = 'user@example.com'; // Default fallbackimage.png

  @override
  void initState() {
    super.initState();
  }

  // Helper to format remaining seconds as M:SS (e.g. 4:58)
  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
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

    // Start timers when user reaches this page
    // Start resend cooldown (60s) if not running
    if (!controller.isResendTimerRunning) {
      controller.startCooldownTimer(() => setState(() {}), seconds: 60);
    }

    // Start token expiry timer (300s) if not running
    if (!controller.isTokenTimerRunning) {
      controller.startTokenExpiryTimer(() => setState(() {}), seconds: 300);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _handleResetPassword() {
    controller.handlePasswordReset(context, () => setState(() {}),
        email: email);
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

            // Back button
            Positioned(
              top: 30,
              left: 30,
              child: GestureDetector(
                onTap: () {
                  // Go back to the previous Forgot Password page instead of
                  // pushing/replacing it (which caused duplicate pages).
                  Navigator.of(context).pop();
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
              top: 100,
              left: 30,
              right: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Create New Password",
                    style: AppFonts.interStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 28,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Subtitle with inline expiration timer after the sentence.
                  RichText(
                    text: TextSpan(
                      style: AppFonts.interStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 14,
                        color: Color(0xFF2D2D2D).withOpacity(0.7),
                      ),
                      children: [
                        TextSpan(
                          text:
                              "Enter the reset token from your email ($email) and set a new password.",
                        ),
                        if (controller.isTokenTimerRunning)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Text(
                                'Expires in ${_formatDuration(controller.tokenExpiryRemaining)}',
                                style: AppFonts.interStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.red,
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

            // Input fields and button
            Positioned(
              top: 220,
              left: 30,
              right: 30,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Token field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: controller.hasTokenError
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFFE5E5E5),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: controller.token,
                      onChanged: (value) {
                        if (controller.hasTokenError) {
                          setState(() {
                            controller.hasTokenError = false;
                            controller.tokenError = null;
                          });
                        }
                      },
                      style: AppFonts.interStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D2D2D),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: "Enter OTP Code",
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
                                  controller.token.text = clipboardData!.text!;
                                  // Clear any existing error
                                  if (controller.hasTokenError) {
                                    setState(() {
                                      controller.hasTokenError = false;
                                      controller.tokenError = null;
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
                      ),
                    ),
                  ),

                  // Token Error Message
                  if (controller.hasTokenError)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 4),
                      child: Text(
                        controller.tokenError ?? '',
                        style: AppFonts.interStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: const Color(0xFFFF6B6B),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Resend functionality
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: controller.canResend
                          ? () async {
                              try {
                                print('🔄 Resending code for $email');

                                // Resend password reset email
                                await controller.resendPasswordReset(
                                    email, () => setState(() {}));

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'New reset OTP code sent to $email'),
                                    backgroundColor: const Color(0xFF00D4AA),
                                  ),
                                );

                                print('✅ Resend completed successfully');
                              } catch (e) {
                                print('❌ Resend failed: $e');
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
                                        "Resend in ${_formatDuration(controller.resendCooldown)}",
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
                        // Removed special character requirement per updated policy
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
