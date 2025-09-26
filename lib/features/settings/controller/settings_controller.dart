import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SettingsController
///
/// Purpose: Encapsulate all backend/data operations related to Settings.
/// - Supabase reads and writes
/// - Future backup/restore flows
///
/// The UI page should use this controller for data access and mutations,
/// keeping all non-UI logic out of the widget layer.
class SettingsController {
  final SupabaseClient supabase;

  SettingsController({SupabaseClient? supabase})
      : supabase = supabase ?? Supabase.instance.client;

  // ----- Appearance -----
  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('settings.dark_mode') ?? false;
  }

  Future<void> setDarkMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings.dark_mode', enabled);
  }

  // ----- Notifications -----
  Future<bool> getInventoryAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Enabled by default
    return prefs.getBool('settings.notify_inventory') ?? true;
  }

  Future<void> setInventoryAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings.notify_inventory', enabled);
  }

  Future<bool> getApprovalAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Enabled by default
    return prefs.getBool('settings.notify_approval') ?? true;
  }

  Future<void> setApprovalAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings.notify_approval', enabled);
  }

  // ----- System: Backup & Restore -----
  Future<void> runBackup() async {
    // Placeholder implementation – integrate with backend later
  }

  Future<void> runRestore() async {
    // Placeholder implementation – integrate with backend later
  }
}
