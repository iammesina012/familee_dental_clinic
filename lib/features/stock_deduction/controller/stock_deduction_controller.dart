import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:projects/features/activity_log/controller/sd_activity_controller.dart';
import 'package:projects/features/notifications/controller/notifications_controller.dart';

class StockDeductionController {
  final FirebaseFirestore firestore;

  StockDeductionController({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

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

      await firestore.runTransaction((transaction) async {
        final DocumentReference<Map<String, dynamic>> ref =
            firestore.collection('supplies').doc(docId);
        final snapshot = await transaction.get(ref);
        if (!snapshot.exists) {
          results[docId] = 0;
          return;
        }

        final data = snapshot.data()!;
        final int currentStock = (data['stock'] ?? 0) as int;
        if (currentStock <= 0) {
          results[docId] = 0;
          return;
        }

        final int deductQty =
            requestedQty > currentStock ? currentStock : requestedQty;
        final int newStock = currentStock - deductQty;
        transaction.update(ref, {'stock': newStock});
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
      });
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

      await firestore.runTransaction((transaction) async {
        final DocumentReference<Map<String, dynamic>> ref =
            firestore.collection('supplies').doc(docId);
        final snapshot = await transaction.get(ref);
        if (!snapshot.exists) {
          results[docId] = 0;
          return;
        }

        final data = snapshot.data()!;
        final int currentStock = (data['stock'] ?? 0) as int;
        final int newStock = currentStock + revertQty;
        transaction.update(ref, {'stock': newStock});
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
      });
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
