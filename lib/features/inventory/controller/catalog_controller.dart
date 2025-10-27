import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';

/// CatalogController provides a product catalog stream that includes
/// all non-archived products regardless of expiry/stock.
/// This is intended for pickers like Purchase Order and Stock Deduction,
/// so users can still find products even if all current batches are expired.
class CatalogController {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<List<GroupedInventoryItem>> getAllProductsStream(
      {bool archived = false, bool? expired}) {
    return _supabase.from('supplies').stream(primaryKey: ['id']).map((data) {
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
        return true;
      }).toList();

      // Group by product key: NAME ONLY (normalized)
      final Map<String, List<InventoryItem>> byProduct = {};
      for (final it in items) {
        final key = (it.name).trim().toLowerCase();
        byProduct.putIfAbsent(key, () => []).add(it);
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final result = <GroupedInventoryItem>[];
      for (final entry in byProduct.entries) {
        final variants = entry.value;

        // Choose a stable representative to avoid the card "switching" on restocks.
        // 1) Prefer non-expired and in-stock variants
        // 2) Else prefer any non-expired
        // 3) Else any
        // Within the chosen set, pick the one with the smallest doc id for stability.
        List<InventoryItem> candidates = variants
            .where((v) => !_isExpired(v, today) && v.stock > 0)
            .toList();
        if (candidates.isEmpty) {
          // Include placeholders (stock = 0, no expiry) in the fallback
          candidates = variants.where((v) => !_isExpired(v, today)).toList();
        }
        if (candidates.isEmpty) {
          candidates = List<InventoryItem>.from(variants);
        }
        // Prefer items that have an image to avoid blank thumbnails,
        // then use a stable tiebreaker by doc id.
        bool hasImage(InventoryItem x) => x.imageUrl.trim().isNotEmpty;
        candidates.sort((a, b) {
          final imgDiff = (hasImage(b) ? 1 : 0) - (hasImage(a) ? 1 : 0);
          if (imgDiff != 0) return imgDiff;
          return a.id.compareTo(b.id);
        });
        final InventoryItem preferred = candidates.first;

        final totalStock = variants.fold(0, (sum, it) => sum + it.stock);
        final preferredId = preferred.id;
        final others = variants.where((v) => v.id != preferredId).toList();

        result.add(
          GroupedInventoryItem(
            productKey: entry.key,
            mainItem: preferred,
            variants: others,
            totalStock: totalStock,
          ),
        );
      }

      // Sort by name for stable display
      result.sort((a, b) => a.mainItem.name
          .toLowerCase()
          .compareTo(b.mainItem.name.toLowerCase()));
      return result;
    });
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
