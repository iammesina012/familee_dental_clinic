import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/inventory_item.dart';

class ArchiveSupplyController {
  Stream<List<InventoryItem>> getArchivedSupplies() {
    return FirebaseFirestore.instance
        .collection('supplies')
        .where('archived', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        return InventoryItem(
          id: doc.id,
          name: data['name'] ?? '',
          imageUrl: data['imageUrl'] ?? '',
          category: data['category'] ?? '',
          cost: (data['cost'] ?? 0).toDouble(),
          stock: (data['stock'] ?? 0) as int,
          unit: data['unit'] ?? '',
          supplier: data['supplier'] ?? '',
          brand: data['brand'] ?? '',
          expiry: data['expiry'],
          noExpiry: data['noExpiry'] ?? false,
          archived: data['archived'] ?? false,
        );
      }).toList();

      // Sort by name in the app instead of in Firestore
      items
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return items;
    });
  }
}
