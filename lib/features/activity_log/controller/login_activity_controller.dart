import 'package:supabase_flutter/supabase_flutter.dart';

class LoginActivityController {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get login activities stream
  Stream<List<Map<String, dynamic>>> getLoginActivitiesStream() {
    return _supabase
        .from('activity_logs')
        .stream(primaryKey: ['id'])
        .eq('category', 'Login')
        .order('created_at', ascending: false);
  }

  /// Filter login activities by search query
  List<Map<String, dynamic>> filterLoginActivities(
    List<Map<String, dynamic>> activities,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) return activities;

    return activities.where((activity) {
      final description =
          (activity['description'] ?? '').toString().toLowerCase();
      final userName = (activity['userName'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();

      return description.contains(query) || userName.contains(query);
    }).toList();
  }

  /// Filter login activities by date
  List<Map<String, dynamic>> filterLoginActivitiesByDate(
    List<Map<String, dynamic>> activities,
    DateTime selectedDate,
  ) {
    return activities.where((activity) {
      final activityDate = activity['date'] as DateTime?;
      if (activityDate == null) return false;

      return activityDate.year == selectedDate.year &&
          activityDate.month == selectedDate.month &&
          activityDate.day == selectedDate.day;
    }).toList();
  }

  /// Delete login activity
  Future<void> deleteLoginActivity(String activityId) async {
    await _supabase.from('activity_logs').delete().eq('id', activityId);
  }

  // LOGGING METHODS

  /// Automatically log an activity when it happens
  /// This should be called from other controllers after successful operations
  Future<void> _logActivity({
    required String action,
    required String category,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Get current user
      final User? currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return; // Don't log if no user

      // Get current timestamp
      final DateTime now = DateTime.now();
      final String timeString = _formatTime(now);

      // Get user role
      String userRole = 'staff'; // Default to lowercase
      try {
        final response = await _supabase
            .from('user_roles')
            .select('role')
            .eq('id', currentUser.id)
            .maybeSingle();
        if (response != null && response['role'] != null) {
          userRole = (response['role'] as String).toLowerCase();
        }
      } catch (e) {
        print('Error getting user role: $e');
      }

      // Create activity data
      final Map<String, dynamic> activityData = {
        'user_name': _getDisplayName(currentUser),
        'description': description,
        'date': now.toIso8601String(),
        'time': timeString,
        'category': category,
        'action': action,
        'user_id': currentUser.id,
        'user_email': currentUser.email,
        'user_role': userRole, // Store the role for filtering
        'metadata': metadata ?? {},
        'created_at': now.toIso8601String(),
      };

      // Save to Supabase
      await _supabase.from('activity_logs').insert(activityData);

      print('Activity logged: $action - $description'); // Debug log
    } catch (e) {
      // Don't throw errors - logging shouldn't break main functionality
      print('Failed to log activity: $e');
    }
  }

  /// Get user-friendly display name
  String _getDisplayName(User user) {
    if (user.userMetadata?['display_name'] != null &&
        (user.userMetadata?['display_name'] as String).isNotEmpty) {
      return user.userMetadata!['display_name'] as String;
    }

    // Extract username from email if no display name
    if (user.email != null) {
      final email = user.email!;
      final username = email.split('@')[0];

      // Clean up username (capitalize first letter, replace separators)
      final cleanUsername = username
          .replaceAll(RegExp(r'[._-]'), ' ')
          .split(' ')
          .map((word) => word.isNotEmpty
              ? word[0].toUpperCase() + word.substring(1).toLowerCase()
              : '')
          .where((word) => word.isNotEmpty)
          .join(' ');

      return cleanUsername.isNotEmpty ? cleanUsername : username;
    }

    return 'Unknown User';
  }

  /// Format time as "9:06 AM" format
  String _formatTime(DateTime dateTime) {
    final int hour = dateTime.hour;
    final int minute = dateTime.minute;
    final String period = hour < 12 ? 'AM' : 'PM';
    final int displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final String minuteStr = minute.toString().padLeft(2, '0');

    return '$displayHour:$minuteStr $period';
  }

  /// Log login activities
  Future<void> logLogin() async {
    await _logActivity(
      action: 'login',
      category: 'Login',
      description: 'User logged in',
    );
  }

  /// Log logout activities
  Future<void> logLogout() async {
    await _logActivity(
      action: 'logout',
      category: 'Login',
      description: 'User logged out',
    );
  }
}
