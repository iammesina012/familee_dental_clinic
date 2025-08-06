import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/inventory_item.dart';
import 'package:flutter/material.dart';

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

    // For view supply page, only show stock status (no expiry chips)
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
    await FirebaseFirestore.instance
        .collection('supplies')
        .doc(docId)
        .update({'archived': true});
  }

  Future<void> unarchiveSupply(String docId) async {
    await FirebaseFirestore.instance
        .collection('supplies')
        .doc(docId)
        .update({'archived': false});
  }

  Future<void> deleteSupply(String docId) async {
    await FirebaseFirestore.instance.collection('supplies').doc(docId).delete();
  }
}
