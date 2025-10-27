import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';

class ArchiveSupplyController {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get archived supplies with real-time updates
  Stream<List<InventoryItem>> getArchivedSupplies() {
    return _supabase
        .from('supplies')
        .stream(primaryKey: ['id'])
        .eq('archived', true)
        .map((data) {
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
          items.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          return items;
        });
  }
}
