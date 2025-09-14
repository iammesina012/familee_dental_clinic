import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItem {
  final String id;
  final String name;
  final String imageUrl;
  final String category;
  final double cost;
  final int stock;
  final String unit;
  final String supplier;
  final String brand;
  final String? expiry;
  final bool noExpiry;
  final bool archived;

  InventoryItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.category,
    required this.cost,
    required this.stock,
    required this.unit,
    required this.supplier,
    required this.brand,
    this.expiry,
    required this.noExpiry,
    required this.archived,
  });
}

class Brand {
  final String id;
  final String name;
  final DateTime createdAt;

  Brand({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdAt': createdAt,
    };
  }

  factory Brand.fromMap(String id, Map<String, dynamic> map) {
    return Brand(
      id: id,
      name: map['name'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

class Supplier {
  final String id;
  final String name;
  final DateTime createdAt;

  Supplier({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdAt': createdAt,
    };
  }

  factory Supplier.fromMap(String id, Map<String, dynamic> map) {
    return Supplier(
      id: id,
      name: map['name'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

class GroupedInventoryItem {
  final String productKey; // name + brand combination
  final InventoryItem mainItem; // The item with earliest expiry
  final List<InventoryItem> variants; // All other items with same name + brand
  final int totalStock; // Total stock across all variants

  GroupedInventoryItem({
    required this.productKey,
    required this.mainItem,
    required this.variants,
    required this.totalStock,
  });

  // Get all items including main item
  List<InventoryItem> getAllItems() {
    return [mainItem, ...variants];
  }

  // Get status based on main item (earliest expiring)
  String getStatus() {
    if (mainItem.archived) return "Archived";

    // Check expiry status FIRST - expired items should show as "Expired" regardless of stock
    if (!mainItem.noExpiry &&
        mainItem.expiry != null &&
        mainItem.expiry!.isNotEmpty) {
      final expiryDate =
          DateTime.tryParse(mainItem.expiry!.replaceAll('/', '-'));
      if (expiryDate != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dateOnly =
            DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

        if (dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today))
          return "Expired";

        final daysUntilExpiry = dateOnly.difference(today).inDays;
        if (daysUntilExpiry <= 30) return "Expiring";
      }
    }

    // Determine stock status using TOTAL stock across batches (only if not expired/expiring)
    if (totalStock == 0) return "Out of Stock";

    // Low stock threshold based on total stock
    if (totalStock <= 2) return "Low Stock";
    return "In Stock";
  }

  // Determine if a batch is expired (treat noExpiry as not expired)
  bool _isExpired(InventoryItem item) {
    if (item.noExpiry || item.expiry == null || item.expiry!.isEmpty) {
      return false;
    }
    final dt = DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
    if (dt == null) return false;
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    return dt.isBefore(todayDateOnly) || dt.isAtSameMomentAs(todayDateOnly);
  }

  // Total stock excluding expired batches
  int get nonExpiredTotalStock {
    return getAllItems()
        .where((it) => !_isExpired(it))
        .fold(0, (sum, it) => sum + it.stock);
  }

  // Whether all batches in this group are expired (or zero non-expired stock)
  bool get allBatchesExpired {
    return nonExpiredTotalStock == 0;
  }
}
