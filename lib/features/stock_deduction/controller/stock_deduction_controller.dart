import 'package:cloud_firestore/cloud_firestore.dart';

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
    final Map<String, int> results = {};

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
      });
    }

    return results;
  }

  /// Reverts stock deductions for the provided items by INCREASING stock.
  /// Each item map is expected to contain at least: 'docId' and 'deductQty'.
  /// Ignores non-positive quantities.
  /// Returns a summary map of docId -> actuallyRevertedQty.
  Future<Map<String, int>> revertDeductions(
      List<Map<String, dynamic>> deductionItems) async {
    final Map<String, int> results = {};

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
      });
    }

    return results;
  }
}
