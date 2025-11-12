import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/shared/services/connectivity_service.dart';

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
  // Singleton pattern to ensure cache and active controllers are shared
  static final NotificationsController _instance =
      NotificationsController._internal();
  factory NotificationsController() => _instance;
  NotificationsController._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  // Local preferences keys
  static const String _kInventoryPref = 'settings.notify_inventory';
  static const String _kApprovalPref = 'settings.notify_approval';
  static const String _kCacheKey = 'notifications_cache_v1';

  List<AppNotification>? _cachedNotifications;

  // Track active stream controllers to emit cache updates immediately
  final Set<StreamController<List<AppNotification>>> _activeControllers = {};

  List<AppNotification> get cachedNotifications => _cachedNotifications != null
      ? List<AppNotification>.from(_cachedNotifications!)
      : const [];

  // Emit current cache to all active stream controllers
  void _emitToAllActiveControllers() {
    if (_cachedNotifications != null) {
      final notifications = List<AppNotification>.from(_cachedNotifications!);
      print(
          '[NOTIFICATIONS] Emitting to ${_activeControllers.length} active controllers, ${notifications.length} notifications');
      for (final controller in _activeControllers) {
        if (!controller.isClosed) {
          controller.add(notifications);
        } else {
          print('[NOTIFICATIONS] Skipping closed controller');
        }
      }
    } else {
      print('[NOTIFICATIONS] Cache is null, cannot emit');
    }
  }

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
    final controller = StreamController<List<AppNotification>>.broadcast();
    StreamSubscription<List<Map<String, dynamic>>>? subscription;

    void safeAdd(List<AppNotification> notifications) {
      if (!controller.isClosed) {
        controller.add(List<AppNotification>.from(notifications));
      }
    }

    void emitCached({bool forceEmpty = false}) {
      if (_cachedNotifications != null) {
        safeAdd(_cachedNotifications!);
      } else if (forceEmpty) {
        safeAdd(const []);
      }
    }

    Future<void> persist(List<AppNotification> notifications) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final serializable = notifications
            .map((n) => {
                  'id': n.id,
                  'data': n.toMap(),
                })
            .toList();
        await prefs.setString(_kCacheKey, jsonEncode(serializable));
      } catch (_) {
        // Ignore cache persistence errors
      }
    }

    void start() {
      subscription ??= _supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(max)
          .listen(
            (data) async {
              try {
                final notifications = data
                    .map((row) =>
                        AppNotification.fromMap(row['id'] as String, row))
                    .toList(growable: false);
                _cachedNotifications = notifications;
                safeAdd(notifications);
                unawaited(persist(notifications));
              } catch (_) {
                emitCached(forceEmpty: true);
              }
            },
            onError: (error) {
              emitCached(forceEmpty: true);
            },
          );
    }

    controller
      ..onListen = () {
        _activeControllers.add(controller);
        // Emit cached data immediately when stream starts listening
        emitCached();
        start();
      }
      ..onCancel = () async {
        _activeControllers.remove(controller);
        await subscription?.cancel();
        subscription = null;
      };

    return controller.stream;
  }

  Future<List<AppNotification>> preloadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw == null || raw.isEmpty) {
        _cachedNotifications = null;
        return const [];
      }
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final restored = decoded.map((entry) {
        final map = entry as Map<String, dynamic>;
        final id = map['id'] as String? ?? '';
        final data =
            Map<String, dynamic>.from(map['data'] as Map<String, dynamic>);
        return AppNotification.fromMap(id, data);
      }).toList(growable: false);
      _cachedNotifications = restored;
      return List<AppNotification>.from(restored);
    } catch (_) {
      _cachedNotifications = null;
      return const [];
    }
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

    final response = await _supabase
        .from('notifications')
        .insert({
          'title': title,
          'message': message,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'type': type,
          'is_read': false,
          if (supplyName != null) 'supply_name': supplyName,
          if (poCode != null) 'po_code': poCode,
        })
        .select()
        .single();

    // Create the notification object from the response
    final newNotification = AppNotification.fromMap(
      response['id'] as String,
      response,
    );

    // Add to cache immediately so badge updates right away
    if (_cachedNotifications != null) {
      _cachedNotifications = [newNotification, ..._cachedNotifications!];
      // Keep only the most recent 20 to match the stream limit
      if (_cachedNotifications!.length > 20) {
        _cachedNotifications = _cachedNotifications!.take(20).toList();
      }
      // Sort by created_at descending to ensure proper order
      _cachedNotifications!.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      print(
          '[NOTIFICATIONS] Added new notification to cache. Total: ${_cachedNotifications!.length}, Unread: ${_cachedNotifications!.where((n) => !n.isRead).length}');
    } else {
      // If cache is null, fetch latest notifications
      try {
        final latest = await _supabase
            .from('notifications')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        _cachedNotifications = latest
            .map((row) => AppNotification.fromMap(row['id'] as String, row))
            .toList();
        print(
            '[NOTIFICATIONS] Fetched ${_cachedNotifications!.length} notifications from database');
      } catch (e) {
        // Fallback: just use the new notification
        _cachedNotifications = [newNotification];
        print('[NOTIFICATIONS] Using fallback cache with 1 notification');
      }
    }

    // Emit updated cache to all active streams immediately
    print('[NOTIFICATIONS] About to emit to active controllers...');
    _emitToAllActiveControllers();

    // Send push notification
    await _sendPushNotification(title, message);
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

    // Immediately update cache to reflect the change
    if (_cachedNotifications != null) {
      _cachedNotifications = _cachedNotifications!.map((notification) {
        if (notification.id == id) {
          return AppNotification(
            id: notification.id,
            title: notification.title,
            message: notification.message,
            createdAt: notification.createdAt,
            type: notification.type,
            isRead: true, // Update to read
            supplyName: notification.supplyName,
            poCode: notification.poCode,
          );
        }
        return notification;
      }).toList();
    }

    // Emit updated cache to all active streams immediately
    _emitToAllActiveControllers();
  }

  Future<void> markAllAsRead() async {
    try {
      print('Marking all notifications as read...');
      final result = await _supabase.from('notifications').update({
        'is_read': true,
      }).eq('is_read', false);
      print('Mark all as read result: $result');

      // Immediately update cache to reflect all notifications as read
      if (_cachedNotifications != null) {
        _cachedNotifications = _cachedNotifications!.map((notification) {
          return AppNotification(
            id: notification.id,
            title: notification.title,
            message: notification.message,
            createdAt: notification.createdAt,
            type: notification.type,
            isRead: true, // Mark all as read
            supplyName: notification.supplyName,
            poCode: notification.poCode,
          );
        }).toList();
      }

      // Emit updated cache to all active streams immediately
      _emitToAllActiveControllers();
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
    bool hasConnection = true;
    try {
      hasConnection = await ConnectivityService().hasInternetConnection();
    } catch (_) {
      hasConnection = true;
    }
    if (!hasConnection) return;

    try {
      final data = await _supabase
          .from('notifications')
          .select('id')
          .order('created_at', ascending: false);

      if (data.length <= max) return;

      final olderIds =
          data.skip(max).map((row) => row['id'] as String).toList();
      if (olderIds.isNotEmpty) {
        await _supabase.from('notifications').delete().inFilter('id', olderIds);
      }
    } catch (_) {
      // Ignore cleanup errors when offline; will retry next time we're online.
    }
  }

  String getRelativeTime(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    print(
        'Relative time calculation: now=$now, createdAt=$createdAt, difference=${difference.inSeconds}s');

    // Handle negative time (future timestamps due to timezone issues)
    if (difference.isNegative) {
      return 'Just now';
    }

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

  // Helper method to calculate status for a supply using the same logic as UI
  // This reuses GroupedInventoryItem.getStatus() logic
  // Returns (status, totalStock) tuple
  Future<(String?, int)> _getSupplyStatus(String supplyName,
      {int? overrideStock, String? overrideId}) async {
    try {
      // Fetch all batches for this supply
      final batches = await _supabase
          .from('supplies')
          .select('*')
          .eq('name', supplyName)
          .eq('archived', false);

      if (batches.isEmpty) return (null, 0);

      // Convert to InventoryItem list
      final items = batches.map((row) {
        DateTime? createdAt;
        if (row['created_at'] != null) {
          try {
            createdAt = DateTime.parse(row['created_at'] as String);
          } catch (e) {
            createdAt = null;
          }
        }

        // Override stock if specified (for "before" calculation)
        int stock = (row['stock'] ?? 0) as int;
        if (overrideStock != null) {
          // If overrideId is provided, use it to find the specific batch
          if (overrideId != null && row['id'] == overrideId) {
            stock = overrideStock;
          }
          // If overrideId is null, try to find batch that matches current stock pattern
          // (This is a best-effort approach when batchId is not available)
          // Note: This might not be 100% accurate if multiple batches have the same stock
        }

        return InventoryItem(
          id: row['id'] as String,
          name: row['name'] ?? '',
          type: row['type'],
          imageUrl: row['image_url'] ?? '',
          category: row['category'] ?? '',
          cost: (row['cost'] ?? 0).toDouble(),
          stock: stock,
          lowStockBaseline: row['low_stock_baseline'] != null
              ? (row['low_stock_baseline'] as num).toInt()
              : null,
          unit: row['unit'] ?? '',
          packagingUnit: row['packaging_unit'],
          packagingContent: row['packaging_content'],
          packagingQuantity: row['packaging_quantity'],
          packagingContentQuantity: row['packaging_content_quantity'],
          supplier: row['supplier'] ?? '',
          brand: row['brand'] ?? '',
          expiry: row['expiry'],
          noExpiry: row['no_expiry'] ?? false,
          archived: row['archived'] ?? false,
          createdAt: createdAt,
        );
      }).toList();

      // Group items by name + category (same logic as InventoryController)
      final Map<String, List<InventoryItem>> grouped = {};
      for (final item in items) {
        final nameKey = item.name.trim().toLowerCase();
        final categoryKey = item.category.trim().toLowerCase();
        final key = '${nameKey}_${categoryKey}';
        if (!grouped.containsKey(key)) {
          grouped[key] = [];
        }
        grouped[key]!.add(item);
      }

      // Get the first group (should be the supply we're checking)
      if (grouped.isEmpty) return (null, 0);
      final groupItems = grouped.values.first;

      // Filter out expired items (same logic as UI)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final nonExpiredItems = groupItems.where((item) {
        if (item.noExpiry || item.expiry == null || item.expiry!.isEmpty) {
          return true;
        }
        final expiryDate = DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
        if (expiryDate == null) return true;
        final dateOnly =
            DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
        return !(dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today));
      }).toList();

      if (nonExpiredItems.isEmpty) return (null, 0);

      // Sort by expiry (earliest first)
      nonExpiredItems.sort((a, b) {
        if (a.noExpiry && b.noExpiry) return 0;
        if (a.noExpiry) return 1;
        if (b.noExpiry) return -1;
        final aExpiry = a.expiry != null
            ? DateTime.tryParse(a.expiry!.replaceAll('/', '-'))
            : null;
        final bExpiry = b.expiry != null
            ? DateTime.tryParse(b.expiry!.replaceAll('/', '-'))
            : null;
        if (aExpiry == null && bExpiry == null) return 0;
        if (aExpiry == null) return 1;
        if (bExpiry == null) return -1;
        return aExpiry.compareTo(bExpiry);
      });

      // Find main item
      final mainItem = nonExpiredItems.firstWhere(
        (it) => it.stock > 0,
        orElse: () => nonExpiredItems.firstWhere(
          (it) => it.stock == 0 && it.noExpiry,
          orElse: () => nonExpiredItems.first,
        ),
      );
      final variants =
          nonExpiredItems.where((it) => it.id != mainItem.id).toList();
      final totalStock =
          nonExpiredItems.fold(0, (sum, item) => sum + item.stock);
      final totalBaseline = nonExpiredItems.fold(
          0, (sum, item) => sum + (item.lowStockBaseline ?? item.stock));

      // Create GroupedInventoryItem and get status (same as UI)
      final groupedItem = GroupedInventoryItem(
        productKey: grouped.keys.first,
        mainItem: mainItem,
        variants: variants,
        totalStock: totalStock,
        totalBaseline: totalBaseline,
      );

      return (groupedItem.getStatus(), totalStock);
    } catch (e) {
      print('Error calculating supply status: $e');
      return (null, 0);
    }
  }

  // Helper method to check if stock level triggers a notification
  // Now uses status comparison instead of recomputing
  Future<void> checkStockLevelNotification(
      String supplyName, int newStock, int previousStock,
      {String? batchId}) async {
    try {
      // Get status BEFORE the change (using previousStock)
      final (statusBefore, _) = await _getSupplyStatus(
        supplyName,
        overrideStock: previousStock,
        overrideId: batchId,
      );

      // Get status AFTER the change (current state) - also get totalStock
      final (statusAfter, totalStock) = await _getSupplyStatus(supplyName);

      // If we couldn't calculate status, fall back to old method
      if (statusBefore == null || statusAfter == null) {
        print('[NOTIFICATIONS] Could not calculate status, using fallback');
        // Fallback to simple stock comparison
        if (newStock == 0 && previousStock > 0) {
          await createOutOfStockNotification(supplyName);
        } else if (newStock > 0 && previousStock == 0) {
          await createInStockNotification(supplyName, newStock);
        }
        return;
      }

      print(
          '[NOTIFICATIONS] Status change: $statusBefore -> $statusAfter for $supplyName');

      // Check status changes and create appropriate notifications
      // Out of Stock: from any status to "Out of Stock"
      if (statusAfter == "Out of Stock" && statusBefore != "Out of Stock") {
        await createOutOfStockNotification(supplyName);
        return;
      }

      // Restocked: from "Out of Stock" to any status with stock
      if (statusBefore == "Out of Stock" &&
          (statusAfter == "In Stock" ||
              statusAfter == "Low Stock" ||
              statusAfter == "Expiring")) {
        await createInStockNotification(supplyName, totalStock);
        return;
      }

      // Low Stock: from "In Stock" or "Expiring" to "Low Stock"
      if (statusAfter == "Low Stock" &&
          (statusBefore == "In Stock" || statusBefore == "Expiring")) {
        await createLowStockNotification(supplyName, totalStock);
        return;
      }

      // Back to In Stock: from "Low Stock" to "In Stock" or "Expiring"
      if ((statusAfter == "In Stock" || statusAfter == "Expiring") &&
          statusBefore == "Low Stock") {
        await createInStockNotification(supplyName, totalStock);
        return;
      }

      // No status change that requires notification
      print(
          '[NOTIFICATIONS] No notification needed: status unchanged or no relevant change');
    } catch (e) {
      print('Error checking stock level notification: $e');
      // Fallback to simple stock comparison if status calculation fails
      if (newStock == 0 && previousStock > 0) {
        await createOutOfStockNotification(supplyName);
      } else if (newStock > 0 && previousStock == 0) {
        await createInStockNotification(supplyName, newStock);
      }
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

  // Push sending skipped: keep in-app notifications only
  Future<void> _sendPushNotification(String title, String message) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      // No-op for now; relying on in-app notifications and Firebase Console tests
      print(
          'Push skipped (no Edge Function): $title - $message for user: ${user.id}');
    } catch (e) {
      print('Error (push skipped): $e');
    }
  }

  // Test function to send a test push notification
  Future<void> sendTestNotification() async {
    await createNotification(
      title: 'Test Notification',
      message: 'This is a test push notification from FamiLee Dental!',
      type: 'test',
    );
  }
}
