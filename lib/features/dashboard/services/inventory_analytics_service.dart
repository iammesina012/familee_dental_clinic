import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';

class InventoryAnalyticsService {
  final FirebaseFirestore firestore;

  InventoryAnalyticsService({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  // Get inventory statistics
  Future<Map<String, dynamic>> getInventoryStats() async {
    try {
      // Get all supplies and filter in code
      final snapshot = await firestore.collection('supplies').get();

      final allSupplies = snapshot.docs.map((doc) {
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
      }).toList();

      // Filter out archived supplies
      final supplies = allSupplies.where((supply) => !supply.archived).toList();

      // Calculate statistics
      int totalSupplies = supplies.length;
      int inStock = 0;
      int lowStock = 0;
      int outOfStock = 0;

      // Debug: Print each supply for verification
      print('=== INVENTORY DEBUG ===');
      print('Total supplies (non-archived): $totalSupplies');
      print('All supplies count: ${allSupplies.length}');

      for (var supply in supplies) {
        print(
            'Supply: ${supply.name}, Stock: ${supply.stock}, Archived: ${supply.archived}');

        if (supply.stock == 0) {
          outOfStock++;
          print('  → Out of Stock');
        } else if (supply.stock <= 2) {
          lowStock++;
          print('  → Low Stock');
        } else {
          inStock++;
          print('  → In Stock');
        }
      }

      print(
          'Final counts - In Stock: $inStock, Low Stock: $lowStock, Out of Stock: $outOfStock');
      print('=== END DEBUG ===');

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
      print('Error in getInventoryStats: $e');
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
    return firestore.collection('supplies').snapshots().map((snapshot) {
      final allSupplies = snapshot.docs.map((doc) {
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
    return firestore.collection('supplies').snapshots().map((snapshot) {
      final allSupplies = snapshot.docs.map((doc) {
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
