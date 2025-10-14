import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backup_restore_service.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/features/activity_log/controller/settings_activity_controller.dart';

/// Service for automatic daily backup creation
/// Now uses Supabase database to store preferences (works with Edge Functions)
class AutomaticBackupService {
  static final _supabase = Supabase.instance.client;

  /// Initialize the automatic backup service
  static Future<void> initialize() async {
    // Ensure user preferences record exists
    await _ensureUserPreferencesExist();
    // Check if backup is needed when app starts
    await checkAndCreateBackupIfNeeded();
  }

  /// Ensure user has a record in user_backup_preferences table
  static Future<void> _ensureUserPreferencesExist() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Check if record exists
      final response = await _supabase
          .from('user_backup_preferences')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      // Create record if it doesn't exist
      if (response == null) {
        await _supabase.from('user_backup_preferences').insert({
          'user_id': user.id,
          'user_email': user.email ?? '',
          'auto_backup_enabled': false,
        });
        debugPrint('Created user backup preferences record');
      }
    } catch (e) {
      debugPrint('Error ensuring user preferences: $e');
    }
  }

  /// Enable automatic daily backups
  static Future<void> enableAutoBackup() async {
    try {
      // Check if user is Owner
      final userRoleProvider = UserRoleProvider();
      if (!userRoleProvider.isOwner) {
        throw Exception('Only Owner can enable automatic backups');
      }

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // Save preference to Supabase
      await _supabase.from('user_backup_preferences').upsert({
        'user_id': user.id,
        'user_email': user.email ?? '',
        'auto_backup_enabled': true,
      }, onConflict: 'user_id');

      debugPrint('Automatic daily backup enabled in Supabase');
    } catch (e) {
      debugPrint('Error enabling auto backup: $e');
      rethrow;
    }
  }

  /// Disable automatic daily backups
  static Future<void> disableAutoBackup() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('No authenticated user for disabling auto backup');
        return;
      }

      // Save preference to Supabase
      await _supabase.from('user_backup_preferences').upsert({
        'user_id': user.id,
        'user_email': user.email ?? '',
        'auto_backup_enabled': false,
      }, onConflict: 'user_id');

      debugPrint('Auto backup preference set to false in Supabase');
    } catch (e) {
      debugPrint('Error in disableAutoBackup: $e');
      // Don't rethrow - just log the error and continue
    }
  }

  /// Check if automatic backup is enabled
  static Future<bool> isAutoBackupEnabled() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('user_backup_preferences')
          .select('auto_backup_enabled')
          .eq('user_id', user.id)
          .maybeSingle();

      return response?['auto_backup_enabled'] as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking auto backup status: $e');
      return false;
    }
  }

  /// Get the last backup date
  static Future<DateTime?> getLastBackupDate() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('user_backup_preferences')
          .select('last_backup_date')
          .eq('user_id', user.id)
          .maybeSingle();

      final dateString = response?['last_backup_date'] as String?;
      if (dateString != null) {
        return DateTime.tryParse(dateString);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting last backup date: $e');
      return null;
    }
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
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('No authenticated user for automatic backup');
        return;
      }

      final backupService = BackupRestoreService();
      final settingsActivityController = SettingsActivityController();

      // Create backup
      await backupService.createBackup(force: true);

      // Update last backup date in Supabase
      await _supabase.from('user_backup_preferences').upsert({
        'user_id': user.id,
        'user_email': user.email ?? '',
        'last_backup_date': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');

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
