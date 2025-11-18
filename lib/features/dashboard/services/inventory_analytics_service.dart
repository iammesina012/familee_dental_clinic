import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/shared/storage/hive_storage.dart';

class InventoryAnalyticsService {
  // Singleton pattern to ensure cache persists across widget rebuilds
  static final InventoryAnalyticsService _instance =
      InventoryAnalyticsService._internal();
  factory InventoryAnalyticsService() => _instance;
  InventoryAnalyticsService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache for last known data (persists across widget rebuilds)
  Map<String, int>? _cachedExpiryCounts;
  Map<String, int>? _cachedSupplyCounts;
  Map<String, int>? _cachedPurchaseOrderCounts;
  Map<String, List<Map<String, dynamic>>>? _cachedSuppliesByStatus;
  Map<String, List<Map<String, dynamic>>>? _cachedPurchaseOrdersByStatus;

  // ===== HIVE PERSISTENT CACHE HELPERS =====

  // Load expiry counts from Hive
  Future<Map<String, int>?> _loadExpiryCountsFromHive() async {
    try {
      final box =
          await HiveStorage.openBox(HiveStorage.dashboardExpiryCountsBox);
      final jsonStr = box.get('expiry_counts') as String?;
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return decoded.map((k, v) => MapEntry(k, v as int));
      }
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
    return null;
  }

  // Save expiry counts to Hive
  Future<void> _saveExpiryCountsToHive(Map<String, int> data) async {
    try {
      final box =
          await HiveStorage.openBox(HiveStorage.dashboardExpiryCountsBox);
      await box.put('expiry_counts', jsonEncode(data));
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
  }

  // Load supply counts from Hive
  Future<Map<String, int>?> _loadSupplyCountsFromHive() async {
    try {
      final box =
          await HiveStorage.openBox(HiveStorage.dashboardSupplyCountsBox);
      final jsonStr = box.get('supply_counts') as String?;
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return decoded.map((k, v) => MapEntry(k, v as int));
      }
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
    return null;
  }

  // Save supply counts to Hive
  Future<void> _saveSupplyCountsToHive(Map<String, int> data) async {
    try {
      final box =
          await HiveStorage.openBox(HiveStorage.dashboardSupplyCountsBox);
      await box.put('supply_counts', jsonEncode(data));
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
  }

  // Load PO counts from Hive
  Future<Map<String, int>?> _loadPOCountsFromHive() async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.dashboardPOCountsBox);
      final jsonStr = box.get('po_counts') as String?;
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return decoded.map((k, v) => MapEntry(k, v as int));
      }
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
    return null;
  }

  // Save PO counts to Hive
  Future<void> _savePOCountsToHive(Map<String, int> data) async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.dashboardPOCountsBox);
      await box.put('po_counts', jsonEncode(data));
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
  }

  // Load supplies by status from Hive
  Future<Map<String, List<Map<String, dynamic>>>?>
      _loadSuppliesByStatusFromHive() async {
    try {
      final box =
          await HiveStorage.openBox(HiveStorage.dashboardSuppliesByStatusBox);
      final jsonStr = box.get('supplies_by_status') as String?;
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return decoded.map(
            (k, v) => MapEntry(k, (v as List).cast<Map<String, dynamic>>()));
      }
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
    return null;
  }

  // Save supplies by status to Hive
  Future<void> _saveSuppliesByStatusToHive(
      Map<String, List<Map<String, dynamic>>> data) async {
    try {
      final box =
          await HiveStorage.openBox(HiveStorage.dashboardSuppliesByStatusBox);
      await box.put('supplies_by_status', jsonEncode(data));
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
  }

  // Load POs by status from Hive
  Future<Map<String, List<Map<String, dynamic>>>?>
      _loadPOsByStatusFromHive() async {
    try {
      final box =
          await HiveStorage.openBox(HiveStorage.dashboardPOsByStatusBox);
      final jsonStr = box.get('pos_by_status') as String?;
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return decoded.map(
            (k, v) => MapEntry(k, (v as List).cast<Map<String, dynamic>>()));
      }
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
    return null;
  }

  // Save POs by status to Hive
  Future<void> _savePOsByStatusToHive(
      Map<String, List<Map<String, dynamic>>> data) async {
    try {
      final box =
          await HiveStorage.openBox(HiveStorage.dashboardPOsByStatusBox);
      await box.put('pos_by_status', jsonEncode(data));
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
  }

  // ===== STREAMS =====

  // Stream for expired and expiring counts
  Stream<Map<String, int>> getExpiryCountsStream() {
    final controller = StreamController<Map<String, int>>.broadcast();

    void emitCachedOrEmpty({bool forceEmpty = false}) {
      if (_cachedExpiryCounts != null) {
        controller.add(_cachedExpiryCounts!);
      } else if (forceEmpty) {
        controller.add({'expired': 0, 'expiring': 0});
      }
    }

    void startSubscription() {
      try {
        _supabase.from('supplies').stream(primaryKey: ['id']).listen(
          (data) {
            try {
              final allSupplies = data.map((row) {
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
                  stock: (row['stock'] ?? 0).toInt(),
                  lowStockBaseline: row['low_stock_baseline'] != null
                      ? (row['low_stock_baseline'] as num).toInt()
                      : null,
                  unit: row['unit'] ?? '',
                  supplier: row['supplier'] ?? '',
                  brand: row['brand'] ?? '',
                  expiry: row['expiry'],
                  noExpiry: row['no_expiry'] ?? false,
                  archived: row['archived'] ?? false,
                  createdAt: createdAt,
                );
              }).toList();

              final supplies = allSupplies
                  .where((supply) => !supply.archived && supply.stock > 0)
                  .toList();

              int expired = 0;
              int expiring = 0;

              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);

              for (final s in supplies) {
                if (s.noExpiry || s.expiry == null || s.expiry!.isEmpty) {
                  continue;
                }
                final parsed =
                    DateTime.tryParse(s.expiry!.replaceAll('/', '-'));
                if (parsed == null) continue;
                final dateOnly =
                    DateTime(parsed.year, parsed.month, parsed.day);
                if (dateOnly.isBefore(today) ||
                    dateOnly.isAtSameMomentAs(today)) {
                  expired++;
                } else {
                  final daysUntil = dateOnly.difference(today).inDays;
                  if (daysUntil <= 30) {
                    expiring++;
                  }
                }
              }

              final result = {
                'expired': expired,
                'expiring': expiring,
              };

              // Cache the result (in-memory + Hive)
              _cachedExpiryCounts = result;
              unawaited(_saveExpiryCountsToHive(result));
              controller.add(result);
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
        if (_cachedExpiryCounts == null) {
          final hiveData = await _loadExpiryCountsFromHive();
          if (hiveData != null) {
            _cachedExpiryCounts = hiveData; // Populate in-memory cache
            controller.add(hiveData); // Emit immediately
          }
        }

        // 3. Subscribe to Supabase for updates
        startSubscription();
      }
      ..onCancel = () {
        // Cleanup handled automatically
      };

    return controller.stream;
  }

  // Stream for supply counts by status (counts individual supplies, not grouped)
  Stream<Map<String, int>> getSupplyCountsStream() {
    final controller = StreamController<Map<String, int>>.broadcast();

    void emitCachedOrEmpty({bool forceEmpty = false}) {
      if (_cachedSupplyCounts != null) {
        controller.add(_cachedSupplyCounts!);
      } else if (forceEmpty) {
        controller
            .add({'inStock': 0, 'lowStock': 0, 'outOfStock': 0, 'total': 0});
      }
    }

    void startSubscription() {
      try {
        _supabase.from('supplies').stream(primaryKey: ['id']).listen(
          (data) {
            try {
              final allSupplies = data.map((row) {
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
                  stock: (row['stock'] ?? 0).toInt(),
                  lowStockBaseline: row['low_stock_baseline'] != null
                      ? (row['low_stock_baseline'] as num).toInt()
                      : null,
                  unit: row['unit'] ?? '',
                  supplier: row['supplier'] ?? '',
                  brand: row['brand'] ?? '',
                  expiry: row['expiry'],
                  noExpiry: row['no_expiry'] ?? false,
                  archived: row['archived'] ?? false,
                  createdAt: createdAt,
                );
              }).toList();

              // Filter out archived supplies only (keep expired for checking)
              final nonArchivedSupplies = allSupplies.where((supply) {
                return !supply.archived;
              }).toList();

              // Helper function to check if a supply is expired
              bool isExpired(InventoryItem supply) {
                if (supply.noExpiry ||
                    supply.expiry == null ||
                    supply.expiry!.isEmpty) {
                  return false;
                }
                final expiryDate =
                    DateTime.tryParse(supply.expiry!.replaceAll('/', '-'));
                if (expiryDate == null) return false;
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final dateOnly =
                    DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
                return dateOnly.isBefore(today) ||
                    dateOnly.isAtSameMomentAs(today);
              }

              // Helper function to check if a supply is expiring (within 30 days)
              bool isExpiring(InventoryItem supply) {
                if (supply.noExpiry ||
                    supply.expiry == null ||
                    supply.expiry!.isEmpty) {
                  return false;
                }
                final expiryDate =
                    DateTime.tryParse(supply.expiry!.replaceAll('/', '-'));
                if (expiryDate == null) return false;
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final dateOnly =
                    DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

                // Check if expired first
                if (dateOnly.isBefore(today) ||
                    dateOnly.isAtSameMomentAs(today)) {
                  return false; // It's expired, not expiring
                }

                // Check if expiring (within 30 days)
                final daysUntil = dateOnly.difference(today).inDays;
                return daysUntil <= 30;
              }

              // Filter out expired and expiring supplies for grouping (but we'll check all batches later)
              final supplies = nonArchivedSupplies.where((supply) {
                return !isExpired(supply) && !isExpiring(supply);
              }).toList();

              // Group ALL non-archived supplies by name + category + type (including expired)
              final Map<String, List<InventoryItem>> allGrouped = {};
              for (final supply in nonArchivedSupplies) {
                final nameKey = supply.name.trim().toLowerCase();
                final categoryKey = supply.category.trim().toLowerCase();
                final typeKey = (supply.type ?? '').trim().toLowerCase();
                final key = '${nameKey}_${categoryKey}_$typeKey';
                if (!allGrouped.containsKey(key)) {
                  allGrouped[key] = [];
                }
                allGrouped[key]!.add(supply);
              }

              // Group non-expired supplies by name + category + type (for status calculation)
              final Map<String, List<InventoryItem>> grouped = {};
              for (final supply in supplies) {
                final nameKey = supply.name.trim().toLowerCase();
                final categoryKey = supply.category.trim().toLowerCase();
                final typeKey = (supply.type ?? '').trim().toLowerCase();
                final key = '${nameKey}_${categoryKey}_$typeKey';
                if (!grouped.containsKey(key)) {
                  grouped[key] = [];
                }
                grouped[key]!.add(supply);
              }

              // Count grouped supplies by status
              int totalInStock = 0;
              int totalLowStock = 0;
              int totalOutOfStock = 0;

              for (final entry in grouped.entries) {
                final groupKey = entry.key;
                final groupItems = entry.value;

                // Check if this group has expired or expiring batches (from allGrouped)
                final allBatchesInGroup = allGrouped[groupKey] ?? [];
                final expiredBatchesInGroup =
                    allBatchesInGroup.where((item) => isExpired(item)).toList();
                final expiringBatchesInGroup = allBatchesInGroup
                    .where((item) => isExpiring(item))
                    .toList();

                // Skip groups where ALL batches are expired OR expiring
                // If a group has both expired/expiring and non-expired/expiring batches, count the non-expired/expiring ones
                if ((expiredBatchesInGroup.length == allBatchesInGroup.length ||
                        expiringBatchesInGroup.length ==
                            allBatchesInGroup.length) &&
                    allBatchesInGroup.isNotEmpty) {
                  // All batches are expired or expiring - skip counting this group in stock status
                  // (it belongs in expired/expiring section instead)
                  continue;
                }

                // Calculate total stock for this group (sum all non-expired batches)
                final totalStock =
                    groupItems.fold(0, (sum, item) => sum + item.stock);

                // Get threshold (all batches share the same threshold)
                int? totalBaseline;
                for (final item in groupItems) {
                  if (item.lowStockBaseline != null &&
                      item.lowStockBaseline! > 0) {
                    totalBaseline = item.lowStockBaseline;
                    break; // All batches have the same threshold
                  }
                }

                // Determine status based on grouped totals (applies to ALL statuses)
                if (totalStock == 0) {
                  totalOutOfStock++;
                } else if (totalBaseline != null &&
                    totalBaseline > 0 &&
                    totalStock <= totalBaseline) {
                  totalLowStock++;
                } else {
                  totalInStock++;
                }
              }

              final result = {
                'inStock': totalInStock,
                'lowStock': totalLowStock,
                'outOfStock': totalOutOfStock,
                'total': grouped.length, // Count unique groups, not batches
              };

              // Cache the result (in-memory + Hive)
              _cachedSupplyCounts = result;
              unawaited(_saveSupplyCountsToHive(result));
              controller.add(result);
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
        if (_cachedSupplyCounts == null) {
          final hiveData = await _loadSupplyCountsFromHive();
          if (hiveData != null) {
            _cachedSupplyCounts = hiveData; // Populate in-memory cache
            controller.add(hiveData); // Emit immediately
          }
        }

        // 3. Subscribe to Supabase for updates
        startSubscription();
      }
      ..onCancel = () {
        // Cleanup handled automatically
      };

    return controller.stream;
  }

  // Stream for purchase order counts by status
  Stream<Map<String, int>> getPurchaseOrderCountsStream() {
    final controller = StreamController<Map<String, int>>.broadcast();

    void emitCachedOrEmpty({bool forceEmpty = false}) {
      if (_cachedPurchaseOrderCounts != null) {
        controller.add(_cachedPurchaseOrderCounts!);
      } else if (forceEmpty) {
        controller.add({'Open': 0, 'Partial': 0, 'Approval': 0, 'Closed': 0});
      }
    }

    void startSubscription() {
      try {
        _supabase.from('purchase_orders').stream(primaryKey: ['id']).listen(
          (data) {
            try {
              int open = 0;
              int partial = 0;
              int approval = 0;
              int closed = 0;

              for (final row in data) {
                final status = row['status']?.toString() ?? '';
                switch (status) {
                  case 'Open':
                    open++;
                    break;
                  case 'Partial':
                  case 'Partially Received':
                    partial++;
                    break;
                  case 'Approval':
                    approval++;
                    break;
                  case 'Closed':
                  case 'Cancelled':
                    closed++;
                    break;
                }
              }

              final result = {
                'Open': open,
                'Partial': partial,
                'Approval': approval,
                'Closed': closed,
              };

              // Cache the result (in-memory + Hive)
              _cachedPurchaseOrderCounts = result;
              unawaited(_savePOCountsToHive(result));
              controller.add(result);
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
        if (_cachedPurchaseOrderCounts == null) {
          final hiveData = await _loadPOCountsFromHive();
          if (hiveData != null) {
            _cachedPurchaseOrderCounts = hiveData; // Populate in-memory cache
            controller.add(hiveData); // Emit immediately
          }
        }

        // 3. Subscribe to Supabase for updates
        startSubscription();
      }
      ..onCancel = () {
        // Cleanup handled automatically
      };

    return controller.stream;
  }

  // Get all supplies with details, categorized by status
  Future<Map<String, List<Map<String, dynamic>>>> getSuppliesByStatus() async {
    // 1. Check in-memory cache first
    if (_cachedSuppliesByStatus != null) {
      // Fetch fresh data in the background, but return cached data immediately
      _fetchSuppliesByStatusInBackground();
      return _cachedSuppliesByStatus!;
    }

    // 2. If in-memory cache is null, auto-load from Hive
    final hiveData = await _loadSuppliesByStatusFromHive();
    if (hiveData != null) {
      _cachedSuppliesByStatus = hiveData; // Populate in-memory cache
      // Fetch fresh data in the background
      _fetchSuppliesByStatusInBackground();
      return hiveData; // Return immediately from Hive
    }

    try {
      final response = await _supabase.from('supplies').select('*');

      final allSupplies = response.map((row) {
        final name = row['name'] ?? '';
        final type = row['type'] ?? '';
        final category = row['category'] ?? '';
        final stock = (row['stock'] ?? 0).toInt();
        // Format supply name with type: "Surgical Mask(Pink)" - separate from quantity
        String displayName = name;
        if (type != null && type.toString().trim().isNotEmpty) {
          displayName = '$name($type)';
        }

        return {
          'id': row['id'] as String,
          'name': name,
          'type': type,
          'category': category,
          'displayName': displayName,
          'stock': stock,
          'lowStockBaseline': row['low_stock_baseline'] != null
              ? (row['low_stock_baseline'] as num).toInt()
              : null,
          'packagingUnit': row['packaging_unit'] ?? row['unit'] ?? '',
          'packagingContent': row['packaging_content'] ?? '',
          'brand': row['brand'] ?? 'N/A',
          'supplier': row['supplier'] ?? 'N/A',
          'cost': (row['cost'] ?? 0).toDouble(),
          'expiry': row['expiry'],
          'noExpiry': row['no_expiry'] ?? false,
          'archived': row['archived'] ?? false,
        };
      }).toList();

      // Filter out archived supplies
      final nonArchivedSupplies =
          allSupplies.where((supply) => !supply['archived']).toList();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Helper function to check if a supply is expired
      bool isExpired(Map<String, dynamic> supply) {
        final noExpiry = supply['noExpiry'] as bool;
        final expiry = supply['expiry'] as String?;
        if (noExpiry || expiry == null || expiry.isEmpty) {
          return false;
        }
        final expiryDate = DateTime.tryParse(expiry.replaceAll('/', '-'));
        if (expiryDate == null) return false;
        final dateOnly =
            DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
        return dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today);
      }

      // Helper function to check if a supply is expiring (within 30 days)
      bool isExpiring(Map<String, dynamic> supply) {
        final noExpiry = supply['noExpiry'] as bool;
        final expiry = supply['expiry'] as String?;
        if (noExpiry || expiry == null || expiry.isEmpty) {
          return false;
        }
        final expiryDate = DateTime.tryParse(expiry.replaceAll('/', '-'));
        if (expiryDate == null) return false;
        final dateOnly =
            DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

        // Check if expired first
        if (dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today)) {
          return false; // It's expired, not expiring
        }

        // Check if expiring (within 30 days)
        final daysUntil = dateOnly.difference(today).inDays;
        return daysUntil <= 30;
      }

      // Filter out expired and expiring supplies for grouping
      final supplies = nonArchivedSupplies.where((supply) {
        return !isExpired(supply) && !isExpiring(supply);
      }).toList();

      // Group ALL non-archived supplies by name + category + type (including expired/expiring)
      final Map<String, List<Map<String, dynamic>>> allGrouped = {};
      for (final supply in nonArchivedSupplies) {
        final nameKey = (supply['name'] as String).trim().toLowerCase();
        final categoryKey = (supply['category'] as String).trim().toLowerCase();
        final typeKey = (supply['type'] as String? ?? '').trim().toLowerCase();
        final key = '${nameKey}_${categoryKey}_$typeKey';
        if (!allGrouped.containsKey(key)) {
          allGrouped[key] = [];
        }
        allGrouped[key]!.add(supply);
      }

      // Group non-expired/non-expiring supplies by name + category + type
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final supply in supplies) {
        final nameKey = (supply['name'] as String).trim().toLowerCase();
        final categoryKey = (supply['category'] as String).trim().toLowerCase();
        final typeKey = (supply['type'] as String? ?? '').trim().toLowerCase();
        final key = '${nameKey}_${categoryKey}_$typeKey';
        if (!grouped.containsKey(key)) {
          grouped[key] = [];
        }
        grouped[key]!.add(supply);
      }

      final Map<String, List<Map<String, dynamic>>> suppliesByStatus = {
        'In Stock': [],
        'Low Stock': [],
        'Out of Stock': [],
        'Expiring': [],
        'Expired': [],
      };

      // Process grouped supplies (for stock status)
      for (final entry in grouped.entries) {
        final groupKey = entry.key;
        final groupItems = entry.value;

        // Check if this group has expired or expiring batches
        final allBatchesInGroup = allGrouped[groupKey] ?? [];
        final expiredBatchesInGroup =
            allBatchesInGroup.where((item) => isExpired(item)).toList();
        final expiringBatchesInGroup =
            allBatchesInGroup.where((item) => isExpiring(item)).toList();

        // Skip groups where ALL batches are expired OR expiring
        if ((expiredBatchesInGroup.length == allBatchesInGroup.length ||
                expiringBatchesInGroup.length == allBatchesInGroup.length) &&
            allBatchesInGroup.isNotEmpty) {
          continue;
        }

        // Calculate total stock for this group
        final totalStock =
            groupItems.fold(0, (sum, item) => sum + (item['stock'] as int));

        // Get threshold (pick first non-null baseline from any batch in group)
        int? totalBaseline;
        for (final item in groupItems) {
          final baseline = item['lowStockBaseline'] as int?;
          if (baseline != null && baseline > 0) {
            totalBaseline = baseline;
            break;
          }
        }

        // Pick first item in group as representative
        final representativeItem = Map<String, dynamic>.from(groupItems.first);
        representativeItem['stock'] = totalStock; // Use grouped total stock
        representativeItem['lowStockBaseline'] = totalBaseline;

        // Determine status based on grouped totals
        String status;
        if (totalStock == 0) {
          status = 'Out of Stock';
        } else if (totalBaseline != null &&
            totalBaseline > 0 &&
            totalStock <= totalBaseline) {
          status = 'Low Stock';
        } else {
          status = 'In Stock';
        }

        representativeItem['status'] = status;
        representativeItem['expiryDisplay'] =
            'No expiry'; // Grouped items may have mixed expiry

        suppliesByStatus[status]!.add(representativeItem);
      }

      // Process expired supplies (individually, not grouped)
      for (final supply in nonArchivedSupplies) {
        if (isExpired(supply)) {
          final supplyCopy = Map<String, dynamic>.from(supply);
          supplyCopy['status'] = 'Expired';
          final expiry = supply['expiry'] as String?;
          supplyCopy['expiryDisplay'] = expiry != null && expiry.isNotEmpty
              ? expiry.replaceAll('/', '-')
              : 'No expiry';
          suppliesByStatus['Expired']!.add(supplyCopy);
        }
      }

      // Process expiring supplies (individually, not grouped)
      for (final supply in nonArchivedSupplies) {
        if (isExpiring(supply)) {
          final supplyCopy = Map<String, dynamic>.from(supply);
          supplyCopy['status'] = 'Expiring';
          final expiry = supply['expiry'] as String?;
          supplyCopy['expiryDisplay'] = expiry != null && expiry.isNotEmpty
              ? expiry.replaceAll('/', '-')
              : 'No expiry';
          suppliesByStatus['Expiring']!.add(supplyCopy);
        }
      }

      // Cache the result (in-memory + Hive)
      _cachedSuppliesByStatus = suppliesByStatus;
      unawaited(_saveSuppliesByStatusToHive(suppliesByStatus));
      return suppliesByStatus;
    } catch (e) {
      // On error, return cached data if available, otherwise return empty
      if (_cachedSuppliesByStatus != null) {
        return _cachedSuppliesByStatus!;
      }
      return {
        'In Stock': [],
        'Low Stock': [],
        'Out of Stock': [],
        'Expiring': [],
        'Expired': [],
      };
    }
  }

  // Fetch supplies by status in background (for prepopulation)
  void _fetchSuppliesByStatusInBackground() {
    _supabase.from('supplies').select('*').then((response) {
      try {
        final allSupplies = response.map((row) {
          final name = row['name'] ?? '';
          final type = row['type'] ?? '';
          final category = row['category'] ?? '';
          final stock = (row['stock'] ?? 0).toInt();
          String displayName = name;
          if (type != null && type.toString().trim().isNotEmpty) {
            displayName = '$name($type)';
          }

          return {
            'id': row['id'] as String,
            'name': name,
            'type': type,
            'category': category,
            'displayName': displayName,
            'stock': stock,
            'lowStockBaseline': row['low_stock_baseline'] != null
                ? (row['low_stock_baseline'] as num).toInt()
                : null,
            'packagingUnit': row['packaging_unit'] ?? row['unit'] ?? '',
            'packagingContent': row['packaging_content'] ?? '',
            'brand': row['brand'] ?? 'N/A',
            'supplier': row['supplier'] ?? 'N/A',
            'cost': (row['cost'] ?? 0).toDouble(),
            'expiry': row['expiry'],
            'noExpiry': row['no_expiry'] ?? false,
            'archived': row['archived'] ?? false,
          };
        }).toList();

        final nonArchivedSupplies =
            allSupplies.where((supply) => !supply['archived']).toList();

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // Helper functions
        bool isExpired(Map<String, dynamic> supply) {
          final noExpiry = supply['noExpiry'] as bool;
          final expiry = supply['expiry'] as String?;
          if (noExpiry || expiry == null || expiry.isEmpty) return false;
          final expiryDate = DateTime.tryParse(expiry.replaceAll('/', '-'));
          if (expiryDate == null) return false;
          final dateOnly =
              DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
          return dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today);
        }

        bool isExpiring(Map<String, dynamic> supply) {
          final noExpiry = supply['noExpiry'] as bool;
          final expiry = supply['expiry'] as String?;
          if (noExpiry || expiry == null || expiry.isEmpty) return false;
          final expiryDate = DateTime.tryParse(expiry.replaceAll('/', '-'));
          if (expiryDate == null) return false;
          final dateOnly =
              DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
          if (dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today))
            return false;
          final daysUntil = dateOnly.difference(today).inDays;
          return daysUntil <= 30;
        }

        final supplies = nonArchivedSupplies.where((supply) {
          return !isExpired(supply) && !isExpiring(supply);
        }).toList();

        // Group supplies
        final Map<String, List<Map<String, dynamic>>> allGrouped = {};
        for (final supply in nonArchivedSupplies) {
          final nameKey = (supply['name'] as String).trim().toLowerCase();
          final categoryKey =
              (supply['category'] as String).trim().toLowerCase();
          final typeKey =
              (supply['type'] as String? ?? '').trim().toLowerCase();
          final key = '${nameKey}_${categoryKey}_$typeKey';
          if (!allGrouped.containsKey(key)) {
            allGrouped[key] = [];
          }
          allGrouped[key]!.add(supply);
        }

        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (final supply in supplies) {
          final nameKey = (supply['name'] as String).trim().toLowerCase();
          final categoryKey =
              (supply['category'] as String).trim().toLowerCase();
          final typeKey =
              (supply['type'] as String? ?? '').trim().toLowerCase();
          final key = '${nameKey}_${categoryKey}_$typeKey';
          if (!grouped.containsKey(key)) {
            grouped[key] = [];
          }
          grouped[key]!.add(supply);
        }

        final Map<String, List<Map<String, dynamic>>> suppliesByStatus = {
          'In Stock': [],
          'Low Stock': [],
          'Out of Stock': [],
          'Expiring': [],
          'Expired': [],
        };

        // Process grouped supplies
        for (final entry in grouped.entries) {
          final groupKey = entry.key;
          final groupItems = entry.value;

          final allBatchesInGroup = allGrouped[groupKey] ?? [];
          final expiredBatchesInGroup =
              allBatchesInGroup.where((item) => isExpired(item)).toList();
          final expiringBatchesInGroup =
              allBatchesInGroup.where((item) => isExpiring(item)).toList();

          if ((expiredBatchesInGroup.length == allBatchesInGroup.length ||
                  expiringBatchesInGroup.length == allBatchesInGroup.length) &&
              allBatchesInGroup.isNotEmpty) {
            continue;
          }

          final totalStock =
              groupItems.fold(0, (sum, item) => sum + (item['stock'] as int));

          int? totalBaseline;
          for (final item in groupItems) {
            final baseline = item['lowStockBaseline'] as int?;
            if (baseline != null && baseline > 0) {
              totalBaseline = baseline;
              break;
            }
          }

          final representativeItem =
              Map<String, dynamic>.from(groupItems.first);
          representativeItem['stock'] = totalStock;
          representativeItem['lowStockBaseline'] = totalBaseline;

          String status;
          if (totalStock == 0) {
            status = 'Out of Stock';
          } else if (totalBaseline != null &&
              totalBaseline > 0 &&
              totalStock <= totalBaseline) {
            status = 'Low Stock';
          } else {
            status = 'In Stock';
          }

          representativeItem['status'] = status;
          representativeItem['expiryDisplay'] = 'No expiry';

          suppliesByStatus[status]!.add(representativeItem);
        }

        // Process expired/expiring individually
        for (final supply in nonArchivedSupplies) {
          if (isExpired(supply)) {
            final supplyCopy = Map<String, dynamic>.from(supply);
            supplyCopy['status'] = 'Expired';
            final expiry = supply['expiry'] as String?;
            supplyCopy['expiryDisplay'] = expiry != null && expiry.isNotEmpty
                ? expiry.replaceAll('/', '-')
                : 'No expiry';
            suppliesByStatus['Expired']!.add(supplyCopy);
          }
        }

        for (final supply in nonArchivedSupplies) {
          if (isExpiring(supply)) {
            final supplyCopy = Map<String, dynamic>.from(supply);
            supplyCopy['status'] = 'Expiring';
            final expiry = supply['expiry'] as String?;
            supplyCopy['expiryDisplay'] = expiry != null && expiry.isNotEmpty
                ? expiry.replaceAll('/', '-')
                : 'No expiry';
            suppliesByStatus['Expiring']!.add(supplyCopy);
          }
        }

        _cachedSuppliesByStatus = suppliesByStatus;
        unawaited(_saveSuppliesByStatusToHive(suppliesByStatus));
      } catch (e) {
        // Ignore background fetch errors
      }
    }).catchError((e) {
      // Ignore background fetch errors
    });
  }

  // Get all purchase orders with details, categorized by status
  Future<Map<String, List<Map<String, dynamic>>>>
      getPurchaseOrdersByStatus() async {
    // 1. Check in-memory cache first
    if (_cachedPurchaseOrdersByStatus != null) {
      // Fetch fresh data in the background, but return cached data immediately
      _fetchPurchaseOrdersByStatusInBackground();
      return _cachedPurchaseOrdersByStatus!;
    }

    // 2. If in-memory cache is null, auto-load from Hive
    final hiveData = await _loadPOsByStatusFromHive();
    if (hiveData != null) {
      _cachedPurchaseOrdersByStatus = hiveData; // Populate in-memory cache
      // Fetch fresh data in the background
      _fetchPurchaseOrdersByStatusInBackground();
      return hiveData; // Return immediately from Hive
    }

    try {
      final response = await _supabase.from('purchase_orders').select('*');

      final Map<String, List<Map<String, dynamic>>> posByStatus = {
        'Open': [],
        'Partial': [],
        'Approval': [],
        'Closed': [],
      };

      for (final row in response) {
        final status = row['status']?.toString() ?? 'Open';
        final supplies =
            (row['supplies'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        // Count received supplies
        int receivedCount = 0;
        List<String> expiryDates = [];

        // Get receipt details from supplies
        String? receiptNumber;
        String? recipientName;
        String? remarks;

        for (final supply in supplies) {
          final receivedQuantities = supply['receivedQuantities'];
          if (receivedQuantities != null &&
              receivedQuantities is Map &&
              receivedQuantities.isNotEmpty) {
            receivedCount++;

            // Collect expiry dates from received supplies
            final expiry = supply['expiry'];
            if (expiry != null && expiry.toString().isNotEmpty) {
              expiryDates.add(expiry.toString());
            }
          }

          // Get receipt details from any supply that has them (not just those with receivedQuantities)
          // Receipt details are saved to all supplies when items are received
          if (receiptNumber == null || receiptNumber.isEmpty) {
            receiptNumber = supply['receiptDrNo']?.toString() ?? '';
          }
          if (recipientName == null || recipientName.isEmpty) {
            recipientName = supply['receiptRecipient']?.toString() ?? '';
          }
          if (remarks == null || remarks.isEmpty) {
            remarks = supply['receiptRemarks']?.toString() ?? '';
          }
        }

        // Get supplier name from first supply (check both supplierName and supplier for compatibility)
        String supplierName = 'N/A';
        if (supplies.isNotEmpty) {
          supplierName = supplies.first['supplierName']?.toString() ??
              supplies.first['supplier']?.toString() ??
              'N/A';
        }

        // Get date received from supplies (if available)
        String? dateReceived;
        for (final supply in supplies) {
          final receiptDate = supply['receiptDate'] ??
              supply['receivedAt'] ??
              supply['received_date'];
          if (receiptDate != null) {
            try {
              if (receiptDate is String) {
                final dt = DateTime.tryParse(receiptDate);
                if (dt != null) {
                  dateReceived =
                      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                  break;
                }
              }
            } catch (_) {}
          }
        }

        final poData = {
          'id': row['id'] as String,
          'code': row['code'] ?? '',
          'supplierName': supplierName,
          'suppliesCount': supplies.length,
          'receivedCount': receivedCount,
          'expiryDates':
              expiryDates.join(', ') == '' ? 'N/A' : expiryDates.join(', '),
          'dateCreated': row['created_at'] != null
              ? DateTime.parse(row['created_at'])
                  .toIso8601String()
                  .split('T')[0]
              : 'N/A',
          'dateReceived': dateReceived ?? 'N/A',
          'receiptNumber': receiptNumber ?? 'N/A',
          'recipientName': recipientName ?? 'N/A',
          'remarks': remarks ?? 'N/A',
          'status': status,
        };

        // Categorize by status
        switch (status) {
          case 'Open':
            posByStatus['Open']!.add(poData);
            break;
          case 'Partial':
          case 'Partially Received':
            posByStatus['Partial']!.add(poData);
            break;
          case 'Approval':
            posByStatus['Approval']!.add(poData);
            break;
          case 'Closed':
          case 'Cancelled':
            posByStatus['Closed']!.add(poData);
            break;
        }
      }

      // Sort each status list by code (extract numeric value from #PO1, #PO2, etc.)
      for (final status in posByStatus.keys) {
        posByStatus[status]!.sort((a, b) {
          final codeA = a['code']?.toString() ?? '';
          final codeB = b['code']?.toString() ?? '';

          // Extract numeric value from code (e.g., #PO1 -> 1, #PO17 -> 17)
          int numA = 0;
          int numB = 0;

          try {
            final matchA = RegExp(r'#PO(\d+)').firstMatch(codeA);
            if (matchA != null) {
              numA = int.parse(matchA.group(1)!);
            }
          } catch (_) {}

          try {
            final matchB = RegExp(r'#PO(\d+)').firstMatch(codeB);
            if (matchB != null) {
              numB = int.parse(matchB.group(1)!);
            }
          } catch (_) {}

          return numA.compareTo(numB);
        });
      }

      // Cache the result (in-memory + Hive)
      _cachedPurchaseOrdersByStatus = posByStatus;
      unawaited(_savePOsByStatusToHive(posByStatus));
      return posByStatus;
    } catch (e) {
      // On error, return cached data if available, otherwise return empty
      if (_cachedPurchaseOrdersByStatus != null) {
        return _cachedPurchaseOrdersByStatus!;
      }
      return {
        'Open': [],
        'Partial': [],
        'Approval': [],
        'Closed': [],
      };
    }
  }

  // Fetch purchase orders by status in background (for prepopulation)
  void _fetchPurchaseOrdersByStatusInBackground() {
    _supabase.from('purchase_orders').select('*').then((response) {
      try {
        final Map<String, List<Map<String, dynamic>>> posByStatus = {
          'Open': [],
          'Partial': [],
          'Approval': [],
          'Closed': [],
        };

        for (final row in response) {
          final status = row['status']?.toString() ?? 'Open';
          final supplies =
              (row['supplies'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          int receivedCount = 0;
          List<String> expiryDates = [];

          String? receiptNumber;
          String? recipientName;
          String? remarks;

          for (final supply in supplies) {
            final receivedQuantities = supply['receivedQuantities'];
            if (receivedQuantities != null &&
                receivedQuantities is Map &&
                receivedQuantities.isNotEmpty) {
              receivedCount++;

              final expiry = supply['expiry'];
              if (expiry != null && expiry.toString().isNotEmpty) {
                expiryDates.add(expiry.toString());
              }
            }

            if (receiptNumber == null || receiptNumber.isEmpty) {
              receiptNumber = supply['receiptDrNo']?.toString() ?? '';
            }
            if (recipientName == null || recipientName.isEmpty) {
              recipientName = supply['receiptRecipient']?.toString() ?? '';
            }
            if (remarks == null || remarks.isEmpty) {
              remarks = supply['receiptRemarks']?.toString() ?? '';
            }
          }

          String supplierName = 'N/A';
          if (supplies.isNotEmpty) {
            supplierName = supplies.first['supplierName']?.toString() ??
                supplies.first['supplier']?.toString() ??
                'N/A';
          }

          String? dateReceived;
          for (final supply in supplies) {
            final receiptDate = supply['receiptDate'] ??
                supply['receivedAt'] ??
                supply['received_date'];
            if (receiptDate != null) {
              try {
                if (receiptDate is String) {
                  final dt = DateTime.tryParse(receiptDate);
                  if (dt != null) {
                    dateReceived =
                        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                    break;
                  }
                }
              } catch (_) {}
            }
          }

          final poData = {
            'id': row['id'] as String,
            'code': row['code'] ?? '',
            'supplierName': supplierName,
            'suppliesCount': supplies.length,
            'receivedCount': receivedCount,
            'expiryDates':
                expiryDates.join(', ') == '' ? 'N/A' : expiryDates.join(', '),
            'dateCreated': row['created_at'] != null
                ? DateTime.parse(row['created_at'])
                    .toIso8601String()
                    .split('T')[0]
                : 'N/A',
            'dateReceived': dateReceived ?? 'N/A',
            'receiptNumber': receiptNumber ?? 'N/A',
            'recipientName': recipientName ?? 'N/A',
            'remarks': remarks ?? 'N/A',
            'status': status,
          };

          switch (status) {
            case 'Open':
              posByStatus['Open']!.add(poData);
              break;
            case 'Partial':
            case 'Partially Received':
              posByStatus['Partial']!.add(poData);
              break;
            case 'Approval':
              posByStatus['Approval']!.add(poData);
              break;
            case 'Closed':
            case 'Cancelled':
              posByStatus['Closed']!.add(poData);
              break;
          }
        }

        for (final status in posByStatus.keys) {
          posByStatus[status]!.sort((a, b) {
            final codeA = a['code']?.toString() ?? '';
            final codeB = b['code']?.toString() ?? '';

            int numA = 0;
            int numB = 0;

            try {
              final matchA = RegExp(r'#PO(\d+)').firstMatch(codeA);
              if (matchA != null) {
                numA = int.parse(matchA.group(1)!);
              }
            } catch (_) {}

            try {
              final matchB = RegExp(r'#PO(\d+)').firstMatch(codeB);
              if (matchB != null) {
                numB = int.parse(matchB.group(1)!);
              }
            } catch (_) {}

            return numA.compareTo(numB);
          });
        }

        _cachedPurchaseOrdersByStatus = posByStatus;
        unawaited(_savePOsByStatusToHive(posByStatus));
      } catch (e) {
        // Ignore background fetch errors
      }
    }).catchError((e) {
      // Ignore background fetch errors
    });
  }
}
