import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InventoryActivityController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get inventory activities stream
  Stream<List<Map<String, dynamic>>> getInventoryActivitiesStream() {
    return _firestore
        .collection('activity_logs')
        .where('category', isEqualTo: 'Inventory')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Filter inventory activities by search query
  List<Map<String, dynamic>> filterInventoryActivities(
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
      final category = (metadata['category'] ?? '').toString().toLowerCase();
      final brand = (metadata['brand'] ?? '').toString().toLowerCase();
      final supplier = (metadata['supplier'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();

      return description.contains(query) ||
          userName.contains(query) ||
          itemName.contains(query) ||
          category.contains(query) ||
          brand.contains(query) ||
          supplier.contains(query);
    }).toList();
  }

  /// Filter inventory activities by date
  List<Map<String, dynamic>> filterInventoryActivitiesByDate(
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

  /// Delete inventory activity
  Future<void> deleteInventoryActivity(String activityId) async {
    await _firestore.collection('activity_logs').doc(activityId).delete();
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
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return; // Don't log if no user

      // Get current timestamp
      final DateTime now = DateTime.now();
      final String timeString = _formatTime(now);

      // Create activity data
      final Map<String, dynamic> activityData = {
        'userName': _getDisplayName(currentUser),
        'description': description,
        'date': now,
        'time': timeString,
        'category': category,
        'action': action,
        'userId': currentUser.uid,
        'userEmail': currentUser.email,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Save to Firebase
      await _firestore.collection('activity_logs').add(activityData);

      print('Activity logged: $action - $description'); // Debug log
    } catch (e) {
      // Don't throw errors - logging shouldn't break main functionality
      print('Failed to log activity: $e');
    }
  }

  /// Get user-friendly display name
  String _getDisplayName(User user) {
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
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

  /// Log inventory supply added
  Future<void> logInventorySupplyAdded({
    required String itemName,
    required String category,
    required int stock,
    required String unit,
    double? cost,
    String? brand,
    String? supplier,
    String? expiryDate,
    bool noExpiry = false,
  }) async {
    await _logActivity(
      action: 'inventory_supply_added',
      category: 'Inventory',
      description: 'Added $itemName',
      metadata: {
        'itemName': itemName,
        'category': category,
        'stock': stock,
        'unit': unit,
        'cost': cost,
        'brand': brand,
        'supplier': supplier,
        'expiryDate':
            noExpiry ? 'No expiry date' : (expiryDate ?? 'No expiry date'),
      },
    );
  }

  /// Log inventory supply edited
  Future<void> logInventorySupplyEdited({
    required String itemName,
    required String category,
    required int stock,
    required String unit,
    double? cost,
    String? brand,
    String? supplier,
    String? expiryDate,
    bool noExpiry = false,
    required Map<String, Map<String, dynamic>> fieldChanges,
  }) async {
    await _logActivity(
      action: 'inventory_supply_edited',
      category: 'Inventory',
      description: 'Edited $itemName',
      metadata: {
        'itemName': itemName,
        'category': category,
        'stock': stock,
        'unit': unit,
        'cost': cost,
        'brand': brand,
        'supplier': supplier,
        'expiryDate':
            noExpiry ? 'No expiry date' : (expiryDate ?? 'No expiry date'),
        'fieldChanges': fieldChanges,
      },
    );
  }

  /// Log inventory supply archived
  Future<void> logInventorySupplyArchived({
    required String itemName,
    required String category,
    required int stock,
    required String unit,
    double? cost,
    String? brand,
    String? supplier,
    String? expiryDate,
    bool noExpiry = false,
  }) async {
    await _logActivity(
      action: 'inventory_supply_archived',
      category: 'Inventory',
      description: 'Archived $itemName',
      metadata: {
        'itemName': itemName,
        'category': category,
        'stock': stock,
        'unit': unit,
        'cost': cost,
        'brand': brand,
        'supplier': supplier,
        'expiryDate':
            noExpiry ? 'No expiry date' : (expiryDate ?? 'No expiry date'),
      },
    );
  }

  /// Log inventory supply unarchived
  Future<void> logInventorySupplyUnarchived({
    required String itemName,
    required String category,
    required int stock,
    required String unit,
    double? cost,
    String? brand,
    String? supplier,
    String? expiryDate,
    bool noExpiry = false,
  }) async {
    await _logActivity(
      action: 'inventory_supply_unarchived',
      category: 'Inventory',
      description: 'Unarchived $itemName',
      metadata: {
        'itemName': itemName,
        'category': category,
        'stock': stock,
        'unit': unit,
        'cost': cost,
        'brand': brand,
        'supplier': supplier,
        'expiryDate':
            noExpiry ? 'No expiry date' : (expiryDate ?? 'No expiry date'),
      },
    );
  }

  /// Log inventory supply deleted
  Future<void> logInventorySupplyDeleted({
    required String itemName,
    required String category,
    required int stock,
    required String unit,
    double? cost,
    String? brand,
    String? supplier,
    String? expiryDate,
    bool noExpiry = false,
  }) async {
    await _logActivity(
      action: 'inventory_supply_deleted',
      category: 'Inventory',
      description: 'Deleted $itemName',
      metadata: {
        'itemName': itemName,
        'category': category,
        'stock': stock,
        'unit': unit,
        'cost': cost,
        'brand': brand,
        'supplier': supplier,
        'expiryDate':
            noExpiry ? 'No expiry date' : (expiryDate ?? 'No expiry date'),
      },
    );
  }

  /// Log expired supply disposed
  Future<void> logExpiredSupplyDisposed({
    required String itemName,
    required String category,
    required int stock,
    required String unit,
    double? cost,
    String? brand,
    String? supplier,
    String? expiryDate,
    bool noExpiry = false,
  }) async {
    await _logActivity(
      action: 'expired_supply_disposed',
      category: 'Inventory',
      description: 'Disposed $itemName',
      metadata: {
        'itemName': itemName,
        'category': category,
        'stock': stock,
        'unit': unit,
        'cost': cost,
        'brand': brand,
        'supplier': supplier,
        'expiryDate':
            noExpiry ? 'No expiry date' : (expiryDate ?? 'No expiry date'),
      },
    );
  }

  /// Log new category added
  Future<void> logCategoryAdded({
    required String categoryName,
  }) async {
    await _logActivity(
      action: 'category_added',
      category: 'Inventory',
      description: 'New Category: $categoryName',
      metadata: {},
    );
  }

  /// Log category updated
  Future<void> logCategoryUpdated({
    required String oldCategoryName,
    required String newCategoryName,
  }) async {
    await _logActivity(
      action: 'category_updated',
      category: 'Inventory',
      description: 'Edited Category: $newCategoryName',
      metadata: {
        'fieldChanges': {
          'Name': {
            'previous': oldCategoryName,
            'new': newCategoryName,
          },
        },
      },
    );
  }

  /// Log category deleted
  Future<void> logCategoryDeleted({
    required String categoryName,
  }) async {
    await _logActivity(
      action: 'category_deleted',
      category: 'Inventory',
      description: 'Deleted Category: $categoryName',
      metadata: {},
    );
  }

  /// Log new brand added
  Future<void> logBrandAdded({
    required String brandName,
  }) async {
    await _logActivity(
      action: 'brand_added',
      category: 'Inventory',
      description: 'New Brand: $brandName',
      metadata: {},
    );
  }

  /// Log brand updated
  Future<void> logBrandUpdated({
    required String oldBrandName,
    required String newBrandName,
  }) async {
    await _logActivity(
      action: 'brand_updated',
      category: 'Inventory',
      description: 'Edited Brand: $newBrandName',
      metadata: {
        'fieldChanges': {
          'Name': {
            'previous': oldBrandName,
            'new': newBrandName,
          },
        },
      },
    );
  }

  /// Log brand deleted
  Future<void> logBrandDeleted({
    required String brandName,
  }) async {
    await _logActivity(
      action: 'brand_deleted',
      category: 'Inventory',
      description: 'Deleted Brand: $brandName',
      metadata: {},
    );
  }

  /// Log new supplier added
  Future<void> logSupplierAdded({
    required String supplierName,
  }) async {
    await _logActivity(
      action: 'supplier_added',
      category: 'Inventory',
      description: 'New Supplier: $supplierName',
      metadata: {},
    );
  }

  /// Log supplier updated
  Future<void> logSupplierUpdated({
    required String oldSupplierName,
    required String newSupplierName,
  }) async {
    await _logActivity(
      action: 'supplier_updated',
      category: 'Inventory',
      description: 'Edited Supplier: $newSupplierName',
      metadata: {
        'fieldChanges': {
          'Name': {
            'previous': oldSupplierName,
            'new': newSupplierName,
          },
        },
      },
    );
  }

  /// Log supplier deleted
  Future<void> logSupplierDeleted({
    required String supplierName,
  }) async {
    await _logActivity(
      action: 'supplier_deleted',
      category: 'Inventory',
      description: 'Deleted Supplier: $supplierName',
      metadata: {},
    );
  }
}
