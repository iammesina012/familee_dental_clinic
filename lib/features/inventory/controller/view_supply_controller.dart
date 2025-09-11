import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/inventory_item.dart';
import 'package:flutter/material.dart';
import 'package:projects/features/activity_log/controller/inventory_activity_controller.dart';

class ViewSupplyController {
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

  String getStatus(InventoryItem item) {
    // Check archived status first
    if (item.archived) {
      return "Archived";
    }

    // If expired, prioritize Expired over stock-based statuses
    if (!item.noExpiry && (item.expiry != null && item.expiry!.isNotEmpty)) {
      final String raw = item.expiry!;
      final String normalized = raw.replaceAll('/', '-');
      final DateTime? date = DateTime.tryParse(normalized);
      if (date != null) {
        final DateTime today = DateTime.now();
        final DateTime todayDateOnly =
            DateTime(today.year, today.month, today.day);
        final DateTime expDateOnly = DateTime(date.year, date.month, date.day);
        // Consider same-day expiry as expired to match grid behavior
        if (expDateOnly.isBefore(todayDateOnly) ||
            expDateOnly.isAtSameMomentAs(todayDateOnly)) {
          return "Expired";
        }
      }
    }

    // For view supply page, show stock status when not expired
    if (item.stock == 0) {
      return "Out of Stock";
    } else if (item.stock <= 2) {
      return "Low Stock";
    } else {
      return "In Stock";
    }
  }

  Color getStatusBgColor(String status) {
    switch (status) {
      case "Archived":
        return const Color(0xFFFFF59D); // Light yellow background
      case "In Stock":
        return Colors.green[100]!;
      case "Low Stock":
        return Colors.orange[100]!;
      case "Expiring":
        return Colors.yellow[100]!;
      case "Out of Stock":
        return const Color(0xFFFFCDD2); // More red background
      default:
        return Colors.red[100]!;
    }
  }

  Color getStatusTextColor(String status) {
    switch (status) {
      case "Archived":
        return const Color(
            0xFFF57C00); // Pure yellow text that complements the background
      case "In Stock":
        return Colors.green;
      case "Low Stock":
        return Colors.orange;
      case "Expiring":
        return Colors.amber[800]!;
      case "Out of Stock":
        return const Color(0xFFFF4747);
      default:
        return Colors.red;
    }
  }

  Future<void> archiveSupply(String docId) async {
    // Get supply data before archiving for activity logging
    final supplyDoc = await FirebaseFirestore.instance
        .collection('supplies')
        .doc(docId)
        .get();

    if (supplyDoc.exists) {
      final supplyData = supplyDoc.data() as Map<String, dynamic>;

      // Archive the supply
      await FirebaseFirestore.instance
          .collection('supplies')
          .doc(docId)
          .update({'archived': true});

      // Log the archive activity
      await InventoryActivityController().logInventorySupplyArchived(
        itemName: supplyData['name'] ?? 'Unknown Item',
        category: supplyData['category'] ?? 'Unknown Category',
        stock: supplyData['stock'] ?? 0,
        unit: supplyData['unit'] ?? 'Unknown Unit',
        cost: supplyData['cost'],
        brand: supplyData['brand'],
        supplier: supplyData['supplier'],
        expiryDate: supplyData['expiryDate'],
        noExpiry: supplyData['noExpiry'] ?? false,
      );
    }
  }

  Future<void> unarchiveSupply(String docId) async {
    // Get supply data before unarchiving for activity logging
    final supplyDoc = await FirebaseFirestore.instance
        .collection('supplies')
        .doc(docId)
        .get();

    if (supplyDoc.exists) {
      final supplyData = supplyDoc.data() as Map<String, dynamic>;

      // Unarchive the supply
      await FirebaseFirestore.instance
          .collection('supplies')
          .doc(docId)
          .update({'archived': false});

      // Log the unarchive activity
      await InventoryActivityController().logInventorySupplyUnarchived(
        itemName: supplyData['name'] ?? 'Unknown Item',
        category: supplyData['category'] ?? 'Unknown Category',
        stock: supplyData['stock'] ?? 0,
        unit: supplyData['unit'] ?? 'Unknown Unit',
        cost: supplyData['cost'],
        brand: supplyData['brand'],
        supplier: supplyData['supplier'],
        expiryDate: supplyData['expiryDate'],
        noExpiry: supplyData['noExpiry'] ?? false,
      );
    }
  }

  Future<void> deleteSupply(String docId) async {
    // Get supply data before deleting for activity logging
    final supplyDoc = await FirebaseFirestore.instance
        .collection('supplies')
        .doc(docId)
        .get();

    if (supplyDoc.exists) {
      final supplyData = supplyDoc.data() as Map<String, dynamic>;

      // Delete the supply
      await FirebaseFirestore.instance
          .collection('supplies')
          .doc(docId)
          .delete();

      // Log the delete activity
      await InventoryActivityController().logInventorySupplyDeleted(
        itemName: supplyData['name'] ?? 'Unknown Item',
        category: supplyData['category'] ?? 'Unknown Category',
        stock: supplyData['stock'] ?? 0,
        unit: supplyData['unit'] ?? 'Unknown Unit',
        cost: supplyData['cost'],
        brand: supplyData['brand'],
        supplier: supplyData['supplier'],
        expiryDate: supplyData['expiryDate'],
        noExpiry: supplyData['noExpiry'] ?? false,
      );
    }
  }
}
