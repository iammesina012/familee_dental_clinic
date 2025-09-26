import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// UserRoleProvider
///
/// Purpose: Global provider for user role management
/// - Stores user role in memory for instant access
/// - No async calls needed in UI components
/// - Smooth, flicker-free experience
///
/// Usage: Access user role instantly without loading states
class UserRoleProvider extends ChangeNotifier {
  static final UserRoleProvider _instance = UserRoleProvider._internal();
  factory UserRoleProvider() => _instance;
  UserRoleProvider._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  String _userRole = 'Staff'; // Default to Staff
  bool _isLoaded = false;

  // Getters
  String get userRole => _userRole;
  bool get isAdmin => _userRole == 'Admin';
  bool get isStaff => _userRole == 'Staff';
  bool get isLoaded => _isLoaded;

  /// Load user role (call after login)
  Future<void> loadUserRole() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        _userRole = 'Staff';
        _isLoaded = true;
        notifyListeners();
        return;
      }

      final response = await _supabase
          .from('user_roles')
          .select('role')
          .eq('auth_id', currentUser.id)
          .limit(1)
          .single();

      _userRole = response['role'] ?? 'Staff';
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      print('Error loading user role: $e');
      _userRole = 'Staff';
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Clear user role (call on logout)
  void clearUserRole() {
    _userRole = 'Staff';
    _isLoaded = false;
    notifyListeners();
  }

  /// Permission checks (instant, no async needed)
  bool canAccessActivityLog() => isAdmin;
  bool canAccessSettings() => isAdmin;
  bool canManageUsers() => isAdmin;
  bool canBackupRestore() => isAdmin;

  // Staff and Admin can access these
  bool canAccessDashboard() => true;
  bool canAccessInventory() => true;
  bool canAccessPurchaseOrders() => true;
  bool canAccessStockDeduction() => true;
  bool canAccessNotifications() => true;
}
