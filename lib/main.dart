import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:projects/features/auth/pages/login_page.dart';
import 'package:projects/features/auth/pages/password_reset_page.dart';
import 'package:projects/features/dashboard/pages/dashboard_page.dart';
import 'package:projects/features/inventory/pages/inventory_page.dart';
import 'package:projects/features/purchase_order/pages/purchase_order_page.dart';
import 'package:projects/features/purchase_order/pages/po_create_page.dart';
import 'package:projects/features/purchase_order/pages/po_add_supply_page.dart';
import 'package:projects/features/purchase_order/pages/po_edit_supply_page.dart';
import 'package:projects/features/purchase_order/pages/po_details_page.dart';
import 'package:projects/features/stock_deduction/pages/stock_deduction_page.dart';
import 'package:projects/features/stock_deduction/pages/sd_add_supply_page.dart';
import 'package:projects/features/stock_deduction/pages/sd_preset_management_page.dart';
import 'package:projects/features/stock_deduction/pages/sd_create_preset_page.dart';
import 'package:projects/features/stock_deduction/pages/sd_edit_preset_page.dart';
import 'package:projects/features/stock_deduction/pages/sd_add_supply_preset_page.dart';
import 'package:projects/features/activity_log/pages/activity_log_page.dart';
import 'package:projects/features/notifications/pages/notifications_page.dart';
import 'package:projects/features/settings/pages/settings_page.dart';
import 'package:projects/features/backup_restore/pages/backup_restore_page.dart';
import 'package:projects/features/auth/services/auth_service.dart';
import 'package:projects/shared/themes/font.dart';
import 'package:projects/shared/providers/user_role_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
      url: "https://mjczybgsgjnrmddcomoc.supabase.co",
      anonKey:
          "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qY3p5YmdzZ2pucm1kZGNvbW9jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI2NzQzNzAsImV4cCI6MjA2ODI1MDM3MH0.zMfnCIRGY27IfJEf8XSDr1ZKaviwlw5rbeU6GPdiQsM");

  // Note: Deep link handling is now managed in AuthWrapper

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
          home: const AuthWrapper(),
          routes: {
            '/login': (context) => const Login(),
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
            '/stock-deduction/add-supply-for-preset': (context) =>
                const StockDeductionAddSupplyForPresetPage(),
            '/stock-deduction/presets': (context) =>
                const PresetManagementPage(),
            '/stock-deduction/create-preset': (context) =>
                const CreatePresetPage(),
            '/stock-deduction/edit-preset': (context) {
              final preset = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
              return EditPresetPage(preset: preset);
            },
            '/activity-log': (context) => const ActivityLogPage(),
            '/notifications': (context) => const NotificationsPage(),
            '/settings': (context) => const SettingsPage(),
            '/backup-restore': (context) => const BackupRestorePage(),
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
  final AppLinks _appLinks = AppLinks();
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _listenToAuthChanges();
    _listenToDeepLinks();
  }

  void _listenToAuthChanges() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.passwordRecovery && session != null) {
        // User clicked password reset link, navigate to password reset page
        print('Password recovery event detected: ${session.user?.email}');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushNamed('/password-reset');
          }
        });
      }
    });
  }

  void _listenToDeepLinks() {
    // Listen to app links while the app is already started
    _appLinks.uriLinkStream.listen((uri) {
      print('Deep link received: $uri');
      _handleDeepLink(uri);
    }, onError: (err) {
      print('Deep link error: $err');
    });

    // Handle deep links when app is launched from a terminated state
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        print('Initial deep link: $uri');
        _handleDeepLink(uri);
      }
    });
  }

  void _handleDeepLink(Uri uri) {
    print('Handling deep link: ${uri.toString()}');

    if (uri.scheme == 'com.example.projects') {
      if (uri.host == 'reset-password') {
        // Navigate to password reset page
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushNamed('/password-reset');
          }
        });
      }
    }
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
