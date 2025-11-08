import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:familee_dental/features/auth/pages/login_page.dart';
import 'package:familee_dental/features/auth/pages/forgot_password_page.dart';
import 'package:familee_dental/features/auth/pages/password_reset_page.dart';
import 'package:familee_dental/features/dashboard/pages/dashboard_page.dart';
import 'package:familee_dental/features/inventory/pages/inventory_page.dart';
import 'package:familee_dental/features/purchase_order/pages/purchase_order_page.dart';
import 'package:familee_dental/features/purchase_order/pages/po_create_page.dart';
import 'package:familee_dental/features/purchase_order/pages/po_add_supply_page.dart';
import 'package:familee_dental/features/purchase_order/pages/po_edit_supply_page.dart';
import 'package:familee_dental/features/purchase_order/pages/po_details_page.dart';
import 'package:familee_dental/features/stock_deduction/pages/stock_deduction_page.dart';
import 'package:familee_dental/features/stock_deduction/pages/sd_add_supply_page.dart';
import 'package:familee_dental/features/stock_deduction/pages/sd_deduction_logs_page.dart';
import 'package:familee_dental/features/stock_deduction/pages/sd_approval_page.dart';
import 'package:familee_dental/features/activity_log/pages/activity_log_page.dart';
import 'package:familee_dental/features/notifications/pages/notifications_page.dart';
import 'package:familee_dental/features/backup_restore/services/automatic_backup_service.dart';
import 'package:familee_dental/features/settings/pages/settings_page.dart';
import 'package:familee_dental/features/settings/pages/app_tutorial_page.dart';
import 'package:familee_dental/features/backup_restore/pages/backup_restore_page.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/features/auth/services/auth_service.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment 1
  await dotenv.load(fileName: ".env");

  // get Supabase credentials from environment variables
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
  final serviceRoleKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw Exception('Missing Supabase credentials in .env file');
  }

  if (serviceRoleKey != null && serviceRoleKey.isNotEmpty) {
    debugPrint("Service role key loaded successfully!");
  } else {
    debugPrint("Service role key not found in .env");
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    debugPrint("Supabase initialized successfully!");
  } catch (e) {
    debugPrint("Supabase init failed: $e");
  }

  // Initialize automatic backup service
  try {
    await AutomaticBackupService.initialize();
    debugPrint("Automatic backup service initialized successfully!");
  } catch (e) {
    debugPrint("Automatic backup service init failed: $e");
  }

  // Initialize theme mode from persisted preference before running app
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('settings.dark_mode') ?? false;
  AppTheme.themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: const Scaffold(
            resizeToAvoidBottomInset: false,
            body: AuthWrapper(),
          ),
          routes: {
            '/login': (context) => const Login(),
            '/forgot-password': (context) => const ForgotPasswordPage(),
            '/password-reset': (context) => const PasswordResetPage(),
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
            '/stock-deduction/deduction-logs': (context) =>
                const DeductionLogsPage(),
            '/stock-deduction/approval': (context) => const ApprovalPage(),
            '/activity-log': (context) => const ActivityLogPage(),
            '/notifications': (context) => const NotificationsPage(),
            '/settings': (context) => const SettingsPage(),
            '/tutorial': (context) => const AppTutorialPage(),
            '/backup-restore': (context) {
              final userRoleProvider = UserRoleProvider();
              if (!userRoleProvider.isOwner) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacementNamed(context, '/settings');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Access Denied: Only the Owner can access backup and restore functionality.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                });
                return const SizedBox(); // Return empty widget while redirecting
              }
              return const BackupRestorePage();
            },
          },
        );
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
  final UserRoleProvider _userRoleProvider = UserRoleProvider();
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await _authService.isUserLoggedIn();

    // Load user role if user is logged in
    if (isLoggedIn) {
      await _userRoleProvider.loadUserRole();
    }

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
