import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/shared/storage/hive_storage.dart';

/// CatalogController provides a product catalog stream that includes
/// all non-archived products regardless of expiry/stock.
/// This is intended for pickers like Purchase Order and Stock Deduction,
/// so users can still find products even if all current batches are expired.
class CatalogController {
  CatalogController._internal();

  static final CatalogController _instance = CatalogController._internal();

  factory CatalogController() => _instance;

  final SupabaseClient _supabase = Supabase.instance.client;

  final Map<String, List<GroupedInventoryItem>> _cachedProducts = {};

  // ===== HIVE PERSISTENT CACHE HELPERS =====

  // Load catalog products Map from Hive
  Future<Map<String, List<GroupedInventoryItem>>?>
      _loadCatalogProductsMapFromHive() async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.catalogProductsBox);
      final jsonStr = box.get('catalog_products_map') as String?;
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return decoded.map((key, value) => MapEntry(
            key,
            (value as List<dynamic>)
                .map(
                    (item) => _groupedItemFromMap(item as Map<String, dynamic>))
                .toList()));
      }
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
    return null;
  }

  // Save catalog products Map to Hive
  Future<void> _saveCatalogProductsMapToHive(
      Map<String, List<GroupedInventoryItem>> products) async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.catalogProductsBox);
      final jsonMap = products.map((key, value) =>
          MapEntry(key, value.map((item) => _groupedItemToMap(item)).toList()));
      await box.put('catalog_products_map', jsonEncode(jsonMap));
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

  Stream<List<GroupedInventoryItem>> getAllProductsStream(
      {bool archived = false, bool? expired}) {
    final controller = StreamController<List<GroupedInventoryItem>>.broadcast();
    StreamSubscription<List<Map<String, dynamic>>>? supabaseSubscription;
    final cacheKey = 'archived:$archived|expired:${expired ?? 'null'}';

    void emitCached() {
      if (_cachedProducts.containsKey(cacheKey)) {
        controller.add(_cachedProducts[cacheKey]!);
      }
    }

    void startSubscription() {
      if (supabaseSubscription != null) return;
      try {
        supabaseSubscription =
            _supabase.from('supplies').stream(primaryKey: ['id']).listen(
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
              }).where((it) {
                if (it.archived != archived) return false;
                if (expired == false) {
                  if (it.expiry == null)
                    return true; // Keep items without expiry
                  return DateTime.now().isBefore(DateTime.parse(it.expiry!));
                }
                if (expired == true) {
                  if (it.expiry == null) return false;
                  return !DateTime.now().isBefore(DateTime.parse(it.expiry!));
                }
                return true;
              }).toList();

              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);

              final Map<String, List<InventoryItem>> byProduct = {};
              for (final it in items) {
                final key = (it.name).trim().toLowerCase();
                byProduct.putIfAbsent(key, () => []).add(it);
              }

              final result = <GroupedInventoryItem>[];
              for (final entry in byProduct.entries) {
                final productVariants = entry.value;

                List<InventoryItem> candidates = productVariants
                    .where((v) => !_isExpired(v, today) && v.stock > 0)
                    .toList();
                if (candidates.isEmpty) {
                  candidates = productVariants
                      .where((v) => !_isExpired(v, today))
                      .toList();
                }
                if (candidates.isEmpty) {
                  candidates = List<InventoryItem>.from(productVariants);
                }
                bool hasImage(InventoryItem x) => x.imageUrl.trim().isNotEmpty;
                candidates.sort((a, b) {
                  final imgDiff = (hasImage(b) ? 1 : 0) - (hasImage(a) ? 1 : 0);
                  if (imgDiff != 0) return imgDiff;
                  return a.id.compareTo(b.id);
                });
                final InventoryItem preferred = candidates.first;

                final totalStock =
                    productVariants.fold(0, (sum, it) => sum + it.stock);
                // Use the threshold value directly (not summed) since all batches share the same threshold
                int totalBaseline = 0;
                for (final item in productVariants) {
                  if (item.lowStockBaseline != null &&
                      item.lowStockBaseline! > 0) {
                    totalBaseline = item.lowStockBaseline!;
                    break; // All batches have the same threshold, so we can use the first one
                  }
                }
                final preferredId = preferred.id;
                final others =
                    productVariants.where((v) => v.id != preferredId).toList();

                result.add(
                  GroupedInventoryItem(
                    productKey: entry.key,
                    mainItem: preferred,
                    variants: others,
                    totalStock: totalStock,
                    totalBaseline: totalBaseline,
                  ),
                );
              }

              result.sort((a, b) => a.mainItem.name
                  .toLowerCase()
                  .compareTo(b.mainItem.name.toLowerCase()));

              _cachedProducts[cacheKey] = result;
              unawaited(_saveCatalogProductsMapToHive(
                  _cachedProducts)); // Save to Hive
              controller.add(result);
            } catch (e) {
              if (_cachedProducts.containsKey(cacheKey)) {
                controller.add(_cachedProducts[cacheKey]!);
              } else {
                controller.add([]);
              }
            }
          },
          onError: (error) {
            if (_cachedProducts.containsKey(cacheKey)) {
              controller.add(_cachedProducts[cacheKey]!);
            } else {
              controller.add([]);
            }
          },
        );
      } catch (e) {
        if (_cachedProducts.containsKey(cacheKey)) {
          controller.add(_cachedProducts[cacheKey]!);
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
        if (!_cachedProducts.containsKey(cacheKey)) {
          final hiveData = await _loadCatalogProductsMapFromHive();
          if (hiveData != null) {
            _cachedProducts.addAll(hiveData); // Populate in-memory cache
            if (_cachedProducts.containsKey(cacheKey)) {
              controller.add(_cachedProducts[cacheKey]!); // Emit immediately
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

  bool _isExpired(InventoryItem item, DateTime today) {
    if (item.noExpiry || item.expiry == null || item.expiry!.isEmpty)
      return false;
    final dt = DateTime.tryParse(item.expiry!) ??
        DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
    if (dt == null) return false;
    final d = DateTime(dt.year, dt.month, dt.day);
    return d.isBefore(today) || d.isAtSameMomentAs(today);
  }
}
