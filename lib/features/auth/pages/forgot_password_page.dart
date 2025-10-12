import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:familee_dental/features/auth/controller/forgot_password_controller.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/utils/responsive_layout.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final controller = ForgotPasswordController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check if email was passed as argument
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['email'] != null) {
      controller.email.text = args['email'] as String;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _handleSendResetToken() {
    controller.handleForgotPassword(context, () => setState(() {}));
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

            // Main content with responsive container
            ResponsiveContainer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Reset Password",
                          style: AppFonts.interStyle(
                            fontWeight: FontWeight.w100,
                            fontSize: 43,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Enter your email address and we'll send you a link to reset your password.",
                          style: AppFonts.interStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                            color: Color(0xFF2D2D2D).withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Email field with responsive constraints
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveLayout.isTablet(context) ||
                              ResponsiveLayout.isDesktop(context)
                          ? 500
                          : double.infinity,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2FAFE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: controller.hasEmailError
                            ? const Color(0xFFFF6B6B)
                            : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: TextField(
                      controller: controller.email,
                      onChanged: (value) {
                        if (controller.hasEmailError) {
                          setState(() {
                            controller.hasEmailError = false;
                            controller.emailError = null;
                          });
                        }
                      },
                      style: AppFonts.interStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D2D2D),
                      ),
                      decoration: InputDecoration(
                        hintText: "Email Address",
                        hintStyle: AppFonts.interStyle(
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF2D2D2D).withOpacity(0.6),
                        ),
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: const Color(0xFF2D2D2D).withOpacity(0.6),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),

                  // Error message display
                  if (controller.hasEmailError && controller.emailError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          controller.emailError!,
                          style: AppFonts.interStyle(
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFFF6B6B),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 30),

                  // Send Reset Token Button with responsive constraints
                  Container(
                    width: double.infinity,
                    height: 50,
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveLayout.isTablet(context) ||
                              ResponsiveLayout.isDesktop(context)
                          ? 500
                          : double.infinity,
                    ),
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
                          controller.isLoading ? null : _handleSendResetToken,
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
                              "SEND RESET OTP",
                              style: AppFonts.interStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Back to Login Link
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      "Back to Login",
                      style: AppFonts.interStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D2D2D),
                        fontSize: 14,
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
