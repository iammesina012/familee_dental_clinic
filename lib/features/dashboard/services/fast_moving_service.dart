import 'package:cloud_firestore/cloud_firestore.dart';

class FastMovingItem {
  final String productKey;
  final String name;
  final String brand;
  final int timesDeducted;

  FastMovingItem({
    required this.productKey,
    required this.name,
    required this.brand,
    required this.timesDeducted,
  });
}

class FastMovingService {
  final FirebaseFirestore firestore;

  FastMovingService({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream top fast moving items within [window] duration.
  /// Uses activity_logs documents with category == 'Stock Deduction'.
  Stream<List<FastMovingItem>> streamTopFastMovingItems({
    int limit = 5,
    Duration window = const Duration(days: 90),
  }) {
    final DateTime since = DateTime.now().subtract(window);

    return firestore
        .collection('activity_logs')
        .where('date', isGreaterThanOrEqualTo: since)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      final Map<String, FastMovingItem> aggregates = {};

      for (final doc in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final String category = (data['category'] ?? '').toString();
        final String action = (data['action'] ?? '').toString();
        if (category != 'Stock Deduction' || action != 'stock_deduction') {
          continue;
        }
        final Map<String, dynamic> metadata =
            (data['metadata'] as Map<String, dynamic>?) ?? {};
        final String name = (metadata['itemName'] ?? '').toString();
        final String brand = (metadata['brand'] ?? '').toString();
        if (name.isEmpty) continue;
        final String key =
            '${name.trim().toLowerCase()}|${brand.trim().toLowerCase()}';

        if (!aggregates.containsKey(key)) {
          aggregates[key] = FastMovingItem(
            productKey: key,
            name: name,
            brand: brand,
            timesDeducted: 1,
          );
        } else {
          final current = aggregates[key]!;
          aggregates[key] = FastMovingItem(
            productKey: current.productKey,
            name: current.name,
            brand: current.brand,
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
