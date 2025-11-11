import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class FastMovingItem {
  final String productKey;
  final String name;
  final String brand;
  final String? type;
  final int quantityDeducted;

  FastMovingItem({
    required this.productKey,
    required this.name,
    required this.brand,
    this.type,
    required this.quantityDeducted,
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
  bool _isPreloading = false;

  // Get fixed date range for period (Monday-Sunday for weekly, first-last day for monthly)
  Map<String, DateTime> _getFixedDateRangeForPeriod(String period) {
    final now = DateTime.now();

    switch (period) {
      case 'Weekly':
        // Get Monday of current week
        final weekday = now.weekday; // 1 = Monday, 7 = Sunday
        final daysFromMonday = weekday - 1;
        final monday = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: daysFromMonday));

        // Get Sunday of current week (6 days after Monday)
        final sunday = monday.add(const Duration(days: 6));

        return {
          'start': monday,
          'end': sunday,
        };
      case 'Monthly':
        // Get first day of current month
        final firstDay = DateTime(now.year, now.month, 1);

        // Get last day of current month
        final lastDay = DateTime(now.year, now.month + 1, 0);

        return {
          'start': firstDay,
          'end': lastDay,
        };
      default:
        // Default to weekly
        final weekday = now.weekday;
        final daysFromMonday = weekday - 1;
        final monday = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: daysFromMonday));
        final sunday = monday.add(const Duration(days: 6));

        return {
          'start': monday,
          'end': sunday,
        };
    }
  }

  Future<void> preloadFastMovingPeriods({int limit = 5}) async {
    if (_isPreloading) return;
    _isPreloading = true;
    try {
      final periods = ['Weekly', 'Monthly'];

      for (final periodKey in periods) {
        if (_cachedFastMovingItems.containsKey(periodKey)) {
          continue;
        }
        final items = await _fetchFastMovingItemsForPeriod(
          periodKey: periodKey,
          limit: limit,
        );
        if (items != null) {
          _cachedFastMovingItems[periodKey] = items;
        }
      }
    } finally {
      _isPreloading = false;
    }
  }

  Future<List<FastMovingItem>?> _fetchFastMovingItemsForPeriod({
    required String periodKey,
    required int limit,
  }) async {
    try {
      final dateRange = _getFixedDateRangeForPeriod(periodKey);
      final startDate = dateRange['start']!;
      final endDate = dateRange['end']!;

      // Set end date to end of day (23:59:59) to include all records from that day
      final endDateWithTime =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      // Fetch from stock_deduction_logs instead of activity_logs
      final List<dynamic> logsResponse = await _supabase
          .from('stock_deduction_logs')
          .select('supplies, created_at')
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDateWithTime.toIso8601String())
          .order('created_at', ascending: false);

      // Aggregate by supply name + brand, summing quantities
      final Map<String, Map<String, dynamic>> aggregates = {};
      final Set<String> uniqueNames = {};

      for (final log in logsResponse) {
        final supplies = log['supplies'] as List<dynamic>?;
        if (supplies != null) {
          for (final supply in supplies) {
            final supplyMap = supply as Map<String, dynamic>?;
            if (supplyMap != null) {
              final name = (supplyMap['name']?.toString() ?? '').trim();
              final brand = (supplyMap['brand']?.toString() ?? '').trim();
              final quantity =
                  supplyMap['deductQty'] ?? supplyMap['quantity'] ?? 0;
              final quantityInt = quantity is num
                  ? quantity.toInt()
                  : (int.tryParse(quantity.toString()) ?? 0);

              if (name.isNotEmpty) {
                final key =
                    '${name.toLowerCase().trim()}|${brand.toLowerCase().trim()}';
                uniqueNames.add(name.toLowerCase().trim());

                if (!aggregates.containsKey(key)) {
                  aggregates[key] = {
                    'name': name,
                    'brand': brand,
                    'quantityDeducted': quantityInt,
                  };
                } else {
                  final current = aggregates[key]!;
                  aggregates[key] = {
                    'name': name,
                    'brand': brand,
                    'quantityDeducted':
                        (current['quantityDeducted'] as int) + quantityInt,
                  };
                }
              }
            }
          }
        }
      }

      // Fetch types (same as before)
      final Map<String, String?> typeCache = {};
      if (uniqueNames.isNotEmpty) {
        try {
          final suppliesResponse = await _supabase
              .from('supplies')
              .select('name, type')
              .eq('archived', false);

          for (final supply in suppliesResponse) {
            final String nameKey =
                (supply['name'] ?? '').toString().trim().toLowerCase();
            if (nameKey.isEmpty ||
                !uniqueNames.contains(nameKey) ||
                typeCache.containsKey(nameKey)) {
              continue;
            }

            final typeValue = supply['type'];
            if (typeValue != null && typeValue.toString().trim().isNotEmpty) {
              typeCache[nameKey] = typeValue.toString().trim();
            }
          }
        } catch (_) {
          // Ignore type lookup failures during preload
        }
      }

      // Create final aggregates with types
      final Map<String, FastMovingItem> finalAggregates = {};
      for (final entry in aggregates.entries) {
        final nameKey = entry.value['name'].toString().trim().toLowerCase();
        final String? type = typeCache[nameKey];
        final String typeKey =
            type != null && type.isNotEmpty ? type.trim().toLowerCase() : '';
        final String key = '$nameKey|$typeKey';

        if (!finalAggregates.containsKey(key)) {
          finalAggregates[key] = FastMovingItem(
            productKey: key,
            name: entry.value['name'],
            brand: entry.value['brand'],
            type: type,
            quantityDeducted: entry.value['quantityDeducted'],
          );
        } else {
          final current = finalAggregates[key]!;
          finalAggregates[key] = FastMovingItem(
            productKey: current.productKey,
            name: current.name,
            brand: current.brand,
            type: current.type ?? type,
            quantityDeducted: current.quantityDeducted +
                (entry.value['quantityDeducted'] as int),
          );
        }
      }

      final List<FastMovingItem> items = finalAggregates.values.toList();
      items.sort((a, b) => b.quantityDeducted.compareTo(a.quantityDeducted));

      return items.length > limit ? items.sublist(0, limit) : items;
    } catch (_) {
      return null;
    }
  }

  /// Stream top fast moving items within [window] duration.
  /// Uses stock_deduction_logs to aggregate quantities deducted.
  /// Note: window duration is used to determine period, but actual data uses fixed date ranges.
  Stream<List<FastMovingItem>> streamTopFastMovingItems({
    int limit = 5,
    Duration window = const Duration(days: 90),
  }) {
    final controller = StreamController<List<FastMovingItem>>.broadcast();

    // Determine period name based on window duration
    // Must match _getDurationForPeriod in dashboard_page.dart
    String periodKey = 'Weekly'; // default
    if (window.inDays <= 8) {
      // Weekly period (7-8 days to account for fixed date range)
      periodKey = 'Weekly';
    } else if (window.inDays <= 32) {
      // Monthly period (28-32 days to account for fixed date range)
      periodKey = 'Monthly';
    }
    _lastSelectedPeriod = periodKey;

    // Get fixed date range for the period
    final dateRange = _getFixedDateRangeForPeriod(periodKey);
    final startDate = dateRange['start']!;
    final endDate = dateRange['end']!;

    // Set end date to end of day (23:59:59) to include all records from that day
    final endDateWithTime =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

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
          .from('stock_deduction_logs')
          .stream(primaryKey: ['id'])
          .gte('created_at', startDate.toIso8601String())
          .order('created_at', ascending: false)
          .listen(
            (data) async {
              try {
                // Filter data to only include records within the fixed date range
                final filteredData = data.where((log) {
                  final createdAtRaw = log['created_at']?.toString();
                  if (createdAtRaw == null) return false;
                  try {
                    final createdAt = DateTime.parse(createdAtRaw);
                    return createdAt.isAfter(
                            startDate.subtract(const Duration(seconds: 1))) &&
                        createdAt.isBefore(
                            endDateWithTime.add(const Duration(seconds: 1)));
                  } catch (_) {
                    return false;
                  }
                }).toList();

                // Aggregate by supply name + brand, summing quantities
                final Map<String, Map<String, dynamic>> aggregates = {};
                final Set<String> uniqueNames = {};

                for (final log in filteredData) {
                  final supplies = log['supplies'] as List<dynamic>?;
                  if (supplies != null) {
                    for (final supply in supplies) {
                      final supplyMap = supply as Map<String, dynamic>?;
                      if (supplyMap != null) {
                        final name =
                            (supplyMap['name']?.toString() ?? '').trim();
                        final brand =
                            (supplyMap['brand']?.toString() ?? '').trim();
                        final quantity = supplyMap['deductQty'] ??
                            supplyMap['quantity'] ??
                            0;
                        final quantityInt = quantity is num
                            ? quantity.toInt()
                            : (int.tryParse(quantity.toString()) ?? 0);

                        if (name.isNotEmpty) {
                          final key =
                              '${name.toLowerCase().trim()}|${brand.toLowerCase().trim()}';
                          uniqueNames.add(name.toLowerCase().trim());

                          if (!aggregates.containsKey(key)) {
                            aggregates[key] = {
                              'name': name,
                              'brand': brand,
                              'quantityDeducted': quantityInt,
                            };
                          } else {
                            final current = aggregates[key]!;
                            aggregates[key] = {
                              'name': name,
                              'brand': brand,
                              'quantityDeducted':
                                  (current['quantityDeducted'] as int) +
                                      quantityInt,
                            };
                          }
                        }
                      }
                    }
                  }
                }

                // Batch fetch all types at once
                final Map<String, String?> typeCache = {};
                if (uniqueNames.isNotEmpty) {
                  try {
                    final suppliesResponse = await _supabase
                        .from('supplies')
                        .select('name, type')
                        .eq('archived', false);

                    for (final supply in suppliesResponse) {
                      final nameKey = (supply['name'] ?? '')
                          .toString()
                          .trim()
                          .toLowerCase();
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

                // Create final aggregates with types
                final Map<String, FastMovingItem> finalAggregates = {};
                for (final entry in aggregates.entries) {
                  final nameKey =
                      entry.value['name'].toString().trim().toLowerCase();
                  final type = typeCache[nameKey];
                  final String typeKey = type != null && type.isNotEmpty
                      ? type.trim().toLowerCase()
                      : '';
                  final String key = '$nameKey|$typeKey';

                  if (!finalAggregates.containsKey(key)) {
                    finalAggregates[key] = FastMovingItem(
                      productKey: key,
                      name: entry.value['name'],
                      brand: entry.value['brand'],
                      type: type,
                      quantityDeducted: entry.value['quantityDeducted'],
                    );
                  } else {
                    final current = finalAggregates[key]!;
                    finalAggregates[key] = FastMovingItem(
                      productKey: current.productKey,
                      name: current.name,
                      brand: current.brand,
                      type: current.type ?? type,
                      quantityDeducted: current.quantityDeducted +
                          (entry.value['quantityDeducted'] as int),
                    );
                  }
                }

                final List<FastMovingItem> items =
                    finalAggregates.values.toList();

                items.sort(
                    (a, b) => b.quantityDeducted.compareTo(a.quantityDeducted));

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
