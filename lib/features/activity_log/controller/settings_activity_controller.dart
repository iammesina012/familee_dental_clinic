import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsActivityController {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Log profile edit activity
  Future<void> logProfileEdit({
    required String userName,
  }) async {
    try {
      // Get current user
      final User? currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return; // Don't log if no user

      // Get user role for role-specific description
      String userRole = 'Staff'; // Default
      try {
        final response = await _supabase
            .from('user_roles')
            .select('role')
            .eq('id', currentUser.id)
            .maybeSingle();
        if (response != null && response['role'] != null) {
          userRole = response['role'] as String;
        }
      } catch (e) {
        print('Error getting user role: $e');
      }

      final metadata = <String, dynamic>{};
      final now = DateTime.now();

      // Format time as 12-hour with AM/PM
      final hour12 =
          now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      final amPm = now.hour >= 12 ? 'PM' : 'AM';
      final timeString =
          '$hour12:${now.minute.toString().padLeft(2, '0')} $amPm';

      await _supabase.from('activity_logs').insert({
        'category': 'Settings',
        'action': 'profile_edited',
        'description': '$userRole edited their profile',
        'user_name': userName,
        'user_id': currentUser.id,
        'user_email': currentUser.email,
        'user_role': userRole, // Store the role for filtering
        'metadata': metadata,
        'date': now.toIso8601String(),
        'time': timeString,
        'created_at': now.toIso8601String(),
      });
    } catch (e) {
      print('Error logging profile edit activity: $e');
    }
  }

  /// Log employee added activity
  Future<void> logEmployeeAdded({
    required String employeeName,
    required String employeeRole,
  }) async {
    try {
      // Get current user
      final User? currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return; // Don't log if no user

      // Get user role for role-specific description
      String userRole = 'Staff'; // Default
      try {
        final response = await _supabase
            .from('user_roles')
            .select('role')
            .eq('id', currentUser.id)
            .maybeSingle();
        if (response != null && response['role'] != null) {
          userRole = response['role'] as String;
        }
      } catch (e) {
        print('Error getting user role: $e');
      }

      final metadata = <String, dynamic>{
        'Name': employeeName,
        'Role': employeeRole,
      };
      final now = DateTime.now();

      // Format time as 12-hour with AM/PM
      final hour12 =
          now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      final amPm = now.hour >= 12 ? 'PM' : 'AM';
      final timeString =
          '$hour12:${now.minute.toString().padLeft(2, '0')} $amPm';

      await _supabase.from('activity_logs').insert({
        'category': 'Settings',
        'action': 'employee_added',
        'description': '$userRole added an employee',
        'user_name': _getCurrentUserName(),
        'user_id': currentUser.id,
        'user_email': currentUser.email,
        'user_role': userRole, // Store the role for filtering
        'metadata': metadata,
        'date': now.toIso8601String(),
        'time': timeString,
        'created_at': now.toIso8601String(),
      });
    } catch (e) {
      print('Error logging employee added activity: $e');
    }
  }

  /// Log employee profile edited activity
  Future<void> logEmployeeProfileEdited({
    required String employeeName,
    required String originalName,
    required String employeeRole,
    required String originalRole,
    required String employeeStatus,
    required String originalStatus,
  }) async {
    try {
      // Get current user
      final User? currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return; // Don't log if no user

      // Get user role for role-specific description
      String userRole = 'Staff'; // Default
      try {
        final response = await _supabase
            .from('user_roles')
            .select('role')
            .eq('id', currentUser.id)
            .maybeSingle();
        if (response != null && response['role'] != null) {
          userRole = response['role'] as String;
        }
      } catch (e) {
        print('Error getting user role: $e');
      }

      final metadata = <String, dynamic>{
        'Name': originalName != employeeName
            ? '$originalName -> $employeeName'
            : employeeName,
        'Role': originalRole != employeeRole
            ? '$originalRole -> $employeeRole'
            : employeeRole,
        'Status': originalStatus != employeeStatus
            ? '$originalStatus -> $employeeStatus'
            : employeeStatus,
      };
      final now = DateTime.now();

      // Format time as 12-hour with AM/PM
      final hour12 =
          now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      final amPm = now.hour >= 12 ? 'PM' : 'AM';
      final timeString =
          '$hour12:${now.minute.toString().padLeft(2, '0')} $amPm';

      await _supabase.from('activity_logs').insert({
        'category': 'Settings',
        'action': 'employee_profile_edited',
        'description': '$userRole edited ${originalRole} profile',
        'user_name': _getCurrentUserName(),
        'user_id': currentUser.id,
        'user_email': currentUser.email,
        'user_role': userRole, // Store the role for filtering
        'metadata': metadata,
        'date': now.toIso8601String(),
        'time': timeString,
        'created_at': now.toIso8601String(),
      });
    } catch (e) {
      print('Error logging employee profile edited activity: $e');
    }
  }

  /// Log backup created activity
  Future<void> logBackupCreated({
    required String backupFileName,
    required DateTime backupTime,
  }) async {
    try {
      // Get current user
      final User? currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return; // Don't log if no user

      // Get user role for role-specific description
      String userRole = 'Staff'; // Default
      try {
        final response = await _supabase
            .from('user_roles')
            .select('role')
            .eq('id', currentUser.id)
            .maybeSingle();
        if (response != null && response['role'] != null) {
          userRole = response['role'] as String;
        }
      } catch (e) {
        print('Error getting user role: $e');
      }

      // Convert UTC to local time if needed
      final localBackupTime =
          backupTime.isUtc ? backupTime.toLocal() : backupTime;

      // Format backup time as MM/DD/YYYY and 12-hour format with AM/PM
      final month = localBackupTime.month.toString().padLeft(2, '0');
      final day = localBackupTime.day.toString().padLeft(2, '0');
      final year = localBackupTime.year;
      final backupDateString = '$month/$day/$year';

      final hour12 = localBackupTime.hour > 12
          ? localBackupTime.hour - 12
          : (localBackupTime.hour == 0 ? 12 : localBackupTime.hour);
      final amPm = localBackupTime.hour >= 12 ? 'PM' : 'AM';
      final backupTimeString =
          '$hour12:${localBackupTime.minute.toString().padLeft(2, '0')} $amPm';

      final metadata = <String, dynamic>{
        'Name': backupFileName,
        'Time': '$backupDateString $backupTimeString',
      };
      final now = DateTime.now();

      // Format current time as 12-hour with AM/PM
      final currentHour12 =
          now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      final currentAmPm = now.hour >= 12 ? 'PM' : 'AM';
      final currentTimeString =
          '$currentHour12:${now.minute.toString().padLeft(2, '0')} $currentAmPm';

      await _supabase.from('activity_logs').insert({
        'category': 'Settings',
        'action': 'backup_created',
        'description': '$userRole created a backup',
        'user_name': _getCurrentUserName(),
        'user_id': currentUser.id,
        'user_email': currentUser.email,
        'user_role': userRole, // Store the role for filtering
        'metadata': metadata,
        'date': now.toIso8601String(),
        'time': currentTimeString,
        'created_at': now.toIso8601String(),
      });
    } catch (e) {
      print('Error logging backup created activity: $e');
    }
  }

  /// Log backup restored activity
  Future<void> logBackupRestored({
    required String backupFileName,
    required DateTime backupTime,
  }) async {
    try {
      // Get current user
      final User? currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return; // Don't log if no user

      // Get user role for role-specific description
      String userRole = 'Staff'; // Default
      try {
        final response = await _supabase
            .from('user_roles')
            .select('role')
            .eq('id', currentUser.id)
            .maybeSingle();
        if (response != null && response['role'] != null) {
          userRole = response['role'] as String;
        }
      } catch (e) {
        print('Error getting user role: $e');
      }

      // Convert UTC to local time if needed
      final localBackupTime =
          backupTime.isUtc ? backupTime.toLocal() : backupTime;

      // Format backup time as MM/DD/YYYY and 12-hour format with AM/PM
      final month = localBackupTime.month.toString().padLeft(2, '0');
      final day = localBackupTime.day.toString().padLeft(2, '0');
      final year = localBackupTime.year;
      final backupDateString = '$month/$day/$year';

      final hour12 = localBackupTime.hour > 12
          ? localBackupTime.hour - 12
          : (localBackupTime.hour == 0 ? 12 : localBackupTime.hour);
      final amPm = localBackupTime.hour >= 12 ? 'PM' : 'AM';
      final backupTimeString =
          '$hour12:${localBackupTime.minute.toString().padLeft(2, '0')} $amPm';

      final metadata = <String, dynamic>{
        'Name': backupFileName,
        'Time': '$backupDateString $backupTimeString',
      };
      final now = DateTime.now();

      // Format current time as 12-hour with AM/PM
      final currentHour12 =
          now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      final currentAmPm = now.hour >= 12 ? 'PM' : 'AM';
      final currentTimeString =
          '$currentHour12:${now.minute.toString().padLeft(2, '0')} $currentAmPm';

      await _supabase.from('activity_logs').insert({
        'category': 'Settings',
        'action': 'backup_restored',
        'description': '$userRole restored a backup',
        'user_name': _getCurrentUserName(),
        'user_id': currentUser.id,
        'user_email': currentUser.email,
        'user_role': userRole, // Store the role for filtering
        'metadata': metadata,
        'date': now.toIso8601String(),
        'time': currentTimeString,
        'created_at': now.toIso8601String(),
      });
    } catch (e) {
      print('Error logging backup restored activity: $e');
    }
  }

  /// Log backup deleted activity
  Future<void> logBackupDeleted({
    required String backupFileName,
    required DateTime backupTime,
  }) async {
    try {
      // Get current user
      final User? currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return; // Don't log if no user

      // Get user role for role-specific description
      String userRole = 'Staff'; // Default
      try {
        final response = await _supabase
            .from('user_roles')
            .select('role')
            .eq('id', currentUser.id)
            .maybeSingle();
        if (response != null && response['role'] != null) {
          userRole = response['role'] as String;
        }
      } catch (e) {
        print('Error getting user role: $e');
      }

      // Convert UTC to local time if needed
      final localBackupTime =
          backupTime.isUtc ? backupTime.toLocal() : backupTime;

      // Format backup time as MM/DD/YYYY and 12-hour format with AM/PM
      final month = localBackupTime.month.toString().padLeft(2, '0');
      final day = localBackupTime.day.toString().padLeft(2, '0');
      final year = localBackupTime.year;
      final backupDateString = '$month/$day/$year';

      final hour12 = localBackupTime.hour > 12
          ? localBackupTime.hour - 12
          : (localBackupTime.hour == 0 ? 12 : localBackupTime.hour);
      final amPm = localBackupTime.hour >= 12 ? 'PM' : 'AM';
      final backupTimeString =
          '$hour12:${localBackupTime.minute.toString().padLeft(2, '0')} $amPm';

      final metadata = <String, dynamic>{
        'Name': backupFileName,
        'Time': '$backupDateString $backupTimeString',
      };
      final now = DateTime.now();

      // Format current time as 12-hour with AM/PM
      final currentHour12 =
          now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      final currentAmPm = now.hour >= 12 ? 'PM' : 'AM';
      final currentTimeString =
          '$currentHour12:${now.minute.toString().padLeft(2, '0')} $currentAmPm';

      await _supabase.from('activity_logs').insert({
        'category': 'Settings',
        'action': 'backup_deleted',
        'description': '$userRole deleted a backup',
        'user_name': _getCurrentUserName(),
        'user_id': currentUser.id,
        'user_email': currentUser.email,
        'user_role': userRole, // Store the role for filtering
        'metadata': metadata,
        'date': now.toIso8601String(),
        'time': currentTimeString,
        'created_at': now.toIso8601String(),
      });
    } catch (e) {
      print('Error logging backup deleted activity: $e');
    }
  }

  /// Log password change activity
  Future<void> logPasswordChange({
    required String userName,
  }) async {
    try {
      // Get current user
      final User? currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return; // Don't log if no user

      // Get user role for role-specific description
      String userRole = 'Staff'; // Default
      try {
        final response = await _supabase
            .from('user_roles')
            .select('role')
            .eq('id', currentUser.id)
            .maybeSingle();
        if (response != null && response['role'] != null) {
          userRole = response['role'] as String;
        }
      } catch (e) {
        print('Error getting user role: $e');
      }

      final now = DateTime.now();

      // Format time as 12-hour with AM/PM
      final hour12 =
          now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      final amPm = now.hour >= 12 ? 'PM' : 'AM';
      final timeString =
          '$hour12:${now.minute.toString().padLeft(2, '0')} $amPm';

      await _supabase.from('activity_logs').insert({
        'category': 'Settings',
        'action': 'password_changed',
        'description': '$userRole changed their password',
        'user_name': userName,
        'user_id': currentUser.id,
        'user_email': currentUser.email,
        'user_role': userRole, // Store the role for filtering
        'metadata': {}, // No additional details for privacy
        'date': now.toIso8601String(),
        'time': timeString,
        'created_at': now.toIso8601String(),
      });
    } catch (e) {
      print('Error logging password change activity: $e');
    }
  }

  /// Helper method to get current user's display name
  String _getCurrentUserName() {
    try {
      final User? currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return 'Unknown User';

      // Try to get display name from user metadata first
      if (currentUser.userMetadata?['display_name'] != null &&
          (currentUser.userMetadata?['display_name'] as String).isNotEmpty) {
        return currentUser.userMetadata!['display_name'] as String;
      }

      // Fallback to email username
      if (currentUser.email != null) {
        return currentUser.email!.split('@')[0];
      }

      return 'Unknown User';
    } catch (e) {
      return 'Unknown User';
    }
  }
}
