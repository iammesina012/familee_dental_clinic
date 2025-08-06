import 'package:flutter/material.dart';
import 'package:projects/features/auth/controller/login_controller.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final controller = LoginController();

  void _handleLogin() {
    controller.handleLogin(context, () => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4CBED), Color(0xFFE7D9D9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
            height: 430,
            width: 350,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Welcome",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 35,
                  ),
                ),
                const SizedBox(height: 60),
                TextField(
                  controller: controller.email,
                  decoration: InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    errorText: controller.emailError,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller.password,
                  obscureText: controller.obscure,
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    errorText: (controller.passwordError != null &&
                            controller.passwordError !=
                                "Incorrect email or password.")
                        ? controller.passwordError
                        : null,
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: IconButton(
                        icon: Icon(
                          controller.obscure
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(
                              () => controller.obscure = !controller.obscure);
                        },
                      ),
                    ),
                  ),
                ),
                (controller.passwordError == "Incorrect email or password.")
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4.0, left: 12.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            controller.passwordError!,
                            style: const TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E38D4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 130),
                  ),
                  child: const Text(
                    "Login",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
