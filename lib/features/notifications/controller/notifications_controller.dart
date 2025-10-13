import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final String type;
  final bool isRead;
  final String? supplyName; // optional payload for inventory
  final String? poCode; // optional payload for purchase orders

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.type,
    this.isRead = false,
    this.supplyName,
    this.poCode,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) {
    return AppNotification(
      id: id,
      title: (data['title'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      createdAt: _parseDateTime(data['created_at']),
      type: (data['type'] ?? 'general').toString(),
      isRead: (data['is_read'] ?? false) as bool,
      supplyName: data['supply_name']?.toString(),
      poCode: data['po_code']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'type': type,
      'is_read': isRead,
      if (supplyName != null) 'supply_name': supplyName,
      if (poCode != null) 'po_code': poCode,
    };
  }

  static DateTime _parseDateTime(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();

    if (timestamp is String) {
      // Try parsing as ISO8601 string
      final parsed = DateTime.tryParse(timestamp);
      if (parsed != null) {
        print('Parsed timestamp: $timestamp -> $parsed');
        return parsed;
      } else {
        print('Failed to parse timestamp: $timestamp');
      }
    }

    // Fallback to current time
    print('Using fallback time for timestamp: $timestamp');
    return DateTime.now();
  }
}

class NotificationsController {
  final SupabaseClient _supabase = Supabase.instance.client;
  // Local preferences keys
  static const String _kInventoryPref = 'settings.notify_inventory';
  static const String _kApprovalPref = 'settings.notify_approval';

  // Default stream (unbounded)
  Stream<List<AppNotification>> getNotificationsStream() {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data
            .map((row) => AppNotification.fromMap(row['id'] as String, row))
            .toList());
  }

  // Limited stream (keeps UI responsive and pairs with enforceMaxNotifications)
  Stream<List<AppNotification>> getNotificationsStreamLimited({int max = 20}) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(max)
        .map((data) => data
            .map((row) => AppNotification.fromMap(row['id'] as String, row))
            .toList());
  }

  Future<void> createNotification({
    required String title,
    required String message,
    required String type,
    String? supplyName,
    String? poCode,
  }) async {
    // Before creating, enforce user preferences
    final typeLower = type.toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final invEnabled = prefs.getBool(_kInventoryPref) ?? true;
    final apprEnabled = prefs.getBool(_kApprovalPref) ?? true;

    final isInventoryType = typeLower == 'low_stock' ||
        typeLower == 'out_of_stock' ||
        typeLower == 'in_stock' ||
        typeLower == 'expired' ||
        typeLower == 'expiring';
    final isApprovalType = typeLower.startsWith('po_');

    if ((isInventoryType && !invEnabled) || (isApprovalType && !apprEnabled)) {
      return; // Respect preferences: do not create notification
    }

    await _supabase.from('notifications').insert({
      'title': title,
      'message': message,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'type': type,
      'is_read': false,
      if (supplyName != null) 'supply_name': supplyName,
      if (poCode != null) 'po_code': poCode,
    });
  }

  // Inventory stock alert methods
  Future<void> createLowStockNotification(
      String supplyName, int currentStock) async {
    await createNotification(
      title: 'Low Stock Alert',
      message: '$supplyName is running low',
      type: 'low_stock',
      supplyName: supplyName,
    );
  }

  Future<void> createOutOfStockNotification(String supplyName) async {
    await createNotification(
      title: 'Out of Stock Alert',
      message: '$supplyName is now out of stock',
      type: 'out_of_stock',
      supplyName: supplyName,
    );
  }

  Future<void> createExpiringNotification(
      String supplyName, int daysUntilExpiry) async {
    await createNotification(
      title: 'Expiring Soon',
      message: '$supplyName expires in $daysUntilExpiry days',
      type: 'expiring',
      supplyName: supplyName,
    );
  }

  Future<void> createExpiredNotification(String supplyName) async {
    await createNotification(
      title: 'Expired Item',
      message: '$supplyName has expired',
      type: 'expired',
      supplyName: supplyName,
    );
  }

  Future<void> createInStockNotification(
      String supplyName, int newStock) async {
    await createNotification(
      title: 'Restocked',
      message: '$supplyName is back in stock',
      type: 'in_stock',
      supplyName: supplyName,
    );
  }

  // PO notifications
  Future<void> createPOWaitingApprovalNotification(String poCode) async {
    await createNotification(
      title: 'Purchase Order',
      message: '$poCode is waiting for approval',
      type: 'po_waiting',
      poCode: poCode,
    );
  }

  Future<void> createPORejectedNotification(String poCode) async {
    await createNotification(
      title: 'Purchase Order',
      message: 'Admin rejected $poCode',
      type: 'po_rejected',
      poCode: poCode,
    );
  }

  Future<void> createPOApprovedNotification(String poCode) async {
    await createNotification(
      title: 'Purchase Order',
      message: 'Admin approved $poCode',
      type: 'po_approved',
      poCode: poCode,
    );
  }

  Future<void> markAsRead(String id) async {
    await _supabase.from('notifications').update({
      'is_read': true,
    }).eq('id', id);
  }

  Future<void> markAllAsRead() async {
    try {
      print('Marking all notifications as read...');
      final result = await _supabase.from('notifications').update({
        'is_read': true,
      }).eq('is_read', false);
      print('Mark all as read result: $result');
    } catch (e) {
      print('Error in markAllAsRead: $e');
      rethrow;
    }
  }

  Future<void> deleteNotification(String id) async {
    await _supabase.from('notifications').delete().eq('id', id);
  }

  Future<void> clearAll() async {
    await _supabase.from('notifications').delete().neq('id', '');
  }

  // Delete older notifications so only the most recent [max] remain
  Future<void> enforceMaxNotifications({int max = 20}) async {
    final data = await _supabase
        .from('notifications')
        .select('id')
        .order('created_at', ascending: false);

    if (data.length <= max) return;

    final olderIds = data.skip(max).map((row) => row['id'] as String).toList();
    if (olderIds.isNotEmpty) {
      await _supabase.from('notifications').delete().inFilter('id', olderIds);
    }
  }

  String getRelativeTime(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    print(
        'Relative time calculation: now=$now, createdAt=$createdAt, difference=${difference.inSeconds}s');

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}m ago';
    } else {
      return '${(difference.inDays / 365).floor()}y ago';
    }
  }

  // Helper method to check if stock level triggers a notification
  Future<void> checkStockLevelNotification(
      String supplyName, int newStock, int previousStock) async {
    // Check for out of stock (from any stock to 0)
    if (newStock == 0 && previousStock > 0) {
      await createOutOfStockNotification(supplyName);
      return;
    }

    // Check for restocked (from 0 to any positive stock)
    if (newStock > 0 && previousStock == 0) {
      await createInStockNotification(supplyName, newStock);
      return;
    }

    // Check for low stock (from >2 to 1-2)
    if (newStock <= 2 && newStock > 0 && previousStock > 2) {
      await createLowStockNotification(supplyName, newStock);
      return;
    }

    // Check for back to normal stock (from 1-2 to 3+)
    if (newStock >= 3 && previousStock <= 2 && previousStock > 0) {
      await createInStockNotification(supplyName, newStock);
      return;
    }
  }

  // Helper method to check expiry notifications
  Future<void> checkExpiryNotification(
      String supplyName, String? expiryDate, bool noExpiry) async {
    if (noExpiry || expiryDate == null || expiryDate.isEmpty) {
      return; // No expiry to check
    }

    final expiry = DateTime.tryParse(expiryDate);
    if (expiry == null) return;

    final now = DateTime.now();
    final remaining = expiry.difference(now);
    final daysUntilExpiry = remaining.inDays;

    // Check if expired
    if (expiry.isBefore(now)) {
      await createExpiredNotification(supplyName);
      return;
    }

    // Only notify at specific thresholds: 30 days, 7 days, and 24 hours
    if (daysUntilExpiry == 30) {
      await createExpiringNotification(supplyName, 30);
      return;
    }

    if (daysUntilExpiry == 7) {
      await createExpiringNotification(supplyName, 7);
      return;
    }

    // Within the last 24 hours (but not expired yet)
    if (daysUntilExpiry == 0 &&
        remaining.inHours > 0 &&
        remaining.inHours <= 24) {
      await createNotification(
        title: 'Expiring Soon',
        message: '$supplyName expires in 24 hours',
        type: 'expiring',
        supplyName: supplyName,
      );
      return;
    }
  }
}
