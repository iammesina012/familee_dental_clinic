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

      // Filter out archived supplies
      final supplies = allSupplies.where((supply) => !supply.archived).toList();

      // Calculate statistics
      int totalSupplies = supplies.length;
      int inStock = 0;
      int lowStock = 0;
      int outOfStock = 0;

      for (var supply in supplies) {
        if (supply.stock == 0) {
          outOfStock++;
        } else if (supply.stock <= 2) {
          lowStock++;
        } else {
          inStock++;
        }
      }

      // Calculate percentages
      double inStockPercentage =
          totalSupplies > 0 ? (inStock / totalSupplies) * 100 : 0;
      double lowStockPercentage =
          totalSupplies > 0 ? (lowStock / totalSupplies) * 100 : 0;
      double outOfStockPercentage =
          totalSupplies > 0 ? (outOfStock / totalSupplies) * 100 : 0;

      return {
        'totalSupplies': totalSupplies,
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

      // Filter out archived supplies
      final supplies = allSupplies.where((supply) => !supply.archived).toList();

      // Calculate statistics
      int totalSupplies = supplies.length;
      int inStock = 0;
      int lowStock = 0;
      int outOfStock = 0;

      for (var supply in supplies) {
        if (supply.stock == 0) {
          outOfStock++;
        } else if (supply.stock <= 2) {
          lowStock++;
        } else {
          inStock++;
        }
      }

      // Calculate percentages
      double inStockPercentage =
          totalSupplies > 0 ? (inStock / totalSupplies) * 100 : 0;
      double lowStockPercentage =
          totalSupplies > 0 ? (lowStock / totalSupplies) * 100 : 0;
      double outOfStockPercentage =
          totalSupplies > 0 ? (outOfStock / totalSupplies) * 100 : 0;

      return {
        'totalSupplies': totalSupplies,
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
