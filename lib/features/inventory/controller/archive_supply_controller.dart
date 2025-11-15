import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/shared/storage/hive_storage.dart';

class ArchiveSupplyController {
  // Singleton pattern to ensure cache persists across widget rebuilds
  static final ArchiveSupplyController _instance =
      ArchiveSupplyController._internal();
  factory ArchiveSupplyController() => _instance;
  ArchiveSupplyController._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache for last known data (persists across widget rebuilds)
  List<InventoryItem>? _cachedArchivedSupplies;

  // ===== HIVE PERSISTENT CACHE HELPERS =====

  // Load archived supplies from Hive
  Future<List<InventoryItem>?> _loadArchivedSuppliesFromHive() async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.archiveSuppliesBox);
      final jsonStr = box.get('archived_supplies') as String?;
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

  // Save archived supplies to Hive
  Future<void> _saveArchivedSuppliesToHive(List<InventoryItem> supplies) async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.archiveSuppliesBox);
      final jsonList =
          supplies.map((item) => _inventoryItemToMap(item)).toList();
      await box.put('archived_supplies', jsonEncode(jsonList));
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

  // Get archived supplies with real-time updates
  Stream<List<InventoryItem>> getArchivedSupplies() {
    final controller = StreamController<List<InventoryItem>>.broadcast();
    StreamSubscription<List<Map<String, dynamic>>>? supabaseSubscription;

    void emitCachedOrEmpty() {
      if (_cachedArchivedSupplies != null) {
        controller.add(_cachedArchivedSupplies!);
      }
    }

    void startSubscription() {
      if (supabaseSubscription != null) return;
      try {
        supabaseSubscription = _supabase
            .from('supplies')
            .stream(primaryKey: ['id'])
            .eq('archived', true)
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

                  // Sort by name in the app instead of in database
                  items.sort((a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                  // Cache the result
                  _cachedArchivedSupplies = items;
                  unawaited(_saveArchivedSuppliesToHive(items)); // Save to Hive
                  controller.add(items);
                } catch (e) {
                  // On error, emit cached data if available
                  if (_cachedArchivedSupplies != null) {
                    controller.add(_cachedArchivedSupplies!);
                  } else {
                    controller.add([]);
                  }
                }
              },
              onError: (error) {
                // On stream error, emit cached data if available
                if (_cachedArchivedSupplies != null) {
                  controller.add(_cachedArchivedSupplies!);
                } else {
                  controller.add([]);
                }
              },
            );
      } catch (e) {
        // If stream creation fails, emit cached data if available
        if (_cachedArchivedSupplies != null) {
          controller.add(_cachedArchivedSupplies!);
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
        if (_cachedArchivedSupplies == null) {
          final hiveData = await _loadArchivedSuppliesFromHive();
          if (hiveData != null) {
            _cachedArchivedSupplies = hiveData; // Populate in-memory cache
            controller.add(hiveData); // Emit immediately
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
}
