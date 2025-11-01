class InventoryItem {
  final String id;
  final String name;
  final String? type;
  final String imageUrl;
  final String category;
  final double cost;
  final int stock;
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

  InventoryItem({
    required this.id,
    required this.name,
    this.type,
    required this.imageUrl,
    required this.category,
    required this.cost,
    required this.stock,
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

  GroupedInventoryItem({
    required this.productKey,
    required this.mainItem,
    required this.variants,
    required this.totalStock,
  });

  // Helper function to calculate critical level (20% of stock, rounded)
  static int calculateCriticalLevel(int stockQuantity) {
    if (stockQuantity <= 0) return 0;
    // Calculate 20% of stock quantity and round it
    return (stockQuantity * 0.2).round();
  }

  // Check if stock is low based on dynamic 20% critical level
  // Note: The critical level is calculated based on the current stock quantity
  // For display purposes, we check if stock is at or below 20% of itself
  // This will only be true for very small stock quantities (e.g., stock 1 -> critical 0, stock 2 -> critical 0)
  // For larger stocks, we need to track previous stock quantity, but that's handled in notification logic
  static bool isLowStock(int currentStock, int totalStockQuantity) {
    if (currentStock == 0) return false; // Out of stock, not low stock
    final criticalLevel = calculateCriticalLevel(totalStockQuantity);
    // If critical level is 0 (for stock < 5), consider stock as low if stock is <= 1
    if (criticalLevel == 0 && currentStock <= 1) return true;
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

    // Low stock threshold based on dynamic 20% critical level
    // We use a tiered approach since we don't have previous stock in display
    // This ensures items show as "Low Stock" when they're at or below 20% threshold
    if (totalStock == 0) {
      return "Out of Stock"; // This should already be handled above, but keeping for safety
    }

    // Calculate critical level based on current stock
    final criticalLevel = calculateCriticalLevel(totalStock);

    // Primary check: If current stock is at or below its own 20% critical level
    // This works for stocks where 20% is meaningful (e.g., stock 5 -> critical 1, so stock <= 1 is low)
    if (criticalLevel > 0 && totalStock <= criticalLevel) {
      return "Low Stock";
    }

    // Tiered approach for cases where dynamic calculation doesn't work well
    // When stock is in certain ranges, use fixed thresholds based on typical scenarios
    // Stock 20 -> 4 (20% = 4): If stock <= 4, consider it low (might be reduced from 20)
    // Stock 10 -> 2 (20% = 2): If stock <= 2, consider it low (might be reduced from 10)
    // Stock 5 -> 1 (20% = 1): If stock <= 1, consider it low (might be reduced from 5)

    // Extended tiered threshold: stocks <= 5 are likely low (covers 20% of up to 25)
    if (totalStock <= 5) {
      return "Low Stock";
    }

    // For stocks > 5, use dynamic calculation which should work better
    // Stock 25 -> critical = 5, so stock 5 would be low
    // Stock 30 -> critical = 6, so stock 6 would be low
    // But we already covered <= 5 above, so this handles stocks 6-30 range
    if (totalStock > 5 && totalStock <= criticalLevel) {
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
