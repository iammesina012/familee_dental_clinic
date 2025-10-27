import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/activity_log/controller/inventory_activity_controller.dart';

class ExpiredViewSupplyController {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get stream of individual supply item from Supabase
  Stream<InventoryItem?> supplyStream(String id) {
    return _supabase
        .from('supplies')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((data) {
          if (data.isEmpty) return null;
          final row = data.first;
          return InventoryItem(
            id: row['id'] as String,
            name: row['name'] ?? '',
            type: row['type'],
            imageUrl: row['image_url'] ?? '',
            category: row['category'] ?? '',
            cost: (row['cost'] ?? 0).toDouble(),
            stock: (row['stock'] ?? 0).toInt(),
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
        });
  }

  /// Stream the total stock for a specific expired date of a product (name + brand)
  Stream<int> aggregatedExpiredStockForDate(
      {required String name, required String brand, required String? expiry}) {
    DateTime? normalize(String? value) {
      if (value == null || value.isEmpty) return null;
      return DateTime.tryParse(value) ??
          DateTime.tryParse(value.replaceAll('/', '-'));
    }

    final targetDate = normalize(expiry);

    return _supabase.from('supplies').stream(primaryKey: ['id']).map((data) {
      // Filter by name and brand on the client side
      final filteredData = data
          .where((row) => row['name'] == name && row['brand'] == brand)
          .toList();
      final items = filteredData
          .map((row) {
            return InventoryItem(
              id: row['id'] as String,
              name: row['name'] ?? '',
              type: row['type'],
              imageUrl: row['image_url'] ?? '',
              category: row['category'] ?? '',
              cost: (row['cost'] ?? 0).toDouble(),
              stock: (row['stock'] ?? 0).toInt(),
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
          })
          .where((it) => it.archived == false)
          .toList();

      // Sum stock for items that are expired and match the same date
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int total = 0;
      for (final it in items) {
        if (it.noExpiry || it.expiry == null || it.expiry!.isEmpty) continue;
        final exp = normalize(it.expiry);
        if (exp == null) continue;
        final expOnly = DateTime(exp.year, exp.month, exp.day);
        final isExpired =
            expOnly.isBefore(today) || expOnly.isAtSameMomentAs(today);
        if (!isExpired) continue;
        if (targetDate == null) continue;
        final targetOnly =
            DateTime(targetDate.year, targetDate.month, targetDate.day);
        if (expOnly == targetOnly) {
          total += it.stock;
        }
      }
      return total;
    });
  }

  /// Get stream of other expired batches of the same product (same name + brand)
  Stream<List<InventoryItem>> getOtherExpiredBatchesStream(
      String productName, String brand, String currentItemId) {
    return _supabase.from('supplies').stream(primaryKey: ['id']).map((data) {
      // Filter by name and brand on the client side
      final filteredData = data
          .where((row) => row['name'] == productName && row['brand'] == brand)
          .toList();
      final items = filteredData
          .map((row) {
            return InventoryItem(
              id: row['id'] as String,
              name: row['name'] ?? '',
              type: row['type'],
              imageUrl: row['image_url'] ?? '',
              category: row['category'] ?? '',
              cost: (row['cost'] ?? 0).toDouble(),
              stock: (row['stock'] ?? 0).toInt(),
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
          })
          .where((it) => it.archived == false)
          .toList();

      // Filter for expired items only and exclude current item
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      return items.where((item) {
        // Exclude current item
        if (item.id == currentItemId) return false;

        // Check if item is expired
        if (item.noExpiry || item.expiry == null || item.expiry!.isEmpty) {
          return false;
        }

        final expiryDate = DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
        if (expiryDate == null) return false;

        final dateOnly =
            DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
        return dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today);
      }).toList();
    });
  }

  /// Delete supply permanently from Supabase
  Future<void> deleteSupply(String id) async {
    try {
      // Get the item data before deletion for activity log
      final itemResponse =
          await _supabase.from('supplies').select('*').eq('id', id).single();

      if (itemResponse.isNotEmpty) {
        final item = InventoryItem(
          id: itemResponse['id'] as String,
          name: itemResponse['name'] ?? '',
          imageUrl: itemResponse['image_url'] ?? '',
          category: itemResponse['category'] ?? '',
          cost: (itemResponse['cost'] ?? 0).toDouble(),
          stock: (itemResponse['stock'] ?? 0).toInt(),
          unit: itemResponse['unit'] ?? '',
          supplier: itemResponse['supplier'] ?? '',
          brand: itemResponse['brand'] ?? '',
          expiry: itemResponse['expiry'],
          noExpiry: itemResponse['no_expiry'] ?? false,
          archived: itemResponse['archived'] ?? false,
        );

        // Determine whether this is the last batch for the product (same name + brand)
        final siblings = await _supabase
            .from('supplies')
            .select('id')
            .eq('name', item.name)
            .eq('brand', item.brand);

        final bool hasOtherBatches = siblings.any((row) => row['id'] != id);

        if (hasOtherBatches) {
          // Safe to delete this expired batch only
          await _supabase.from('supplies').delete().eq('id', id);
        } else {
          // This is the last batch of the product. Convert to a placeholder
          // so the product remains visible in catalog/pickers with 0 stock.
          await _supabase.from('supplies').update({
            'stock': 0,
            'no_expiry': true,
            'expiry': null,
          }).eq('id', id);
        }

        // Log the disposal of an expired supply
        final activityController = InventoryActivityController();
        await activityController.logExpiredSupplyDisposed(
          itemName: item.name,
          category: item.category,
          stock: item.stock,
          unit: item.unit,
          cost: item.cost,
          brand: item.brand,
          supplier: item.supplier,
          expiryDate: item.expiry,
          noExpiry: item.noExpiry,
        );
      }
    } catch (e) {
      throw Exception('Failed to delete supply: $e');
    }
  }

  /// Get status for expired items (always returns "Expired")
  String getStatus(InventoryItem item) {
    return "Expired";
  }

  /// Get status background color for expired items
  Color getStatusBgColor(String status) {
    switch (status) {
      case "Expired":
        return const Color(0xFFFFCDD2); // Red background for expired
      default:
        return Colors.red[100]!;
    }
  }
}
