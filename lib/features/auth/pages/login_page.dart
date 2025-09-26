import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:projects/features/auth/controller/login_controller.dart';
import 'package:projects/shared/themes/font.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final controller = LoginController();
  bool rememberMe = false;

  void _handleLogin() {
    controller.handleLogin(context, () => setState(() {}),
        rememberMe: rememberMe);
  }

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
  }

  void _loadRememberedCredentials() async {
    await controller.loadRememberedCredentials();
    final isRememberMeEnabled = await controller.auth.isRememberMeEnabled();
    setState(() {
      rememberMe = isRememberMeEnabled;
    });
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

            // Main content
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Sign In",
                            style: AppFonts.interStyle(
                              fontWeight: FontWeight.w100,
                              fontSize: 43,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
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
                            });
                          }
                        },
                        style: AppFonts.interStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2D2D2D),
                        ),
                        decoration: InputDecoration(
                          hintText: "Email/Username",
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
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2FAFE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: controller.hasPasswordError
                              ? const Color(0xFFFF6B6B)
                              : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: TextField(
                        controller: controller.password,
                        onChanged: (value) {
                          if (controller.hasPasswordError) {
                            setState(() {
                              controller.hasPasswordError = false;
                            });
                          }
                        },
                        obscureText: controller.obscure,
                        style: AppFonts.interStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2D2D2D),
                        ),
                        decoration: InputDecoration(
                          hintText: "Password",
                          hintStyle: AppFonts.interStyle(
                            fontWeight: FontWeight.w500,
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
                                controller.obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF2D2D2D).withOpacity(0.6),
                              ),
                              onPressed: () {
                                setState(() =>
                                    controller.obscure = !controller.obscure);
                              },
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Row(
                        children: [
                          Transform.scale(
                            scale: 1.2,
                            child: Checkbox(
                              value: rememberMe,
                              onChanged: (value) {
                                setState(() {
                                  rememberMe = value ?? false;
                                });
                              },
                              activeColor: const Color(0xFF00D4AA),
                              checkColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              side: BorderSide(
                                color: const Color(0xFF2D2D2D).withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                          ),
                          Text(
                            "Remember me",
                            style: AppFonts.interStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF2D2D2D),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      width: double.infinity,
                      height: 50,
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
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          "LOGIN",
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
