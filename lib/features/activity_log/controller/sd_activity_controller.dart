import 'package:supabase_flutter/supabase_flutter.dart';

class SdActivityController {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get stock deduction activities stream
  Stream<List<Map<String, dynamic>>> getSdActivitiesStream() {
    return _supabase
        .from('activity_logs')
        .stream(primaryKey: ['id'])
        .eq('category', 'Stock Deduction')
        .order('created_at', ascending: false);
  }

  /// Filter stock deduction activities by search query
  List<Map<String, dynamic>> filterSdActivities(
    List<Map<String, dynamic>> activities,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) return activities;

    return activities.where((activity) {
      final description =
          (activity['description'] ?? '').toString().toLowerCase();
      final userName = (activity['userName'] ?? '').toString().toLowerCase();
      final metadata = activity['metadata'] as Map<String, dynamic>? ?? {};
      final itemName = (metadata['itemName'] ?? '').toString().toLowerCase();
      final brand = (metadata['brand'] ?? '').toString().toLowerCase();
      final supplier = (metadata['supplier'] ?? '').toString().toLowerCase();
      final presetName =
          (metadata['presetName'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();

      return description.contains(query) ||
          userName.contains(query) ||
          itemName.contains(query) ||
          brand.contains(query) ||
          supplier.contains(query) ||
          presetName.contains(query);
    }).toList();
  }

  /// Filter stock deduction activities by date
  List<Map<String, dynamic>> filterSdActivitiesByDate(
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

  /// Delete stock deduction activity
  Future<void> deleteSdActivity(String activityId) async {
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

  /// Log stock deduction activities
  Future<void> logStockDeduction({
    required String itemName,
    required String brand,
    required int quantity,
    required String supplier,
  }) async {
    await _logActivity(
      action: 'stock_deduction',
      category: 'Stock Deduction',
      description: 'Stocks Deducted',
      metadata: {
        'itemName': itemName,
        'brand': brand,
        'quantity': quantity,
        'supplier': supplier,
      },
    );
  }

  /// Log stock revert (undo) activities
  Future<void> logStockReverted({
    required String itemName,
    required String brand,
    required int quantity,
    required String supplier,
  }) async {
    await _logActivity(
      action: 'stock_reverted',
      category: 'Stock Deduction',
      description: 'Stocks Reverted',
      metadata: {
        'itemName': itemName,
        'brand': brand,
        'quantity': quantity,
        'supplier': supplier,
      },
    );
  }

  /// Log deduction log creation activities
  Future<void> logDeductionLogCreated({
    required String purpose,
    required List<Map<String, dynamic>> supplies,
  }) async {
    await _logActivity(
      action: 'deduction_log_created',
      category: 'Stock Deduction',
      description: 'Created Deduction Log: $purpose',
      metadata: {
        'purpose': purpose,
        'suppliesCount': supplies.length,
        'supplies': supplies
            .map((supply) => {
                  'supplyName': supply['name'] ?? 'Unknown',
                  'brand': supply['brand'] ?? 'Unknown',
                  'supplier': supply['supplier'] ?? 'Unknown',
                })
            .toList(),
      },
    );
  }
}
