import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/dashboard/services/inventory_analytics_service.dart';
import 'package:familee_dental/shared/storage/hive_storage.dart';

/// Turnover Item model
class TurnoverItem {
  final String name;
  final String brand;
  final int quantityConsumed;
  final int currentStock;
  final double averageStock;
  final double turnoverRate;

  TurnoverItem({
    required this.name,
    required this.brand,
    required this.quantityConsumed,
    required this.currentStock,
    required this.averageStock,
    required this.turnoverRate,
  });
}

class TurnoverRateService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final InventoryAnalyticsService _analyticsService =
      InventoryAnalyticsService();

  // ===== In-memory cache for Usage Speed (by period) =====
  final Map<String, List<TurnoverItem>> _cachedTurnoverItems = {};
  bool _isPreloadingTurnover = false;

  // ===== HIVE PERSISTENT CACHE HELPERS =====
  Future<List<TurnoverItem>?> _loadTurnoverFromHive(String period) async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.usageSpeedBox);
      final jsonStr = box.get('usage_speed_$period') as String?;
      if (jsonStr == null) return null;
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      return decoded.map((e) {
        final m = e as Map<String, dynamic>;
        return TurnoverItem(
          name: (m['name'] ?? '').toString(),
          brand: (m['brand'] ?? '').toString(),
          quantityConsumed: (m['quantityConsumed'] ?? 0) as int,
          currentStock: (m['currentStock'] ?? 0) as int,
          averageStock: (m['averageStock'] ?? 0.0) as double,
          turnoverRate: (m['turnoverRate'] ?? 0.0) as double,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveTurnoverToHive(
      String period, List<TurnoverItem> items) async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.usageSpeedBox);
      final jsonList = items
          .map((e) => {
                'name': e.name,
                'brand': e.brand,
                'quantityConsumed': e.quantityConsumed,
                'currentStock': e.currentStock,
                'averageStock': e.averageStock,
                'turnoverRate': e.turnoverRate,
              })
          .toList();
      await box.put('usage_speed_$period', jsonEncode(jsonList));
    } catch (_) {
      // best effort
    }
  }

  Future<void> preloadTurnoverPeriods() async {
    if (_isPreloadingTurnover) return;
    _isPreloadingTurnover = true;
    try {
      final periods = ['Monthly', 'Quarterly', 'Yearly'];
      for (final p in periods) {
        if (_cachedTurnoverItems.containsKey(p)) continue;
        final hive = await _loadTurnoverFromHive(p);
        if (hive != null) {
          _cachedTurnoverItems[p] = hive;
          continue;
        }
        final computed = await computeTurnoverItems(p);
        _cachedTurnoverItems[p] = computed;
        unawaited(_saveTurnoverToHive(p, computed));
      }
    } finally {
      _isPreloadingTurnover = false;
    }
  }

  /// Get fixed date range for period (Monthly, Quarterly, Yearly)
  /// Public method to access date ranges from dashboard
  Map<String, DateTime> getDateRangeForPeriod(String period) {
    return _getFixedDateRangeForPeriod(period);
  }

  /// Get fixed date range for period (Monthly, Quarterly, Yearly)
  /// Uses calendar periods: current month, current quarter, current year
  Map<String, DateTime> _getFixedDateRangeForPeriod(String period) {
    final now = DateTime.now();

    switch (period) {
      case 'Monthly':
        // First day of current month to last day of current month
        final startDate = DateTime(now.year, now.month, 1);
        final endDate =
            DateTime(now.year, now.month + 1, 0); // Last day of current month

        return {
          'start': startDate,
          'end': endDate,
        };
      case 'Quarterly':
        // First day of current quarter to last day of current quarter
        final quarter = ((now.month - 1) ~/ 3) + 1; // 1-4
        final quarterStartMonth = (quarter - 1) * 3 + 1; // 1, 4, 7, or 10
        final startDate = DateTime(now.year, quarterStartMonth, 1);
        // Last day of quarter: month 3, 6, 9, or 12
        final quarterEndMonth = quarterStartMonth + 2;
        final endDate = DateTime(
            now.year, quarterEndMonth + 1, 0); // Last day of quarter end month

        return {
          'start': startDate,
          'end': endDate,
        };
      case 'Yearly':
        // First day of current year to last day of current year
        final startDate = DateTime(now.year, 1, 1);
        final endDate = DateTime(now.year, 12, 31);

        return {
          'start': startDate,
          'end': endDate,
        };
      default:
        // Default to Monthly (current month)
        final startDate = DateTime(now.year, now.month, 1);
        final endDate = DateTime(now.year, now.month + 1, 0);

        return {
          'start': startDate,
          'end': endDate,
        };
    }
  }

  /// Fetch all supplies deducted within period with purpose, date, and deduction count
  Future<List<Map<String, dynamic>>> _fetchAllDeductionsWithDetails(
      String period) async {
    try {
      final dateRange = _getFixedDateRangeForPeriod(period);
      final startDate = dateRange['start']!;
      final endDate = dateRange['end']!;

      // Set end date to end of day (23:59:59) to include all records from that day
      final endDateWithTime =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      // Fetch all stock deduction logs within the fixed date range
      final logsResponse = await _supabase
          .from('stock_deduction_logs')
          .select('id, purpose, supplies, created_at')
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDateWithTime.toIso8601String())
          .order('created_at', ascending: false);

      // Aggregate by supply name + brand (matching dashboard behavior)
      // Also track deduction count (frequency) for turnover calculation
      final Map<String, Map<String, dynamic>> aggregates = {};

      for (final log in logsResponse) {
        final purpose = (log['purpose']?.toString() ?? '').trim();
        final createdAtRaw = log['created_at']?.toString();
        DateTime? dateDeducted;
        if (createdAtRaw != null) {
          try {
            dateDeducted = DateTime.parse(createdAtRaw).toLocal();
          } catch (_) {
            // Ignore parse errors
          }
        }

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
                // Create a key for aggregation (name + brand, case-insensitive)
                final key =
                    '${name.toLowerCase().trim()}|${brand.toLowerCase().trim()}';

                if (!aggregates.containsKey(key)) {
                  aggregates[key] = {
                    'name': name,
                    'brand': brand,
                    'purpose': purpose.isEmpty ? 'No Purpose' : purpose,
                    'dateDeducted': dateDeducted,
                    'quantityDeducted': quantityInt,
                    'deductionCount': 1, // Track number of times deducted
                  };
                } else {
                  final current = aggregates[key]!;
                  aggregates[key] = {
                    'name': name,
                    'brand': brand,
                    // Keep the most recent purpose and date
                    'purpose': purpose.isEmpty ? current['purpose'] : purpose,
                    'dateDeducted': dateDeducted != null &&
                            (current['dateDeducted'] == null ||
                                dateDeducted.isAfter(
                                    current['dateDeducted'] as DateTime))
                        ? dateDeducted
                        : current['dateDeducted'],
                    'quantityDeducted':
                        (current['quantityDeducted'] as int) + quantityInt,
                    'deductionCount': (current['deductionCount'] ?? 0) + 1,
                  };
                }
              }
            }
          }
        }
      }

      // Convert to list and sort by quantity deducted (descending) to match dashboard
      final List<Map<String, dynamic>> result = aggregates.values.toList();
      result.sort((a, b) => (b['quantityDeducted'] as int)
          .compareTo(a['quantityDeducted'] as int));

      return result;
    } catch (e) {
      return [];
    }
  }

  /// Fetch all-time deductions (no date filter)
  Future<List<Map<String, dynamic>>> _fetchAllTimeDeductions() async {
    try {
      // Fetch all stock deduction logs (no date filter)
      final logsResponse = await _supabase
          .from('stock_deduction_logs')
          .select('id, purpose, supplies, created_at')
          .order('created_at', ascending: false);

      // Aggregate by supply name + brand (matching dashboard behavior)
      // Also track deduction count (frequency) for turnover calculation
      final Map<String, Map<String, dynamic>> aggregates = {};

      for (final log in logsResponse) {
        final purpose = (log['purpose']?.toString() ?? '').trim();
        final createdAtRaw = log['created_at']?.toString();
        DateTime? dateDeducted;
        if (createdAtRaw != null) {
          try {
            dateDeducted = DateTime.parse(createdAtRaw).toLocal();
          } catch (_) {
            // Ignore parse errors
          }
        }

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
                // Create a key for aggregation (name + brand, case-insensitive)
                final key =
                    '${name.toLowerCase().trim()}|${brand.toLowerCase().trim()}';

                if (!aggregates.containsKey(key)) {
                  aggregates[key] = {
                    'name': name,
                    'brand': brand,
                    'purpose': purpose.isEmpty ? 'No Purpose' : purpose,
                    'dateDeducted': dateDeducted,
                    'quantityDeducted': quantityInt,
                    'deductionCount': 1, // Track number of times deducted
                  };
                } else {
                  final current = aggregates[key]!;
                  aggregates[key] = {
                    'name': name,
                    'brand': brand,
                    // Keep the most recent purpose and date
                    'purpose': purpose.isEmpty ? current['purpose'] : purpose,
                    'dateDeducted': dateDeducted != null &&
                            (current['dateDeducted'] == null ||
                                dateDeducted.isAfter(
                                    current['dateDeducted'] as DateTime))
                        ? dateDeducted
                        : current['dateDeducted'],
                    'quantityDeducted':
                        (current['quantityDeducted'] as int) + quantityInt,
                    'deductionCount': (current['deductionCount'] ?? 0) + 1,
                  };
                }
              }
            }
          }
        }
      }

      // Convert to list and sort by quantity deducted (descending)
      final List<Map<String, dynamic>> result = aggregates.values.toList();
      result.sort((a, b) => (b['quantityDeducted'] as int)
          .compareTo(a['quantityDeducted'] as int));

      return result;
    } catch (e) {
      return [];
    }
  }

  /// Compute turnover items for a given period
  /// Uses historical consumption data to calculate turnover rate
  Future<List<TurnoverItem>> computeTurnoverItems(String period) async {
    try {
      // Fetch deductions for the period
      final deductions = await _fetchAllDeductionsWithDetails(period);

      if (deductions.isEmpty) {
        return [];
      }

      // Fetch all supplies grouped by status (for current stock reference)
      final suppliesByStatus = await _analyticsService.getSuppliesByStatus();

      // Create a map of supplies by name+brand key (case-insensitive)
      // This is optional - we'll include items even if not in current supplies
      final Map<String, Map<String, dynamic>> supplyMap = {};
      if (suppliesByStatus.isNotEmpty) {
        // Flatten all supplies into a single list
        final allSupplies = <Map<String, dynamic>>[];
        for (final statusList in suppliesByStatus.values) {
          if (statusList.isNotEmpty) {
            allSupplies.addAll(statusList);
          }
        }

        for (final supply in allSupplies) {
          final name = (supply['name']?.toString() ?? '').trim();
          final brand = (supply['brand']?.toString() ?? '').trim();
          if (name.isNotEmpty) {
            final key = '${name.toLowerCase()}|${brand.toLowerCase()}';
            // If multiple supplies with same name+brand, aggregate stock
            if (supplyMap.containsKey(key)) {
              final existing = supplyMap[key]!;
              final existingStock = (existing['stock'] ?? 0) as int;
              final newStock = (supply['stock'] ?? 0) as int;
              supplyMap[key] = {
                ...existing,
                'stock': existingStock + newStock,
              };
            } else {
              supplyMap[key] = {
                'name': name,
                'brand': brand,
                'stock': supply['stock'] ?? 0,
              };
            }
          }
        }
      }

      // Match deductions with supplies and compute turnover
      // Only include items that still exist (non-archived) in current supplies
      final List<TurnoverItem> turnoverItems = [];
      final Map<String, bool> processedKeys =
          {}; // Track processed items to avoid duplicates

      for (final deduction in deductions) {
        final name = (deduction['name']?.toString() ?? '').trim();
        final brand = (deduction['brand']?.toString() ?? '').trim();
        final quantityConsumed = (deduction['quantityDeducted'] ?? 0) as int;

        if (name.isEmpty || quantityConsumed <= 0) continue;

        final key = '${name.toLowerCase()}|${brand.toLowerCase()}';

        // Skip if already processed (aggregated by name+brand)
        if (processedKeys.containsKey(key)) continue;
        processedKeys[key] = true;

        final supply = supplyMap[key];
        // Skip items that are no longer present (or archived) in current supplies
        if (supply == null) {
          continue;
        }
        // Use current stock when present
        final currentStock = (supply['stock'] ?? 0) as int;

        // Get deduction count (frequency) for better turnover calculation
        final deductionCount = (deduction['deductionCount'] ?? 1) as int;

        // Historical calculation: opening stock = current stock + quantity consumed
        // This represents the stock level at the start of the period (before consumption)
        final openingStock = currentStock + quantityConsumed;

        // Calculate average stock and turnover rate
        // Use historical consumption data to calculate meaningful turnover
        double averageStock;
        double turnoverRate;

        // Average stock = average of opening and current stock
        averageStock = (openingStock + currentStock) / 2.0;

        // Calculate turnover rate based on consumption and average inventory
        // If currentStock = 0 (fully consumed), the standard formula gives 2.0
        // So we use deduction frequency (how many times it was consumed) as a factor
        if (currentStock == 0 && averageStock > 0) {
          // Fully consumed items: use deduction frequency to differentiate
          // Higher frequency = higher turnover (more active consumption)
          // Base turnover is 2.0, multiply by deduction frequency to show activity
          // Formula: (quantityConsumed / averageStock) * (1 + deductionCount * 0.2)
          // This gives: 1 deduction = 2.4, 2 deductions = 2.8, 5 deductions = 4.0, etc.
          turnoverRate = (quantityConsumed / averageStock) *
              (1.0 + (deductionCount * 0.2));
        } else if (averageStock > 0) {
          // Standard formula: quantity consumed / average stock
          turnoverRate = quantityConsumed / averageStock;
        } else {
          // If average stock is 0 (shouldn't happen, but safety check)
          // Use consumption frequency as turnover indicator
          turnoverRate = deductionCount > 0 ? deductionCount.toDouble() : 0.0;
        }

        turnoverItems.add(TurnoverItem(
          name: name,
          brand: brand,
          quantityConsumed: quantityConsumed,
          currentStock: currentStock,
          averageStock: averageStock,
          turnoverRate: turnoverRate,
        ));
      }

      // Sort by turnover rate (descending) and limit to top 5
      turnoverItems.sort((a, b) => b.turnoverRate.compareTo(a.turnoverRate));
      return turnoverItems.take(5).toList();
    } catch (e) {
      // On error, return empty list
      print('Error computing turnover items: $e');
      return [];
    }
  }

  /// Compute all-time turnover items
  Future<List<TurnoverItem>> computeAllTimeTurnoverItems() async {
    try {
      // Fetch all-time deductions
      final deductions = await _fetchAllTimeDeductions();

      if (deductions.isEmpty) {
        return [];
      }

      // Fetch all supplies grouped by status (for current stock reference)
      final suppliesByStatus = await _analyticsService.getSuppliesByStatus();

      // Create a map of supplies by name+brand key (case-insensitive)
      // This is optional - we'll include items even if not in current supplies
      final Map<String, Map<String, dynamic>> supplyMap = {};
      if (suppliesByStatus.isNotEmpty) {
        // Flatten all supplies into a single list
        final allSupplies = <Map<String, dynamic>>[];
        for (final statusList in suppliesByStatus.values) {
          if (statusList.isNotEmpty) {
            allSupplies.addAll(statusList);
          }
        }

        for (final supply in allSupplies) {
          final name = (supply['name']?.toString() ?? '').trim();
          final brand = (supply['brand']?.toString() ?? '').trim();
          if (name.isNotEmpty) {
            final key = '${name.toLowerCase()}|${brand.toLowerCase()}';
            // If multiple supplies with same name+brand, aggregate stock
            if (supplyMap.containsKey(key)) {
              final existing = supplyMap[key]!;
              final existingStock = (existing['stock'] ?? 0) as int;
              final newStock = (supply['stock'] ?? 0) as int;
              supplyMap[key] = {
                ...existing,
                'stock': existingStock + newStock,
              };
            } else {
              supplyMap[key] = {
                'name': name,
                'brand': brand,
                'stock': supply['stock'] ?? 0,
              };
            }
          }
        }
      }

      // Match deductions with supplies and compute turnover
      // Include ALL items with consumption, even if not in current supplies
      final List<TurnoverItem> turnoverItems = [];
      final Map<String, bool> processedKeys =
          {}; // Track processed items to avoid duplicates

      for (final deduction in deductions) {
        final name = (deduction['name']?.toString() ?? '').trim();
        final brand = (deduction['brand']?.toString() ?? '').trim();
        final quantityConsumed = (deduction['quantityDeducted'] ?? 0) as int;

        if (name.isEmpty || quantityConsumed <= 0) continue;

        final key = '${name.toLowerCase()}|${brand.toLowerCase()}';

        // Skip if already processed (aggregated by name+brand)
        if (processedKeys.containsKey(key)) continue;
        processedKeys[key] = true;

        final supply = supplyMap[key];
        // Use current stock if available, otherwise 0 (item was fully consumed or restocked)
        final currentStock = supply != null ? (supply['stock'] ?? 0) as int : 0;

        // Get deduction count (frequency) for better turnover calculation
        final deductionCount = (deduction['deductionCount'] ?? 1) as int;

        // Historical calculation: opening stock = current stock + quantity consumed
        // This represents the stock level at the start (before all-time consumption)
        final openingStock = currentStock + quantityConsumed;

        // Calculate average stock and turnover rate
        // Use historical consumption data to calculate meaningful turnover
        double averageStock;
        double turnoverRate;

        // Average stock = average of opening and current stock
        averageStock = (openingStock + currentStock) / 2.0;

        // Calculate turnover rate based on consumption and average inventory
        // If currentStock = 0 (fully consumed), the standard formula gives 2.0
        // So we use deduction frequency (how many times it was consumed) as a factor
        if (currentStock == 0 && averageStock > 0) {
          // Fully consumed items: use deduction frequency to differentiate
          // Higher frequency = higher turnover (more active consumption)
          // Base turnover is 2.0, multiply by deduction frequency to show activity
          // Formula: (quantityConsumed / averageStock) * (1 + deductionCount * 0.2)
          // This gives: 1 deduction = 2.4, 2 deductions = 2.8, 5 deductions = 4.0, etc.
          turnoverRate = (quantityConsumed / averageStock) *
              (1.0 + (deductionCount * 0.2));
        } else if (averageStock > 0) {
          // Standard formula: quantity consumed / average stock
          turnoverRate = quantityConsumed / averageStock;
        } else {
          // If average stock is 0 (shouldn't happen, but safety check)
          // Use consumption frequency as turnover indicator
          turnoverRate = deductionCount > 0 ? deductionCount.toDouble() : 0.0;
        }

        turnoverItems.add(TurnoverItem(
          name: name,
          brand: brand,
          quantityConsumed: quantityConsumed,
          currentStock: currentStock,
          averageStock: averageStock,
          turnoverRate: turnoverRate,
        ));
      }

      // Sort by turnover rate (descending) and limit to top 5
      turnoverItems.sort((a, b) => b.turnoverRate.compareTo(a.turnoverRate));
      return turnoverItems.take(5).toList();
    } catch (e) {
      // On error, return empty list
      print('Error computing all-time turnover items: $e');
      return [];
    }
  }
}

extension TurnoverRateServiceStreaming on TurnoverRateService {
  /// Hybrid stream: in-memory -> Hive -> live updates (recompute on changes)
  Stream<List<TurnoverItem>> streamTurnoverItems({required String period}) {
    final controller = StreamController<List<TurnoverItem>>.broadcast();

    void emitCached() {
      if (_cachedTurnoverItems.containsKey(period)) {
        controller.add(_cachedTurnoverItems[period]!);
      }
    }

    void startSubscription() {
      try {
        final range = getDateRangeForPeriod(period);
        final start = range['start']!;
        final end = range['end']!;
        final endWithTime = DateTime(end.year, end.month, end.day, 23, 59, 59);

        _supabase
            .from('stock_deduction_logs')
            .stream(primaryKey: ['id'])
            .gte('created_at', start.toIso8601String())
            .order('created_at', ascending: false)
            .listen(
              (data) async {
                try {
                  // Ensure date values are parsable and within range (no-op; computation follows)
                  data.any((log) {
                    final raw = log['created_at']?.toString();
                    if (raw == null) return false;
                    try {
                      final ts = DateTime.parse(raw);
                      return ts.isAfter(
                              start.subtract(const Duration(seconds: 1))) &&
                          ts.isBefore(
                              endWithTime.add(const Duration(seconds: 1)));
                    } catch (_) {
                      return false;
                    }
                  });

                  // If no logs in range, still recompute which will return [] or values
                  // Use computeTurnoverItems to include supplies info
                  final computed = await computeTurnoverItems(period);
                  _cachedTurnoverItems[period] = computed;
                  unawaited(_saveTurnoverToHive(period, computed));
                  controller.add(computed);
                } catch (_) {
                  emitCached();
                  controller.add(_cachedTurnoverItems[period] ?? []);
                }
              },
              onError: (_) {
                emitCached();
                controller.add(_cachedTurnoverItems[period] ?? []);
              },
            );
      } catch (_) {
        emitCached();
        if (!_cachedTurnoverItems.containsKey(period)) {
          controller.add([]);
        }
      }
    }

    controller
      ..onListen = () async {
        // 1) in-memory
        emitCached();

        // 2) Hive if memory empty
        if (!_cachedTurnoverItems.containsKey(period)) {
          final hive = await _loadTurnoverFromHive(period);
          if (hive != null) {
            _cachedTurnoverItems[period] = hive;
            controller.add(hive);
          }
        }

        // 3) Live updates
        startSubscription();
      }
      ..onCancel = () {};

    return controller.stream;
  }
}

extension TurnoverRateServiceCacheAccess on TurnoverRateService {
  /// Expose cached turnover items for a given period (if any)
  List<TurnoverItem>? getCachedTurnoverItems(String period) {
    return _cachedTurnoverItems[period];
  }
}
