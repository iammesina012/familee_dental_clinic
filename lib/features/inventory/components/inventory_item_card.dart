import 'package:flutter/material.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';

class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final String? status;
  const InventoryItemCard({required this.item, this.status, super.key});

  String getStatus() {
    // Check archived status first - archived items should always show "Archived"
    if (item.archived) {
      return "Archived";
    }

    // If status is provided, use it (for grouped items)
    if (status != null) {
      return status!;
    }

    // Check expiry status - if expired or expiring soon, show that instead of stock status
    final expiryStatus = getExpiryStatus();
    if (expiryStatus != null) {
      return expiryStatus;
    }

    // Otherwise, calculate status based on item properties
    if (item.stock == 0) {
      return "Out of Stock";
    } else if (item.stock <= 2) {
      return "Low Stock";
    } else {
      return "In Stock";
    }
  }

  String? getExpiryStatus() {
    // If item has no expiry flag, return null (no expiry chip)
    if (item.noExpiry) return null;

    // If item has no expiry date, return null (no expiry chip)
    if (item.expiry == null || item.expiry!.isEmpty) return null;

    // Try to parse the expiry date
    final expiryDate = DateTime.tryParse(item.expiry!);
    if (expiryDate == null) return null;

    final today = DateTime.now();
    final daysUntilExpiry = expiryDate.difference(today).inDays;

    // Check if expired
    if (expiryDate.isBefore(today)) return "Expired";

    // Check if expiring soon (within 30 days)
    if (daysUntilExpiry <= 30) return "Expiring";

    // If not expiring soon and not expired, no chip needed
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final status = getStatus();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Show Firestore image (or placeholder)
            item.imageUrl.isNotEmpty
                ? Image.network(
                    item.imageUrl,
                    width: 96,
                    height: 96,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.image_not_supported,
                          size: 96, color: Colors.grey);
                    },
                  )
                : Icon(Icons.image_not_supported, size: 96, color: Colors.grey),
            SizedBox(height: 18),
            SizedBox(
              height: 45,
              child: Text(
                item.name,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Stock: ${item.stock}',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
                SizedBox(width: 8),
                Container(
                  constraints: BoxConstraints(minWidth: 72),
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == "Archived"
                        ? const Color(0xFFFFF59D) // Light yellow background
                        : status == "In Stock"
                            ? Colors.green[100]
                            : status == "Low Stock"
                                ? Colors.orange[100]
                                : status == "Out of Stock"
                                    ? Color(0xFFFFCDD2) // More red background
                                    : status == "Expired"
                                        ? Color(
                                            0xFFFFCDD2) // Same as Out of Stock
                                        : status == "Expiring"
                                            ? Colors.orange[
                                                100] // Same as Low Stock
                                            : Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: status == "Archived"
                          ? const Color(0xFFF57C00) // Pure yellow text
                          : status == "In Stock"
                              ? Colors.green
                              : status == "Low Stock"
                                  ? Colors.orange
                                  : status == "Out of Stock"
                                      ? Color(0xFFFF4747)
                                      : status == "Expired"
                                          ? Color(
                                              0xFFFF4747) // Same as Out of Stock
                                          : status == "Expiring"
                                              ? Colors
                                                  .orange // Same as Low Stock
                                              : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
