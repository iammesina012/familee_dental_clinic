import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';

class InventoryController {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream to get all supplies ordered by name, with optional archived filter
  Stream<List<InventoryItem>> getSuppliesStream({bool? archived}) {
    return _supabase.from('supplies').stream(primaryKey: ['id']).map((data) {
      List<InventoryItem> items = data.map((row) {
        return InventoryItem(
          id: row['id'] as String,
          name: row['name'] ?? '',
          imageUrl: row['image_url'] ?? '',
          category: row['category'] ?? '',
          cost: (row['cost'] ?? 0).toDouble(),
          stock: (row['stock'] ?? 0) as int,
          unit: row['unit'] ?? '',
          supplier: row['supplier'] ?? '',
          brand: row['brand'] ?? '',
          expiry: row['expiry'],
          noExpiry: row['no_expiry'] ?? false,
          archived: row['archived'] ?? false,
        );
      }).toList();

      // Apply archived filter
      if (archived != null) {
        if (archived == true) {
          items = items.where((item) => item.archived == true).toList();
        } else {
          items = items.where((item) => item.archived != true).toList();
        }
      }

      // Sort by name
      items
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return items;
    });
  }

  // New method to get grouped supplies for main inventory display
  Stream<List<GroupedInventoryItem>> getGroupedSuppliesStream(
      {bool? archived}) {
    return getSuppliesStream(archived: archived).map((items) {
      // Keep ALL items (including expired ones) for proper status display
      // The GroupedInventoryItem.getStatus() method will handle showing "Expired" status
      return _groupItems(items);
    });
  }

  // Group items by name + brand, separating expired and non-expired batches
  List<GroupedInventoryItem> _groupItems(List<InventoryItem> items) {
    final Map<String, List<InventoryItem>> grouped = {};

    // Group items by name + category (normalize to avoid case/whitespace mismatches)
    for (final item in items) {
      final nameKey = (item.name).trim().toLowerCase();
      final categoryKey = (item.category).trim().toLowerCase();
      final key = '${nameKey}_${categoryKey}';
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(item);
    }

    // Create GroupedInventoryItem for each group
    final List<GroupedInventoryItem> result = [];

    for (final entry in grouped.entries) {
      final items = entry.value;

      // Separate expired and non-expired items
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final nonExpiredItems = items.where((item) {
        if (item.noExpiry || item.expiry == null || item.expiry!.isEmpty) {
          return true;
        }
        final expiryDate = DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
        if (expiryDate == null) return true;
        final dateOnly =
            DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
        return !(dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today));
      }).toList();

      // Create groups for non-expired items (including placeholders with 0 stock)
      if (nonExpiredItems.isNotEmpty) {
        // Sort by expiry date (earliest first)
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

        // Find main item - prefer items with stock > 0, but include placeholders (stock = 0, no expiry)
        final mainItem = nonExpiredItems.firstWhere(
          (it) => it.stock > 0,
          orElse: () => nonExpiredItems.firstWhere(
            (it) => it.stock == 0 && it.noExpiry, // Placeholder items
            orElse: () => nonExpiredItems.first,
          ),
        );
        final variants =
            nonExpiredItems.where((it) => it.id != mainItem.id).toList();
        final totalStock =
            nonExpiredItems.fold(0, (sum, item) => sum + item.stock);

        result.add(GroupedInventoryItem(
          productKey: entry.key,
          mainItem: mainItem,
          variants: variants,
          totalStock: totalStock,
        ));
      }
    }

    return result;
  }

  // Get all variants for a specific product (for view supply page)
  Stream<List<InventoryItem>> getProductVariants(String productKey) {
    return getSuppliesStream().map((items) {
      return items.where((item) {
        final key =
            '${item.name.trim().toLowerCase()}_${item.category.trim().toLowerCase()}';
        return key == productKey;
      }).toList();
    });
  }

  // Filtering, searching, and sorting logic
  List<InventoryItem> filterAndSortItems({
    required List<InventoryItem> items,
    required String selectedCategory,
    required String searchText,
    required String? selectedSort,
  }) {
    final filtered = items
        .where((item) =>
            item.category == selectedCategory &&
            (searchText.isEmpty ||
                item.name.toLowerCase().contains(searchText.toLowerCase())))
        .toList();
    return sortItems(filtered, selectedSort);
  }

  // New method for filtering and sorting grouped items
  List<GroupedInventoryItem> filterAndSortGroupedItems({
    required List<GroupedInventoryItem> items,
    required String selectedCategory,
    required String searchText,
    required String? selectedSort,
    Map<String, dynamic>? filters,
  }) {
    final filtered = items.where((item) {
      // Keep all items - let the status display handle expired items properly

      // Category filter - include the group if ANY variant matches the category
      if (selectedCategory.isNotEmpty) {
        final matchesCategory = item
            .getAllItems()
            .any((variant) => variant.category == selectedCategory);
        if (!matchesCategory) return false;
      }

      // Search text filter
      if (searchText.isNotEmpty &&
          !item.mainItem.name
              .toLowerCase()
              .contains(searchText.toLowerCase())) {
        return false;
      }

      // Advanced filters
      if (filters != null) {
        // Brand filter
        if (filters['brands'] != null &&
            (filters['brands'] as List).isNotEmpty &&
            !(filters['brands'] as List).contains(item.mainItem.brand)) {
          return false;
        }

        // Supplier filter
        if (filters['suppliers'] != null &&
            (filters['suppliers'] as List).isNotEmpty &&
            !(filters['suppliers'] as List).contains(item.mainItem.supplier)) {
          return false;
        }

        // Stock status filter
        if (filters['stockStatus'] != null &&
            (filters['stockStatus'] as List).isNotEmpty) {
          final String status = _getItemStatus(item.mainItem);
          if (!(filters['stockStatus'] as List).contains(status)) {
            return false;
          }
        }

        // Expiry filter (Inventory only): ignore 'Expired' since expired items live on a separate page
        if (filters['expiry'] != null &&
            (filters['expiry'] as List).isNotEmpty) {
          final List<dynamic> expirySelections =
              List<dynamic>.from(filters['expiry'] as List);
          // Remove any 'Expired' entries if present
          expirySelections.removeWhere((e) => e?.toString() == 'Expired');
          if (expirySelections.isNotEmpty) {
            final expiryStatus = getExpiryStatus(item.mainItem);
            if (!expirySelections.contains(expiryStatus)) {
              return false;
            }
          }
        }

        // Unit filter
        if (filters['unit'] != null &&
            filters['unit'].toString().isNotEmpty &&
            item.mainItem.unit != filters['unit']) {
          return false;
        }

        // Cost range filter
        if (filters['minCost'] != null &&
            filters['minCost'].toString().isNotEmpty) {
          final minCost = double.tryParse(filters['minCost'].toString());
          if (minCost != null && item.mainItem.cost < minCost) {
            return false;
          }
        }

        if (filters['maxCost'] != null &&
            filters['maxCost'].toString().isNotEmpty) {
          final maxCost = double.tryParse(filters['maxCost'].toString());
          if (maxCost != null && item.mainItem.cost > maxCost) {
            return false;
          }
        }
      }

      return true;
    }).toList();

    return sortGroupedItems(filtered, selectedSort);
  }

  // Sorting logic for grouped items
  List<GroupedInventoryItem> sortGroupedItems(
      List<GroupedInventoryItem> items, String? selectedSort) {
    // Early return if no items or no sort selected
    if (items.isEmpty || selectedSort == null) return items;

    // Limit the number of items to sort to prevent performance issues
    final itemsToSort = items.length > 1000 ? items.take(1000).toList() : items;
    final sorted = List<GroupedInventoryItem>.from(itemsToSort);
    switch (selectedSort) {
      case "Name (A → Z)":
        sorted.sort((a, b) => a.mainItem.name
            .toLowerCase()
            .compareTo(b.mainItem.name.toLowerCase()));
        break;
      case "Name (Z → A)":
        sorted.sort((a, b) => b.mainItem.name
            .toLowerCase()
            .compareTo(a.mainItem.name.toLowerCase()));
        break;
      case "Quantity (Low → High)":
        sorted.sort((a, b) => a.mainItem.stock.compareTo(b.mainItem.stock));
        break;
      case "Quantity (High → Low)":
        sorted.sort((a, b) => b.mainItem.stock.compareTo(a.mainItem.stock));
        break;
      case "Status (Low Stock → In Stock)":
        sorted.sort((a, b) =>
            _statusOrder(a.mainItem).compareTo(_statusOrder(b.mainItem)));
        break;
      case "Status (In Stock → Low Stock)":
        sorted.sort((a, b) =>
            _statusOrder(b.mainItem).compareTo(_statusOrder(a.mainItem)));
        break;
      case "Expiry Date (Soonest First)":
        sorted.sort((a, b) =>
            _expiryOrder(a.mainItem).compareTo(_expiryOrder(b.mainItem)));
        break;
      case "Expiry Date (Latest First)":
        sorted.sort((a, b) =>
            _expiryOrder(b.mainItem).compareTo(_expiryOrder(a.mainItem)));
        break;
    }
    return sorted;
  }

  // Sorting logic
  List<InventoryItem> sortItems(
      List<InventoryItem> items, String? selectedSort) {
    // Early return if no items or no sort selected
    if (items.isEmpty || selectedSort == null) return items;

    // Limit the number of items to sort to prevent performance issues
    final itemsToSort = items.length > 1000 ? items.take(1000).toList() : items;
    final sorted = List<InventoryItem>.from(itemsToSort);
    switch (selectedSort) {
      case "Name (A → Z)":
        sorted.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case "Name (Z → A)":
        sorted.sort(
            (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case "Quantity (Low → High)":
        sorted.sort((a, b) => a.stock.compareTo(b.stock));
        break;
      case "Quantity (High → Low)":
        sorted.sort((a, b) => b.stock.compareTo(a.stock));
        break;
      case "Status (Low Stock → In Stock)":
        sorted.sort((a, b) => _statusOrder(a).compareTo(_statusOrder(b)));
        break;
      case "Status (In Stock → Low Stock)":
        sorted.sort((a, b) => _statusOrder(b).compareTo(_statusOrder(a)));
        break;
      case "Expiry Date (Soonest First)":
        sorted.sort((a, b) => _expiryOrder(a).compareTo(_expiryOrder(b)));
        break;
      case "Expiry Date (Latest First)":
        sorted.sort((a, b) => _expiryOrder(b).compareTo(_expiryOrder(a)));
        break;
    }
    return sorted;
  }

  int _statusOrder(InventoryItem item) {
    if (item.stock == 0) return 2;
    if (item.stock <= 2) return 0;
    return 1;
  }

  int _expiryOrder(InventoryItem item) {
    // Cache the result to avoid repeated calculations
    if (item.noExpiry == true) return 999999;
    if (item.expiry == null || item.expiry!.isEmpty) return 999999;

    try {
      final date = DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
      return date != null ? date.millisecondsSinceEpoch : 999999;
    } catch (e) {
      // Handle any parsing errors gracefully
      return 999999;
    }
  }

  // Helper method to get item status for filtering
  String _getItemStatus(InventoryItem item) {
    // Note: Expired status is now handled by the dedicated Expired Supply page
    // Main inventory system no longer shows expired status

    // Check stock status only
    if (item.stock == 0) return "Out of Stock";
    if (item.stock <= 2) return "Low Stock";
    return "In Stock";
  }

  // Helper method to get expiry status for filtering
  String getExpiryStatus(InventoryItem item) {
    // If item has no expiry flag, return "No Expiry"
    if (item.noExpiry) return "No Expiry";

    // If item has no expiry date, return "No Expiry"
    if (item.expiry == null || item.expiry!.isEmpty) return "No Expiry";

    // Try to parse the expiry date (support both / and - formats)
    final expiryDate = DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
    if (expiryDate == null) return "No Expiry";

    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final expiryDateOnly =
        DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

    // Check if expired (using same logic as grouping)
    if (expiryDateOnly.isBefore(todayDateOnly) ||
        expiryDateOnly.isAtSameMomentAs(todayDateOnly)) return "Expired";

    final daysUntilExpiry = expiryDateOnly.difference(todayDateOnly).inDays;

    // Check if expiring soon (within 30 days)
    if (daysUntilExpiry <= 30) return "Expiring";

    // If not expiring soon and not expired, return "Future Expiry" (items with future expiry should not be in "No Expiry" filter)
    return "Future Expiry";
  }

  // One-time cleanup: delete zero-stock duplicate batches when another batch has stock
  Future<void> cleanupZeroStockDuplicates() async {
    try {
      final response = await _supabase.from('supplies').select('*');
      final supplies = response;
      if (supplies.isEmpty) return;

      // Group by name + brand
      final Map<String, List<Map<String, dynamic>>> groups = {};
      for (final supply in supplies) {
        final key = '${supply['name'] ?? ''}_${supply['brand'] ?? ''}';
        groups.putIfAbsent(key, () => []);
        groups[key]!.add(supply);
      }

      for (final entry in groups.entries) {
        final groupSupplies = entry.value;

        final bool anyHasStock = groupSupplies.any((supply) {
          final int stock = (supply['stock'] ?? 0) as int;
          final bool archived = (supply['archived'] ?? false) as bool;
          return !archived && stock > 0;
        });

        // Only clean up if there are items with stock > 0 AND there are duplicate 0-stock items
        if (!anyHasStock) continue; // keep zero-stock if it's the only batch

        // Count 0-stock items that are NOT placeholders
        final zeroStockItems = groupSupplies.where((supply) {
          final int stock = (supply['stock'] ?? 0) as int;
          final bool archived = (supply['archived'] ?? false) as bool;
          final bool noExpiry = (supply['no_expiry'] ?? false) as bool;
          return !archived && stock == 0 && !noExpiry; // Not placeholders
        }).toList();

        // Only delete if there are multiple 0-stock non-placeholder items
        if (zeroStockItems.length > 1) {
          for (final supply in zeroStockItems.skip(1)) {
            // Keep one, delete the rest
            await _supabase.from('supplies').delete().eq('id', supply['id']);
          }
        }
      }
    } catch (_) {
      // Swallow errors; cleanup is best-effort
    }
  }
}
