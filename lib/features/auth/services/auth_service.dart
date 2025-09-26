import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:projects/features/activity_log/controller/login_activity_controller.dart';
import 'package:projects/shared/providers/user_role_provider.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _rememberMeKey = 'remember_me';
  static const String _rememberedEmailKey = 'remembered_email';

  Future<void> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    // Normalize email to avoid case-related bypasses
    final provided = email.trim();
    final providedLower = provided.toLowerCase();

    // First, attempt authentication so wrong creds show the correct error
    await _supabase.auth
        .signInWithPassword(email: providedLower, password: password);

    // After successful auth, get the user ID and check isActive flag
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw AuthException('Authentication failed');
    }

    final statusSnap = await _supabase
        .from('user_roles')
        .select('*')
        .eq('auth_id', currentUser.id)
        .limit(1);

    if (statusSnap.isNotEmpty) {
      final isActive = statusSnap.first['is_active'] as bool? ?? true;
      if (!isActive) {
        // Prevent session if deactivated
        try {
          await _supabase.auth.signOut();
        } catch (_) {}
        throw AuthException(
          'This account is inactive. Please contact an admin.',
        );
      }
    }

    // Save remember me preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, rememberMe);

    if (rememberMe) {
      await prefs.setString(
          _rememberedEmailKey, email); // Store original email for display
    } else {
      await prefs.remove(_rememberedEmailKey);
    }

    // Load user role after successful login
    await UserRoleProvider().loadUserRole();
  }

  /// Login with username instead of email
  Future<void> loginWithUsername({
    required String username,
    required String password,
    bool rememberMe = false,
  }) async {
    // Look up email from username in Supabase
    final userQuery = await _supabase
        .from('user_roles')
        .select('*')
        .eq('username', username)
        .limit(1);

    if (userQuery.isEmpty) {
      throw AuthException('Username not found');
    }

    final userData = userQuery.first;
    final email = userData['email'] as String?;

    if (email == null || email.isEmpty) {
      throw AuthException('No email associated with this username');
    }

    // Authenticate with Supabase using the resolved email
    await _supabase.auth.signInWithPassword(
      email: email.toLowerCase(),
      password: password,
    );

    // After successful auth, get the user ID and check isActive flag
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw AuthException('Authentication failed');
    }

    // Block inactive users using auth ID
    final statusSnap = await _supabase
        .from('user_roles')
        .select('*')
        .eq('auth_id', currentUser.id)
        .limit(1);

    if (statusSnap.isNotEmpty) {
      final isActive = statusSnap.first['is_active'] as bool? ?? true;
      if (!isActive) {
        try {
          await _supabase.auth.signOut();
        } catch (_) {}
        throw AuthException(
          'This account is inactive. Please contact an admin.',
        );
      }
    }

    // Save remember me preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, rememberMe);

    if (rememberMe) {
      await prefs.setString(_rememberedEmailKey, email);
    } else {
      await prefs.remove(_rememberedEmailKey);
    }

    // Load user role after successful login
    await UserRoleProvider().loadUserRole();
  }

  Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  Future<String?> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rememberedEmailKey);
  }

  Future<bool> isUserLoggedIn() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final rememberMe = await isRememberMeEnabled();
      return rememberMe;
    }
    return false;
  }

  Future<void> logout() async {
    // Log logout activity before signing out
    await LoginActivityController().logLogout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, false);
    await prefs.remove(_rememberedEmailKey);
    await _supabase.auth.signOut();

    // Clear user role on logout
    UserRoleProvider().clearUserRole();
  }

  User? get currentUser => _supabase.auth.currentUser;
}
