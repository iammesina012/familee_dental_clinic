import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/activity_log/controller/inventory_activity_controller.dart';

class ExpiredSupplyController {
  // Singleton pattern to ensure cache persists across widget rebuilds
  static final ExpiredSupplyController _instance =
      ExpiredSupplyController._internal();
  factory ExpiredSupplyController() => _instance;
  ExpiredSupplyController._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache for last known data (persists across widget rebuilds)
  List<InventoryItem>? _cachedSupplies;

  /// Get stream of supplies from Supabase with database filtering for better realtime performance
  Stream<List<InventoryItem>> getSuppliesStream({bool archived = false}) {
    final controller = StreamController<List<InventoryItem>>.broadcast();

    // Emit cached data immediately if available (no delay - instant feedback)
    if (_cachedSupplies != null) {
      List<InventoryItem> filtered =
          _cachedSupplies!.where((item) => item.archived == archived).toList();
      controller.add(filtered);
    }

    try {
      _supabase
          .from('supplies')
          .stream(primaryKey: ['id'])
          .eq('archived', archived)
          .listen(
            (data) {
              try {
                final items = data.map((row) {
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
                    packagingContentQuantity: row['packaging_content_quantity'],
                    supplier: row['supplier'] ?? '',
                    brand: row['brand'] ?? '',
                    expiry: row['expiry'],
                    noExpiry: row['no_expiry'] ?? false,
                    archived: row['archived'] ?? false,
                  );
                }).toList();

                // Cache all supplies (before filtering)
                _cachedSupplies = items;
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

      // Group by name + brand to find products
      final Map<String, List<InventoryItem>> productGroups = {};
      for (final item in allItems) {
        final key = '${item.name}_${item.brand}';
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

        // If there are expired items and no non-expired items, convert the first expired item to placeholder
        if (expiredItems.isNotEmpty && nonExpiredItems.isEmpty) {
          final firstExpired = expiredItems.first;

          // Check if there are other batches of the same product (not just in this group)
          final allBatches = await _supabase
              .from('supplies')
              .select('id')
              .eq('name', firstExpired.name)
              .eq('brand', firstExpired.brand);

          final bool hasOtherBatches =
              allBatches.any((row) => row['id'] != firstExpired.id);

          if (!hasOtherBatches) {
            // Check if placeholder already exists
            final existingPlaceholders = await _supabase
                .from('supplies')
                .select('id')
                .eq('name', firstExpired.name)
                .eq('brand', firstExpired.brand)
                .eq('stock', 0)
                .eq('no_expiry', true);

            if (existingPlaceholders.isEmpty) {
              // This is the last batch of the product. Create a NEW placeholder item
              // without modifying the existing expired supply
              await _supabase.from('supplies').insert({
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
              });

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

  /// Group expired items by product (name + brand) and keep one representative
  /// batch per product. Prefer the latest expired date; if equal, prefer higher stock.
  List<InventoryItem> groupExpiredByProduct(List<InventoryItem> expiredItems) {
    final Map<String, InventoryItem> keyToItem = {};

    DateTime? parseExpiry(String? value) {
      if (value == null || value.isEmpty) return null;
      return DateTime.tryParse(value) ??
          DateTime.tryParse(value.replaceAll('/', '-'));
    }

    for (final item in expiredItems) {
      final key = '${item.name}_${item.brand}';
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
