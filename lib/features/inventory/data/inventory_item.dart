class InventoryItem {
  final String id;
  final String name;
  final String? type;
  final String imageUrl;
  final String category;
  final double cost;
  final int stock;
  final int? lowStockBaseline;
  final String unit;
  final String? packagingUnit;
  final String? packagingContent;
  final int? packagingQuantity;
  final int? packagingContentQuantity;
  final String supplier;
  final String brand;
  final String? expiry;
  final bool noExpiry;
  final bool archived;
  final DateTime? createdAt;

  InventoryItem({
    required this.id,
    required this.name,
    this.type,
    required this.imageUrl,
    required this.category,
    required this.cost,
    required this.stock,
    this.lowStockBaseline,
    required this.unit,
    this.packagingUnit,
    this.packagingContent,
    this.packagingQuantity,
    this.packagingContentQuantity,
    required this.supplier,
    required this.brand,
    this.expiry,
    required this.noExpiry,
    required this.archived,
    this.createdAt,
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
      createdAt: DateTime.parse(map['created_at'] as String),
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
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class GroupedInventoryItem {
  final String productKey; // name + category combination
  final InventoryItem mainItem; // The item with earliest expiry
  final List<InventoryItem>
      variants; // All other items with same name + category
  final int totalStock; // Total stock across all variants
  final int totalBaseline;

  GroupedInventoryItem({
    required this.productKey,
    required this.mainItem,
    required this.variants,
    required this.totalStock,
    required this.totalBaseline,
  });

  // Helper function to calculate critical level (20% of stock, rounded)
  static int calculateCriticalLevel(int stockQuantity) {
    if (stockQuantity <= 0) return 0;
    // Calculate 20% of stock quantity and round it
    return (stockQuantity * 0.2).round();
  }

  // Check if stock is low based on dynamic 20% critical level
  static bool isLowStock(int currentStock, int totalStockQuantity) {
    if (currentStock == 0) return false; // Out of stock, not low stock
    final criticalLevel = calculateCriticalLevel(totalStockQuantity);
    return currentStock <= criticalLevel;
  }

  // Get all items including main item
  List<InventoryItem> getAllItems() {
    return [mainItem, ...variants];
  }

  // Get status based on main item (earliest expiring)
  String getStatus() {
    if (mainItem.archived) return "Archived";

    // 1) Expired overrides everything
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
      }
    }

    // 2) Out of Stock should beat Expiring when total stock is zero
    if (totalStock == 0) return "Out of Stock";

    // 3) Expiring applies only when there is stock
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

        final daysUntilExpiry = dateOnly.difference(today).inDays;
        if (daysUntilExpiry <= 30) return "Expiring";
      }
    }

    // Low stock threshold based purely on the dynamic 20% critical level
    if (totalStock == 0) {
      return "Out of Stock"; // This should already be handled above, but keeping for safety
    }

    final baseline = totalBaseline > 0
        ? totalBaseline
        : (mainItem.lowStockBaseline ?? totalStock);
    final criticalLevel = calculateCriticalLevel(baseline);

    if (totalStock <= criticalLevel) {
      return "Low Stock";
    }

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
