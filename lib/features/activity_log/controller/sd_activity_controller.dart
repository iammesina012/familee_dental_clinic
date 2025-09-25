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

  /// Log preset creation activities
  Future<void> logPresetCreated({
    required String presetName,
    required List<Map<String, dynamic>> supplies,
  }) async {
    await _logActivity(
      action: 'preset_created',
      category: 'Stock Deduction',
      description: 'Created Preset: $presetName',
      metadata: {
        'presetName': presetName,
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

  /// Log preset editing activities
  Future<void> logPresetEdited({
    required String originalPresetName,
    required String newPresetName,
    required List<Map<String, dynamic>> originalSupplies,
    required List<Map<String, dynamic>> newSupplies,
    required Map<String, dynamic> fieldChanges,
  }) async {
    // Main description should show only the new preset name
    String description = 'Edited Preset: $newPresetName';

    // Find added and removed supplies
    List<String> addedSupplies = [];
    List<String> removedSupplies = [];

    // Get supply names for comparison
    List<String> originalSupplyNames = originalSupplies
        .map((s) => s['name']?.toString() ?? 'Unknown')
        .toList();
    List<String> newSupplyNames =
        newSupplies.map((s) => s['name']?.toString() ?? 'Unknown').toList();

    // Find added supplies
    for (String supplyName in newSupplyNames) {
      if (!originalSupplyNames.contains(supplyName)) {
        addedSupplies.add(supplyName);
      }
    }

    // Find removed supplies
    for (String supplyName in originalSupplyNames) {
      if (!newSupplyNames.contains(supplyName)) {
        removedSupplies.add(supplyName);
      }
    }

    await _logActivity(
      action: 'preset_edited',
      category: 'Stock Deduction',
      description: description,
      metadata: {
        'presetName': newPresetName,
        'originalPresetName': originalPresetName,
        'suppliesCount': newSupplies.length,
        'originalSuppliesCount': originalSupplies.length,
        'supplies': newSupplies
            .map((supply) => {
                  'supplyName': supply['name'] ?? 'Unknown',
                  'brand': supply['brand'] ?? 'Unknown',
                  'supplier': supply['supplier'] ?? 'Unknown',
                })
            .toList(),
        'fieldChanges': fieldChanges,
        'addedSupplies': addedSupplies,
        'removedSupplies': removedSupplies,
      },
    );
  }

  /// Log preset deletion activities
  Future<void> logPresetDeleted({
    required String presetName,
    required List<Map<String, dynamic>> supplies,
  }) async {
    await _logActivity(
      action: 'preset_deleted',
      category: 'Stock Deduction',
      description: 'Deleted Preset: ' + presetName,
      metadata: {
        'suppliesCount': supplies.length,
        'supplies': supplies
            .map((supply) => {
                  'supplyName':
                      supply['name'] ?? supply['supplyName'] ?? 'Unknown',
                  'brand': supply['brand'] ?? 'Unknown',
                  'supplier': supply['supplier'] ?? 'Unknown',
                })
            .toList(),
      },
    );
  }

  /// Log preset usage activities
  Future<void> logPresetUsed({
    required String presetName,
    required List<Map<String, dynamic>> supplies,
  }) async {
    await _logActivity(
      action: 'preset_used',
      category: 'Stock Deduction',
      description: 'Preset Used: ' + presetName,
      metadata: {
        'presetName': presetName,
        'suppliesCount': supplies.length,
        'supplies': supplies
            .map((supply) => {
                  'supplyName': supply['name'] ?? supply['supplyName'] ?? 'N/A',
                  'brand': supply['brand'] ?? 'N/A',
                  'supplier': supply['supplier'] ?? 'N/A',
                })
            .toList(),
      },
    );
  }
}
