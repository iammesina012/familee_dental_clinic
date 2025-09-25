import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';
import 'package:flutter/material.dart';
import 'package:projects/features/activity_log/controller/inventory_activity_controller.dart';

class ViewSupplyController {
  final SupabaseClient _supabase = Supabase.instance.client;

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
    final supplyResponse =
        await _supabase.from('supplies').select('*').eq('id', docId).single();

    if (supplyResponse.isEmpty) return;

    final String name = (supplyResponse['name'] ?? '').toString();

    // Archive all stocks that share the same name
    await _supabase
        .from('supplies')
        .update({'archived': true}).eq('name', name);

    // Log the archive activity for the initiating item (single log to avoid spam)
    await InventoryActivityController().logInventorySupplyArchived(
      itemName: supplyResponse['name'] ?? 'Unknown Item',
      category: supplyResponse['category'] ?? 'Unknown Category',
      stock: supplyResponse['stock'] ?? 0,
      unit: supplyResponse['unit'] ?? 'Unknown Unit',
      cost: supplyResponse['cost'],
      brand: supplyResponse['brand'],
      supplier: supplyResponse['supplier'],
      expiryDate: supplyResponse['expiry'],
      noExpiry: supplyResponse['no_expiry'] ?? false,
    );
  }

  Future<void> unarchiveSupply(String docId) async {
    // Get initiating doc to determine supply name
    final supplyResponse =
        await _supabase.from('supplies').select('*').eq('id', docId).single();

    if (supplyResponse.isEmpty) return;

    final String name = (supplyResponse['name'] ?? '').toString();

    // Unarchive all stocks sharing the same name
    await _supabase
        .from('supplies')
        .update({'archived': false})
        .eq('name', name)
        .eq('archived', true);

    // Single activity log for the action
    await InventoryActivityController().logInventorySupplyUnarchived(
      itemName: supplyResponse['name'] ?? 'Unknown Item',
      category: supplyResponse['category'] ?? 'Unknown Category',
      stock: supplyResponse['stock'] ?? 0,
      unit: supplyResponse['unit'] ?? 'Unknown Unit',
      cost: supplyResponse['cost'],
      brand: supplyResponse['brand'],
      supplier: supplyResponse['supplier'],
      expiryDate: supplyResponse['expiry'],
      noExpiry: supplyResponse['no_expiry'] ?? false,
    );
  }

  Future<void> deleteSupply(String docId) async {
    // Get initiating doc to determine supply name
    final supplyResponse =
        await _supabase.from('supplies').select('*').eq('id', docId).single();

    if (supplyResponse.isEmpty) return;

    final String name = (supplyResponse['name'] ?? '').toString();

    // Delete all archived stocks sharing the same name
    await _supabase
        .from('supplies')
        .delete()
        .eq('name', name)
        .eq('archived', true);

    // Single activity log
    await InventoryActivityController().logInventorySupplyDeleted(
      itemName: supplyResponse['name'] ?? 'Unknown Item',
      category: supplyResponse['category'] ?? 'Unknown Category',
      stock: supplyResponse['stock'] ?? 0,
      unit: supplyResponse['unit'] ?? 'Unknown Unit',
      cost: supplyResponse['cost'],
      brand: supplyResponse['brand'],
      supplier: supplyResponse['supplier'],
      expiryDate: supplyResponse['expiry'],
      noExpiry: supplyResponse['no_expiry'] ?? false,
    );
  }
}
