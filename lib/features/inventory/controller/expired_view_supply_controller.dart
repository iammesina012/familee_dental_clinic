import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/inventory_item.dart';
import 'package:projects/features/activity_log/controller/inventory_activity_controller.dart';

class ExpiredViewSupplyController {
  /// Get stream of individual supply item from Firebase
  Stream<InventoryItem?> supplyStream(String id) {
    return FirebaseFirestore.instance
        .collection('supplies')
        .doc(id)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
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

    return FirebaseFirestore.instance
        .collection('supplies')
        .where('name', isEqualTo: name)
        .where('brand', isEqualTo: brand)
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
    return FirebaseFirestore.instance
        .collection('supplies')
        .where('name', isEqualTo: productName)
        .where('brand', isEqualTo: brand)
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

  /// Delete supply permanently from Firebase
  Future<void> deleteSupply(String id) async {
    try {
      // Get the item data before deletion for activity log
      final doc =
          await FirebaseFirestore.instance.collection('supplies').doc(id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final item = InventoryItem(
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

        // Delete from Firebase
        await FirebaseFirestore.instance
            .collection('supplies')
            .doc(id)
            .delete();

        // Log the deletion activity
        final activityController = InventoryActivityController();
        await activityController.logInventorySupplyDeleted(
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
