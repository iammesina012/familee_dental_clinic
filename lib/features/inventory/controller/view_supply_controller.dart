import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:flutter/material.dart';
import 'package:familee_dental/features/activity_log/controller/inventory_activity_controller.dart';

class ViewSupplyController {
  // Singleton pattern to ensure cache persists across widget rebuilds
  static final ViewSupplyController _instance =
      ViewSupplyController._internal();
  factory ViewSupplyController() => _instance;
  ViewSupplyController._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache for last known data per supply ID (persists across widget rebuilds)
  final Map<String, InventoryItem> _cachedSupplies = {};

  Stream<InventoryItem?> supplyStream(String id) {
    final controller = StreamController<InventoryItem?>.broadcast();

    // Emit cached data immediately if available (no delay - instant feedback)
    if (_cachedSupplies.containsKey(id)) {
      controller.add(_cachedSupplies[id]);
    }

    try {
      _supabase.from('supplies').stream(primaryKey: ['id']).eq('id', id).listen(
            (data) {
              try {
                if (data.isEmpty) {
                  controller.add(null);
                  return;
                }
                final row = data.first;
                final item = InventoryItem(
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

                // Cache the result
                _cachedSupplies[id] = item;
                controller.add(item);
              } catch (e) {
                // On error, emit cached data if available
                if (_cachedSupplies.containsKey(id)) {
                  controller.add(_cachedSupplies[id]);
                } else {
                  controller.add(null);
                }
              }
            },
            onError: (error) {
              // On stream error, emit cached data if available
              if (_cachedSupplies.containsKey(id)) {
                controller.add(_cachedSupplies[id]);
              } else {
                controller.add(null);
              }
            },
          );
    } catch (e) {
      // If stream creation fails, emit cached data if available
      if (_cachedSupplies.containsKey(id)) {
        controller.add(_cachedSupplies[id]);
      } else {
        controller.add(null);
      }
    }

    return controller.stream;
  }

  String getStatus(InventoryItem item) {
    // Check archived status first
    if (item.archived) {
      return "Archived";
    }

    // Note: Expired status is now handled by the dedicated Expired Supply page
    // Main inventory system no longer shows expired status

    // For view supply page, show stock status when not expired
    // Using dynamic 20% critical level with tiered thresholds
    if (item.stock == 0) {
      return "Out of Stock";
    } else {
      // Calculate critical level dynamically
      final criticalLevel =
          GroupedInventoryItem.calculateCriticalLevel(item.stock);

      // Primary check: If current stock is at or below its own 20% critical level
      if (criticalLevel > 0 && item.stock <= criticalLevel) {
        return "Low Stock";
      }

      // Extended tiered threshold: stocks <= 5 are likely low (covers 20% of up to 25)
      // This ensures that when stock is deducted (e.g., 20 -> 4), it shows as low stock
      if (item.stock <= 5) {
        return "Low Stock";
      }

      // For stocks > 5, use dynamic calculation
      if (item.stock > 5 && item.stock <= criticalLevel) {
        return "Low Stock";
      }

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
