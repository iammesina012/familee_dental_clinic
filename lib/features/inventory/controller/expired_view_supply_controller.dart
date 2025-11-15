import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/activity_log/controller/inventory_activity_controller.dart';
import 'package:familee_dental/shared/storage/hive_storage.dart';

class ExpiredViewSupplyController {
  // Singleton pattern to ensure cache persists across widget rebuilds
  static final ExpiredViewSupplyController _instance =
      ExpiredViewSupplyController._internal();
  factory ExpiredViewSupplyController() => _instance;
  ExpiredViewSupplyController._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache for last known data per supply ID (persists across widget rebuilds)
  final Map<String, InventoryItem> _cachedSupplies = {};

  // Cache for other expired batches per product (key: "productName_brand_currentItemId")
  final Map<String, List<InventoryItem>> _cachedOtherExpiredBatches = {};

  // Cache for aggregated expired stock per date (key: "name_brand_expiry")
  final Map<String, int> _cachedAggregatedStock = {};

  // ===== HIVE PERSISTENT CACHE HELPERS =====

  // Load supplies Map from Hive
  Future<Map<String, InventoryItem>?> _loadSuppliesMapFromHive() async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.expiredViewSuppliesBox);
      final jsonStr = box.get('supplies_map') as String?;
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return decoded.map((key, value) => MapEntry(
            key, _inventoryItemFromMap(value as Map<String, dynamic>)));
      }
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
    return null;
  }

  // Save supplies Map to Hive
  Future<void> _saveSuppliesMapToHive(
      Map<String, InventoryItem> supplies) async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.expiredViewSuppliesBox);
      final jsonMap = supplies
          .map((key, value) => MapEntry(key, _inventoryItemToMap(value)));
      await box.put('supplies_map', jsonEncode(jsonMap));
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
  }

  // Load other expired batches Map from Hive
  Future<Map<String, List<InventoryItem>>?>
      _loadOtherBatchesMapFromHive() async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.expiredOtherBatchesBox);
      final jsonStr = box.get('other_batches_map') as String?;
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return decoded.map((key, value) => MapEntry(
            key,
            (value as List<dynamic>)
                .map((item) =>
                    _inventoryItemFromMap(item as Map<String, dynamic>))
                .toList()));
      }
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
    return null;
  }

  // Save other expired batches Map to Hive
  Future<void> _saveOtherBatchesMapToHive(
      Map<String, List<InventoryItem>> batches) async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.expiredOtherBatchesBox);
      final jsonMap = batches.map((key, value) => MapEntry(
          key, value.map((item) => _inventoryItemToMap(item)).toList()));
      await box.put('other_batches_map', jsonEncode(jsonMap));
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
  }

  // Load aggregated stock Map from Hive
  Future<Map<String, int>?> _loadAggregatedStockMapFromHive() async {
    try {
      final box =
          await HiveStorage.openBox(HiveStorage.expiredAggregatedStockBox);
      final jsonStr = box.get('aggregated_stock_map') as String?;
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return decoded.map((key, value) => MapEntry(key, value as int));
      }
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
    return null;
  }

  // Save aggregated stock Map to Hive
  Future<void> _saveAggregatedStockMapToHive(Map<String, int> stockMap) async {
    try {
      final box =
          await HiveStorage.openBox(HiveStorage.expiredAggregatedStockBox);
      await box.put('aggregated_stock_map', jsonEncode(stockMap));
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

  /// Get stream of individual supply item from Supabase
  Stream<InventoryItem?> supplyStream(String id) {
    final controller = StreamController<InventoryItem?>.broadcast();
    StreamSubscription<List<Map<String, dynamic>>>? supabaseSubscription;

    void emitCached() {
      if (_cachedSupplies.containsKey(id)) {
        controller.add(_cachedSupplies[id]);
      }
    }

    void startSubscription() {
      if (supabaseSubscription != null) return;
      try {
        supabaseSubscription = _supabase
            .from('supplies')
            .stream(primaryKey: ['id'])
            .eq('id', id)
            .listen(
              (data) {
                try {
                  if (data.isEmpty) {
                    controller.add(null);
                    return;
                  }
                  final row = data.first;
                  DateTime? createdAt;
                  if (row['created_at'] != null) {
                    try {
                      createdAt = DateTime.parse(row['created_at'] as String);
                    } catch (e) {
                      createdAt = null;
                    }
                  }
                  final item = InventoryItem(
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
                    packagingContentQuantity: row['packaging_content_quantity'],
                    supplier: row['supplier'] ?? '',
                    brand: row['brand'] ?? '',
                    expiry: row['expiry'],
                    noExpiry: row['no_expiry'] ?? false,
                    archived: row['archived'] ?? false,
                    createdAt: createdAt,
                  );

                  // Cache the result
                  _cachedSupplies[id] = item;
                  unawaited(
                      _saveSuppliesMapToHive(_cachedSupplies)); // Save to Hive
                  controller.add(item);
                } catch (e) {
                  // On error, emit cached data if available
                  if (_cachedSupplies.containsKey(id)) {
                    controller.add(_cachedSupplies[id]);
                  } else {
                    controller.add(null);
                  }
                }
              },
              onError: (error) {
                // On stream error, emit cached data if available
                if (_cachedSupplies.containsKey(id)) {
                  controller.add(_cachedSupplies[id]);
                } else {
                  controller.add(null);
                }
              },
            );
      } catch (e) {
        // If stream creation fails, emit cached data if available
        if (_cachedSupplies.containsKey(id)) {
          controller.add(_cachedSupplies[id]);
        } else {
          controller.add(null);
        }
      }
    }

    controller
      ..onListen = () async {
        // 1. Check in-memory cache first
        emitCached();

        // 2. If in-memory cache is null for this ID, auto-load from Hive
        if (!_cachedSupplies.containsKey(id)) {
          final hiveData = await _loadSuppliesMapFromHive();
          if (hiveData != null) {
            _cachedSupplies.addAll(hiveData); // Populate in-memory cache
            if (_cachedSupplies.containsKey(id)) {
              controller.add(_cachedSupplies[id]); // Emit immediately
            }
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

  /// Stream the total stock for a specific expired date of a product (name + brand)
  Stream<int> aggregatedExpiredStockForDate(
      {required String name, required String brand, required String? expiry}) {
    final controller = StreamController<int>.broadcast();
    StreamSubscription<List<Map<String, dynamic>>>? supabaseSubscription;

    // Create cache key
    final cacheKey = '${name}_${brand}_${expiry ?? 'null'}';

    void emitCached() {
      if (_cachedAggregatedStock.containsKey(cacheKey)) {
        controller.add(_cachedAggregatedStock[cacheKey]!);
      }
    }

    DateTime? normalize(String? value) {
      if (value == null || value.isEmpty) return null;
      return DateTime.tryParse(value) ??
          DateTime.tryParse(value.replaceAll('/', '-'));
    }

    final targetDate = normalize(expiry);

    void startSubscription() {
      if (supabaseSubscription != null) return;
      try {
        supabaseSubscription =
            _supabase.from('supplies').stream(primaryKey: ['id']).listen(
          (data) {
            try {
              // Filter by name and brand on the client side
              final filteredData = data
                  .where((row) => row['name'] == name && row['brand'] == brand)
                  .toList();
              final items = filteredData
                  .map((row) {
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
                    );
                  })
                  .where((it) => it.archived == false)
                  .toList();

              // Sum stock for items that are expired and match the same date
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);

              int total = 0;
              for (final it in items) {
                if (it.noExpiry || it.expiry == null || it.expiry!.isEmpty)
                  continue;
                final exp = normalize(it.expiry);
                if (exp == null) continue;
                final expOnly = DateTime(exp.year, exp.month, exp.day);
                final isExpired =
                    expOnly.isBefore(today) || expOnly.isAtSameMomentAs(today);
                if (!isExpired) continue;
                if (targetDate == null) continue;
                final targetOnly =
                    DateTime(targetDate.year, targetDate.month, targetDate.day);
                if (expOnly == targetOnly) {
                  total += it.stock;
                }
              }

              // Cache the result
              _cachedAggregatedStock[cacheKey] = total;
              unawaited(_saveAggregatedStockMapToHive(
                  _cachedAggregatedStock)); // Save to Hive
              controller.add(total);
            } catch (e) {
              // On error, emit cached data if available
              if (_cachedAggregatedStock.containsKey(cacheKey)) {
                controller.add(_cachedAggregatedStock[cacheKey]!);
              } else {
                controller.add(0);
              }
            }
          },
          onError: (error) {
            // On stream error, emit cached data if available
            if (_cachedAggregatedStock.containsKey(cacheKey)) {
              controller.add(_cachedAggregatedStock[cacheKey]!);
            } else {
              controller.add(0);
            }
          },
        );
      } catch (e) {
        // If stream creation fails, emit cached data if available
        if (_cachedAggregatedStock.containsKey(cacheKey)) {
          controller.add(_cachedAggregatedStock[cacheKey]!);
        } else {
          controller.add(0);
        }
      }
    }

    controller
      ..onListen = () async {
        // 1. Check in-memory cache first
        emitCached();

        // 2. If in-memory cache is null for this key, auto-load from Hive
        if (!_cachedAggregatedStock.containsKey(cacheKey)) {
          final hiveData = await _loadAggregatedStockMapFromHive();
          if (hiveData != null) {
            _cachedAggregatedStock.addAll(hiveData); // Populate in-memory cache
            if (_cachedAggregatedStock.containsKey(cacheKey)) {
              controller
                  .add(_cachedAggregatedStock[cacheKey]!); // Emit immediately
            }
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

  /// Get stream of other expired batches of the same product (same name + brand)
  Stream<List<InventoryItem>> getOtherExpiredBatchesStream(
      String productName, String brand, String currentItemId) {
    final controller = StreamController<List<InventoryItem>>.broadcast();
    StreamSubscription<List<Map<String, dynamic>>>? supabaseSubscription;

    // Create cache key
    final cacheKey = '${productName}_${brand}_$currentItemId';

    void emitCached() {
      if (_cachedOtherExpiredBatches.containsKey(cacheKey)) {
        controller.add(_cachedOtherExpiredBatches[cacheKey]!);
      }
    }

    void startSubscription() {
      if (supabaseSubscription != null) return;
      try {
        supabaseSubscription =
            _supabase.from('supplies').stream(primaryKey: ['id']).listen(
          (data) {
            try {
              // Filter by name and brand on the client side
              final filteredData = data
                  .where((row) =>
                      row['name'] == productName && row['brand'] == brand)
                  .toList();
              final items = filteredData
                  .map((row) {
                    return InventoryItem(
                      id: row['id'] as String,
                      name: row['name'] ?? '',
                      type: row['type'],
                      imageUrl: row['image_url'] ?? '',
                      category: row['category'] ?? '',
                      cost: (row['cost'] ?? 0).toDouble(),
                      stock: (row['stock'] ?? 0).toInt(),
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
                    );
                  })
                  .where((it) => it.archived == false)
                  .toList();

              // Filter for expired items only and exclude current item
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);

              final result = items.where((item) {
                // Exclude current item
                if (item.id == currentItemId) return false;

                // Check if item is expired
                if (item.noExpiry ||
                    item.expiry == null ||
                    item.expiry!.isEmpty) {
                  return false;
                }

                final expiryDate =
                    DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
                if (expiryDate == null) return false;

                final dateOnly =
                    DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
                return dateOnly.isBefore(today) ||
                    dateOnly.isAtSameMomentAs(today);
              }).toList();

              // Cache the result
              _cachedOtherExpiredBatches[cacheKey] = result;
              unawaited(_saveOtherBatchesMapToHive(
                  _cachedOtherExpiredBatches)); // Save to Hive
              controller.add(result);
            } catch (e) {
              // On error, emit cached data if available
              if (_cachedOtherExpiredBatches.containsKey(cacheKey)) {
                controller.add(_cachedOtherExpiredBatches[cacheKey]!);
              } else {
                controller.add([]);
              }
            }
          },
          onError: (error) {
            // On stream error, emit cached data if available
            if (_cachedOtherExpiredBatches.containsKey(cacheKey)) {
              controller.add(_cachedOtherExpiredBatches[cacheKey]!);
            } else {
              controller.add([]);
            }
          },
        );
      } catch (e) {
        // If stream creation fails, emit cached data if available
        if (_cachedOtherExpiredBatches.containsKey(cacheKey)) {
          controller.add(_cachedOtherExpiredBatches[cacheKey]!);
        } else {
          controller.add([]);
        }
      }
    }

    controller
      ..onListen = () async {
        // 1. Check in-memory cache first
        emitCached();

        // 2. If in-memory cache is null for this key, auto-load from Hive
        if (!_cachedOtherExpiredBatches.containsKey(cacheKey)) {
          final hiveData = await _loadOtherBatchesMapFromHive();
          if (hiveData != null) {
            _cachedOtherExpiredBatches
                .addAll(hiveData); // Populate in-memory cache
            if (_cachedOtherExpiredBatches.containsKey(cacheKey)) {
              controller.add(
                  _cachedOtherExpiredBatches[cacheKey]!); // Emit immediately
            }
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

  /// Delete supply permanently from Supabase
  Future<void> deleteSupply(String id) async {
    try {
      // Get the item data before deletion for activity log
      final itemResponse =
          await _supabase.from('supplies').select('*').eq('id', id).single();

      if (itemResponse.isNotEmpty) {
        final item = InventoryItem(
          id: itemResponse['id'] as String,
          name: itemResponse['name'] ?? '',
          type: itemResponse['type'],
          imageUrl: itemResponse['image_url'] ?? '',
          category: itemResponse['category'] ?? '',
          cost: (itemResponse['cost'] ?? 0).toDouble(),
          stock: (itemResponse['stock'] ?? 0).toInt(),
          lowStockBaseline: itemResponse['low_stock_baseline'] != null
              ? (itemResponse['low_stock_baseline'] as num).toInt()
              : null,
          unit: itemResponse['unit'] ?? '',
          supplier: itemResponse['supplier'] ?? '',
          brand: itemResponse['brand'] ?? '',
          expiry: itemResponse['expiry'],
          noExpiry: itemResponse['no_expiry'] ?? false,
          archived: itemResponse['archived'] ?? false,
        );

        // Normalize type for querying
        final typeKey = (item.type ?? '').trim();

        // Determine whether this is the last batch for this product type (name + category + type)
        var siblingsQuery = _supabase
            .from('supplies')
            .select('id')
            .eq('name', item.name)
            .eq('category', item.category);

        // Filter by type if it exists
        if (typeKey.isNotEmpty) {
          siblingsQuery = siblingsQuery.eq('type', typeKey);
        } else {
          // For supplies without types, check for null or empty type
          siblingsQuery = siblingsQuery.or('type.is.null,type.eq.');
        }

        final siblings = await siblingsQuery;
        final bool hasOtherBatches = siblings.any((row) => row['id'] != id);

        if (hasOtherBatches) {
          // Safe to delete this expired batch only (there are other batches of this type)
          await _supabase.from('supplies').delete().eq('id', id);
        } else {
          // This is the last batch of this product type. Create a placeholder
          // so the product type remains visible in catalog/pickers with 0 stock.

          // Check if placeholder already exists for this type
          var placeholderQuery = _supabase
              .from('supplies')
              .select('id')
              .eq('name', item.name)
              .eq('category', item.category)
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
            // Create a new placeholder for this type (don't modify the expired supply)
            final placeholderData = {
              'name': item.name,
              'image_url': item.imageUrl,
              'category': item.category,
              'cost': item.cost,
              'stock': 0,
              'unit': item.unit,
              'supplier': item.supplier,
              'brand': item.brand,
              'expiry': null,
              'no_expiry': true,
              'archived': false,
              'created_at': DateTime.now().toIso8601String(),
              if (item.type != null && item.type!.isNotEmpty) 'type': item.type,
              if (item.lowStockBaseline != null)
                'low_stock_baseline': item.lowStockBaseline,
            };

            await _supabase.from('supplies').insert(placeholderData);
          }

          // Delete the expired supply after creating placeholder
          await _supabase.from('supplies').delete().eq('id', id);
        }

        // Log the disposal of an expired supply
        final activityController = InventoryActivityController();
        await activityController.logExpiredSupplyDisposed(
          itemName: item.name,
          type: item.type,
          category: item.category,
          stock: item.stock,
          unit: item.unit,
          packagingUnit: item.packagingUnit,
          packagingContent: item.packagingContent,
          packagingContentQuantity: item.packagingContentQuantity,
          cost: item.cost,
          brand: item.brand,
          supplier: item.supplier,
          expiryDate: item.expiry,
          noExpiry: item.noExpiry,
          lowStockBaseline: item.lowStockBaseline,
        );
      }
    } catch (e) {
      throw Exception('Failed to delete supply: $e');
    }
  }

  /// Get status for expired items (always returns "Expired")
  String getStatus(InventoryItem item) {
    return "Expired";
  }

  /// Get status background color for expired items
  Color getStatusBgColor(String status) {
    switch (status) {
      case "Expired":
        return const Color(0xFFFFCDD2); // Red background for expired
      default:
        return Colors.red[100]!;
    }
  }
}
