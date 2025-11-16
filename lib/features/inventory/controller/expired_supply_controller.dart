import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/activity_log/controller/inventory_activity_controller.dart';
import 'package:familee_dental/shared/storage/hive_storage.dart';

class ExpiredSupplyController {
  // Singleton pattern to ensure cache persists across widget rebuilds
  static final ExpiredSupplyController _instance =
      ExpiredSupplyController._internal();
  factory ExpiredSupplyController() => _instance;
  ExpiredSupplyController._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache for last known data (persists across widget rebuilds)
  List<InventoryItem>? _cachedSupplies;

  // ===== HIVE PERSISTENT CACHE HELPERS =====

  // Load expired supplies from Hive
  Future<List<InventoryItem>?> _loadExpiredSuppliesFromHive() async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.expiredSuppliesBox);
      final jsonStr = box.get('expired_supplies') as String?;
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

  // Save expired supplies to Hive
  Future<void> _saveExpiredSuppliesToHive(List<InventoryItem> supplies) async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.expiredSuppliesBox);
      final jsonList =
          supplies.map((item) => _inventoryItemToMap(item)).toList();
      await box.put('expired_supplies', jsonEncode(jsonList));
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
  }

  // Helper to convert InventoryItem to Map for JSON (reusing from InventoryController pattern)
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

  /// Get stream of supplies from Supabase with database filtering for better realtime performance
  Stream<List<InventoryItem>> getSuppliesStream({bool archived = false}) {
    final controller = StreamController<List<InventoryItem>>.broadcast();
    StreamSubscription<List<Map<String, dynamic>>>? supabaseSubscription;

    void emitCachedOrEmpty() {
      if (_cachedSupplies != null) {
        List<InventoryItem> filtered = _cachedSupplies!
            .where((item) => item.archived == archived)
            .toList();
        controller.add(filtered);
      }
    }

    void startSubscription() {
      if (supabaseSubscription != null) return;
      try {
        supabaseSubscription = _supabase
            .from('supplies')
            .stream(primaryKey: ['id'])
            .eq('archived', archived)
            .listen(
              (data) {
                try {
                  final items = data.map((row) {
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
                      packagingUnit: row['packaging_unit'],
                      packagingContent: row['packaging_content'],
                      packagingQuantity: row['packaging_quantity'],
                      packagingContentQuantity:
                          row['packaging_content_quantity'],
                      supplier: row['supplier'] ?? '',
                      brand: row['brand'] ?? '',
                      expiry: row['expiry'],
                      noExpiry: row['no_expiry'] ?? false,
                      archived: row['archived'] ?? false,
                      createdAt: createdAt,
                    );
                  }).toList();

                  // Cache all supplies (before filtering)
                  _cachedSupplies = items;
                  unawaited(_saveExpiredSuppliesToHive(items)); // Save to Hive
                  controller.add(items);
                } catch (e) {
                  // On error, emit cached data if available
                  if (_cachedSupplies != null) {
                    List<InventoryItem> filtered = _cachedSupplies!
                        .where((item) => item.archived == archived)
                        .toList();
                    controller.add(filtered);
                  } else {
                    controller.add([]);
                  }
                }
              },
              onError: (error) {
                // On stream error, emit cached data if available
                if (_cachedSupplies != null) {
                  List<InventoryItem> filtered = _cachedSupplies!
                      .where((item) => item.archived == archived)
                      .toList();
                  controller.add(filtered);
                } else {
                  controller.add([]);
                }
              },
            );
      } catch (e) {
        // If stream creation fails, emit cached data if available
        if (_cachedSupplies != null) {
          List<InventoryItem> filtered = _cachedSupplies!
              .where((item) => item.archived == archived)
              .toList();
          controller.add(filtered);
        } else {
          controller.add([]);
        }
      }
    }

    controller
      ..onListen = () async {
        // 1. Check in-memory cache first
        emitCachedOrEmpty();

        // 2. If in-memory cache is null, auto-load from Hive
        if (_cachedSupplies == null) {
          final hiveData = await _loadExpiredSuppliesFromHive();
          if (hiveData != null) {
            _cachedSupplies = hiveData; // Populate in-memory cache
            List<InventoryItem> filtered =
                hiveData.where((item) => item.archived == archived).toList();
            controller.add(filtered); // Emit immediately
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

  /// Filter expired items from the supplies stream
  List<InventoryItem> filterExpiredItems(List<InventoryItem> items) {
    return items.where((item) {
      // First check if item is expired
      if (item.noExpiry || item.expiry == null || item.expiry!.isEmpty) {
        return false;
      }

      final expiryDate = DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
      if (expiryDate == null) return false;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateOnly =
          DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

      return dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today);
    }).toList();
  }

  /// Automatically convert expired supplies to placeholders
  Future<void> convertExpiredToPlaceholders() async {
    try {
      // Get all supplies (not just expired ones)
      final allItems = await getSuppliesStream().first;

      // Group by name + category + type to find products (type-specific grouping)
      final Map<String, List<InventoryItem>> productGroups = {};
      for (final item in allItems) {
        // Normalize type - null/empty becomes empty string for grouping
        final typeKey = (item.type ?? '').trim();
        final key = '${item.name}_${item.category}_$typeKey';
        productGroups.putIfAbsent(key, () => []);
        productGroups[key]!.add(item);
      }

      for (final group in productGroups.values) {
        // Separate expired and non-expired items in this product group
        final expiredItems = group.where((item) {
          if (item.noExpiry || item.expiry == null || item.expiry!.isEmpty) {
            return false;
          }
          final expiryDate =
              DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
          if (expiryDate == null) return false;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final dateOnly =
              DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
          return dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today);
        }).toList();

        final nonExpiredItems = group.where((item) {
          if (item.noExpiry || item.expiry == null || item.expiry!.isEmpty) {
            return true;
          }
          final expiryDate =
              DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
          if (expiryDate == null) return true;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final dateOnly =
              DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
          return !(dateOnly.isBefore(today) ||
              dateOnly.isAtSameMomentAs(today));
        }).toList();

        // If there are expired items and no non-expired items, create placeholder for this type
        if (expiredItems.isNotEmpty && nonExpiredItems.isEmpty) {
          final firstExpired = expiredItems.first;
          final typeKey = (firstExpired.type ?? '').trim();

          // Check if there are other batches of the same product type (name + category + type)
          var allBatchesQuery = _supabase
              .from('supplies')
              .select('id')
              .eq('name', firstExpired.name)
              .eq('category', firstExpired.category);

          // Filter by type if it exists
          if (typeKey.isNotEmpty) {
            allBatchesQuery = allBatchesQuery.eq('type', typeKey);
          } else {
            // For supplies without types, check for null or empty type
            allBatchesQuery = allBatchesQuery.or('type.is.null,type.eq.');
          }

          final allBatches = await allBatchesQuery;
          final bool hasOtherBatches =
              allBatches.any((row) => row['id'] != firstExpired.id);

          if (!hasOtherBatches) {
            // Check if placeholder already exists for this type
            var placeholderQuery = _supabase
                .from('supplies')
                .select('id')
                .eq('name', firstExpired.name)
                .eq('category', firstExpired.category)
                .eq('stock', 0)
                .eq('no_expiry', true);

            // Filter by type if it exists
            if (typeKey.isNotEmpty) {
              placeholderQuery = placeholderQuery.eq('type', typeKey);
            } else {
              placeholderQuery = placeholderQuery.or('type.is.null,type.eq.');
            }

            final existingPlaceholders = await placeholderQuery;

            if (existingPlaceholders.isEmpty) {
              // This is the last batch of this product type. Create a NEW placeholder item
              // without modifying the existing expired supply
              final placeholderData = {
                'name': firstExpired.name,
                'image_url': firstExpired.imageUrl,
                'category': firstExpired.category,
                'cost': firstExpired.cost,
                'stock': 0,
                'unit': firstExpired.unit,
                'supplier': firstExpired.supplier,
                'brand': firstExpired.brand,
                'expiry': null,
                'no_expiry': true,
                'archived': false,
                'created_at': DateTime.now().toIso8601String(),
                if (firstExpired.type != null && firstExpired.type!.isNotEmpty)
                  'type': firstExpired.type,
                if (firstExpired.lowStockBaseline != null)
                  'low_stock_baseline': firstExpired.lowStockBaseline,
              };

              await _supabase.from('supplies').insert(placeholderData);

              // Log the placeholder creation
              final activityController = InventoryActivityController();
              await activityController.logExpiredSupplyDisposed(
                itemName: firstExpired.name,
                category: firstExpired.category,
                stock: 0, // Placeholder has 0 stock
                unit: firstExpired.unit,
                cost: firstExpired.cost,
                brand: firstExpired.brand,
                supplier: firstExpired.supplier,
                expiryDate: null, // No expiry for placeholder
                noExpiry: true,
              );
            }
          }
          // Note: We don't delete expired supplies - they should remain in the expired supply page
        }
      }
    } catch (e) {
      // Swallow errors; this is best-effort
      print('Error converting expired supplies to placeholders: $e');
    }
  }

  /// Apply search filter to expired items
  List<InventoryItem> applySearchFilter(
      List<InventoryItem> expiredItems, String searchText) {
    if (searchText.isEmpty) return expiredItems;

    return expiredItems.where((item) {
      return item.name.toLowerCase().contains(searchText.toLowerCase()) ||
          item.brand.toLowerCase().contains(searchText.toLowerCase());
    }).toList();
  }

  /// Group expired items by product (name + brand + type) and keep one representative
  /// batch per product. Prefer the latest expired date; if equal, prefer higher stock.
  List<InventoryItem> groupExpiredByProduct(List<InventoryItem> expiredItems) {
    final Map<String, InventoryItem> keyToItem = {};

    DateTime? parseExpiry(String? value) {
      if (value == null || value.isEmpty) return null;
      return DateTime.tryParse(value) ??
          DateTime.tryParse(value.replaceAll('/', '-'));
    }

    for (final item in expiredItems) {
      final typeKey = (item.type ?? '').trim();
      final key = '${item.name}_${item.brand}_$typeKey';
      final current = keyToItem[key];
      if (current == null) {
        keyToItem[key] = item;
        continue;
      }

      final currDate = parseExpiry(current.expiry);
      final nextDate = parseExpiry(item.expiry);

      bool replace;
      if (currDate == null && nextDate == null) {
        replace = item.stock > current.stock;
      } else if (currDate == null) {
        replace = true;
      } else if (nextDate == null) {
        replace = false;
      } else if (nextDate.isAfter(currDate)) {
        // Prefer the latest expired date for the representative
        replace = true;
      } else {
        replace = false;
      }

      if (!replace &&
          currDate != null &&
          nextDate != null &&
          currDate.compareTo(nextDate) == 0) {
        replace = item.stock > current.stock;
      }

      if (replace) {
        keyToItem[key] = item;
      }
    }

    final result = keyToItem.values.toList();
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  /// Get filtered expired supplies with search
  List<InventoryItem> getFilteredExpiredSupplies(
      List<InventoryItem> allItems, String searchText) {
    final expiredItems = filterExpiredItems(allItems);
    final grouped = groupExpiredByProduct(expiredItems);
    return applySearchFilter(grouped, searchText);
  }
}
