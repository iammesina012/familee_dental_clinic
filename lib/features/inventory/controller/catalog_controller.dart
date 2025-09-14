import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/inventory_item.dart';

/// CatalogController provides a product catalog stream that includes
/// all non-archived products regardless of expiry/stock.
/// This is intended for pickers like Purchase Order and Stock Deduction,
/// so users can still find products even if all current batches are expired.
class CatalogController {
  Stream<List<GroupedInventoryItem>> getAllProductsStream(
      {bool archived = false}) {
    return FirebaseFirestore.instance
        .collection('supplies')
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return InventoryItem(
              id: doc.id,
              name: data['name'] ?? '',
              imageUrl: data['imageUrl'] ?? '',
              category: data['category'] ?? '',
              cost: (data['cost'] ?? 0).toDouble(),
              stock: (data['stock'] ?? 0) as int,
              unit: data['unit'] ?? '',
              supplier: data['supplier'] ?? '',
              brand: data['brand'] ?? '',
              expiry: data['expiry'],
              noExpiry: data['noExpiry'] ?? false,
              archived: data['archived'] ?? false,
            );
          })
          .where((it) => it.archived == archived)
          .toList();

      // Group by product key (name + brand, case-insensitive)
      final Map<String, List<InventoryItem>> byProduct = {};
      for (final it in items) {
        final key = '${it.name.toLowerCase()}_${it.brand.toLowerCase()}';
        byProduct.putIfAbsent(key, () => []).add(it);
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final result = <GroupedInventoryItem>[];
      for (final entry in byProduct.entries) {
        final variants = entry.value;

        // Prefer a non-expired, in-stock item as the main representative when available
        InventoryItem? preferred;
        for (final v in variants) {
          final isExpired = _isExpired(v, today);
          if (!isExpired && v.stock > 0) {
            preferred = v;
            break;
          }
        }

        // If none found, fall back to any non-expired, or else the first
        preferred ??= variants.firstWhere(
          (v) => !_isExpired(v, today),
          orElse: () => variants.first,
        );

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
