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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (item.noExpiry == true) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        ),
        child: Center(
          child: Text(
            "No expiry date.",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
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
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
            ),
            child: Center(
              child: Text(
                "No other expiry batches found.",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ),
          );
        }

        // Parse and filter batches
        final batches = snapshot.data!.docs.map((doc) {
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
            expiry: data['expiry'] ?? 'No expiry',
            noExpiry: data['noExpiry'] ?? false,
            archived: data['archived'] ?? false,
          );
        }).where((batch) {
          // Keep only same category using normalized comparison
          final batchCat = batch.category.trim().toLowerCase();
          final currentCat = item.category.trim().toLowerCase();
          if (batchCat != currentCat) return false;

          // Exclude the item we are viewing, zero-stock batches, and expired batches
          if (batch.id == item.id || batch.stock == 0) return false;

          // Filter out expired batches ONLY for non-archived view.
          // When viewing an archived item, include expired batches so they are visible.
          final bool viewingArchived = item.archived;
          if (!viewingArchived) {
            if (!batch.noExpiry &&
                batch.expiry != null &&
                batch.expiry!.isNotEmpty) {
              final today = DateTime.now();
              final todayDateOnly =
                  DateTime(today.year, today.month, today.day);

              final expiryDate = DateTime.tryParse(batch.expiry!) ??
                  DateTime.tryParse(batch.expiry!.replaceAll('/', '-'));

              if (expiryDate != null) {
                final expiryDateOnly =
                    DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
                // Exclude if expired (on or before today)
                if (expiryDateOnly.isBefore(todayDateOnly) ||
                    expiryDateOnly.isAtSameMomentAs(todayDateOnly)) {
                  return false;
                }
              }
            }
          }

          return true;
        }).toList();

        // Sort by expiry date (earliest first, null/empty last). Normalize formats.
        DateTime? parseExpiry(String? value) {
          if (value == null || value.isEmpty) return null;
          return DateTime.tryParse(value) ??
              DateTime.tryParse(value.replaceAll('/', '-'));
        }

        batches.sort((a, b) {
          final da = parseExpiry(a.expiry);
          final db = parseExpiry(b.expiry);
          if (da == null && db == null) return 0;
          if (da == null) return 1; // nulls last
          if (db == null) return -1;
          return da.compareTo(db);
        });

        if (batches.isEmpty) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
            ),
            child: Center(
              child: Text(
                "No other expiry batches found.",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ),
          );
        }

        // Merge batches by normalized (brand, supplier, expiry, unit, cost) and sum stock
        String norm(String v) => v.trim().toLowerCase();
        DateTime? parseExpiry2(String? v) {
          if (v == null || v.isEmpty) return null;
          return DateTime.tryParse(v) ??
              DateTime.tryParse(v.replaceAll('/', '-'));
        }

        final Map<String, InventoryItem> merged = {};
        for (final b in batches) {
          final exp = parseExpiry2(b.expiry);
          final expKey = exp == null
              ? 'noexpiry'
              : '${exp.year}-${exp.month.toString().padLeft(2, '0')}-${exp.day.toString().padLeft(2, '0')}';
          final key =
              '${norm(b.brand)}|${norm(b.supplier)}|$expKey|${norm(b.unit)}|${b.cost.toStringAsFixed(2)}';
          if (merged.containsKey(key)) {
            final existing = merged[key]!;
            merged[key] = InventoryItem(
              id: existing.id,
              name: existing.name,
              imageUrl: existing.imageUrl,
              category: existing.category,
              cost: existing.cost,
              stock: existing.stock + b.stock,
              unit: existing.unit,
              supplier: existing.supplier,
              brand: existing.brand,
              expiry: existing.expiry,
              noExpiry: existing.noExpiry,
              archived: existing.archived,
            );
          } else {
            merged[key] = b;
          }
        }

        final mergedList = merged.values.toList();

        return Column(
          children: mergedList.map((batch) {
            final status = controller.getStatus(batch); // from your helpers
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      "${batch.stock}",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      batch.unit,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "₱${batch.cost.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color,
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
                      (batch.expiry ?? "").replaceAll('-', '/'),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => InventoryViewSupplyPage(
                              item: batch, skipAutoRedirect: true),
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
