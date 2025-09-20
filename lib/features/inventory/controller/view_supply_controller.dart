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

    // Note: Expired status is now handled by the dedicated Expired Supply page
    // Main inventory system no longer shows expired status

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
    // Get supply data before archiving for activity logging and name-based bulk archive
    final suppliesRef = FirebaseFirestore.instance.collection('supplies');
    final supplyDoc = await suppliesRef.doc(docId).get();

    if (!supplyDoc.exists) return;

    final supplyData = supplyDoc.data() as Map<String, dynamic>;
    final String name = (supplyData['name'] ?? '').toString();

    // Archive all stocks that share the same name
    final query = await suppliesRef.where('name', isEqualTo: name).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'archived': true});
    }
    await batch.commit();

    // Log the archive activity for the initiating item (single log to avoid spam)
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

  Future<void> unarchiveSupply(String docId) async {
    // Get initiating doc to determine supply name
    final suppliesRef = FirebaseFirestore.instance.collection('supplies');
    final supplyDoc = await suppliesRef.doc(docId).get();

    if (!supplyDoc.exists) return;

    final supplyData = supplyDoc.data() as Map<String, dynamic>;
    final String name = (supplyData['name'] ?? '').toString();

    // Unarchive all stocks sharing the same name
    final query = await suppliesRef
        .where('name', isEqualTo: name)
        .where('archived', isEqualTo: true)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'archived': false});
    }
    await batch.commit();

    // Single activity log for the action
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

  Future<void> deleteSupply(String docId) async {
    // Get initiating doc to determine supply name
    final suppliesRef = FirebaseFirestore.instance.collection('supplies');
    final supplyDoc = await suppliesRef.doc(docId).get();

    if (!supplyDoc.exists) return;

    final supplyData = supplyDoc.data() as Map<String, dynamic>;
    final String name = (supplyData['name'] ?? '').toString();

    // Delete all archived stocks sharing the same name
    final query = await suppliesRef
        .where('name', isEqualTo: name)
        .where('archived', isEqualTo: true)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in query.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // Single activity log
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
