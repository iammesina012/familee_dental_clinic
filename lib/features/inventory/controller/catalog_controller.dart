import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';

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

  Stream<List<GroupedInventoryItem>> getAllProductsStream(
      {bool archived = false, bool? expired}) {
    final controller = StreamController<List<GroupedInventoryItem>>.broadcast();
    final cacheKey = 'archived:$archived|expired:${expired ?? 'null'}';

    // Emit cached data immediately if available (prepopulate)
    if (_cachedProducts.containsKey(cacheKey)) {
      controller.add(_cachedProducts[cacheKey]!);
    }

    try {
      _supabase.from('supplies').stream(primaryKey: ['id']).listen(
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
                stock: (row['stock'] ?? 0) as int,
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
            }).where((it) {
              if (it.archived != archived) return false;
              if (expired == false) {
                if (it.expiry == null) return true; // Keep items without expiry
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
              final variants = entry.value;

              List<InventoryItem> candidates = variants
                  .where((v) => !_isExpired(v, today) && v.stock > 0)
                  .toList();
              if (candidates.isEmpty) {
                candidates =
                    variants.where((v) => !_isExpired(v, today)).toList();
              }
              if (candidates.isEmpty) {
                candidates = List<InventoryItem>.from(variants);
              }
              bool hasImage(InventoryItem x) => x.imageUrl.trim().isNotEmpty;
              candidates.sort((a, b) {
                final imgDiff = (hasImage(b) ? 1 : 0) - (hasImage(a) ? 1 : 0);
                if (imgDiff != 0) return imgDiff;
                return a.id.compareTo(b.id);
              });
              final InventoryItem preferred = candidates.first;

              final totalStock = variants.fold(0, (sum, it) => sum + it.stock);
              final preferredId = preferred.id;
              final others =
                  variants.where((v) => v.id != preferredId).toList();

              result.add(
                GroupedInventoryItem(
                  productKey: entry.key,
                  mainItem: preferred,
                  variants: others,
                  totalStock: totalStock,
                ),
              );
            }

            result.sort((a, b) => a.mainItem.name
                .toLowerCase()
                .compareTo(b.mainItem.name.toLowerCase()));

            _cachedProducts[cacheKey] = result;
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
