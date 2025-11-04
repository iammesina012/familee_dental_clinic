import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';

class InventoryAnalyticsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream for expired and expiring counts
  Stream<Map<String, int>> getExpiryCountsStream() {
    return _supabase.from('supplies').stream(primaryKey: ['id']).map((data) {
      final allSupplies = data.map((row) {
        return InventoryItem(
          id: row['id'] as String,
          name: row['name'] ?? '',
          imageUrl: row['image_url'] ?? '',
          category: row['category'] ?? '',
          cost: (row['cost'] ?? 0).toDouble(),
          stock: (row['stock'] ?? 0).toInt(),
          unit: row['unit'] ?? '',
          supplier: row['supplier'] ?? '',
          brand: row['brand'] ?? '',
          expiry: row['expiry'],
          noExpiry: row['no_expiry'] ?? false,
          archived: row['archived'] ?? false,
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
        if (dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today)) {
          expired++;
        } else {
          final daysUntil = dateOnly.difference(today).inDays;
          if (daysUntil <= 30) {
            expiring++;
          }
        }
      }

      return {
        'expired': expired,
        'expiring': expiring,
      };
    });
  }

  // Stream for supply counts by status (counts individual supplies, not grouped)
  Stream<Map<String, int>> getSupplyCountsStream() {
    return _supabase.from('supplies').stream(primaryKey: ['id']).map((data) {
      final allSupplies = data.map((row) {
        return InventoryItem(
          id: row['id'] as String,
          name: row['name'] ?? '',
          imageUrl: row['image_url'] ?? '',
          category: row['category'] ?? '',
          cost: (row['cost'] ?? 0).toDouble(),
          stock: (row['stock'] ?? 0).toInt(),
          unit: row['unit'] ?? '',
          supplier: row['supplier'] ?? '',
          brand: row['brand'] ?? '',
          expiry: row['expiry'],
          noExpiry: row['no_expiry'] ?? false,
          archived: row['archived'] ?? false,
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
            final dateOnly =
                DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

            if (dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today)) {
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
          final criticalLevel =
              GroupedInventoryItem.calculateCriticalLevel(supply.stock);

          // Primary check: If current stock is at or below its own 20% critical level
          if (criticalLevel > 0 && supply.stock <= criticalLevel) {
            totalLowStock++;
          }
          // Extended tiered threshold: stocks <= 5 are likely low (covers 20% of up to 25)
          else if (supply.stock <= 5) {
            totalLowStock++;
          }
          // For stocks > 5, use dynamic calculation
          else if (supply.stock > 5 && supply.stock <= criticalLevel) {
            totalLowStock++;
          }
          // In stock: stock > 5 and stock > critical level
          else {
            totalInStock++;
          }
        }
      }

      return {
        'inStock': totalInStock,
        'lowStock': totalLowStock,
        'outOfStock': totalOutOfStock,
        'total': supplies.length,
      };
    });
  }

  // Stream for purchase order counts by status
  Stream<Map<String, int>> getPurchaseOrderCountsStream() {
    return _supabase
        .from('purchase_orders')
        .stream(primaryKey: ['id']).map((data) {
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
            closed++;
            break;
        }
      }

      return {
        'Open': open,
        'Partial': partial,
        'Approval': approval,
        'Closed': closed,
      };
    });
  }

  // Get all supplies with details, categorized by status
  Future<Map<String, List<Map<String, dynamic>>>> getSuppliesByStatus() async {
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

        // Determine stock status (if not expired/expiring) using dynamic 20% critical level and tiered thresholds
        if (!isExpired && !isExpiring) {
          if (stock == 0) {
            status = 'Out of Stock';
          } else {
            final criticalLevel =
                GroupedInventoryItem.calculateCriticalLevel(stock);

            // Primary check: If current stock is at or below its own 20% critical level
            if (criticalLevel > 0 && stock <= criticalLevel) {
              status = 'Low Stock';
            }
            // Extended tiered threshold: stocks <= 5 are likely low (covers 20% of up to 25)
            else if (stock <= 5) {
              status = 'Low Stock';
            }
            // For stocks > 5, use dynamic calculation
            else if (stock > 5 && stock <= criticalLevel) {
              status = 'Low Stock';
            }
            // In stock: stock > 5 and stock > critical level
            else {
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

      return suppliesByStatus;
    } catch (e) {
      return {
        'In Stock': [],
        'Low Stock': [],
        'Out of Stock': [],
        'Expiring': [],
        'Expired': [],
      };
    }
  }

  // Get all purchase orders with details, categorized by status
  Future<Map<String, List<Map<String, dynamic>>>>
      getPurchaseOrdersByStatus() async {
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

      return posByStatus;
    } catch (e) {
      return {
        'Open': [],
        'Partial': [],
        'Approval': [],
        'Closed': [],
      };
    }
  }
}
