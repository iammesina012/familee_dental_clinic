import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/utils/responsive_layout.dart';

class PasswordResetConfirmationPage extends StatelessWidget {
  final String email;

  const PasswordResetConfirmationPage({
    super.key,
    required this.email,
  });

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
                  // Success Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4AA),
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D4AA).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.email_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Title and subtitle with responsive constraints
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveLayout.isTablet(context) ||
                              ResponsiveLayout.isDesktop(context)
                          ? 500
                          : double.infinity,
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Check Your Email",
                          style: AppFonts.interStyle(
                            fontWeight: FontWeight.w100,
                            fontSize: 43,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "We've sent a password reset link to:",
                          style: AppFonts.interStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                            color: Color(0xFF2D2D2D).withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Email container with responsive constraints
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveLayout.isTablet(context) ||
                              ResponsiveLayout.isDesktop(context)
                          ? 500
                          : double.infinity,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF00D4AA),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      email,
                      style: AppFonts.interStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Color(0xFF2D2D2D),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Back to Login Button with responsive constraints
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveLayout.isTablet(context) ||
                              ResponsiveLayout.isDesktop(context)
                          ? 500
                          : double.infinity,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushReplacementNamed('/login');
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
                  ),
                ],
              ),
            ),

            // Logo and clinic info at top-left
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
          ],
        ),
      ),
    );
  }
}
