import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/inventory_item.dart';

class ExpiredSupplyController {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get stream of all supplies from Supabase (do not filter by archived in query
  /// to ensure documents without the field are included). Filter archived
  /// client-side instead.
  Stream<List<InventoryItem>> getSuppliesStream({bool archived = false}) {
    return _supabase.from('supplies').stream(primaryKey: ['id']).map((data) {
      return data
          .map((row) {
            return InventoryItem(
              id: row['id'] as String,
              name: row['name'] ?? '',
              imageUrl: row['image_url'] ?? '',
              category: row['category'] ?? '',
              cost: (row['cost'] ?? 0).toDouble(),
              stock: (row['stock'] ?? 0).toInt(),
              unit: row['unit'] ?? '',
              supplier: row['supplier'] ?? '',
              brand: row['brand'] ?? '',
              expiry: row['expiry'],
              noExpiry: row['no_expiry'] ?? false,
              archived: row['archived'] ?? false,
            );
          })
          .where((item) => item.archived == archived)
          .toList();
    });
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
