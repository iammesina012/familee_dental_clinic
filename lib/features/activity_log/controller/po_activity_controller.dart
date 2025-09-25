import 'package:supabase_flutter/supabase_flutter.dart';

class PoActivityController {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get purchase order activities stream
  Stream<List<Map<String, dynamic>>> getPoActivitiesStream() {
    return _supabase
        .from('activity_logs')
        .stream(primaryKey: ['id'])
        .eq('category', 'Purchase Order')
        .order('created_at', ascending: false);
  }

  /// Filter purchase order activities by search query
  List<Map<String, dynamic>> filterPoActivities(
    List<Map<String, dynamic>> activities,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) return activities;

    return activities.where((activity) {
      final description =
          (activity['description'] ?? '').toString().toLowerCase();
      final userName = (activity['userName'] ?? '').toString().toLowerCase();
      final metadata = activity['metadata'] as Map<String, dynamic>? ?? {};
      final poCode = (metadata['poCode'] ?? '').toString().toLowerCase();
      final poName = (metadata['poName'] ?? '').toString().toLowerCase();
      final supplyName =
          (metadata['supplyName'] ?? '').toString().toLowerCase();
      final brandName = (metadata['brandName'] ?? '').toString().toLowerCase();
      final supplierName =
          (metadata['supplierName'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();

      return description.contains(query) ||
          userName.contains(query) ||
          poCode.contains(query) ||
          poName.contains(query) ||
          supplyName.contains(query) ||
          brandName.contains(query) ||
          supplierName.contains(query);
    }).toList();
  }

  /// Filter purchase order activities by date
  List<Map<String, dynamic>> filterPoActivitiesByDate(
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

  /// Delete purchase order activity
  Future<void> deletePoActivity(String activityId) async {
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

  /// Log purchase order created
  Future<void> logPurchaseOrderCreated({
    required String poCode,
    required String poName,
    required List<Map<String, dynamic>> supplies,
  }) async {
    // Normalize code (avoid double #)
    final normalizedCode =
        poCode.startsWith('#') ? poCode.substring(1) : poCode;

    // Build normalized supplies list for details
    final List<Map<String, dynamic>> normalizedSupplies = supplies.map((s) {
      final List<Map<String, dynamic>> batches = [];
      if (s['expiryBatches'] is List) {
        for (final b in (s['expiryBatches'] as List)) {
          final qty = (b['quantity'] ?? 0) as int;
          final exp = (b['expiryDate'] ?? '').toString();
          batches.add({
            'quantity': qty,
            'expiryDate': exp.isEmpty ? 'No expiry date' : exp,
          });
        }
      }
      return {
        'supplyName': s['supplyName'] ?? s['name'] ?? 'N/A',
        'brandName': s['brandName'] ?? s['brand'] ?? 'N/A',
        'supplierName': s['supplierName'] ?? s['supplier'] ?? 'N/A',
        'quantity': s['quantity'] ?? 0,
        'cost': s['cost'] ?? 0.0,
        'expiryDate': s['expiryDate'] ?? 'No expiry date',
        'expiryBatches': batches,
      };
    }).toList();

    // Use first item for backward-compatible top-level details
    final firstSupply =
        normalizedSupplies.isNotEmpty ? normalizedSupplies.first : {};

    // Collect expiry batches (if present)
    final List<Map<String, dynamic>> expiryBatches = [];
    if (firstSupply['expiryBatches'] is List) {
      for (final b in (firstSupply['expiryBatches'] as List)) {
        final qty = (b['quantity'] ?? 0) as int;
        final exp = (b['expiryDate'] ?? '').toString();
        expiryBatches.add({
          'quantity': qty,
          'expiryDate': exp.isEmpty ? 'No expiry date' : exp,
        });
      }
    }

    await _logActivity(
      action: 'purchase_order_created',
      category: 'Purchase Order',
      description: 'Created #$normalizedCode: $poName',
      metadata: {
        'supplies': normalizedSupplies,
        'supplyName': firstSupply['supplyName'] ?? 'N/A',
        'brandName': firstSupply['brandName'] ?? 'N/A',
        'supplierName': firstSupply['supplierName'] ?? 'N/A',
        'quantity': firstSupply['quantity'] ?? 0,
        'subtotal': firstSupply['cost'] ?? 0.0,
        // Backward compatibility single expiry
        'expiryDate': firstSupply['expiryDate'] ?? 'No expiry date',
        // New: multiple expiry batches
        'expiryBatches': expiryBatches,
      },
    );
  }

  /// Log purchase order edited (Open section edits)
  Future<void> logPurchaseOrderEdited({
    required String poCode,
    required String poName,
    required List<Map<String, dynamic>> supplies,
    Map<String, Map<String, dynamic>>? fieldChanges,
  }) async {
    // Normalize code (avoid double #)
    final normalizedCode =
        poCode.startsWith('#') ? poCode.substring(1) : poCode;

    // Build normalized supplies list for details
    final List<Map<String, dynamic>> normalizedSupplies = supplies.map((s) {
      final List<Map<String, dynamic>> batches = [];
      if (s['expiryBatches'] is List) {
        for (final b in (s['expiryBatches'] as List)) {
          final qty = (b['quantity'] ?? 0) as int;
          final exp = (b['expiryDate'] ?? '').toString();
          batches.add({
            'quantity': qty,
            'expiryDate': exp.isEmpty ? 'No expiry date' : exp,
          });
        }
      }
      return {
        'supplyName': s['supplyName'] ?? s['name'] ?? 'N/A',
        'brandName': s['brandName'] ?? s['brand'] ?? 'N/A',
        'supplierName': s['supplierName'] ?? s['supplier'] ?? 'N/A',
        'quantity': s['quantity'] ?? 0,
        'cost': s['cost'] ?? 0.0,
        'expiryDate': s['expiryDate'] ?? 'No expiry date',
        'expiryBatches': batches,
      };
    }).toList();

    // Use first item for backward-compatible top-level details
    final firstSupply =
        normalizedSupplies.isNotEmpty ? normalizedSupplies.first : {};

    // Collect expiry batches (if present)
    final List<Map<String, dynamic>> expiryBatches = [];
    if (firstSupply['expiryBatches'] is List) {
      for (final b in (firstSupply['expiryBatches'] as List)) {
        final qty = (b['quantity'] ?? 0) as int;
        final exp = (b['expiryDate'] ?? '').toString();
        expiryBatches.add({
          'quantity': qty,
          'expiryDate': exp.isEmpty ? 'No expiry date' : exp,
        });
      }
    }

    await _logActivity(
      action: 'purchase_order_edited',
      category: 'Purchase Order',
      description: 'Edited #$normalizedCode: $poName',
      metadata: {
        'supplies': normalizedSupplies,
        'supplyName': firstSupply['supplyName'] ?? 'N/A',
        'brandName': firstSupply['brandName'] ?? 'N/A',
        'supplierName': firstSupply['supplierName'] ?? 'N/A',
        'quantity': firstSupply['quantity'] ?? 0,
        'subtotal': firstSupply['cost'] ?? 0.0,
        'expiryDate': firstSupply['expiryDate'] ?? 'No expiry date',
        'expiryBatches': expiryBatches,
        if (fieldChanges != null && fieldChanges.isNotEmpty)
          'fieldChanges': fieldChanges,
      },
    );
  }

  /// Log purchase order removed (deleted from Open section)
  Future<void> logPurchaseOrderRemoved({
    required String poCode,
    required String poName,
    required List<Map<String, dynamic>> supplies,
  }) async {
    // Normalize code (avoid double #)
    final normalizedCode =
        poCode.startsWith('#') ? poCode.substring(1) : poCode;

    // Build normalized supplies list for details
    final List<Map<String, dynamic>> normalizedSupplies = supplies.map((s) {
      final List<Map<String, dynamic>> batches = [];
      if (s['expiryBatches'] is List) {
        for (final b in (s['expiryBatches'] as List)) {
          final qty = (b['quantity'] ?? 0) as int;
          final exp = (b['expiryDate'] ?? '').toString();
          batches.add({
            'quantity': qty,
            'expiryDate': exp.isEmpty ? 'No expiry date' : exp,
          });
        }
      }
      return {
        'supplyName': s['supplyName'] ?? s['name'] ?? 'N/A',
        'brandName': s['brandName'] ?? s['brand'] ?? 'N/A',
        'supplierName': s['supplierName'] ?? s['supplier'] ?? 'N/A',
        'quantity': s['quantity'] ?? 0,
        'cost': s['cost'] ?? 0.0,
        'expiryDate': s['expiryDate'] ?? 'No expiry date',
        'expiryBatches': batches,
      };
    }).toList();

    // Use first item for backward-compatible top-level details
    final firstSupply =
        normalizedSupplies.isNotEmpty ? normalizedSupplies.first : {};

    // Collect expiry batches (if present)
    final List<Map<String, dynamic>> expiryBatches = [];
    if (firstSupply['expiryBatches'] is List) {
      for (final b in (firstSupply['expiryBatches'] as List)) {
        final qty = (b['quantity'] ?? 0) as int;
        final exp = (b['expiryDate'] ?? '').toString();
        expiryBatches.add({
          'quantity': qty,
          'expiryDate': exp.isEmpty ? 'No expiry date' : exp,
        });
      }
    }

    await _logActivity(
      action: 'purchase_order_removed',
      category: 'Purchase Order',
      description: 'Removed #$normalizedCode: $poName',
      metadata: {
        'supplies': normalizedSupplies,
        'supplyName': firstSupply['supplyName'] ?? 'N/A',
        'brandName': firstSupply['brandName'] ?? 'N/A',
        'supplierName': firstSupply['supplierName'] ?? 'N/A',
        'quantity': firstSupply['quantity'] ?? 0,
        'subtotal': firstSupply['cost'] ?? 0.0,
        'expiryDate': firstSupply['expiryDate'] ?? 'No expiry date',
        'expiryBatches': expiryBatches,
      },
    );
  }

  /// Log purchase order supply received (mark as received)
  Future<void> logPurchaseOrderReceived({
    required String poCode,
    required String poName,
    required List<Map<String, dynamic>> supplies,
  }) async {
    // Normalize code (avoid double #)
    final normalizedCode =
        poCode.startsWith('#') ? poCode.substring(1) : poCode;

    // Build normalized supplies list for details (usually one supply)
    final List<Map<String, dynamic>> normalizedSupplies = supplies.map((s) {
      final List<Map<String, dynamic>> batches = [];
      if (s['expiryBatches'] is List) {
        for (final b in (s['expiryBatches'] as List)) {
          final qty = (b['quantity'] ?? 0) as int;
          final exp = (b['expiryDate'] ?? '').toString();
          batches.add({
            'quantity': qty,
            'expiryDate': exp.isEmpty ? 'No expiry date' : exp,
          });
        }
      }
      return {
        'supplyName': s['supplyName'] ?? s['name'] ?? 'N/A',
        'brandName': s['brandName'] ?? s['brand'] ?? 'N/A',
        'supplierName': s['supplierName'] ?? s['supplier'] ?? 'N/A',
        'quantity': s['quantity'] ?? 0,
        'cost': s['cost'] ?? 0.0,
        'expiryDate': s['expiryDate'] ?? 'No expiry date',
        'expiryBatches': batches,
      };
    }).toList();

    // Use first item for backward-compatible top-level details
    final firstSupply =
        normalizedSupplies.isNotEmpty ? normalizedSupplies.first : {};

    // Collect expiry batches (if present)
    final List<Map<String, dynamic>> expiryBatches = [];
    if (firstSupply['expiryBatches'] is List) {
      for (final b in (firstSupply['expiryBatches'] as List)) {
        final qty = (b['quantity'] ?? 0) as int;
        final exp = (b['expiryDate'] ?? '').toString();
        expiryBatches.add({
          'quantity': qty,
          'expiryDate': exp.isEmpty ? 'No expiry date' : exp,
        });
      }
    }

    await _logActivity(
      action: 'purchase_order_received',
      category: 'Purchase Order',
      description: 'Received #$normalizedCode: $poName',
      metadata: {
        'supplies': normalizedSupplies,
        'supplyName': firstSupply['supplyName'] ?? 'N/A',
        'brandName': firstSupply['brandName'] ?? 'N/A',
        'supplierName': firstSupply['supplierName'] ?? 'N/A',
        'quantity': firstSupply['quantity'] ?? 0,
        'subtotal': firstSupply['cost'] ?? 0.0,
        'expiryDate': firstSupply['expiryDate'] ?? 'No expiry date',
        'expiryBatches': expiryBatches,
      },
    );
  }

  /// Log purchase order approved
  Future<void> logPurchaseOrderApproved({
    required String poCode,
    required String poName,
    required List<Map<String, dynamic>> supplies,
  }) async {
    final normalizedCode =
        poCode.startsWith('#') ? poCode.substring(1) : poCode;

    final List<Map<String, dynamic>> normalizedSupplies = supplies.map((s) {
      final List<Map<String, dynamic>> batches = [];
      if (s['expiryBatches'] is List) {
        for (final b in (s['expiryBatches'] as List)) {
          final qty = (b['quantity'] ?? 0) as int;
          final exp = (b['expiryDate'] ?? '').toString();
          batches.add({
            'quantity': qty,
            'expiryDate': exp.isEmpty ? 'No expiry date' : exp,
          });
        }
      }
      return {
        'supplyName': s['supplyName'] ?? s['name'] ?? 'N/A',
        'brandName': s['brandName'] ?? s['brand'] ?? 'N/A',
        'supplierName': s['supplierName'] ?? s['supplier'] ?? 'N/A',
        'quantity': s['quantity'] ?? 0,
        'cost': s['cost'] ?? 0.0,
        'expiryDate': s['expiryDate'] ?? 'No expiry date',
        'expiryBatches': batches,
      };
    }).toList();

    final firstSupply =
        normalizedSupplies.isNotEmpty ? normalizedSupplies.first : {};

    final List<Map<String, dynamic>> expiryBatches = [];
    if (firstSupply['expiryBatches'] is List) {
      for (final b in (firstSupply['expiryBatches'] as List)) {
        final qty = (b['quantity'] ?? 0) as int;
        final exp = (b['expiryDate'] ?? '').toString();
        expiryBatches.add({
          'quantity': qty,
          'expiryDate': exp.isEmpty ? 'No expiry date' : exp,
        });
      }
    }

    await _logActivity(
      action: 'purchase_order_approved',
      category: 'Purchase Order',
      description: 'Approved #$normalizedCode: $poName',
      metadata: {
        'supplies': normalizedSupplies,
        'supplyName': firstSupply['supplyName'] ?? 'N/A',
        'brandName': firstSupply['brandName'] ?? 'N/A',
        'supplierName': firstSupply['supplierName'] ?? 'N/A',
        'quantity': firstSupply['quantity'] ?? 0,
        'subtotal': firstSupply['cost'] ?? 0.0,
        'expiryDate': firstSupply['expiryDate'] ?? 'No expiry date',
        'expiryBatches': expiryBatches,
      },
    );
  }

  /// Log purchase order rejected
  Future<void> logPurchaseOrderRejected({
    required String poCode,
    required String poName,
    required List<Map<String, dynamic>> supplies,
  }) async {
    final normalizedCode =
        poCode.startsWith('#') ? poCode.substring(1) : poCode;

    final List<Map<String, dynamic>> normalizedSupplies = supplies.map((s) {
      final List<Map<String, dynamic>> batches = [];
      if (s['expiryBatches'] is List) {
        for (final b in (s['expiryBatches'] as List)) {
          final qty = (b['quantity'] ?? 0) as int;
          final exp = (b['expiryDate'] ?? '').toString();
          batches.add({
            'quantity': qty,
            'expiryDate': exp.isEmpty ? 'No expiry date' : exp,
          });
        }
      }
      return {
        'supplyName': s['supplyName'] ?? s['name'] ?? 'N/A',
        'brandName': s['brandName'] ?? s['brand'] ?? 'N/A',
        'supplierName': s['supplierName'] ?? s['supplier'] ?? 'N/A',
        'quantity': s['quantity'] ?? 0,
        'cost': s['cost'] ?? 0.0,
        'expiryDate': s['expiryDate'] ?? 'No expiry date',
        'expiryBatches': batches,
      };
    }).toList();

    final firstSupply =
        normalizedSupplies.isNotEmpty ? normalizedSupplies.first : {};

    final List<Map<String, dynamic>> expiryBatches = [];
    if (firstSupply['expiryBatches'] is List) {
      for (final b in (firstSupply['expiryBatches'] as List)) {
        final qty = (b['quantity'] ?? 0) as int;
        final exp = (b['expiryDate'] ?? '').toString();
        expiryBatches.add({
          'quantity': qty,
          'expiryDate': exp.isEmpty ? 'No expiry date' : exp,
        });
      }
    }

    await _logActivity(
      action: 'purchase_order_rejected',
      category: 'Purchase Order',
      description: 'Rejected #$normalizedCode: $poName',
      metadata: {
        'supplies': normalizedSupplies,
        'supplyName': firstSupply['supplyName'] ?? 'N/A',
        'brandName': firstSupply['brandName'] ?? 'N/A',
        'supplierName': firstSupply['supplierName'] ?? 'N/A',
        'quantity': firstSupply['quantity'] ?? 0,
        'subtotal': firstSupply['cost'] ?? 0.0,
        'expiryDate': firstSupply['expiryDate'] ?? 'No expiry date',
        'expiryBatches': expiryBatches,
      },
    );
  }
}
