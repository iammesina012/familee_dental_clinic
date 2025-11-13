import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';

class InventoryAnalyticsService {
  // Singleton pattern to ensure cache persists across widget rebuilds
  static final InventoryAnalyticsService _instance =
      InventoryAnalyticsService._internal();
  factory InventoryAnalyticsService() => _instance;
  InventoryAnalyticsService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache for last known data (persists across widget rebuilds)
  Map<String, int>? _cachedExpiryCounts;
  Map<String, int>? _cachedSupplyCounts;
  Map<String, int>? _cachedPurchaseOrderCounts;
  Map<String, List<Map<String, dynamic>>>? _cachedSuppliesByStatus;
  Map<String, List<Map<String, dynamic>>>? _cachedPurchaseOrdersByStatus;

  // Stream for expired and expiring counts
  Stream<Map<String, int>> getExpiryCountsStream() {
    final controller = StreamController<Map<String, int>>.broadcast();

    // Emit cached data immediately if available (no delay - instant feedback)
    if (_cachedExpiryCounts != null) {
      controller.add(_cachedExpiryCounts!);
    }

    try {
      _supabase.from('supplies').stream(primaryKey: ['id']).listen(
        (data) {
          try {
            final allSupplies = data.map((row) {
              DateTime? createdAt;
              if (row['created_at'] != null) {
                try {
                  createdAt = DateTime.parse(row['created_at'] as String);
                } catch (e) {
                  createdAt = null;
                }
              }
              return InventoryItem(
                id: row['id'] as String,
                name: row['name'] ?? '',
                imageUrl: row['image_url'] ?? '',
                category: row['category'] ?? '',
                cost: (row['cost'] ?? 0).toDouble(),
                stock: (row['stock'] ?? 0).toInt(),
                lowStockBaseline: row['low_stock_baseline'] != null
                    ? (row['low_stock_baseline'] as num).toInt()
                    : null,
                unit: row['unit'] ?? '',
                supplier: row['supplier'] ?? '',
                brand: row['brand'] ?? '',
                expiry: row['expiry'],
                noExpiry: row['no_expiry'] ?? false,
                archived: row['archived'] ?? false,
                createdAt: createdAt,
              );
            }).toList();

            final supplies = allSupplies
                .where((supply) => !supply.archived && supply.stock > 0)
                .toList();

            int expired = 0;
            int expiring = 0;

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);

            for (final s in supplies) {
              if (s.noExpiry || s.expiry == null || s.expiry!.isEmpty) {
                continue;
              }
              final parsed = DateTime.tryParse(s.expiry!.replaceAll('/', '-'));
              if (parsed == null) continue;
              final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);
              if (dateOnly.isBefore(today) ||
                  dateOnly.isAtSameMomentAs(today)) {
                expired++;
              } else {
                final daysUntil = dateOnly.difference(today).inDays;
                if (daysUntil <= 30) {
                  expiring++;
                }
              }
            }

            final result = {
              'expired': expired,
              'expiring': expiring,
            };

            // Cache the result
            _cachedExpiryCounts = result;
            controller.add(result);
          } catch (e) {
            // On error, emit cached data if available, otherwise emit defaults
            if (_cachedExpiryCounts != null) {
              controller.add(_cachedExpiryCounts!);
            } else {
              controller.add({'expired': 0, 'expiring': 0});
            }
          }
        },
        onError: (error) {
          // On stream error, emit cached data if available, otherwise emit defaults
          if (_cachedExpiryCounts != null) {
            controller.add(_cachedExpiryCounts!);
          } else {
            controller.add({'expired': 0, 'expiring': 0});
          }
        },
      );
    } catch (e) {
      // If stream creation fails, emit cached data if available, otherwise emit defaults
      if (_cachedExpiryCounts != null) {
        controller.add(_cachedExpiryCounts!);
      } else {
        controller.add({'expired': 0, 'expiring': 0});
      }
    }

    return controller.stream;
  }

  // Stream for supply counts by status (counts individual supplies, not grouped)
  Stream<Map<String, int>> getSupplyCountsStream() {
    final controller = StreamController<Map<String, int>>.broadcast();

    // Emit cached data immediately if available (no delay - instant feedback)
    if (_cachedSupplyCounts != null) {
      controller.add(_cachedSupplyCounts!);
    }

    try {
      _supabase.from('supplies').stream(primaryKey: ['id']).listen(
        (data) {
          try {
            final allSupplies = data.map((row) {
              DateTime? createdAt;
              if (row['created_at'] != null) {
                try {
                  createdAt = DateTime.parse(row['created_at'] as String);
                } catch (e) {
                  createdAt = null;
                }
              }
              return InventoryItem(
                id: row['id'] as String,
                name: row['name'] ?? '',
                imageUrl: row['image_url'] ?? '',
                category: row['category'] ?? '',
                cost: (row['cost'] ?? 0).toDouble(),
                stock: (row['stock'] ?? 0).toInt(),
                lowStockBaseline: row['low_stock_baseline'] != null
                    ? (row['low_stock_baseline'] as num).toInt()
                    : null,
                unit: row['unit'] ?? '',
                supplier: row['supplier'] ?? '',
                brand: row['brand'] ?? '',
                expiry: row['expiry'],
                noExpiry: row['no_expiry'] ?? false,
                archived: row['archived'] ?? false,
                createdAt: createdAt,
              );
            }).toList();

            // Filter out archived supplies AND expired supplies
            final supplies = allSupplies.where((supply) {
              if (supply.archived) return false;

              // Filter out expired supplies
              if (!supply.noExpiry &&
                  supply.expiry != null &&
                  supply.expiry!.isNotEmpty) {
                final expiryDate =
                    DateTime.tryParse(supply.expiry!.replaceAll('/', '-'));
                if (expiryDate != null) {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final dateOnly = DateTime(
                      expiryDate.year, expiryDate.month, expiryDate.day);

                  if (dateOnly.isBefore(today) ||
                      dateOnly.isAtSameMomentAs(today)) {
                    return false; // Filter out expired items
                  }
                }
              }

              return true;
            }).toList();

            // Count individual supplies by status (across all batches)
            // Using dynamic 20% critical level and tiered thresholds
            int totalInStock = 0;
            int totalLowStock = 0;
            int totalOutOfStock = 0; // stock = 0

            for (final supply in supplies) {
              if (supply.stock == 0) {
                totalOutOfStock++;
              } else {
                // Use manually set threshold for low stock detection
                if (supply.lowStockBaseline != null &&
                    supply.lowStockBaseline! > 0 &&
                    supply.stock <= supply.lowStockBaseline!) {
                  totalLowStock++;
                } else {
                  totalInStock++;
                }
              }
            }

            final result = {
              'inStock': totalInStock,
              'lowStock': totalLowStock,
              'outOfStock': totalOutOfStock,
              'total': supplies.length,
            };

            // Cache the result
            _cachedSupplyCounts = result;
            controller.add(result);
          } catch (e) {
            // On error, emit cached data if available, otherwise emit defaults
            if (_cachedSupplyCounts != null) {
              controller.add(_cachedSupplyCounts!);
            } else {
              controller.add(
                  {'inStock': 0, 'lowStock': 0, 'outOfStock': 0, 'total': 0});
            }
          }
        },
        onError: (error) {
          // On stream error, emit cached data if available, otherwise emit defaults
          if (_cachedSupplyCounts != null) {
            controller.add(_cachedSupplyCounts!);
          } else {
            controller.add(
                {'inStock': 0, 'lowStock': 0, 'outOfStock': 0, 'total': 0});
          }
        },
      );
    } catch (e) {
      // If stream creation fails, emit cached data if available, otherwise emit defaults
      if (_cachedSupplyCounts != null) {
        controller.add(_cachedSupplyCounts!);
      } else {
        controller
            .add({'inStock': 0, 'lowStock': 0, 'outOfStock': 0, 'total': 0});
      }
    }

    return controller.stream;
  }

  // Stream for purchase order counts by status
  Stream<Map<String, int>> getPurchaseOrderCountsStream() {
    final controller = StreamController<Map<String, int>>.broadcast();

    // Emit cached data immediately if available (no delay - instant feedback)
    if (_cachedPurchaseOrderCounts != null) {
      controller.add(_cachedPurchaseOrderCounts!);
    }

    try {
      _supabase.from('purchase_orders').stream(primaryKey: ['id']).listen(
        (data) {
          try {
            int open = 0;
            int partial = 0;
            int approval = 0;
            int closed = 0;

            for (final row in data) {
              final status = row['status']?.toString() ?? '';
              switch (status) {
                case 'Open':
                  open++;
                  break;
                case 'Partial':
                case 'Partially Received':
                  partial++;
                  break;
                case 'Approval':
                  approval++;
                  break;
                case 'Closed':
                case 'Cancelled':
                  closed++;
                  break;
              }
            }

            final result = {
              'Open': open,
              'Partial': partial,
              'Approval': approval,
              'Closed': closed,
            };

            // Cache the result
            _cachedPurchaseOrderCounts = result;
            controller.add(result);
          } catch (e) {
            // On error, emit cached data if available, otherwise emit defaults
            if (_cachedPurchaseOrderCounts != null) {
              controller.add(_cachedPurchaseOrderCounts!);
            } else {
              controller
                  .add({'Open': 0, 'Partial': 0, 'Approval': 0, 'Closed': 0});
            }
          }
        },
        onError: (error) {
          // On stream error, emit cached data if available, otherwise emit defaults
          if (_cachedPurchaseOrderCounts != null) {
            controller.add(_cachedPurchaseOrderCounts!);
          } else {
            controller
                .add({'Open': 0, 'Partial': 0, 'Approval': 0, 'Closed': 0});
          }
        },
      );
    } catch (e) {
      // If stream creation fails, emit cached data if available, otherwise emit defaults
      if (_cachedPurchaseOrderCounts != null) {
        controller.add(_cachedPurchaseOrderCounts!);
      } else {
        controller.add({'Open': 0, 'Partial': 0, 'Approval': 0, 'Closed': 0});
      }
    }

    return controller.stream;
  }

  // Get all supplies with details, categorized by status
  Future<Map<String, List<Map<String, dynamic>>>> getSuppliesByStatus() async {
    // Return cached data immediately if available (prepopulate)
    if (_cachedSuppliesByStatus != null) {
      // Fetch fresh data in the background, but return cached data immediately
      _fetchSuppliesByStatusInBackground();
      return _cachedSuppliesByStatus!;
    }

    try {
      final response = await _supabase.from('supplies').select('*');

      final allSupplies = response.map((row) {
        final name = row['name'] ?? '';
        final type = row['type'] ?? '';
        final stock = (row['stock'] ?? 0).toInt();
        // Format supply name with type: "Surgical Mask(Pink)" - separate from quantity
        String displayName = name;
        if (type != null && type.toString().trim().isNotEmpty) {
          displayName = '$name($type)';
        }

        return {
          'id': row['id'] as String,
          'name': name,
          'type': type,
          'displayName': displayName,
          'stock': stock,
          'lowStockBaseline': row['low_stock_baseline'] != null
              ? (row['low_stock_baseline'] as num).toInt()
              : null,
          'packagingUnit': row['packaging_unit'] ?? row['unit'] ?? '',
          'packagingContent': row['packaging_content'] ?? '',
          'brand': row['brand'] ?? 'N/A',
          'supplier': row['supplier'] ?? 'N/A',
          'cost': (row['cost'] ?? 0).toDouble(),
          'expiry': row['expiry'],
          'noExpiry': row['no_expiry'] ?? false,
          'archived': row['archived'] ?? false,
        };
      }).toList();

      // Filter out archived supplies
      final supplies =
          allSupplies.where((supply) => !supply['archived']).toList();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final Map<String, List<Map<String, dynamic>>> suppliesByStatus = {
        'In Stock': [],
        'Low Stock': [],
        'Out of Stock': [],
        'Expiring': [],
        'Expired': [],
      };

      for (final supply in supplies) {
        final stock = supply['stock'] as int;
        final noExpiry = supply['noExpiry'] as bool;
        final expiry = supply['expiry'] as String?;

        String status = 'In Stock';
        bool isExpired = false;
        bool isExpiring = false;

        // Check expiry first
        if (!noExpiry && expiry != null && expiry.isNotEmpty) {
          final expiryDate = DateTime.tryParse(expiry.replaceAll('/', '-'));
          if (expiryDate != null) {
            final dateOnly =
                DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
            if (dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today)) {
              isExpired = true;
              status = 'Expired';
            } else {
              final daysUntil = dateOnly.difference(today).inDays;
              if (daysUntil <= 30) {
                isExpiring = true;
                status = 'Expiring';
              }
            }
          }
        }

        // Determine stock status (if not expired/expiring) using manually set threshold
        if (!isExpired && !isExpiring) {
          if (stock == 0) {
            status = 'Out of Stock';
          } else {
            final lowStockBaseline = supply['lowStockBaseline'] as int?;
            // Use manually set threshold for low stock detection
            if (lowStockBaseline != null &&
                lowStockBaseline > 0 &&
                stock <= lowStockBaseline) {
              status = 'Low Stock';
            } else {
              status = 'In Stock';
            }
          }
        }

        // Add status field to supply
        supply['status'] = status;
        supply['expiryDisplay'] = noExpiry || expiry == null || expiry.isEmpty
            ? 'No expiry'
            : expiry.replaceAll('/', '-');

        suppliesByStatus[status]!.add(supply);
      }

      // Cache the result
      _cachedSuppliesByStatus = suppliesByStatus;
      return suppliesByStatus;
    } catch (e) {
      // On error, return cached data if available, otherwise return empty
      if (_cachedSuppliesByStatus != null) {
        return _cachedSuppliesByStatus!;
      }
      return {
        'In Stock': [],
        'Low Stock': [],
        'Out of Stock': [],
        'Expiring': [],
        'Expired': [],
      };
    }
  }

  // Fetch supplies by status in background (for prepopulation)
  void _fetchSuppliesByStatusInBackground() {
    _supabase.from('supplies').select('*').then((response) {
      try {
        final allSupplies = response.map((row) {
          final name = row['name'] ?? '';
          final type = row['type'] ?? '';
          final stock = (row['stock'] ?? 0).toInt();
          String displayName = name;
          if (type != null && type.toString().trim().isNotEmpty) {
            displayName = '$name($type)';
          }

          return {
            'id': row['id'] as String,
            'name': name,
            'type': type,
            'displayName': displayName,
            'stock': stock,
            'packagingUnit': row['packaging_unit'] ?? row['unit'] ?? '',
            'packagingContent': row['packaging_content'] ?? '',
            'brand': row['brand'] ?? 'N/A',
            'supplier': row['supplier'] ?? 'N/A',
            'cost': (row['cost'] ?? 0).toDouble(),
            'expiry': row['expiry'],
            'noExpiry': row['no_expiry'] ?? false,
            'archived': row['archived'] ?? false,
          };
        }).toList();

        final supplies =
            allSupplies.where((supply) => !supply['archived']).toList();

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final Map<String, List<Map<String, dynamic>>> suppliesByStatus = {
          'In Stock': [],
          'Low Stock': [],
          'Out of Stock': [],
          'Expiring': [],
          'Expired': [],
        };

        for (final supply in supplies) {
          final stock = supply['stock'] as int;
          final noExpiry = supply['noExpiry'] as bool;
          final expiry = supply['expiry'] as String?;

          String status = 'In Stock';
          bool isExpired = false;
          bool isExpiring = false;

          if (!noExpiry && expiry != null && expiry.isNotEmpty) {
            final expiryDate = DateTime.tryParse(expiry.replaceAll('/', '-'));
            if (expiryDate != null) {
              final dateOnly =
                  DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
              if (dateOnly.isBefore(today) ||
                  dateOnly.isAtSameMomentAs(today)) {
                isExpired = true;
                status = 'Expired';
              } else {
                final daysUntil = dateOnly.difference(today).inDays;
                if (daysUntil <= 30) {
                  isExpiring = true;
                  status = 'Expiring';
                }
              }
            }
          }

          if (!isExpired && !isExpiring) {
            if (stock == 0) {
              status = 'Out of Stock';
            } else {
              final lowStockBaseline = supply['lowStockBaseline'] as int?;
              // Use manually set threshold for low stock detection
              if (lowStockBaseline != null &&
                  lowStockBaseline > 0 &&
                  stock <= lowStockBaseline) {
                status = 'Low Stock';
              } else {
                status = 'In Stock';
              }
            }
          }

          supply['status'] = status;
          supply['expiryDisplay'] = noExpiry || expiry == null || expiry.isEmpty
              ? 'No expiry'
              : expiry.replaceAll('/', '-');

          suppliesByStatus[status]!.add(supply);
        }

        _cachedSuppliesByStatus = suppliesByStatus;
      } catch (e) {
        // Ignore background fetch errors
      }
    }).catchError((e) {
      // Ignore background fetch errors
    });
  }

  // Get all purchase orders with details, categorized by status
  Future<Map<String, List<Map<String, dynamic>>>>
      getPurchaseOrdersByStatus() async {
    // Return cached data immediately if available (prepopulate)
    if (_cachedPurchaseOrdersByStatus != null) {
      // Fetch fresh data in the background, but return cached data immediately
      _fetchPurchaseOrdersByStatusInBackground();
      return _cachedPurchaseOrdersByStatus!;
    }

    try {
      final response = await _supabase.from('purchase_orders').select('*');

      final Map<String, List<Map<String, dynamic>>> posByStatus = {
        'Open': [],
        'Partial': [],
        'Approval': [],
        'Closed': [],
      };

      for (final row in response) {
        final status = row['status']?.toString() ?? 'Open';
        final supplies =
            (row['supplies'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        // Count received supplies
        int receivedCount = 0;
        List<String> expiryDates = [];

        // Get receipt details from supplies
        String? receiptNumber;
        String? recipientName;
        String? remarks;

        for (final supply in supplies) {
          final receivedQuantities = supply['receivedQuantities'];
          if (receivedQuantities != null &&
              receivedQuantities is Map &&
              receivedQuantities.isNotEmpty) {
            receivedCount++;

            // Collect expiry dates from received supplies
            final expiry = supply['expiry'];
            if (expiry != null && expiry.toString().isNotEmpty) {
              expiryDates.add(expiry.toString());
            }
          }

          // Get receipt details from any supply that has them (not just those with receivedQuantities)
          // Receipt details are saved to all supplies when items are received
          if (receiptNumber == null || receiptNumber.isEmpty) {
            receiptNumber = supply['receiptDrNo']?.toString() ?? '';
          }
          if (recipientName == null || recipientName.isEmpty) {
            recipientName = supply['receiptRecipient']?.toString() ?? '';
          }
          if (remarks == null || remarks.isEmpty) {
            remarks = supply['receiptRemarks']?.toString() ?? '';
          }
        }

        // Get supplier name from first supply (check both supplierName and supplier for compatibility)
        String supplierName = 'N/A';
        if (supplies.isNotEmpty) {
          supplierName = supplies.first['supplierName']?.toString() ??
              supplies.first['supplier']?.toString() ??
              'N/A';
        }

        // Get date received from supplies (if available)
        String? dateReceived;
        for (final supply in supplies) {
          final receiptDate = supply['receiptDate'] ??
              supply['receivedAt'] ??
              supply['received_date'];
          if (receiptDate != null) {
            try {
              if (receiptDate is String) {
                final dt = DateTime.tryParse(receiptDate);
                if (dt != null) {
                  dateReceived =
                      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                  break;
                }
              }
            } catch (_) {}
          }
        }

        final poData = {
          'id': row['id'] as String,
          'code': row['code'] ?? '',
          'supplierName': supplierName,
          'suppliesCount': supplies.length,
          'receivedCount': receivedCount,
          'expiryDates':
              expiryDates.join(', ') == '' ? 'N/A' : expiryDates.join(', '),
          'dateCreated': row['created_at'] != null
              ? DateTime.parse(row['created_at'])
                  .toIso8601String()
                  .split('T')[0]
              : 'N/A',
          'dateReceived': dateReceived ?? 'N/A',
          'receiptNumber': receiptNumber ?? 'N/A',
          'recipientName': recipientName ?? 'N/A',
          'remarks': remarks ?? 'N/A',
          'status': status,
        };

        // Categorize by status
        switch (status) {
          case 'Open':
            posByStatus['Open']!.add(poData);
            break;
          case 'Partial':
          case 'Partially Received':
            posByStatus['Partial']!.add(poData);
            break;
          case 'Approval':
            posByStatus['Approval']!.add(poData);
            break;
          case 'Closed':
          case 'Cancelled':
            posByStatus['Closed']!.add(poData);
            break;
        }
      }

      // Sort each status list by code (extract numeric value from #PO1, #PO2, etc.)
      for (final status in posByStatus.keys) {
        posByStatus[status]!.sort((a, b) {
          final codeA = a['code']?.toString() ?? '';
          final codeB = b['code']?.toString() ?? '';

          // Extract numeric value from code (e.g., #PO1 -> 1, #PO17 -> 17)
          int numA = 0;
          int numB = 0;

          try {
            final matchA = RegExp(r'#PO(\d+)').firstMatch(codeA);
            if (matchA != null) {
              numA = int.parse(matchA.group(1)!);
            }
          } catch (_) {}

          try {
            final matchB = RegExp(r'#PO(\d+)').firstMatch(codeB);
            if (matchB != null) {
              numB = int.parse(matchB.group(1)!);
            }
          } catch (_) {}

          return numA.compareTo(numB);
        });
      }

      // Cache the result
      _cachedPurchaseOrdersByStatus = posByStatus;
      return posByStatus;
    } catch (e) {
      // On error, return cached data if available, otherwise return empty
      if (_cachedPurchaseOrdersByStatus != null) {
        return _cachedPurchaseOrdersByStatus!;
      }
      return {
        'Open': [],
        'Partial': [],
        'Approval': [],
        'Closed': [],
      };
    }
  }

  // Fetch purchase orders by status in background (for prepopulation)
  void _fetchPurchaseOrdersByStatusInBackground() {
    _supabase.from('purchase_orders').select('*').then((response) {
      try {
        final Map<String, List<Map<String, dynamic>>> posByStatus = {
          'Open': [],
          'Partial': [],
          'Approval': [],
          'Closed': [],
        };

        for (final row in response) {
          final status = row['status']?.toString() ?? 'Open';
          final supplies =
              (row['supplies'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          int receivedCount = 0;
          List<String> expiryDates = [];

          String? receiptNumber;
          String? recipientName;
          String? remarks;

          for (final supply in supplies) {
            final receivedQuantities = supply['receivedQuantities'];
            if (receivedQuantities != null &&
                receivedQuantities is Map &&
                receivedQuantities.isNotEmpty) {
              receivedCount++;

              final expiry = supply['expiry'];
              if (expiry != null && expiry.toString().isNotEmpty) {
                expiryDates.add(expiry.toString());
              }
            }

            if (receiptNumber == null || receiptNumber.isEmpty) {
              receiptNumber = supply['receiptDrNo']?.toString() ?? '';
            }
            if (recipientName == null || recipientName.isEmpty) {
              recipientName = supply['receiptRecipient']?.toString() ?? '';
            }
            if (remarks == null || remarks.isEmpty) {
              remarks = supply['receiptRemarks']?.toString() ?? '';
            }
          }

          String supplierName = 'N/A';
          if (supplies.isNotEmpty) {
            supplierName = supplies.first['supplierName']?.toString() ??
                supplies.first['supplier']?.toString() ??
                'N/A';
          }

          String? dateReceived;
          for (final supply in supplies) {
            final receiptDate = supply['receiptDate'] ??
                supply['receivedAt'] ??
                supply['received_date'];
            if (receiptDate != null) {
              try {
                if (receiptDate is String) {
                  final dt = DateTime.tryParse(receiptDate);
                  if (dt != null) {
                    dateReceived =
                        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                    break;
                  }
                }
              } catch (_) {}
            }
          }

          final poData = {
            'id': row['id'] as String,
            'code': row['code'] ?? '',
            'supplierName': supplierName,
            'suppliesCount': supplies.length,
            'receivedCount': receivedCount,
            'expiryDates':
                expiryDates.join(', ') == '' ? 'N/A' : expiryDates.join(', '),
            'dateCreated': row['created_at'] != null
                ? DateTime.parse(row['created_at'])
                    .toIso8601String()
                    .split('T')[0]
                : 'N/A',
            'dateReceived': dateReceived ?? 'N/A',
            'receiptNumber': receiptNumber ?? 'N/A',
            'recipientName': recipientName ?? 'N/A',
            'remarks': remarks ?? 'N/A',
            'status': status,
          };

          switch (status) {
            case 'Open':
              posByStatus['Open']!.add(poData);
              break;
            case 'Partial':
            case 'Partially Received':
              posByStatus['Partial']!.add(poData);
              break;
            case 'Approval':
              posByStatus['Approval']!.add(poData);
              break;
            case 'Closed':
            case 'Cancelled':
              posByStatus['Closed']!.add(poData);
              break;
          }
        }

        for (final status in posByStatus.keys) {
          posByStatus[status]!.sort((a, b) {
            final codeA = a['code']?.toString() ?? '';
            final codeB = b['code']?.toString() ?? '';

            int numA = 0;
            int numB = 0;

            try {
              final matchA = RegExp(r'#PO(\d+)').firstMatch(codeA);
              if (matchA != null) {
                numA = int.parse(matchA.group(1)!);
              }
            } catch (_) {}

            try {
              final matchB = RegExp(r'#PO(\d+)').firstMatch(codeB);
              if (matchB != null) {
                numB = int.parse(matchB.group(1)!);
              }
            } catch (_) {}

            return numA.compareTo(numB);
          });
        }

        _cachedPurchaseOrdersByStatus = posByStatus;
      } catch (e) {
        // Ignore background fetch errors
      }
    }).catchError((e) {
      // Ignore background fetch errors
    });
  }
}
