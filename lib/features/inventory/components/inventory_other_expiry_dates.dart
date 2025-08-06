import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';
import 'package:projects/features/inventory/pages/view_supply_page.dart'; // for status helpers
import '../controller/view_supply_controller.dart';

class FirestoreOtherExpiryBatches extends StatelessWidget {
  final InventoryItem item;
  const FirestoreOtherExpiryBatches({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.noExpiry == true) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFFFDF4FC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            "No expiry date.",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: Colors.black54,
            ),
          ),
        ),
      );
    }

    final controller = ViewSupplyController();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('supplies')
          .where('name', isEqualTo: item.name)
          .where('brand', isEqualTo: item.brand)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFFFDF4FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                "No other expiry batches found.",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
            ),
          );
        }

        // Parse and filter batches
        final batches = snapshot.data!.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
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
            })
            .where((batch) => batch.id != item.id)
            .toList();

        // Sort by expiry date (earliest first, null/empty last)
        batches.sort((a, b) {
          // Place null/empty expiry at the end
          if (a.expiry == null || a.expiry!.isEmpty) return 1;
          if (b.expiry == null || b.expiry!.isEmpty) return -1;
          // Parse and compare as DateTime (assumes yyyy-mm-dd or yyyy/mm/dd or mm/dd/yyyy)
          try {
            DateTime aDate = DateTime.tryParse(a.expiry!) ??
                DateTime(9999, 12, 31); // fallback: very future
            DateTime bDate =
                DateTime.tryParse(b.expiry!) ?? DateTime(9999, 12, 31);
            return aDate.compareTo(bDate);
          } catch (e) {
            // fallback: compare as strings
            return a.expiry!.compareTo(b.expiry!);
          }
        });

        if (batches.isEmpty) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFFFDF4FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                "No other expiry batches found.",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
            ),
          );
        }

        return Column(
          children: batches.map((batch) {
            final status = controller.getStatus(batch); // from your helpers
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF4FC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      "${batch.stock}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      batch.unit,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "₱${batch.cost.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: controller.getStatusBgColor(status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: controller.getStatusTextColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      batch.expiry ?? "",
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.black54),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => InventoryViewSupplyPage(item: batch),
                        ),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
