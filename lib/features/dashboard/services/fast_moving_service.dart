import 'dart:async';
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
  // Singleton pattern to ensure cache persists across widget rebuilds
  static final FastMovingService _instance = FastMovingService._internal();
  factory FastMovingService() => _instance;
  FastMovingService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache for last known data per period (persists across widget rebuilds)
  // Key: period name (Daily, Weekly, Monthly), Value: cached items
  final Map<String, List<FastMovingItem>> _cachedFastMovingItems = {};

  // Cache the last selected period to show appropriate data
  String? _lastSelectedPeriod;

  /// Stream top fast moving items within [window] duration.
  /// Uses activity_logs documents with category == 'Stock Deduction'.
  Stream<List<FastMovingItem>> streamTopFastMovingItems({
    int limit = 5,
    Duration window = const Duration(days: 90),
  }) {
    final controller = StreamController<List<FastMovingItem>>.broadcast();
    final DateTime since = DateTime.now().subtract(window);

    // Determine period name based on window duration
    // Must match _getDurationForPeriod in dashboard_page.dart
    String periodKey = 'Weekly'; // default
    if (window.inDays == 7) {
      periodKey = 'Weekly';
    } else if (window.inDays == 30) {
      periodKey = 'Monthly';
    }
    _lastSelectedPeriod = periodKey;

    // Emit cached data immediately if available (no delay - instant feedback)
    if (_cachedFastMovingItems.containsKey(periodKey)) {
      controller.add(_cachedFastMovingItems[periodKey]!);
    } else if (_lastSelectedPeriod != null &&
        _cachedFastMovingItems.containsKey(_lastSelectedPeriod!)) {
      // Fallback to last cached period if current period has no cache
      controller.add(_cachedFastMovingItems[_lastSelectedPeriod!]!);
    } else if (_cachedFastMovingItems.isNotEmpty) {
      // Fallback to any cached data if available
      controller.add(_cachedFastMovingItems.values.first);
    }

    try {
      _supabase
          .from('activity_logs')
          .stream(primaryKey: ['id'])
          .gte('date', since.toIso8601String())
          .order('date', ascending: false)
          .listen(
            (data) async {
              try {
                // Step 1: Aggregate without type lookups (fast)
                final Map<String, FastMovingItem> aggregates = {};
                final Set<String> uniqueNames =
                    {}; // Collect unique names for batch lookup

                for (final row in data) {
                  final String category = (row['category'] ?? '').toString();
                  final String action = (row['action'] ?? '').toString();
                  if (category != 'Stock Deduction' ||
                      action != 'stock_deduction') {
                    continue;
                  }
                  final Map<String, dynamic> metadata =
                      (row['metadata'] as Map<String, dynamic>?) ?? {};
                  final String name = (metadata['itemName'] ?? '').toString();
                  final String brand = (metadata['brand'] ?? '').toString();
                  if (name.isEmpty) continue;

                  // Collect unique names for batch type lookup later
                  uniqueNames.add(name.trim().toLowerCase());

                  // Temporarily use name only as key (we'll update with type later)
                  final String tempKey = name.trim().toLowerCase();

                  if (!aggregates.containsKey(tempKey)) {
                    aggregates[tempKey] = FastMovingItem(
                      productKey: tempKey,
                      name: name,
                      brand: brand,
                      type: null, // Will be looked up in batch
                      timesDeducted: 1,
                    );
                  } else {
                    final current = aggregates[tempKey]!;
                    aggregates[tempKey] = FastMovingItem(
                      productKey: current.productKey,
                      name: current.name,
                      brand: current.brand, // Keep first brand
                      type: null, // Will be looked up in batch
                      timesDeducted: current.timesDeducted + 1,
                    );
                  }
                }

                // Step 2: Batch fetch all types at once (much faster than individual queries)
                final Map<String, String?> typeCache = {};
                if (uniqueNames.isNotEmpty) {
                  try {
                    // Fetch all non-archived supplies and filter in memory
                    // This is still much faster than individual queries per activity log entry
                    final suppliesResponse = await _supabase
                        .from('supplies')
                        .select('name, type')
                        .eq('archived', false);

                    // Build a cache: for each name, store the first type found
                    // If multiple supplies have same name, prefer the first one
                    for (final supply in suppliesResponse) {
                      final nameKey = (supply['name'] ?? '')
                          .toString()
                          .trim()
                          .toLowerCase();
                      // Only cache types for names we actually need
                      if (nameKey.isNotEmpty &&
                          uniqueNames.contains(nameKey) &&
                          !typeCache.containsKey(nameKey)) {
                        final typeValue = supply['type'];
                        if (typeValue != null &&
                            typeValue.toString().trim().isNotEmpty) {
                          typeCache[nameKey] = typeValue.toString().trim();
                        }
                      }
                    }
                  } catch (e) {
                    // If batch lookup fails, types remain null
                  }
                }

                // Step 3: Update aggregates with types and re-key using name+type
                final Map<String, FastMovingItem> finalAggregates = {};
                for (final item in aggregates.values) {
                  final nameKey = item.name.trim().toLowerCase();
                  final type = typeCache[nameKey];
                  final String typeKey = type != null && type.isNotEmpty
                      ? type.trim().toLowerCase()
                      : '';
                  final String key = '$nameKey|$typeKey';

                  if (!finalAggregates.containsKey(key)) {
                    finalAggregates[key] = FastMovingItem(
                      productKey: key,
                      name: item.name,
                      brand: item.brand,
                      type: type,
                      timesDeducted: item.timesDeducted,
                    );
                  } else {
                    final current = finalAggregates[key]!;
                    // Merge: combine counts
                    finalAggregates[key] = FastMovingItem(
                      productKey: current.productKey,
                      name: current.name,
                      brand: current.brand,
                      type: current.type ?? type,
                      timesDeducted: current.timesDeducted + item.timesDeducted,
                    );
                  }
                }

                final List<FastMovingItem> items =
                    finalAggregates.values.toList();

                items
                    .sort((a, b) => b.timesDeducted.compareTo(a.timesDeducted));

                final result =
                    items.length > limit ? items.sublist(0, limit) : items;

                // Cache the result for this specific period
                _cachedFastMovingItems[periodKey] = result;
                controller.add(result);
              } catch (e) {
                // On error, emit cached data if available for this period or any period
                if (_cachedFastMovingItems.containsKey(periodKey)) {
                  controller.add(_cachedFastMovingItems[periodKey]!);
                } else if (_lastSelectedPeriod != null &&
                    _cachedFastMovingItems.containsKey(_lastSelectedPeriod!)) {
                  controller.add(_cachedFastMovingItems[_lastSelectedPeriod!]!);
                } else if (_cachedFastMovingItems.isNotEmpty) {
                  // Fallback to any cached data if available
                  controller.add(_cachedFastMovingItems.values.first);
                } else {
                  controller.add([]);
                }
              }
            },
            onError: (error) {
              // On stream error, emit cached data if available for this period or any period
              if (_cachedFastMovingItems.containsKey(periodKey)) {
                controller.add(_cachedFastMovingItems[periodKey]!);
              } else if (_lastSelectedPeriod != null &&
                  _cachedFastMovingItems.containsKey(_lastSelectedPeriod!)) {
                controller.add(_cachedFastMovingItems[_lastSelectedPeriod!]!);
              } else if (_cachedFastMovingItems.isNotEmpty) {
                // Fallback to any cached data if available
                controller.add(_cachedFastMovingItems.values.first);
              } else {
                controller.add([]);
              }
            },
          );
    } catch (e) {
      // If stream creation fails, emit cached data if available for this period or any period
      if (_cachedFastMovingItems.containsKey(periodKey)) {
        controller.add(_cachedFastMovingItems[periodKey]!);
      } else if (_lastSelectedPeriod != null &&
          _cachedFastMovingItems.containsKey(_lastSelectedPeriod!)) {
        controller.add(_cachedFastMovingItems[_lastSelectedPeriod!]!);
      } else if (_cachedFastMovingItems.isNotEmpty) {
        // Fallback to any cached data if available
        controller.add(_cachedFastMovingItems.values.first);
      } else {
        controller.add([]);
      }
    }

    return controller.stream;
  }
}
