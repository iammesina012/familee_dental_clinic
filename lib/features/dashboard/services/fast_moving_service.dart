import 'package:supabase_flutter/supabase_flutter.dart';

class FastMovingItem {
  final String productKey;
  final String name;
  final String brand;
  final String? type;
  final int timesDeducted;

  FastMovingItem({
    required this.productKey,
    required this.name,
    required this.brand,
    this.type,
    required this.timesDeducted,
  });
}

class FastMovingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Stream top fast moving items within [window] duration.
  /// Uses activity_logs documents with category == 'Stock Deduction'.
  Stream<List<FastMovingItem>> streamTopFastMovingItems({
    int limit = 5,
    Duration window = const Duration(days: 90),
  }) {
    final DateTime since = DateTime.now().subtract(window);

    return _supabase
        .from('activity_logs')
        .stream(primaryKey: ['id'])
        .gte('date', since.toIso8601String())
        .order('date', ascending: false)
        .asyncMap((data) async {
          final Map<String, FastMovingItem> aggregates = {};

          for (final row in data) {
            final String category = (row['category'] ?? '').toString();
            final String action = (row['action'] ?? '').toString();
            if (category != 'Stock Deduction' || action != 'stock_deduction') {
              continue;
            }
            final Map<String, dynamic> metadata =
                (row['metadata'] as Map<String, dynamic>?) ?? {};
            final String name = (metadata['itemName'] ?? '').toString();
            final String brand = (metadata['brand'] ?? '').toString();
            if (name.isEmpty) continue;
            final String key =
                '${name.trim().toLowerCase()}|${brand.trim().toLowerCase()}';

            // Look up type from supplies table
            String? type;
            try {
              final supplyResponse = await _supabase
                  .from('supplies')
                  .select('type')
                  .eq('name', name)
                  .eq('brand', brand)
                  .eq('archived', false)
                  .limit(1)
                  .maybeSingle();
              if (supplyResponse != null && supplyResponse['type'] != null) {
                final typeValue = supplyResponse['type'];
                if (typeValue != null &&
                    typeValue.toString().trim().isNotEmpty) {
                  type = typeValue.toString().trim();
                }
              }
            } catch (e) {
              // If lookup fails, type remains null
            }

            if (!aggregates.containsKey(key)) {
              aggregates[key] = FastMovingItem(
                productKey: key,
                name: name,
                brand: brand,
                type: type,
                timesDeducted: 1,
              );
            } else {
              final current = aggregates[key]!;
              aggregates[key] = FastMovingItem(
                productKey: current.productKey,
                name: current.name,
                brand: current.brand,
                type: current.type ?? type, // Use existing type or new one
                timesDeducted: current.timesDeducted + 1,
              );
            }
          }

          final List<FastMovingItem> items = aggregates.values.toList()
            ..sort((a, b) => b.timesDeducted.compareTo(a.timesDeducted));

          if (items.length > limit) {
            return items.sublist(0, limit);
          }
          return items;
        });
  }
}
