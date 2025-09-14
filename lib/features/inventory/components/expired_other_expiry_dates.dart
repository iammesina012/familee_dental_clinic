import 'package:flutter/material.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';
import 'package:projects/features/inventory/pages/expired_view_supply_page.dart';
import '../controller/expired_view_supply_controller.dart';

class ExpiredOtherExpiryBatches extends StatelessWidget {
  final InventoryItem item;
  const ExpiredOtherExpiryBatches({super.key, required this.item});

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

    final controller = ExpiredViewSupplyController();

    return StreamBuilder<List<InventoryItem>>(
      stream: controller.getOtherExpiredBatchesStream(
          item.name, item.brand, item.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                "No other expired batches found.",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
            ),
          );
        }

        // Exclude the same expiry date as the current item to avoid duplicating the main section
        final batches = snapshot.data!;
        DateTime? currentDt;
        try {
          currentDt = DateTime.tryParse(item.expiry ?? '') ??
              DateTime.tryParse((item.expiry ?? '').replaceAll('/', '-'));
        } catch (_) {
          currentDt = null;
        }

        // Group by expiry date (normalized yyyy-MM-dd) and sum stock
        DateTime? _parseExpiry(String? value) {
          if (value == null || value.isEmpty) return null;
          return DateTime.tryParse(value) ??
              DateTime.tryParse(value.replaceAll('/', '-'));
        }

        final Map<String, Map<String, dynamic>> dateKeyToGroup = {};
        for (final batch in batches) {
          final dt = _parseExpiry(batch.expiry);
          if (dt == null) continue;
          if (currentDt != null) {
            final isSame = dt.year == currentDt.year &&
                dt.month == currentDt.month &&
                dt.day == currentDt.day;
            if (isSame)
              continue; // skip same date as the main (aggregated in header)
          }
          final key = '${dt.year.toString().padLeft(4, '0')}-'
              '${dt.month.toString().padLeft(2, '0')}-'
              '${dt.day.toString().padLeft(2, '0')}';
          if (!dateKeyToGroup.containsKey(key)) {
            dateKeyToGroup[key] = {
              'item': batch, // representative for unit/cost/navigation
              'stock': batch.stock,
              'date': dt,
            };
          } else {
            dateKeyToGroup[key]!['stock'] =
                (dateKeyToGroup[key]!['stock'] as int) + batch.stock;
            // keep the first representative
          }
        }

        final grouped = dateKeyToGroup.values.toList()
          ..sort((a, b) =>
              (a['date'] as DateTime).compareTo(b['date'] as DateTime));

        return Column(
          children: grouped.map((g) {
            final batch = g['item'] as InventoryItem;
            final totalStock = g['stock'] as int;
            final status = "Expired"; // Force expired status
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
                      "$totalStock",
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
                        color: Color(0xFFFFCDD2), // Red background for expired
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: Color(0xFFFF4747), // Red text
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
                          builder: (_) => ExpiredViewSupplyPage(
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
