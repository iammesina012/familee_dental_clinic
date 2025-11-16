import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:flutter/material.dart';
import 'package:familee_dental/features/activity_log/controller/inventory_activity_controller.dart';
import 'package:familee_dental/features/inventory/controller/inventory_controller.dart';
import 'package:familee_dental/shared/storage/hive_storage.dart';

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

  // ===== HIVE PERSISTENT CACHE HELPERS =====

  // Load supplies Map from Hive
  Future<Map<String, InventoryItem>?> _loadSuppliesMapFromHive() async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.viewSuppliesBox);
      final jsonStr = box.get('supplies_map') as String?;
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return decoded.map((key, value) => MapEntry(
            key, _inventoryItemFromMap(value as Map<String, dynamic>)));
      }
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
    return null;
  }

  // Save supplies Map to Hive
  Future<void> _saveSuppliesMapToHive(
      Map<String, InventoryItem> supplies) async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.viewSuppliesBox);
      final jsonMap = supplies
          .map((key, value) => MapEntry(key, _inventoryItemToMap(value)));
      await box.put('supplies_map', jsonEncode(jsonMap));
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
  }

  // Load supply types Map from Hive
  Future<Map<String, List<String>>?> _loadSupplyTypesMapFromHive() async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.viewSupplyTypesBox);
      final jsonStr = box.get('supply_types_map') as String?;
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        return decoded.map((key, value) => MapEntry(
            key, (value as List<dynamic>).map((e) => e as String).toList()));
      }
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
    return null;
  }

  // Save supply types Map to Hive
  Future<void> _saveSupplyTypesMapToHive(
      Map<String, List<String>> typesMap) async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.viewSupplyTypesBox);
      await box.put('supply_types_map', jsonEncode(typesMap));
    } catch (e) {
      // Ignore errors - Hive is best effort
    }
  }

  // Helper to convert InventoryItem to Map for JSON
  Map<String, dynamic> _inventoryItemToMap(InventoryItem item) {
    return {
      'id': item.id,
      'name': item.name,
      'type': item.type,
      'imageUrl': item.imageUrl,
      'category': item.category,
      'cost': item.cost,
      'stock': item.stock,
      'lowStockBaseline': item.lowStockBaseline,
      'unit': item.unit,
      'packagingUnit': item.packagingUnit,
      'packagingContent': item.packagingContent,
      'packagingQuantity': item.packagingQuantity,
      'packagingContentQuantity': item.packagingContentQuantity,
      'supplier': item.supplier,
      'brand': item.brand,
      'expiry': item.expiry,
      'noExpiry': item.noExpiry,
      'archived': item.archived,
      'createdAt': item.createdAt?.toIso8601String(),
    };
  }

  // Helper to convert Map to InventoryItem from JSON
  InventoryItem _inventoryItemFromMap(Map<String, dynamic> map) {
    DateTime? createdAt;
    if (map['createdAt'] != null) {
      try {
        createdAt = DateTime.parse(map['createdAt'] as String);
      } catch (e) {
        createdAt = null;
      }
    }
    return InventoryItem(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String?,
      imageUrl: map['imageUrl'] as String? ?? '',
      category: map['category'] as String? ?? '',
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      lowStockBaseline: (map['lowStockBaseline'] as num?)?.toInt(),
      unit: map['unit'] as String? ?? '',
      packagingUnit: map['packagingUnit'] as String?,
      packagingContent: map['packagingContent'] as String?,
      packagingQuantity: (map['packagingQuantity'] as num?)?.toInt(),
      packagingContentQuantity:
          (map['packagingContentQuantity'] as num?)?.toInt(),
      supplier: map['supplier'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      expiry: map['expiry'] as String?,
      noExpiry: map['noExpiry'] as bool? ?? false,
      archived: map['archived'] as bool? ?? false,
      createdAt: createdAt,
    );
  }

  Stream<InventoryItem?> supplyStream(String id) {
    debugPrint('[STREAM_CONTROLLER] Creating supplyStream for ID: $id');
    final controller = StreamController<InventoryItem?>.broadcast();
    StreamSubscription<List<Map<String, dynamic>>>? supabaseSubscription;

    void emitCached() {
      if (_cachedSupplies.containsKey(id)) {
        debugPrint(
            '[STREAM_CONTROLLER] Emitting cached data for ID: $id (${_cachedSupplies[id]?.name})');
        controller.add(_cachedSupplies[id]);
      } else {
        debugPrint('[STREAM_CONTROLLER] No cached data for ID: $id');
      }
    }

    void startSubscription() {
      if (supabaseSubscription != null) return;
      try {
        debugPrint(
            '[STREAM_CONTROLLER] Setting up Supabase stream listener for ID: $id');
        supabaseSubscription = _supabase
            .from('supplies')
            .stream(primaryKey: ['id'])
            .eq('id', id)
            .listen(
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
                  unawaited(
                      _saveSuppliesMapToHive(_cachedSupplies)); // Save to Hive
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
    }

    controller
      ..onListen = () async {
        // 1. Check in-memory cache first
        emitCached();

        // 2. If in-memory cache is null for this ID, auto-load from Hive
        if (!_cachedSupplies.containsKey(id)) {
          final hiveData = await _loadSuppliesMapFromHive();
          if (hiveData != null) {
            _cachedSupplies.addAll(hiveData); // Populate in-memory cache
            if (_cachedSupplies.containsKey(id)) {
              controller.add(_cachedSupplies[id]); // Emit immediately
            }
          }
        }

        // 3. Subscribe to Supabase for updates
        startSubscription();
      }
      ..onCancel = () async {
        if (!controller.hasListener) {
          await supabaseSubscription?.cancel();
          supabaseSubscription = null;
        }
      };

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
    final String type = (supplyResponse['type'] ?? '').toString();

    // Enforce zero-stock rule: sum all active batches for this name+type
    try {
      final List<dynamic> rows = await _supabase
          .from('supplies')
          .select('stock, archived, name, type')
          .eq('name', name)
          .eq('type', type)
          .eq('archived', false);
      int totalActiveStock = 0;
      for (final row in rows) {
        final s = (row['stock'] ?? 0) as int;
        totalActiveStock += s;
      }
      if (totalActiveStock > 0) {
        throw Exception('ARCHIVE_BLOCKED_STOCK_REMAINING');
      }
    } catch (e) {
      // Re-throw to be caught by UI; if it's our sentinel, let it bubble up
      if (e.toString().contains('ARCHIVE_BLOCKED_STOCK_REMAINING')) {
        throw e;
      }
      // If query failed (e.g., offline), propagate error
      rethrow;
    }

    // Archive all stocks that share the same name AND type (only this supply type)
    await _supabase
        .from('supplies')
        .update({'archived': true})
        .eq('name', name)
        .eq('type', type);

    // Invalidate cached type list for this supply name so dropdown updates
    invalidateSupplyTypesCache(name);

    // Log the archive activity for the initiating item (single log to avoid spam)
    await InventoryActivityController().logInventorySupplyArchived(
      itemName: supplyResponse['name'] ?? 'Unknown Item',
      type: supplyResponse['type'],
      category: supplyResponse['category'] ?? 'Unknown Category',
      stock: supplyResponse['stock'] ?? 0,
      unit: supplyResponse['unit'] ?? 'Unknown Unit',
      packagingUnit: supplyResponse['packaging_unit'],
      packagingContent: supplyResponse['packaging_content'],
      packagingContentQuantity:
          supplyResponse['packaging_content_quantity'] != null
              ? (supplyResponse['packaging_content_quantity'] as num).toInt()
              : null,
      cost: supplyResponse['cost'],
      brand: supplyResponse['brand'],
      supplier: supplyResponse['supplier'],
      expiryDate: supplyResponse['expiry'],
      noExpiry: supplyResponse['no_expiry'] ?? false,
      lowStockBaseline: supplyResponse['low_stock_baseline'] != null
          ? (supplyResponse['low_stock_baseline'] as num).toInt()
          : null,
    );
  }

  // Helper to compute total stock for a given supply name+type.
  // If onlyActive = true, sums only non-archived batches; otherwise includes all.
  Future<int> getTotalStockByNameAndType(
    String supplyName,
    String type, {
    bool onlyActive = true,
  }) async {
    final query = _supabase
        .from('supplies')
        .select('stock, archived')
        .eq('name', supplyName)
        .eq('type', type);
    final List<dynamic> rows =
        onlyActive ? await query.eq('archived', false) : await query;
    int total = 0;
    for (final row in rows) {
      final s = (row['stock'] ?? 0) as int;
      total += s;
    }
    return total;
  }

  Future<void> unarchiveSupply(String docId) async {
    // Get initiating doc to determine supply name
    final supplyResponse =
        await _supabase.from('supplies').select('*').eq('id', docId).single();

    if (supplyResponse.isEmpty) return;

    final String name = (supplyResponse['name'] ?? '').toString();
    final String type = (supplyResponse['type'] ?? '').toString();

    // Unarchive all stocks sharing the same name AND type (only this supply type)
    await _supabase
        .from('supplies')
        .update({'archived': false})
        .eq('name', name)
        .eq('type', type)
        .eq('archived', true);

    // Invalidate cached type list so restored type appears again
    invalidateSupplyTypesCache(name);

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
    final String type = (supplyResponse['type'] ?? '').toString();

    // Delete all archived stocks sharing the same name AND type (only this supply type)
    await _supabase
        .from('supplies')
        .delete()
        .eq('name', name)
        .eq('type', type)
        .eq('archived', true);

    // Invalidate cached type list so UI can refresh if needed
    invalidateSupplyTypesCache(name);

    // Single activity log
    await InventoryActivityController().logInventorySupplyDeleted(
      itemName: supplyResponse['name'] ?? 'Unknown Item',
      type: supplyResponse['type'],
      category: supplyResponse['category'] ?? 'Unknown Category',
      stock: supplyResponse['stock'] ?? 0,
      unit: supplyResponse['unit'] ?? 'Unknown Unit',
      packagingUnit: supplyResponse['packaging_unit'],
      packagingContent: supplyResponse['packaging_content'],
      packagingContentQuantity:
          supplyResponse['packaging_content_quantity'] != null
              ? (supplyResponse['packaging_content_quantity'] as num).toInt()
              : null,
      cost: supplyResponse['cost'],
      brand: supplyResponse['brand'],
      supplier: supplyResponse['supplier'],
      expiryDate: supplyResponse['expiry'],
      noExpiry: supplyResponse['no_expiry'] ?? false,
      lowStockBaseline: supplyResponse['low_stock_baseline'] != null
          ? (supplyResponse['low_stock_baseline'] as num).toInt()
          : null,
    );
  }

  // Invalidate cache for a specific supply name (useful when new types are added)
  void invalidateSupplyTypesCache(String supplyName) {
    debugPrint('[STREAM_CONTROLLER] Invalidating cache for: $supplyName');
    _cachedSupplyTypes.remove(supplyName);
    // Also remove from Hive persistent cache to avoid stale dropdowns
    unawaited(() async {
      try {
        final box = await HiveStorage.openBox(HiveStorage.viewSupplyTypesBox);
        final jsonStr = box.get('supply_types_map') as String?;
        if (jsonStr != null) {
          final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (decoded.containsKey(supplyName)) {
            decoded.remove(supplyName);
            await box.put('supply_types_map', jsonEncode(decoded));
            debugPrint(
                '[STREAM_CONTROLLER] Removed "$supplyName" from Hive types cache');
          }
        }
      } catch (e) {
        debugPrint(
            '[STREAM_CONTROLLER] Failed to remove "$supplyName" from Hive types cache: $e');
      }
    }());
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

    // 2. If in-memory cache is null, auto-load from Hive
    final hiveData = await _loadSupplyTypesMapFromHive();
    if (hiveData != null) {
      _cachedSupplyTypes.addAll(hiveData); // Populate in-memory cache
      if (_cachedSupplyTypes.containsKey(supplyName)) {
        debugPrint(
            '[STREAM_CONTROLLER] Returning types from Hive for: $supplyName');
        return _cachedSupplyTypes[supplyName]!;
      }
    }

    // 2b. OFFLINE FALLBACK: derive types from locally cached supplies if Hive had none
    try {
      // First attempt: use the view supplies map cache (targeted for view flows)
      final suppliesMap = await _loadSuppliesMapFromHive();
      List<String> derived = [];
      if (suppliesMap != null && suppliesMap.isNotEmpty) {
        derived = suppliesMap.values
            .where((it) =>
                it.name.trim().toLowerCase() == supplyName.trim().toLowerCase())
            .map((it) => (it.type ?? '').trim())
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
      }

      // Second attempt: use the main inventory cached supplies (broader cache)
      if (derived.isEmpty) {
        try {
          final invItems =
              await InventoryController().getSuppliesStream().first;
          derived = invItems
              .where((it) =>
                  it.name.trim().toLowerCase() ==
                  supplyName.trim().toLowerCase())
              .map((it) => (it.type ?? '').trim())
              .where((t) => t.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
        } catch (_) {
          // best effort; ignore
        }
      }

      if (derived.isNotEmpty) {
        _cachedSupplyTypes[supplyName] = derived;
        // Persist to Hive so future offline sessions show immediately
        unawaited(_saveSupplyTypesMapToHive(_cachedSupplyTypes));
        debugPrint(
            '[STREAM_CONTROLLER] Derived ${derived.length} types from local cache for: $supplyName');
        return derived;
      }
    } catch (_) {
      // best effort; continue to online attempt below
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
      unawaited(_saveSupplyTypesMapToHive(_cachedSupplyTypes)); // Save to Hive
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
