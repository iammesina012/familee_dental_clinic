import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';

class ArchiveSupplyController {
  // Singleton pattern to ensure cache persists across widget rebuilds
  static final ArchiveSupplyController _instance =
      ArchiveSupplyController._internal();
  factory ArchiveSupplyController() => _instance;
  ArchiveSupplyController._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache for last known data (persists across widget rebuilds)
  List<InventoryItem>? _cachedArchivedSupplies;

  // Get archived supplies with real-time updates
  Stream<List<InventoryItem>> getArchivedSupplies() {
    final controller = StreamController<List<InventoryItem>>.broadcast();

    // Emit cached data immediately if available (no delay - instant feedback)
    if (_cachedArchivedSupplies != null) {
      controller.add(_cachedArchivedSupplies!);
    }

    try {
      _supabase
          .from('supplies')
          .stream(primaryKey: ['id'])
          .eq('archived', true)
          .listen(
            (data) {
              try {
                final items = data.map((row) {
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
                }).toList();

                // Sort by name in the app instead of in database
                items.sort((a, b) =>
                    a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                // Cache the result
                _cachedArchivedSupplies = items;
                controller.add(items);
              } catch (e) {
                // On error, emit cached data if available
                if (_cachedArchivedSupplies != null) {
                  controller.add(_cachedArchivedSupplies!);
                } else {
                  controller.add([]);
                }
              }
            },
            onError: (error) {
              // On stream error, emit cached data if available
              if (_cachedArchivedSupplies != null) {
                controller.add(_cachedArchivedSupplies!);
              } else {
                controller.add([]);
              }
            },
          );
    } catch (e) {
      // If stream creation fails, emit cached data if available
      if (_cachedArchivedSupplies != null) {
        controller.add(_cachedArchivedSupplies!);
      } else {
        controller.add([]);
      }
    }

    return controller.stream;
  }
}
