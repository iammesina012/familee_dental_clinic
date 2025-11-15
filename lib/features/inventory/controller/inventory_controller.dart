import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/shared/storage/hive_storage.dart';

class InventoryController {
  // Singleton pattern to ensure cache persists across widget rebuilds
  static final InventoryController _instance = InventoryController._internal();
  factory InventoryController() => _instance;
  InventoryController._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache for last known data (persists across widget rebuilds)
  List<InventoryItem>? _cachedSupplies;
  List<GroupedInventoryItem>? _cachedGroupedSupplies;

  // ===== HIVE PERSISTENT CACHE HELPERS =====

  // Load supplies from Hive
  Future<List<InventoryItem>?> _loadSuppliesFromHive() async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.inventorySuppliesBox);
      final jsonStr = box.get('supplies') as String?;
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        return decoded
            .map((item) => _inventoryItemFromMap(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
    return null;
  }

  // Save supplies to Hive
  Future<void> _saveSuppliesToHive(List<InventoryItem> supplies) async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.inventorySuppliesBox);
      final jsonList =
          supplies.map((item) => _inventoryItemToMap(item)).toList();
      await box.put('supplies', jsonEncode(jsonList));
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
  }

  // Load grouped supplies from Hive
  Future<List<GroupedInventoryItem>?> _loadGroupedSuppliesFromHive() async {
    try {
      final box =
          await HiveStorage.openBox(HiveStorage.inventoryGroupedSuppliesBox);
      final jsonStr = box.get('grouped_supplies') as String?;
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        return decoded
            .map((item) => _groupedItemFromMap(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
    return null;
  }

  // Save grouped supplies to Hive
  Future<void> _saveGroupedSuppliesToHive(
      List<GroupedInventoryItem> groupedSupplies) async {
    try {
      final box =
          await HiveStorage.openBox(HiveStorage.inventoryGroupedSuppliesBox);
      final jsonList =
          groupedSupplies.map((item) => _groupedItemToMap(item)).toList();
      await box.put('grouped_supplies', jsonEncode(jsonList));
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
  }

  // Helper to convert InventoryItem to Map for JSON
  Map<String, dynamic> _inventoryItemToMap(InventoryItem item) {
    return {
      'id': item.id,
      'name': item.name,
      'type': item.type,
      'imageUrl': item.imageUrl,
      'category': item.category,
      'cost': item.cost,
      'stock': item.stock,
      'lowStockBaseline': item.lowStockBaseline,
      'unit': item.unit,
      'packagingUnit': item.packagingUnit,
      'packagingContent': item.packagingContent,
      'packagingQuantity': item.packagingQuantity,
      'packagingContentQuantity': item.packagingContentQuantity,
      'supplier': item.supplier,
      'brand': item.brand,
      'expiry': item.expiry,
      'noExpiry': item.noExpiry,
      'archived': item.archived,
      'createdAt': item.createdAt?.toIso8601String(),
    };
  }

  // Helper to convert Map to InventoryItem from JSON
  InventoryItem _inventoryItemFromMap(Map<String, dynamic> map) {
    DateTime? createdAt;
    if (map['createdAt'] != null) {
      try {
        createdAt = DateTime.parse(map['createdAt'] as String);
      } catch (e) {
        createdAt = null;
      }
    }
    return InventoryItem(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String?,
      imageUrl: map['imageUrl'] as String? ?? '',
      category: map['category'] as String? ?? '',
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      lowStockBaseline: (map['lowStockBaseline'] as num?)?.toInt(),
      unit: map['unit'] as String? ?? '',
      packagingUnit: map['packagingUnit'] as String?,
      packagingContent: map['packagingContent'] as String?,
      packagingQuantity: (map['packagingQuantity'] as num?)?.toInt(),
      packagingContentQuantity:
          (map['packagingContentQuantity'] as num?)?.toInt(),
      supplier: map['supplier'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      expiry: map['expiry'] as String?,
      noExpiry: map['noExpiry'] as bool? ?? false,
      archived: map['archived'] as bool? ?? false,
      createdAt: createdAt,
    );
  }

  // Helper to convert GroupedInventoryItem to Map for JSON
  Map<String, dynamic> _groupedItemToMap(GroupedInventoryItem item) {
    return {
      'productKey': item.productKey,
      'mainItem': _inventoryItemToMap(item.mainItem),
      'variants': item.variants.map((v) => _inventoryItemToMap(v)).toList(),
      'totalStock': item.totalStock,
      'totalBaseline': item.totalBaseline,
    };
  }

  // Helper to convert Map to GroupedInventoryItem from JSON
  GroupedInventoryItem _groupedItemFromMap(Map<String, dynamic> map) {
    return GroupedInventoryItem(
      productKey: map['productKey'] as String,
      mainItem: _inventoryItemFromMap(map['mainItem'] as Map<String, dynamic>),
      variants: (map['variants'] as List<dynamic>)
          .map((v) => _inventoryItemFromMap(v as Map<String, dynamic>))
          .toList(),
      totalStock: (map['totalStock'] as num?)?.toInt() ?? 0,
      totalBaseline: (map['totalBaseline'] as num?)?.toInt() ?? 0,
    );
  }

  // Get cached supplies (for searching by name and type)
  List<InventoryItem>? getCachedSupplies() => _cachedSupplies;

  // Get cached grouped supplies (for getting grouped totals)
  List<GroupedInventoryItem>? getCachedGroupedSupplies() =>
      _cachedGroupedSupplies;

  // Stream to get all supplies ordered by name, with optional archived filter
  Stream<List<InventoryItem>> getSuppliesStream({bool? archived}) {
    final controller = StreamController<List<InventoryItem>>.broadcast();
    StreamSubscription<List<Map<String, dynamic>>>? supabaseSubscription;

    void safeAdd(List<InventoryItem> items) {
      if (!controller.isClosed) {
        controller.add(items);
      }
    }

    void emitFiltered(List<InventoryItem> items) {
      List<InventoryItem> filtered = items;
      if (archived != null) {
        if (archived == true) {
          filtered = filtered.where((item) => item.archived == true).toList();
        } else {
          filtered = filtered.where((item) => item.archived != true).toList();
        }
      }
      filtered
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      safeAdd(filtered);
    }

    void emitCachedOrEmpty({bool forceEmpty = false}) {
      if (_cachedSupplies != null) {
        emitFiltered(List<InventoryItem>.from(_cachedSupplies!));
      } else if (forceEmpty) {
        safeAdd([]);
      }
    }

    void startSubscription() {
      if (supabaseSubscription != null) return;
      try {
        supabaseSubscription =
            _supabase.from('supplies').stream(primaryKey: ['id']).listen(
          (data) {
            try {
              final List<InventoryItem> items = data.map((row) {
                DateTime? createdAt;
                if (row['created_at'] != null) {
                  try {
                    createdAt = DateTime.parse(row['created_at'] as String);
                  } catch (e) {
                    createdAt = null;
                  }
                }
                return InventoryItem(
                  id: row['id'] as String,
                  name: row['name'] ?? '',
                  type: row['type'],
                  imageUrl: row['image_url'] ?? '',
                  category: row['category'] ?? '',
                  cost: (row['cost'] ?? 0).toDouble(),
                  stock: (row['stock'] ?? 0) as int,
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

              emitFiltered(items);
              _cachedSupplies = List<InventoryItem>.from(items);
              unawaited(_saveSuppliesToHive(_cachedSupplies!)); // Save to Hive
            } catch (e) {
              emitCachedOrEmpty(forceEmpty: true);
            }
          },
          onError: (error) {
            emitCachedOrEmpty(forceEmpty: true);
          },
        );
      } catch (e) {
        emitCachedOrEmpty(forceEmpty: true);
      }
    }

    controller
      ..onListen = () async {
        // 1. Check in-memory cache first
        emitCachedOrEmpty();

        // 2. If in-memory cache is null, auto-load from Hive
        if (_cachedSupplies == null) {
          final hiveData = await _loadSuppliesFromHive();
          if (hiveData != null) {
            _cachedSupplies = hiveData; // Populate in-memory cache
            emitFiltered(
                List<InventoryItem>.from(hiveData)); // Emit immediately
          }
        }

        // 3. Subscribe to Supabase for updates
        startSubscription();
      }
      ..onCancel = () async {
        if (!controller.hasListener) {
          await supabaseSubscription?.cancel();
          supabaseSubscription = null;
        }
      };

    return controller.stream;
  }

  // New method to get grouped supplies for main inventory display
  Stream<List<GroupedInventoryItem>> getGroupedSuppliesStream(
      {bool? archived, bool? expired}) {
    final controller = StreamController<List<GroupedInventoryItem>>.broadcast();
    StreamSubscription<List<InventoryItem>>? suppliesSubscription;

    void safeAdd(List<GroupedInventoryItem> items) {
      if (!controller.isClosed) {
        controller.add(items);
      }
    }

    void emitCachedOrEmpty({bool forceEmpty = false}) {
      if (_cachedGroupedSupplies != null) {
        safeAdd(List<GroupedInventoryItem>.from(_cachedGroupedSupplies!));
      } else if (forceEmpty) {
        safeAdd([]);
      }
    }

    void handleItems(List<InventoryItem> items) {
      try {
        List<InventoryItem> filteredItems = items;
        if (expired == false) {
          filteredItems = items.where((item) {
            if (item.expiry == null) return true; // Keep items without expiry
            try {
              return DateTime.now()
                  .isBefore(DateTime.parse(item.expiry!.replaceAll('/', '-')));
            } catch (e) {
              return true; // Keep items with invalid expiry dates
            }
          }).toList();
        }
        final grouped = _groupItems(filteredItems);
        safeAdd(grouped);
        _cachedGroupedSupplies = List<GroupedInventoryItem>.from(grouped);
        unawaited(_saveGroupedSuppliesToHive(
            _cachedGroupedSupplies!)); // Save to Hive
      } catch (e) {
        emitCachedOrEmpty(forceEmpty: true);
      }
    }

    void startListening() {
      if (suppliesSubscription != null) return;
      suppliesSubscription = getSuppliesStream(archived: archived).listen(
        handleItems,
        onError: (error) {
          emitCachedOrEmpty(forceEmpty: true);
        },
      );
    }

    controller
      ..onListen = () async {
        // 1. Check in-memory cache first
        if (_cachedGroupedSupplies != null) {
          safeAdd(List<GroupedInventoryItem>.from(_cachedGroupedSupplies!));
        }

        // 2. If in-memory cache is null, auto-load from Hive
        if (_cachedGroupedSupplies == null) {
          final hiveData = await _loadGroupedSuppliesFromHive();
          if (hiveData != null) {
            _cachedGroupedSupplies = hiveData; // Populate in-memory cache
            safeAdd(
                List<GroupedInventoryItem>.from(hiveData)); // Emit immediately
          }
        }

        // 3. Subscribe to Supabase for updates
        startListening();
      }
      ..onCancel = () async {
        if (!controller.hasListener) {
          await suppliesSubscription?.cancel();
          suppliesSubscription = null;
        }
      };

    return controller.stream;
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
        // Use the threshold value directly (not summed) since all batches share the same threshold
        // Find the first non-null threshold value, or 0 if none exist
        int totalBaseline = 0;
        for (final item in nonExpiredItems) {
          if (item.lowStockBaseline != null && item.lowStockBaseline! > 0) {
            totalBaseline = item.lowStockBaseline!;
            break; // All batches have the same threshold, so we can use the first one
          }
        }

        result.add(GroupedInventoryItem(
          productKey: entry.key,
          mainItem: mainItem,
          variants: variants,
          totalStock: totalStock,
          totalBaseline: totalBaseline,
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
        sorted.sort((a, b) {
          // Primary: Total stock (low to high)
          final stockCompare = a.totalStock.compareTo(b.totalStock);
          if (stockCompare != 0) return stockCompare;

          // Secondary: Reverse expiry order for Low to High (no expiry first)
          final expiryCompare =
              _expiryOrder(b.mainItem).compareTo(_expiryOrder(a.mainItem));
          if (expiryCompare != 0) return expiryCompare;

          // Tertiary: Same as High to Low (status)
          return _statusOrder(a.mainItem).compareTo(_statusOrder(b.mainItem));
        });
        break;
      case "Quantity (High → Low)":
        sorted.sort((a, b) {
          // Primary: Total stock (high to low)
          final stockCompare = b.totalStock.compareTo(a.totalStock);
          if (stockCompare != 0) return stockCompare;

          // Secondary: Expiry date (earliest first)
          final expiryCompare =
              _expiryOrder(a.mainItem).compareTo(_expiryOrder(b.mainItem));
          if (expiryCompare != 0) return expiryCompare;

          // Tertiary: Status (as final tiebreaker)
          return _statusOrder(a.mainItem).compareTo(_statusOrder(b.mainItem));
        });
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
    // Priority 1: Out of Stock (highest priority)
    if (item.stock == 0) return 0;

    // Priority 2: Expiring (within 30 days) - check expiry date
    if (!item.noExpiry && item.expiry != null && item.expiry!.isNotEmpty) {
      try {
        final date = DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
        if (date != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final dateOnly = DateTime(date.year, date.month, date.day);
          final daysUntilExpiry = dateOnly.difference(today).inDays;

          // If expiring within 30 days, return priority 1
          if (daysUntilExpiry <= 30 && daysUntilExpiry >= 0) {
            return 1; // Expiring status
          }
        }
      } catch (e) {
        // Continue to next priority
      }
    }

    // Priority 3: Low Stock (using manually set threshold)
    if (item.lowStockBaseline != null &&
        item.lowStockBaseline! > 0 &&
        item.stock <= item.lowStockBaseline! &&
        item.stock > 0) return 2;

    // Priority 4: In Stock (lowest priority)
    return 3;
  }

  int _expiryOrder(InventoryItem item) {
    // Priority 1: Out of stock items first
    if (item.stock == 0) return 0;

    // Priority 2: Expiring soon (within 30 days)
    if (!item.noExpiry && item.expiry != null && item.expiry!.isNotEmpty) {
      try {
        final date = DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
        if (date != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final dateOnly = DateTime(date.year, date.month, date.day);
          final daysUntilExpiry = dateOnly.difference(today).inDays;

          // If expiring within 30 days, prioritize by days remaining
          if (daysUntilExpiry <= 30) {
            return 1000 + daysUntilExpiry; // 1000-1030 range
          }

          // If not expiring soon but has expiry date, put in Priority 3
          // Use a smaller range to ensure no expiry items come last
          final daysFromNow = dateOnly.difference(today).inDays;
          return 2000 + daysFromNow; // 2000+ range (much smaller numbers)
        }
      } catch (e) {
        // Continue to next priority
      }
    }

    // Priority 3: Items with no expiry - sort by stock status
    // Low Stock items should come before In Stock items
    if (item.lowStockBaseline != null &&
        item.lowStockBaseline! > 0 &&
        item.stock <= item.lowStockBaseline! &&
        item.stock > 0) {
      return 999999999998; // Low stock with no expiry
    }

    // Priority 4: In Stock items with no expiry (at the very end)
    return 999999999999;
  }

  // Helper method to get item status for filtering
  String _getItemStatus(InventoryItem item) {
    // Note: Expired status is now handled by the dedicated Expired Supply page
    // Main inventory system no longer shows expired status

    // Check stock status only using manually set threshold
    if (item.stock == 0) return "Out of Stock";

    // Use manually set threshold for low stock detection
    if (item.lowStockBaseline != null &&
        item.lowStockBaseline! > 0 &&
        item.stock <= item.lowStockBaseline!) {
      return "Low Stock";
    }

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
