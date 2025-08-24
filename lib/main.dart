import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:projects/features/auth/pages/login_page.dart';
import 'package:projects/features/dashboard/pages/dashboard_page.dart';
import 'package:projects/features/inventory/pages/inventory_page.dart';
import 'package:projects/features/purchase_order/pages/purchase_order_page.dart';
import 'package:projects/features/purchase_order/pages/create_po_page.dart';
import 'package:projects/features/purchase_order/pages/add_supply_page.dart';
import 'package:projects/features/purchase_order/pages/edit_supply_po_page.dart';
import 'package:projects/features/purchase_order/pages/po_details_page.dart';
import 'package:projects/features/stock_deduction/pages/stock_deduction_page.dart';
import 'package:projects/features/stock_deduction/pages/add_supply_page.dart';
import 'package:projects/features/stock_deduction/pages/preset_management_page.dart';
import 'package:projects/features/stock_deduction/pages/create_preset_page.dart';
import 'package:projects/features/stock_deduction/pages/edit_preset_page.dart';
import 'package:projects/features/stock_deduction/pages/add_supply_for_preset_page.dart';
import 'package:projects/features/auth/services/auth_service.dart';
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
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const Login(),
        '/dashboard': (context) => const Dashboard(),
        '/inventory': (context) => const Inventory(),
        '/purchase-order': (context) => const PurchaseOrderPage(),
        '/create-po': (context) => const CreatePOPage(),
        '/add-supply': (context) => const AddSupplyPage(),
        '/edit-supply-po': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return EditSupplyPOPage(supply: args);
        },
        '/po-details': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return PODetailsPage(purchaseOrder: args['purchaseOrder']);
        },
        '/stock-deduction': (context) => const StockDeductionPage(),
        '/stock-deduction/add-supply': (context) =>
            const StockDeductionAddSupplyPage(),
        '/stock-deduction/add-supply-for-preset': (context) =>
            const StockDeductionAddSupplyForPresetPage(),
        '/stock-deduction/presets': (context) => const PresetManagementPage(),
        '/stock-deduction/create-preset': (context) => const CreatePresetPage(),
        '/stock-deduction/edit-preset': (context) {
          final preset = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return EditPresetPage(preset: preset);
        },
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await _authService.isUserLoggedIn();
    setState(() {
      _isLoggedIn = isLoggedIn;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00D4AA),
          ),
        ),
      );
    }

    return _isLoggedIn ? const Dashboard() : const Login();
  }
}
