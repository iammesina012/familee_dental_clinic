import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:flutter/material.dart';
import 'package:familee_dental/features/activity_log/controller/inventory_activity_controller.dart';
import 'package:familee_dental/features/inventory/controller/inventory_controller.dart';

class ViewSupplyController {
  // Singleton pattern to ensure cache persists across widget rebuilds
  static final ViewSupplyController _instance =
      ViewSupplyController._internal();
  factory ViewSupplyController() => _instance;
  ViewSupplyController._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache for last known data per supply ID (persists across widget rebuilds)
  final Map<String, InventoryItem> _cachedSupplies = {};

  // Cache for supply types per supply name (persists across widget rebuilds)
  final Map<String, List<String>> _cachedSupplyTypes = {};

  Stream<InventoryItem?> supplyStream(String id) {
    debugPrint('[STREAM_CONTROLLER] Creating supplyStream for ID: $id');
    final controller = StreamController<InventoryItem?>.broadcast();

    // Emit cached data immediately if available (no delay - instant feedback)
    if (_cachedSupplies.containsKey(id)) {
      debugPrint(
          '[STREAM_CONTROLLER] Emitting cached data for ID: $id (${_cachedSupplies[id]?.name})');
      controller.add(_cachedSupplies[id]);
    } else {
      debugPrint('[STREAM_CONTROLLER] No cached data for ID: $id');
    }

    try {
      debugPrint(
          '[STREAM_CONTROLLER] Setting up Supabase stream listener for ID: $id');
      _supabase.from('supplies').stream(primaryKey: ['id']).eq('id', id).listen(
            (data) {
              debugPrint(
                  '[STREAM_CONTROLLER] Stream received data for ID: $id, isEmpty: ${data.isEmpty}');
              try {
                if (data.isEmpty) {
                  debugPrint(
                      '[STREAM_CONTROLLER] Data is empty, emitting null');
                  controller.add(null);
                  return;
                }
                final row = data.first;
                DateTime? createdAt;
                if (row['created_at'] != null) {
                  try {
                    createdAt = DateTime.parse(row['created_at'] as String);
                  } catch (e) {
                    createdAt = null;
                  }
                }
                final item = InventoryItem(
                  id: row['id'] as String,
                  name: row['name'] ?? '',
                  type: row['type'],
                  imageUrl: row['image_url'] ?? '',
                  category: row['category'] ?? '',
                  cost: (row['cost'] ?? 0).toDouble(),
                  stock: (row['stock'] ?? 0).toInt(),
                  lowStockBaseline: row['low_stock_baseline'] != null
                      ? (row['low_stock_baseline'] as num).toInt()
                      : null,
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
                  createdAt: createdAt,
                );

                debugPrint(
                    '[STREAM_CONTROLLER] Parsed item: ${item.name}, Image URL: ${item.imageUrl.isEmpty ? "EMPTY" : item.imageUrl}');
                // Cache the result
                _cachedSupplies[id] = item;
                controller.add(item);
                debugPrint('[STREAM_CONTROLLER] Emitted item to stream');
              } catch (e) {
                debugPrint('[STREAM_CONTROLLER] ERROR parsing data: $e');
                // On error, emit cached data if available
                if (_cachedSupplies.containsKey(id)) {
                  debugPrint(
                      '[STREAM_CONTROLLER] Emitting cached data on error');
                  controller.add(_cachedSupplies[id]);
                } else {
                  debugPrint(
                      '[STREAM_CONTROLLER] No cached data available, emitting null');
                  controller.add(null);
                }
              }
            },
            onError: (error) {
              debugPrint(
                  '[STREAM_CONTROLLER] Stream error for ID: $id, Error: $error');
              // On stream error, emit cached data if available
              if (_cachedSupplies.containsKey(id)) {
                debugPrint(
                    '[STREAM_CONTROLLER] Emitting cached data on stream error');
                controller.add(_cachedSupplies[id]);
              } else {
                debugPrint(
                    '[STREAM_CONTROLLER] No cached data available on stream error, emitting null');
                controller.add(null);
              }
            },
          );
    } catch (e) {
      debugPrint('[STREAM_CONTROLLER] ERROR creating stream: $e');
      // If stream creation fails, emit cached data if available
      if (_cachedSupplies.containsKey(id)) {
        debugPrint(
            '[STREAM_CONTROLLER] Emitting cached data on stream creation error');
        controller.add(_cachedSupplies[id]);
      } else {
        debugPrint(
            '[STREAM_CONTROLLER] No cached data available on stream creation error, emitting null');
        controller.add(null);
      }
    }

    return controller.stream;
  }

  String getStatus(InventoryItem item, {int? totalStock, int? totalBaseline}) {
    // Check archived status first
    if (item.archived) {
      return "Archived";
    }

    // Use grouped logic if totalStock is provided
    if (totalStock != null) {
      // Check expiry status (same logic as GroupedInventoryItem.getStatus)
      if (!item.noExpiry && item.expiry != null && item.expiry!.isNotEmpty) {
        final expiryDate = DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
        if (expiryDate != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final dateOnly =
              DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

          // Check if expired
          if (dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today)) {
            return "Expired";
          }

          // Check if expiring soon (within 30 days) - but only if there's stock
          final daysUntilExpiry = dateOnly.difference(today).inDays;
          if (daysUntilExpiry <= 30 && totalStock > 0) {
            return "Expiring";
          }
        }
      }

      // Check stock status using grouped totals
      if (totalStock == 0) {
        return "Out of Stock";
      }

      // Use manually set threshold for low stock detection
      if (totalBaseline != null &&
          totalBaseline > 0 &&
          totalStock <= totalBaseline) {
        return "Low Stock";
      }

      return "In Stock";
    }

    // Fallback to individual item logic (for backward compatibility)
    // Check expiry status (same logic as GroupedInventoryItem.getStatus)
    if (!item.noExpiry && item.expiry != null && item.expiry!.isNotEmpty) {
      final expiryDate = DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
      if (expiryDate != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dateOnly =
            DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

        // Check if expired
        if (dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today)) {
          return "Expired";
        }

        // Check if expiring soon (within 30 days) - but only if there's stock
        final daysUntilExpiry = dateOnly.difference(today).inDays;
        if (daysUntilExpiry <= 30 && item.stock > 0) {
          return "Expiring";
        }
      }
    }

    // Check stock status only
    if (item.stock == 0) {
      return "Out of Stock";
    }

    // Use manually set threshold for low stock detection
    if (item.lowStockBaseline != null &&
        item.lowStockBaseline! > 0 &&
        item.stock <= item.lowStockBaseline!) {
      return "Low Stock";
    }

    return "In Stock";
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

  // Invalidate cache for a specific supply name (useful when new types are added)
  void invalidateSupplyTypesCache(String supplyName) {
    debugPrint('[STREAM_CONTROLLER] Invalidating cache for: $supplyName');
    _cachedSupplyTypes.remove(supplyName);
  }

  // Get all types for a supply name with caching
  Future<List<String>> getSupplyTypes(String supplyName) async {
    debugPrint('[STREAM_CONTROLLER] getSupplyTypes called for: $supplyName');

    // Return cached data immediately if available
    if (_cachedSupplyTypes.containsKey(supplyName)) {
      debugPrint(
          '[STREAM_CONTROLLER] Returning cached types for: $supplyName (${_cachedSupplyTypes[supplyName]!.length} types)');
      return _cachedSupplyTypes[supplyName]!;
    }

    try {
      debugPrint(
          '[STREAM_CONTROLLER] Fetching types from Supabase for: $supplyName');
      // Add timeout to prevent blocking when offline
      List<Map<String, dynamic>> response;
      try {
        response = await _supabase
            .from('supplies')
            .select('type')
            .eq('name', supplyName)
            .eq('archived', false)
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint(
            '[STREAM_CONTROLLER] getSupplyTypes TIMEOUT or ERROR after 2s for: $supplyName');
        // Return cached data if available, otherwise empty list
        if (_cachedSupplyTypes.containsKey(supplyName)) {
          debugPrint(
              '[STREAM_CONTROLLER] Returning cached types on timeout for: $supplyName');
          return _cachedSupplyTypes[supplyName]!;
        }
        return [];
      }

      final types = <String>[];
      for (final row in response) {
        final type = row['type'] as String?;
        if (type != null && type.isNotEmpty && !types.contains(type)) {
          types.add(type);
        }
      }

      // Cache the result
      _cachedSupplyTypes[supplyName] = types;
      debugPrint(
          '[STREAM_CONTROLLER] Cached ${types.length} types for: $supplyName');
      return types;
    } catch (e) {
      debugPrint(
          '[STREAM_CONTROLLER] Error getting supply types for $supplyName: $e');
      // On error, return cached data if available
      if (_cachedSupplyTypes.containsKey(supplyName)) {
        debugPrint(
            '[STREAM_CONTROLLER] Returning cached types on error for: $supplyName');
        return _cachedSupplyTypes[supplyName]!;
      }
      return [];
    }
  }

  // Get a supply by name and type with caching
  Future<InventoryItem?> getSupplyByNameAndType(
      String supplyName, String type) async {
    debugPrint(
        '[STREAM_CONTROLLER] getSupplyByNameAndType called for: $supplyName, type: $type');

    // First, try to find in cached supplies from InventoryController
    final inventoryController = InventoryController();
    final cachedSupplies = inventoryController.getCachedSupplies();
    if (cachedSupplies != null) {
      final found = cachedSupplies.firstWhere(
        (item) =>
            item.name == supplyName &&
            item.type == type &&
            item.archived == false,
        orElse: () => InventoryItem(
          id: '',
          name: '',
          type: null,
          imageUrl: '',
          category: '',
          cost: 0,
          stock: 0,
          lowStockBaseline: null,
          unit: '',
          supplier: '',
          brand: '',
          expiry: null,
          noExpiry: false,
          archived: false,
        ),
      );
      if (found.id.isNotEmpty) {
        debugPrint(
            '[STREAM_CONTROLLER] Found supply in cache: ${found.name} (${found.type})');
        // Also cache it in our local cache
        _cachedSupplies[found.id] = found;
        return found;
      }
    }

    // Also check our local cache by searching through cached items
    for (final item in _cachedSupplies.values) {
      if (item.name == supplyName &&
          item.type == type &&
          item.archived == false) {
        debugPrint(
            '[STREAM_CONTROLLER] Found supply in local cache: ${item.name} (${item.type})');
        return item;
      }
    }

    // If not in cache, try to fetch from Supabase with timeout
    try {
      debugPrint(
          '[STREAM_CONTROLLER] Fetching supply from Supabase: $supplyName, type: $type');
      List<Map<String, dynamic>> response;
      try {
        response = await _supabase
            .from('supplies')
            .select('*')
            .eq('name', supplyName)
            .eq('type', type)
            .eq('archived', false)
            .limit(1)
            .timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint(
            '[STREAM_CONTROLLER] getSupplyByNameAndType TIMEOUT or ERROR after 2s');
        // Return null if not found in cache and query fails
        return null;
      }

      if (response.isNotEmpty) {
        final row = response.first;
        final item = InventoryItem(
          id: row['id'] as String,
          name: row['name'] ?? '',
          type: row['type'],
          imageUrl: row['image_url'] ?? '',
          category: row['category'] ?? '',
          cost: (row['cost'] ?? 0).toDouble(),
          stock: (row['stock'] ?? 0).toInt(),
          lowStockBaseline: row['low_stock_baseline'] != null
              ? (row['low_stock_baseline'] as num).toInt()
              : null,
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
        _cachedSupplies[item.id] = item;
        debugPrint(
            '[STREAM_CONTROLLER] Cached supply: ${item.name} (${item.type})');
        return item;
      }
      return null;
    } catch (e) {
      debugPrint(
          '[STREAM_CONTROLLER] Error getting supply by name and type: $e');
      return null;
    }
  }
}
