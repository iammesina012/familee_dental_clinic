import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SettingsController
///
/// Purpose: Encapsulate all backend/data operations related to Settings.
/// - Firebase/Supabase reads and writes
/// - Future backup/restore flows
///
/// The UI page should use this controller for data access and mutations,
/// keeping all non-UI logic out of the widget layer.
class SettingsController {
  final FirebaseFirestore firestore;
  final SupabaseClient supabase;

  SettingsController({FirebaseFirestore? firestore, SupabaseClient? supabase})
      : firestore = firestore ?? FirebaseFirestore.instance,
        supabase = supabase ?? Supabase.instance.client;

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
    // Placeholder implementation – integrate with backend later
    return true;
  }

  Future<void> setInventoryAlertsEnabled(bool enabled) async {
    // Placeholder implementation – integrate with backend later
  }

  Future<bool> getApprovalAlertsEnabled() async {
    // Placeholder implementation – integrate with backend later
    return true;
  }

  Future<void> setApprovalAlertsEnabled(bool enabled) async {
    // Placeholder implementation – integrate with backend later
  }

  // ----- System: Backup & Restore -----
  Future<void> runBackup() async {
    // Placeholder implementation – integrate with backend later
  }

  Future<void> runRestore() async {
    // Placeholder implementation – integrate with backend later
  }
}
