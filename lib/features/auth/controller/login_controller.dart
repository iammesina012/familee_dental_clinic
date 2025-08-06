import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:projects/features/dashboard/pages/dashboard_page.dart';
import 'package:projects/features/auth/services/auth_service.dart';

class LoginController {
  final email = TextEditingController();
  final password = TextEditingController();
  final auth = AuthService();

  String? emailError;
  String? passwordError;
  bool obscure = true;

  Future<void> handleLogin(
      BuildContext context, VoidCallback onStateUpdate) async {
    emailError = null;
    passwordError = null;
    onStateUpdate();

    final emailText = email.text.trim();
    final passText = password.text;

    if (emailText.isEmpty) {
      emailError = "Please enter an email.";
      onStateUpdate();
      return;
    }
    if (passText.isEmpty) {
      passwordError = "Please enter a password.";
      onStateUpdate();
      return;
    }

    try {
      await auth.login(email: emailText, password: passText);

      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Dashboard()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        emailError = "Invalid email format.";
      } else if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        passwordError = "Incorrect email or password.";
      } else {
        emailError = "Login failed. Try again.";
      }
      onStateUpdate();
    }
  }
}
