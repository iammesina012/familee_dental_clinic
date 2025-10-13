import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/activity_log/controller/sd_activity_controller.dart';
import 'package:familee_dental/features/notifications/controller/notifications_controller.dart';

class StockDeductionController {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Applies stock deductions for the provided items.
  /// Each item map is expected to contain at least: 'docId' and 'deductQty'.
  /// Never allows negative stock; if requested qty > current stock, it clamps to current stock.
  /// Returns a summary map of docId -> actuallyDeductedQty.
  Future<Map<String, int>> applyDeductions(
      List<Map<String, dynamic>> deductionItems) async {
    final Map<String, dynamic> results = {};
    // summary counters removed

    for (final item in deductionItems) {
      final String? docId = item['docId'] as String?;
      final int requestedQty = (item['deductQty'] ?? 0) as int;
      if (docId == null || requestedQty <= 0) {
        continue;
      }

      // Check if this item has multiple batches for FIFO deduction
      final List<dynamic>? allBatches = item['allBatches'] as List<dynamic>?;

      if (allBatches != null && allBatches.isNotEmpty) {
        // FIFO deduction across multiple batches
        int remainingQty = requestedQty;
        final String itemName = item['name'] ?? 'Unknown Item';

        for (final batch in allBatches) {
          if (remainingQty <= 0) break;

          final String batchDocId = batch['docId'] as String;
          final int batchStock = (batch['stock'] ?? 0) as int;

          if (batchStock <= 0) continue;

          final int deductFromBatch =
              remainingQty > batchStock ? batchStock : remainingQty;
          final int newBatchStock = batchStock - deductFromBatch;

          // Update this batch
          await _supabase
              .from('supplies')
              .update({'stock': newBatchStock}).eq('id', batchDocId);

          results[batchDocId] = deductFromBatch;
          remainingQty -= deductFromBatch;

          // Store notification and log data for this batch
          results['_notificationData_$batchDocId'] = {
            'itemName': itemName,
            'newStock': newBatchStock,
            'previousStock': batchStock,
          };

          results['_logData_$batchDocId'] = {
            'itemName': itemName,
            'brand': item['brand'] ?? 'Unknown Brand',
            'quantity': deductFromBatch,
            'supplier': 'Multiple Batches',
          };
        }
      } else {
        // Single batch deduction (original logic)
        try {
          // Get current stock from Supabase for this specific batch only
          final response = await _supabase
              .from('supplies')
              .select('*')
              .eq('id', docId)
              .single();

          final data = response;
          final int currentStock = (data['stock'] ?? 0) as int;

          // Debug logging
          print(
              'Stock Deduction Debug - Item: ${data['name']}, Current Stock: $currentStock, Requested: $requestedQty');

          if (currentStock <= 0) {
            results[docId] = 0;
            continue;
          }

          final int deductQty =
              requestedQty > currentStock ? currentStock : requestedQty;
          final int newStock = currentStock - deductQty;

          // Update stock in Supabase for this specific batch only
          await _supabase
              .from('supplies')
              .update({'stock': newStock}).eq('id', docId);

          results[docId] = deductQty;

          // Store notification data for after transaction
          results['_notificationData_$docId'] = {
            'itemName': data['name'] ?? 'Unknown Item',
            'newStock': newStock,
            'previousStock': currentStock,
          };

          // Log the stock deduction activity
          // Note: We'll log this after the transaction completes successfully
          results['_logData_$docId'] = {
            'itemName': data['name'] ?? 'Unknown Item',
            'brand': data['brand'] ?? 'Unknown Brand',
            'quantity': deductQty,
            'supplier': data['supplier'] ?? 'Unknown Supplier',
          };
        } catch (e) {
          // If item doesn't exist or other error, set result to 0
          results[docId] = 0;
        }
      }
    }

    // Log all successful deductions and check for notifications
    final notificationsController = NotificationsController();
    for (final item in deductionItems) {
      final String? docId = item['docId'] as String?;
      if (docId != null && results.containsKey(docId)) {
        final logData = results['_logData_$docId'] as Map<String, dynamic>?;
        final notificationData =
            results['_notificationData_$docId'] as Map<String, dynamic>?;

        if (logData != null) {
          await SdActivityController().logStockDeduction(
            itemName: logData['itemName'] ?? 'Unknown Item',
            brand: logData['brand'] ?? 'Unknown Brand',
            quantity: logData['quantity'] ?? 0,
            supplier: logData['supplier'] ?? 'Unknown Supplier',
          );
        }

        // Check for stock level notifications
        if (notificationData != null) {
          final itemName = notificationData['itemName'] ?? 'Unknown Item';
          final newStock = notificationData['newStock'] ?? 0;
          final previousStock = notificationData['previousStock'] ?? 0;

          await notificationsController.checkStockLevelNotification(
            itemName,
            newStock as int,
            previousStock as int,
          );

          // summary tally removed
        }
      }
    }

    // summary notifications removed

    // Clean up log and notification data from results before returning
    final cleanResults = <String, int>{};
    results.forEach((key, value) {
      if (!key.startsWith('_logData_') &&
          !key.startsWith('_notificationData_')) {
        cleanResults[key] = value as int;
      }
    });

    return cleanResults;
  }

  /// Reverts stock deductions for the provided items by INCREASING stock.
  /// Each item map is expected to contain at least: 'docId' and 'deductQty'.
  /// Ignores non-positive quantities.
  /// Returns a summary map of docId -> actuallyRevertedQty.
  Future<Map<String, int>> revertDeductions(
      List<Map<String, dynamic>> deductionItems) async {
    final Map<String, dynamic> results = {};

    for (final item in deductionItems) {
      final String? docId = item['docId'] as String?;
      final int revertQty = (item['deductQty'] ?? 0) as int;
      if (docId == null || revertQty <= 0) {
        continue;
      }

      try {
        // Get current stock from Supabase
        final response = await _supabase
            .from('supplies')
            .select('*')
            .eq('id', docId)
            .single();

        final data = response;
        final int currentStock = (data['stock'] ?? 0) as int;
        final int newStock = currentStock + revertQty;

        // Update stock in Supabase
        await _supabase
            .from('supplies')
            .update({'stock': newStock}).eq('id', docId);

        results[docId] = revertQty;

        // Store notification data for after transaction
        results['_notificationData_$docId'] = {
          'itemName': data['name'] ?? 'Unknown Item',
          'newStock': newStock,
          'previousStock': currentStock,
        };

        // Store log data for after transaction
        results['_logData_$docId'] = {
          'itemName': data['name'] ?? 'Unknown Item',
          'brand': data['brand'] ?? 'Unknown Brand',
          'quantity': revertQty,
          'supplier': data['supplier'] ?? 'Unknown Supplier',
        };
      } catch (e) {
        // If item doesn't exist or other error, set result to 0
        results[docId] = 0;
      }
    }

    // Check for stock level notifications after reverting and log activities
    final notificationsController = NotificationsController();
    final sdActivityController = SdActivityController();
    for (final item in deductionItems) {
      final String? docId = item['docId'] as String?;
      if (docId != null && results.containsKey(docId)) {
        final notificationData =
            results['_notificationData_$docId'] as Map<String, dynamic>?;
        final logData = results['_logData_$docId'] as Map<String, dynamic>?;

        // Check for stock level notifications
        if (notificationData != null) {
          final itemName = notificationData['itemName'] ?? 'Unknown Item';
          final newStock = notificationData['newStock'] ?? 0;
          final previousStock = notificationData['previousStock'] ?? 0;

          await notificationsController.checkStockLevelNotification(
            itemName,
            newStock as int,
            previousStock as int,
          );
        }

        // Log stocks reverted activity
        if (logData != null) {
          await sdActivityController.logStockReverted(
            itemName: logData['itemName'] ?? 'Unknown Item',
            brand: logData['brand'] ?? 'Unknown Brand',
            quantity: logData['quantity'] ?? 0,
            supplier: logData['supplier'] ?? 'Unknown Supplier',
          );
        }
      }
    }

    // Clean up notification/log data from results before returning
    final cleanResults = <String, int>{};
    results.forEach((key, value) {
      if (!key.startsWith('_notificationData_') &&
          !key.startsWith('_logData_')) {
        cleanResults[key] = value;
      }
    });

    return cleanResults;
  }
}
