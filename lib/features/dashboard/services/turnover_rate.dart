import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/dashboard/services/inventory_analytics_service.dart';
import 'package:familee_dental/shared/storage/hive_storage.dart';

/// Turnover Item model
class TurnoverItem {
  final String name;
  final String? type;
  final int quantityConsumed;
  final int currentStock;
  final double averageStock;
  final double turnoverRate;

  TurnoverItem({
    required this.name,
    this.type,
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
          type: m['type']?.toString(),
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
                'type': e.type,
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

      // Aggregate by supply name + type (matching dashboard behavior)
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
              final type = supplyMap['type']?.toString().trim();
              final quantity =
                  supplyMap['deductQty'] ?? supplyMap['quantity'] ?? 0;
              final quantityInt = quantity is num
                  ? quantity.toInt()
                  : (int.tryParse(quantity.toString()) ?? 0);

              if (name.isNotEmpty) {
                // Create a key for aggregation (name + type, case-insensitive)
                final typeKey = (type ?? '').toLowerCase().trim();
                final key = '${name.toLowerCase().trim()}|$typeKey';

                if (!aggregates.containsKey(key)) {
                  aggregates[key] = {
                    'name': name,
                    'type': type,
                    'purpose': purpose.isEmpty ? 'No Purpose' : purpose,
                    'dateDeducted': dateDeducted,
                    'quantityDeducted': quantityInt,
                    'deductionCount': 1, // Track number of times deducted
                  };
                } else {
                  final current = aggregates[key]!;
                  aggregates[key] = {
                    'name': name,
                    'type': type,
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

      // Aggregate by supply name + type (matching dashboard behavior)
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
              final type = supplyMap['type']?.toString().trim();
              final quantity =
                  supplyMap['deductQty'] ?? supplyMap['quantity'] ?? 0;
              final quantityInt = quantity is num
                  ? quantity.toInt()
                  : (int.tryParse(quantity.toString()) ?? 0);

              if (name.isNotEmpty) {
                // Create a key for aggregation (name + type, case-insensitive)
                final typeKey = (type ?? '').toLowerCase().trim();
                final key = '${name.toLowerCase().trim()}|$typeKey';

                if (!aggregates.containsKey(key)) {
                  aggregates[key] = {
                    'name': name,
                    'type': type,
                    'purpose': purpose.isEmpty ? 'No Purpose' : purpose,
                    'dateDeducted': dateDeducted,
                    'quantityDeducted': quantityInt,
                    'deductionCount': 1, // Track number of times deducted
                  };
                } else {
                  final current = aggregates[key]!;
                  aggregates[key] = {
                    'name': name,
                    'type': type,
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
  /// [limit] - Optional limit on number of items to return. If null, returns all items.
  ///           Defaults to 5 for dashboard display.
  Future<List<TurnoverItem>> computeTurnoverItems(String period,
      {int? limit = 5}) async {
    try {
      // Fetch deductions for the period
      final deductions = await _fetchAllDeductionsWithDetails(period);

      if (deductions.isEmpty) {
        return [];
      }

      // Fetch all supplies grouped by status (for current stock reference)
      final suppliesByStatus = await _analyticsService.getSuppliesByStatus();

      // Create a map of supplies by name+type key (case-insensitive)
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

        // CRITICAL: Deduplicate by id to prevent counting the same supply multiple times
        // (A supply should only appear once, but this ensures we don't double-count)
        final seenIds = <String>{};
        final uniqueSupplies = <Map<String, dynamic>>[];
        for (final supply in allSupplies) {
          final id = supply['id']?.toString();
          if (id != null && !seenIds.contains(id)) {
            seenIds.add(id);
            uniqueSupplies.add(supply);
          }
        }

        // CRITICAL: Also filter out expired supplies (similar to inventory view)
        // Only count non-expired supplies for current stock calculation
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final activeSupplies = uniqueSupplies.where((supply) {
          final noExpiry = supply['noExpiry'] as bool? ?? false;
          final expiry = supply['expiry']?.toString();

          if (noExpiry || expiry == null || expiry.isEmpty) {
            return true; // No expiry or no expiry date - include it
          }

          // Check if expired
          try {
            final expiryDate = DateTime.tryParse(expiry.replaceAll('/', '-'));
            if (expiryDate != null) {
              final dateOnly =
                  DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
              // Exclude expired supplies (expired on or before today)
              return dateOnly.isAfter(today);
            }
          } catch (_) {
            // If we can't parse the date, include it to be safe
          }
          return true;
        }).toList();

        for (final supply in activeSupplies) {
          final name = (supply['name']?.toString() ?? '').trim();
          final type = supply['type']?.toString().trim();
          if (name.isNotEmpty) {
            final typeKey = (type ?? '').toLowerCase();
            final key = '${name.toLowerCase()}|$typeKey';
            // If multiple supplies with same name+type, aggregate stock
            if (supplyMap.containsKey(key)) {
              final existing = supplyMap[key]!;
              final existingStock = (existing['stock'] ?? 0) as int;
              final newStock = (supply['stock'] ?? 0) as int;
              supplyMap[key] = {
                ...existing,
                'stock': existingStock + newStock,
                '_key': key,
              };
            } else {
              supplyMap[key] = {
                'name': name,
                'type': type,
                'stock': supply['stock'] ?? 0,
                '_key': key,
              };
            }

            // Also create an entry keyed by name only (for backwards compatibility with deductions that don't have type)
            // BUT: Only create this for supplies that actually have no type (null or empty)
            // CRITICAL FIX: If type is empty, key == nameOnlyKey, so we've already created/updated it above!
            // Don't create it again or we'll double-count the stock.
            final nameOnlyKey = '${name.toLowerCase()}|';
            final hasNoType = type == null || type.isEmpty;

            // Only create nameOnlyKey if it's DIFFERENT from the key we just created
            // (i.e., if type was not empty, so key != nameOnlyKey)
            if (hasNoType && key != nameOnlyKey) {
              // This shouldn't happen (hasNoType means type is empty, so key should == nameOnlyKey)
              // But just in case, handle it safely
              if (!supplyMap.containsKey(nameOnlyKey)) {
                supplyMap[nameOnlyKey] = {
                  'name': name,
                  'type': null, // Explicitly null for supplies without types
                  'stock': supply['stock'] ?? 0,
                  '_isNameOnlyEntry': true,
                  '_key': nameOnlyKey,
                };
              } else {
                // Only aggregate if the existing entry also represents supplies without types
                final existing = supplyMap[nameOnlyKey]!;
                final existingHasNoType = existing['type'] == null ||
                    (existing['type']?.toString().trim().isEmpty ?? true);

                if (existingHasNoType) {
                  final existingStock = (existing['stock'] ?? 0) as int;
                  final newStock = (supply['stock'] ?? 0) as int;
                  supplyMap[nameOnlyKey] = {
                    ...existing,
                    'stock': existingStock + newStock,
                    '_isNameOnlyEntry': true,
                    '_key': nameOnlyKey,
                  };
                }
              }
            }
            // If key == nameOnlyKey (type is empty), we already created/updated it above, so skip
          }
        }
      }

      // CRITICAL: Clean up any incorrectly created nameOnlyKey entries
      // If there are supplies with types for a name, remove the nameOnlyKey entry to prevent aggregation
      final keysToRemove = <String>[];
      for (final entry in supplyMap.entries) {
        final key = entry.key;
        if (key.endsWith('|') && key != '|') {
          // This is a nameOnlyKey (ends with |)
          final nameOnly = key.substring(0, key.length - 1);
          // Check if there are any supplies with types for this name
          bool hasSuppliesWithTypes = false;
          for (final otherEntry in supplyMap.entries) {
            final otherKey = otherEntry.key;
            if (otherKey.startsWith('$nameOnly|') && otherKey != key) {
              // This is a name+type key
              final otherSupply = otherEntry.value;
              final otherType = otherSupply['type']?.toString().trim();
              if (otherType != null && otherType.isNotEmpty) {
                hasSuppliesWithTypes = true;
                break;
              }
            }
          }
          // If there are supplies with types, remove this nameOnlyKey entry
          if (hasSuppliesWithTypes) {
            keysToRemove.add(key);
          }
        }
      }
      // Remove the incorrectly created entries
      for (final key in keysToRemove) {
        supplyMap.remove(key);
      }

      // Match deductions with supplies and compute turnover
      // Only include items that still exist (non-archived) in current supplies
      final List<TurnoverItem> turnoverItems = [];
      final Map<String, bool> processedKeys =
          {}; // Track processed items to avoid duplicates

      for (final deduction in deductions) {
        final name = (deduction['name']?.toString() ?? '').trim();
        final type = deduction['type']?.toString().trim();
        final quantityConsumed = (deduction['quantityDeducted'] ?? 0) as int;

        if (name.isEmpty || quantityConsumed <= 0) continue;

        final typeKey = (type ?? '').toLowerCase();
        final key = '${name.toLowerCase()}|$typeKey';

        // Skip if already processed (aggregated by name+type)
        if (processedKeys.containsKey(key)) continue;
        processedKeys[key] = true;

        // Try to match by name+type first, then fallback to name only for backwards compatibility
        Map<String, dynamic>? supply = supplyMap[key];

        // CRITICAL: If deduction has a type (even if empty string), we should ONLY match against exact name+type key
        // Never fall back to nameOnlyKey for deductions with types, as that would incorrectly aggregate stock
        final deductionHasNoType = type == null || type.isEmpty;

        if (supply == null && deductionHasNoType) {
          // Only try nameOnlyKey if deduction truly has no type
          // BUT: First check if there are ANY supplies with types for this name
          // If there are, we should NOT use nameOnlyKey to avoid incorrect aggregation
          bool hasSuppliesWithTypes = false;
          final nameLower = name.toLowerCase();
          for (final entry in supplyMap.entries) {
            final entryKey = entry.key;
            if (entryKey.startsWith('$nameLower|') &&
                entryKey != '$nameLower|') {
              // This is a name+type key (not nameOnlyKey)
              final entrySupply = entry.value;
              final entryType = entrySupply['type']?.toString().trim();
              if (entryType != null && entryType.isNotEmpty) {
                hasSuppliesWithTypes = true;
                break;
              }
            }
          }

          // Only use nameOnlyKey if there are NO supplies with types for this name
          if (!hasSuppliesWithTypes) {
            final nameOnlyKey = '${name.toLowerCase()}|';
            final nameOnlySupply = supplyMap[nameOnlyKey];

            // Only use this entry if it's a proper name-only entry (not aggregated from multiple types)
            // We require BOTH conditions: no type AND the flag, to ensure it's not aggregated
            if (nameOnlySupply != null) {
              final entryHasNoType = nameOnlySupply['type'] == null ||
                  (nameOnlySupply['type']?.toString().trim().isEmpty ?? true);
              final isNameOnlyEntry =
                  nameOnlySupply['_isNameOnlyEntry'] == true;

              if (entryHasNoType && isNameOnlyEntry) {
                // Double-check: ensure this is truly a name-only entry, not aggregated
                supply = nameOnlySupply;
              }
              // If the entry has a type or doesn't have the flag, it means it was aggregated - don't use it
            }
          }
        }
        // If deduction has a type but no match found, skip it (don't use aggregated entries)

        // Skip items that are no longer present (or archived) in current supplies
        if (supply == null) {
          continue;
        }
        // Use current stock when present
        // CRITICAL: Double-check that we're not using an aggregated entry
        // If this is a nameOnlyKey entry and there are supplies with types, skip it
        final supplyKey = supply['_key'] as String?;
        if (supplyKey != null && supplyKey.endsWith('|')) {
          // This is a nameOnlyKey entry - verify it's safe to use
          final nameLower = name.toLowerCase();
          bool hasSuppliesWithTypes = false;
          for (final entry in supplyMap.entries) {
            final entryKey = entry.key;
            if (entryKey.startsWith('$nameLower|') &&
                entryKey != '$nameLower|') {
              final entrySupply = entry.value;
              final entryType = entrySupply['type']?.toString().trim();
              if (entryType != null && entryType.isNotEmpty) {
                hasSuppliesWithTypes = true;
                break;
              }
            }
          }
          if (hasSuppliesWithTypes) {
            // There are supplies with types - don't use this aggregated entry
            continue;
          }
        }
        final currentStock = (supply['stock'] ?? 0) as int;

        // Debug: Log Gauze stock calculation
        if (name.toLowerCase() == 'gauze') {
          print(
              'DEBUG GAUZE: name=$name, type="$type", key=$key, supplyKey=${supply['_key']}, currentStock=$currentStock, supplyMap keys=${supplyMap.keys.where((k) => k.startsWith('gauze|')).toList()}');
          for (final entry in supplyMap.entries) {
            if (entry.key.startsWith('gauze|')) {
              print(
                  '  - ${entry.key}: stock=${entry.value['stock']}, type=${entry.value['type']}');
            }
          }
        }

        // Historical calculation: opening stock = current stock + quantity consumed
        // This represents the stock level at the start of the period (before consumption)
        final openingStock = currentStock + quantityConsumed;

        // Calculate average stock and turnover rate
        // Use historical consumption data to calculate meaningful turnover
        double averageStock;
        double turnoverRate;

        // Average stock = average of opening and current stock
        averageStock = (openingStock + currentStock) / 2.0;

        // Calculate turnover rate: usageSpeed = qtyConsumed / max(averageStock, 1)
        // Example sanity check:
        //   qtyConsumed = 9, currentStock = 0, openingStock = 9
        //   averageStock = (9 + 0) / 2 = 4.5
        //   turnoverRate = 9 / max(4.5, 1) = 9 / 4.5 = 2.0
        if (averageStock > 0) {
          turnoverRate = quantityConsumed / averageStock;
        } else {
          // If average stock is 0 (shouldn't happen, but safety check)
          // Use quantity consumed directly (with minimum denominator of 1)
          turnoverRate =
              quantityConsumed > 0 ? quantityConsumed.toDouble() : 0.0;
        }

        turnoverItems.add(TurnoverItem(
          name: name,
          type: type,
          quantityConsumed: quantityConsumed,
          currentStock: currentStock,
          averageStock: averageStock,
          turnoverRate: turnoverRate,
        ));
      }

      // Sort by turnover rate (descending)
      turnoverItems.sort((a, b) => b.turnoverRate.compareTo(a.turnoverRate));

      // Apply limit if specified, otherwise return all items
      if (limit != null && limit > 0) {
        return turnoverItems.take(limit).toList();
      }
      return turnoverItems;
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

      // Create a map of supplies by name+type key (case-insensitive)
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

        // CRITICAL: Deduplicate by id to prevent counting the same supply multiple times
        // (A supply should only appear once, but this ensures we don't double-count)
        final seenIds2 = <String>{};
        final uniqueSupplies2 = <Map<String, dynamic>>[];
        for (final supply in allSupplies) {
          final id = supply['id']?.toString();
          if (id != null && !seenIds2.contains(id)) {
            seenIds2.add(id);
            uniqueSupplies2.add(supply);
          }
        }

        // CRITICAL: Also filter out expired supplies (similar to inventory view)
        // Only count non-expired supplies for current stock calculation
        final now2 = DateTime.now();
        final today2 = DateTime(now2.year, now2.month, now2.day);
        final activeSupplies2 = uniqueSupplies2.where((supply) {
          final noExpiry = supply['noExpiry'] as bool? ?? false;
          final expiry = supply['expiry']?.toString();

          if (noExpiry || expiry == null || expiry.isEmpty) {
            return true; // No expiry or no expiry date - include it
          }

          // Check if expired
          try {
            final expiryDate = DateTime.tryParse(expiry.replaceAll('/', '-'));
            if (expiryDate != null) {
              final dateOnly =
                  DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
              // Exclude expired supplies (expired on or before today)
              return dateOnly.isAfter(today2);
            }
          } catch (_) {
            // If we can't parse the date, include it to be safe
          }
          return true;
        }).toList();

        for (final supply in activeSupplies2) {
          final name = (supply['name']?.toString() ?? '').trim();
          final type = supply['type']?.toString().trim();
          if (name.isNotEmpty) {
            final typeKey = (type ?? '').toLowerCase();
            final key = '${name.toLowerCase()}|$typeKey';
            // If multiple supplies with same name+type, aggregate stock
            if (supplyMap.containsKey(key)) {
              final existing = supplyMap[key]!;
              final existingStock = (existing['stock'] ?? 0) as int;
              final newStock = (supply['stock'] ?? 0) as int;
              supplyMap[key] = {
                ...existing,
                'stock': existingStock + newStock,
                '_key': key,
              };
            } else {
              supplyMap[key] = {
                'name': name,
                'type': type,
                'stock': supply['stock'] ?? 0,
                '_key': key,
              };
            }

            // Also create an entry keyed by name only (for backwards compatibility with deductions that don't have type)
            // BUT: Only create this for supplies that actually have no type (null or empty)
            // CRITICAL FIX: If type is empty, key == nameOnlyKey, so we've already created/updated it above!
            // Don't create it again or we'll double-count the stock.
            final nameOnlyKey = '${name.toLowerCase()}|';
            final hasNoType = type == null || type.isEmpty;

            // Only create nameOnlyKey if it's DIFFERENT from the key we just created
            // (i.e., if type was not empty, so key != nameOnlyKey)
            if (hasNoType && key != nameOnlyKey) {
              // This shouldn't happen (hasNoType means type is empty, so key should == nameOnlyKey)
              // But just in case, handle it safely
              if (!supplyMap.containsKey(nameOnlyKey)) {
                supplyMap[nameOnlyKey] = {
                  'name': name,
                  'type': null, // Explicitly null for supplies without types
                  'stock': supply['stock'] ?? 0,
                  '_isNameOnlyEntry': true,
                  '_key': nameOnlyKey,
                };
              } else {
                // Only aggregate if the existing entry also represents supplies without types
                final existing = supplyMap[nameOnlyKey]!;
                final existingHasNoType = existing['type'] == null ||
                    (existing['type']?.toString().trim().isEmpty ?? true);

                if (existingHasNoType) {
                  final existingStock = (existing['stock'] ?? 0) as int;
                  final newStock = (supply['stock'] ?? 0) as int;
                  supplyMap[nameOnlyKey] = {
                    ...existing,
                    'stock': existingStock + newStock,
                    '_isNameOnlyEntry': true,
                    '_key': nameOnlyKey,
                  };
                }
              }
            }
            // If key == nameOnlyKey (type is empty), we already created/updated it above, so skip
          }
        }
      }

      // CRITICAL: Clean up any incorrectly created nameOnlyKey entries
      // If there are supplies with types for a name, remove the nameOnlyKey entry to prevent aggregation
      final keysToRemove2 = <String>[];
      for (final entry in supplyMap.entries) {
        final key = entry.key;
        if (key.endsWith('|') && key != '|') {
          // This is a nameOnlyKey (ends with |)
          final nameOnly = key.substring(0, key.length - 1);
          // Check if there are any supplies with types for this name
          bool hasSuppliesWithTypes = false;
          for (final otherEntry in supplyMap.entries) {
            final otherKey = otherEntry.key;
            if (otherKey.startsWith('$nameOnly|') && otherKey != key) {
              // This is a name+type key
              final otherSupply = otherEntry.value;
              final otherType = otherSupply['type']?.toString().trim();
              if (otherType != null && otherType.isNotEmpty) {
                hasSuppliesWithTypes = true;
                break;
              }
            }
          }
          // If there are supplies with types, remove this nameOnlyKey entry
          if (hasSuppliesWithTypes) {
            keysToRemove2.add(key);
          }
        }
      }
      // Remove the incorrectly created entries
      for (final key in keysToRemove2) {
        supplyMap.remove(key);
      }

      // Match deductions with supplies and compute turnover
      // Include ALL items with consumption, even if not in current supplies
      final List<TurnoverItem> turnoverItems = [];
      final Map<String, bool> processedKeys =
          {}; // Track processed items to avoid duplicates

      for (final deduction in deductions) {
        final name = (deduction['name']?.toString() ?? '').trim();
        final type = deduction['type']?.toString().trim();
        final quantityConsumed = (deduction['quantityDeducted'] ?? 0) as int;

        if (name.isEmpty || quantityConsumed <= 0) continue;

        final typeKey = (type ?? '').toLowerCase();
        final key = '${name.toLowerCase()}|$typeKey';

        // Skip if already processed (aggregated by name+type)
        if (processedKeys.containsKey(key)) continue;
        processedKeys[key] = true;

        // Try to match by name+type first, then fallback to name only for backwards compatibility
        Map<String, dynamic>? supply = supplyMap[key];

        // CRITICAL: If deduction has a type (even if empty string), we should ONLY match against exact name+type key
        // Never fall back to nameOnlyKey for deductions with types, as that would incorrectly aggregate stock
        final deductionHasNoType = type == null || type.isEmpty;

        if (supply == null && deductionHasNoType) {
          // Only try nameOnlyKey if deduction truly has no type
          // BUT: First check if there are ANY supplies with types for this name
          // If there are, we should NOT use nameOnlyKey to avoid incorrect aggregation
          bool hasSuppliesWithTypes = false;
          final nameLower = name.toLowerCase();
          for (final entry in supplyMap.entries) {
            final entryKey = entry.key;
            if (entryKey.startsWith('$nameLower|') &&
                entryKey != '$nameLower|') {
              // This is a name+type key (not nameOnlyKey)
              final entrySupply = entry.value;
              final entryType = entrySupply['type']?.toString().trim();
              if (entryType != null && entryType.isNotEmpty) {
                hasSuppliesWithTypes = true;
                break;
              }
            }
          }

          // Only use nameOnlyKey if there are NO supplies with types for this name
          if (!hasSuppliesWithTypes) {
            final nameOnlyKey = '${name.toLowerCase()}|';
            final nameOnlySupply = supplyMap[nameOnlyKey];

            // Only use this entry if it's a proper name-only entry (not aggregated from multiple types)
            // We require BOTH conditions: no type AND the flag, to ensure it's not aggregated
            if (nameOnlySupply != null) {
              final entryHasNoType = nameOnlySupply['type'] == null ||
                  (nameOnlySupply['type']?.toString().trim().isEmpty ?? true);
              final isNameOnlyEntry =
                  nameOnlySupply['_isNameOnlyEntry'] == true;

              if (entryHasNoType && isNameOnlyEntry) {
                // Double-check: ensure this is truly a name-only entry, not aggregated
                supply = nameOnlySupply;
              }
              // If the entry has a type or doesn't have the flag, it means it was aggregated - don't use it
            }
          }
        }
        // If deduction has a type but no match found, skip it (don't use aggregated entries)

        // Use current stock if available, otherwise 0 (item was fully consumed or restocked)
        final currentStock = supply != null ? (supply['stock'] ?? 0) as int : 0;

        // Historical calculation: opening stock = current stock + quantity consumed
        // This represents the stock level at the start (before all-time consumption)
        final openingStock = currentStock + quantityConsumed;

        // Calculate average stock and turnover rate
        // Use historical consumption data to calculate meaningful turnover
        double averageStock;
        double turnoverRate;

        // Average stock = average of opening and current stock
        averageStock = (openingStock + currentStock) / 2.0;

        // Calculate turnover rate: usageSpeed = qtyConsumed / max(averageStock, 1)
        // Example sanity check:
        //   qtyConsumed = 9, currentStock = 0, openingStock = 9
        //   averageStock = (9 + 0) / 2 = 4.5
        //   turnoverRate = 9 / max(4.5, 1) = 9 / 4.5 = 2.0
        if (averageStock > 0) {
          turnoverRate = quantityConsumed / averageStock;
        } else {
          // If average stock is 0 (shouldn't happen, but safety check)
          // Use quantity consumed directly (with minimum denominator of 1)
          turnoverRate =
              quantityConsumed > 0 ? quantityConsumed.toDouble() : 0.0;
        }

        turnoverItems.add(TurnoverItem(
          name: name,
          type: type,
          quantityConsumed: quantityConsumed,
          currentStock: currentStock,
          averageStock: averageStock,
          turnoverRate: turnoverRate,
        ));
      }

      // Sort by turnover rate (descending)
      turnoverItems.sort((a, b) => b.turnoverRate.compareTo(a.turnoverRate));

      // Apply limit if specified, otherwise return all items
      // For all-time, default to 5 for dashboard display
      if (turnoverItems.length > 5) {
        return turnoverItems.take(5).toList();
      }
      return turnoverItems;
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
