import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backup_restore_service.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/features/activity_log/controller/settings_activity_controller.dart';

/// Service for automatic daily backup creation
/// Uses a simpler approach that checks for backup needs when app is used
class AutomaticBackupService {
  static const String _autoBackupKey = 'auto_backup_enabled';
  static const String _lastBackupDateKey = 'last_backup_date';

  /// Initialize the automatic backup service
  static Future<void> initialize() async {
    // Check if backup is needed when app starts
    await checkAndCreateBackupIfNeeded();
  }

  /// Enable automatic daily backups
  static Future<void> enableAutoBackup() async {
    try {
      // Check if user is Owner
      final userRoleProvider = UserRoleProvider();
      if (!userRoleProvider.isOwner) {
        throw Exception('Only Owner can enable automatic backups');
      }

      // Save preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoBackupKey, true);

      debugPrint('Automatic daily backup enabled');
    } catch (e) {
      debugPrint('Error enabling auto backup: $e');
      rethrow;
    }
  }

  /// Disable automatic daily backups
  static Future<void> disableAutoBackup() async {
    try {
      // Save preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoBackupKey, false);
      debugPrint('Auto backup preference set to false');
    } catch (e) {
      debugPrint('Error in disableAutoBackup: $e');
      // Don't rethrow - just log the error and continue
    }
  }

  /// Check if automatic backup is enabled
  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupKey) ?? false;
  }

  /// Get the last backup date
  static Future<DateTime?> getLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_lastBackupDateKey);
    if (dateString != null) {
      return DateTime.tryParse(dateString);
    }
    return null;
  }

  /// Check and create backup if needed (called when app starts or backup page is opened)
  static Future<void> checkAndCreateBackupIfNeeded() async {
    try {
      // Check if auto backup is enabled
      final isEnabled = await isAutoBackupEnabled();
      if (!isEnabled) {
        debugPrint('Auto backup is disabled, skipping check');
        return;
      }

      // Check if user is logged in
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint('No user logged in, skipping backup check');
        return;
      }

      // Check if backup was already created today
      final lastBackupDate = await getLastBackupDate();
      final today = DateTime.now();

      if (lastBackupDate != null &&
          lastBackupDate.year == today.year &&
          lastBackupDate.month == today.month &&
          lastBackupDate.day == today.day) {
        debugPrint('Backup already created today, skipping');
        return;
      }

      // Check if we should create backup (after 11:59 PM)
      final now = DateTime.now();
      if (now.hour < 23 || (now.hour == 23 && now.minute < 59)) {
        debugPrint('Not yet time for daily backup (waiting for 11:59 PM)');
        return;
      }

      // Create backup
      debugPrint('Creating automatic daily backup...');
      await _createAutomaticBackup();
    } catch (e) {
      debugPrint('Error in checkAndCreateBackupIfNeeded: $e');
    }
  }

  /// Create the actual backup
  static Future<void> _createAutomaticBackup() async {
    try {
      final backupService = BackupRestoreService();
      final settingsActivityController = SettingsActivityController();

      // Create backup
      await backupService.createBackup(force: true);

      // Update last backup date
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _lastBackupDateKey, DateTime.now().toIso8601String());

      // Log activity
      await settingsActivityController.logBackupCreated(
        backupFileName:
            'familee_dental_${DateTime.now().millisecondsSinceEpoch}.json',
        backupTime: DateTime.now(),
      );

      debugPrint('Automatic backup created successfully');
    } catch (e) {
      debugPrint('Error creating automatic backup: $e');
    }
  }

  /// Force check for backup (can be called manually)
  static Future<void> forceCheckForBackup() async {
    await checkAndCreateBackupIfNeeded();
  }
}
