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
  bool get isOwner => _userRole == 'Owner';
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
  bool canAccessActivityLog() => isOwner || isAdmin;
  bool canAccessSettings() => true; // All roles can access settings
  bool canManageUsers() => isOwner || isAdmin;
  bool canBackupRestore() => isOwner || isAdmin;

  // Staff and Admin can access these
  bool canAccessDashboard() => true;
  bool canAccessInventory() => true;
  bool canAccessPurchaseOrders() => true;
  bool canAccessStockDeduction() => true;
  bool canAccessNotifications() => true;

  /// Role hierarchy management
  /// Owner can manage Admin and Staff
  /// Admin can manage Staff only
  /// Staff cannot manage anyone
  bool canManageRole(String targetRole) {
    if (isOwner) {
      return true; // Owner can manage anyone
    } else if (isAdmin) {
      return targetRole == 'Staff'; // Admin can only manage Staff
    }
    return false; // Staff cannot manage anyone
  }

  /// Get available roles for current user to assign
  List<String> getAvailableRolesToAssign() {
    if (isOwner) {
      return [
        'Admin',
        'Staff'
      ]; // Owner can assign Admin and Staff (but not Owner to prevent self-demotion)
    } else if (isAdmin) {
      return ['Staff']; // Admin can only assign Staff role
    }
    return []; // Staff cannot assign any roles
  }
}
