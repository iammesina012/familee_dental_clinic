import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';

class InventoryAnalyticsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get inventory statistics
  Future<Map<String, dynamic>> getInventoryStats() async {
    try {
      // Get all supplies from Supabase
      final response = await _supabase.from('supplies').select('*');

      final allSupplies = response.map((row) {
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
      }).toList();

      // Filter out archived supplies AND expired supplies (same logic as main inventory page)
      final supplies = allSupplies.where((supply) {
        if (supply.archived) return false;

        // Also filter out expired supplies (same as inventory page)
        if (!supply.noExpiry &&
            supply.expiry != null &&
            supply.expiry!.isNotEmpty) {
          final expiryDate =
              DateTime.tryParse(supply.expiry!.replaceAll('/', '-'));
          if (expiryDate != null) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final dateOnly =
                DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

            if (dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today)) {
              return false; // Filter out expired items
            }
          }
        }

        return true;
      }).toList();

      // Group supplies by product (name + category) to match main inventory logic
      final Map<String, List<InventoryItem>> grouped = {};

      for (final item in supplies) {
        final nameKey = item.name.trim().toLowerCase();
        final categoryKey = item.category.trim().toLowerCase();
        final key = '${nameKey}_${categoryKey}';
        if (!grouped.containsKey(key)) {
          grouped[key] = [];
        }
        grouped[key]!.add(item);
      }

      // Calculate statistics based on total stock per product
      int totalProducts = grouped.length;
      int inStock = 0;
      int lowStock = 0;
      int outOfStock = 0;

      for (final productGroup in grouped.values) {
        // Calculate total stock for this product (excluding expired batches)
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        int totalStock = 0;
        for (final item in productGroup) {
          // Only count non-expired stock
          if (item.noExpiry || item.expiry == null || item.expiry!.isEmpty) {
            totalStock += item.stock;
          } else {
            final expiryDate =
                DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
            if (expiryDate != null) {
              final dateOnly =
                  DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
              if (!(dateOnly.isBefore(today) ||
                  dateOnly.isAtSameMomentAs(today))) {
                totalStock += item.stock; // Only count non-expired stock
              }
            }
          }
        }

        // Determine status based on total stock
        if (totalStock == 0) {
          outOfStock++;
        } else if (totalStock <= 2) {
          lowStock++;
        } else {
          inStock++;
        }
      }

      // Calculate percentages
      double inStockPercentage =
          totalProducts > 0 ? (inStock / totalProducts) * 100 : 0;
      double lowStockPercentage =
          totalProducts > 0 ? (lowStock / totalProducts) * 100 : 0;
      double outOfStockPercentage =
          totalProducts > 0 ? (outOfStock / totalProducts) * 100 : 0;

      return {
        'totalSupplies': totalProducts,
        'inStock': inStock,
        'lowStock': lowStock,
        'outOfStock': outOfStock,
        'inStockPercentage': inStockPercentage.round(),
        'lowStockPercentage': lowStockPercentage.round(),
        'outOfStockPercentage': outOfStockPercentage.round(),
      };
    } catch (e) {
      // Return default values if there's an error
      return {
        'totalSupplies': 0,
        'inStock': 0,
        'lowStock': 0,
        'outOfStock': 0,
        'inStockPercentage': 0,
        'lowStockPercentage': 0,
        'outOfStockPercentage': 0,
      };
    }
  }

  // Stream for real-time updates
  Stream<Map<String, dynamic>> getInventoryStatsStream() {
    return _supabase.from('supplies').stream(primaryKey: ['id']).map((data) {
      final allSupplies = data.map((row) {
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
      }).toList();

      // Filter out archived supplies AND expired supplies (same logic as main inventory page)
      final supplies = allSupplies.where((supply) {
        if (supply.archived) return false;

        // Also filter out expired supplies (same as inventory page)
        if (!supply.noExpiry &&
            supply.expiry != null &&
            supply.expiry!.isNotEmpty) {
          final expiryDate =
              DateTime.tryParse(supply.expiry!.replaceAll('/', '-'));
          if (expiryDate != null) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final dateOnly =
                DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

            if (dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today)) {
              return false; // Filter out expired items
            }
          }
        }

        return true;
      }).toList();

      // Group supplies by product (name + category) to match main inventory logic
      final Map<String, List<InventoryItem>> grouped = {};

      for (final item in supplies) {
        final nameKey = item.name.trim().toLowerCase();
        final categoryKey = item.category.trim().toLowerCase();
        final key = '${nameKey}_${categoryKey}';
        if (!grouped.containsKey(key)) {
          grouped[key] = [];
        }
        grouped[key]!.add(item);
      }

      // Calculate statistics based on total stock per product
      int totalProducts = grouped.length;
      int inStock = 0;
      int lowStock = 0;
      int outOfStock = 0;

      for (final productGroup in grouped.values) {
        // Calculate total stock for this product (excluding expired batches)
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        int totalStock = 0;
        for (final item in productGroup) {
          // Only count non-expired stock
          if (item.noExpiry || item.expiry == null || item.expiry!.isEmpty) {
            totalStock += item.stock;
          } else {
            final expiryDate =
                DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
            if (expiryDate != null) {
              final dateOnly =
                  DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
              if (!(dateOnly.isBefore(today) ||
                  dateOnly.isAtSameMomentAs(today))) {
                totalStock += item.stock; // Only count non-expired stock
              }
            }
          }
        }

        // Determine status based on total stock
        if (totalStock == 0) {
          outOfStock++;
        } else if (totalStock <= 2) {
          lowStock++;
        } else {
          inStock++;
        }
      }

      // Calculate percentages
      double inStockPercentage =
          totalProducts > 0 ? (inStock / totalProducts) * 100 : 0;
      double lowStockPercentage =
          totalProducts > 0 ? (lowStock / totalProducts) * 100 : 0;
      double outOfStockPercentage =
          totalProducts > 0 ? (outOfStock / totalProducts) * 100 : 0;

      return {
        'totalSupplies': totalProducts,
        'inStock': inStock,
        'lowStock': lowStock,
        'outOfStock': outOfStock,
        'inStockPercentage': inStockPercentage.round(),
        'lowStockPercentage': lowStockPercentage.round(),
        'outOfStockPercentage': outOfStockPercentage.round(),
      };
    });
  }

  // Stream for expired and expiring counts
  Stream<Map<String, int>> getExpiryCountsStream() {
    return _supabase.from('supplies').stream(primaryKey: ['id']).map((data) {
      final allSupplies = data.map((row) {
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
        final parsed = DateTime.tryParse(s.expiry!.replaceAll('/', '-'));
        if (parsed == null) continue;
        final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);
        if (dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today)) {
          expired++;
        } else {
          final daysUntil = dateOnly.difference(today).inDays;
          if (daysUntil <= 30) {
            expiring++;
          }
        }
      }

      return {
        'expired': expired,
        'expiring': expiring,
      };
    });
  }
}
