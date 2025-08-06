import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:projects/features/auth/pages/login_page.dart';
import 'package:projects/features/dashboard/pages/dashboard_page.dart';
import 'package:projects/features/inventory/pages/inventory_page.dart';
import 'package:projects/shared/themes/font.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await Supabase.initialize(
      url: "https://mjczybgsgjnrmddcomoc.supabase.co",
      anonKey:
          "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qY3p5YmdzZ2pucm1kZGNvbW9jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI2NzQzNzAsImV4cCI6MjA2ODI1MDM3MH0.zMfnCIRGY27IfJEf8XSDr1ZKaviwlw5rbeU6GPdiQsM");

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const Login(),
        '/dashboard': (context) => const Dashboard(),
        '/inventory': (context) => const Inventory(),
      },
    );
  }
}
