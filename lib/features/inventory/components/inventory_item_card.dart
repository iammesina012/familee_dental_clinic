import 'package:flutter/material.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';

class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final String? status;
  final String? currentSort;
  final bool? showExpiryDate;
  final int? overrideStock; // When provided, display this instead of item.stock
  final bool hideStock;
  final bool hideExpiry;
  const InventoryItemCard(
      {required this.item,
      this.status,
      this.currentSort,
      this.showExpiryDate,
      this.overrideStock,
      this.hideStock = false,
      this.hideExpiry = false,
      super.key});

  String getStatus() {
    // Check archived status first - archived items should always show "Archived"
    if (item.archived) {
      return "Archived";
    }

    // If status is provided, use it (for grouped items) - this takes priority
    if (status != null) {
      return status!;
    }

    // Note: Expired status is now handled by the dedicated Expired Supply page
    // Main inventory system no longer shows expired status

    // Check stock status only
    if (item.stock == 0) {
      return "Out of Stock";
    }

    // Otherwise, calculate status based on item properties
    if (item.stock <= 2) {
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

    // Try to parse the expiry date with consistent normalization
    final expiryDate = DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
    if (expiryDate == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly =
        DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final daysUntilExpiry = dateOnly.difference(today).inDays;

    // Check if expired (using date-only comparison)
    if (dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today))
      return "Expired";

    // Check if expiring soon (within 30 days)
    if (daysUntilExpiry <= 30) return "Expiring";

    // If not expiring soon and not expired, no chip needed
    return null;
  }

  // Check if current sort is an expiry date sort or if expiry date should be shown
  bool get isExpirySort {
    // If showExpiryDate is explicitly set, use that
    if (showExpiryDate != null) return showExpiryDate!;

    // Check if current sort is an expiry date sort
    if (currentSort != null && currentSort!.contains("Expiry Date")) {
      return true;
    }

    // Show expiry date if item is expiring or if status is explicitly set to "Expired"
    final expiryStatus = getExpiryStatus();
    return expiryStatus == "Expiring" ||
        (status != null && status == "Expired");
  }

  // Format expiry date for display
  String formatExpiryDate() {
    if (item.noExpiry || item.expiry == null || item.expiry!.isEmpty) {
      return "N/A";
    }

    try {
      final expiryDate = DateTime.parse(item.expiry!.replaceAll('/', '-'));
      return "${expiryDate.month}/${expiryDate.day}/${expiryDate.year}";
    } catch (e) {
      return item.expiry!; // Return as-is if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = getStatus();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (theme.brightness == Brightness.dark
                    ? Colors.black
                    : Colors.black)
                .withOpacity(0.12),
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
            SizedBox(height: 16),
            // Flexible text container that adjusts based on expiry display
            Flexible(
              child: Text(
                item.name,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.textTheme.bodyMedium?.color),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Only show stock number if not "Out of Stock"
                if (!hideStock && status != "Out of Stock") ...[
                  Text(
                    'Stock: ${overrideStock ?? item.stock}',
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium?.color),
                  ),
                  SizedBox(width: 8),
                ],
                // Add extra top spacing only for "Out of Stock" to align with other chips
                Container(
                  constraints: BoxConstraints(minWidth: 72),
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == "Archived"
                        ? const Color(0xFFFFF59D)
                        : status == "In Stock"
                            ? (theme.brightness == Brightness.dark
                                ? Colors.green[900]
                                : Colors.green[100])
                            : status == "Low Stock"
                                ? (theme.brightness == Brightness.dark
                                    ? Colors.orange[900]
                                    : Colors.orange[100])
                                : status == "Out of Stock"
                                    ? (theme.brightness == Brightness.dark
                                        ? const Color(0xFF5B2B2B)
                                        : const Color(0xFFFFCDD2))
                                    : status == "Expired"
                                        ? (theme.brightness == Brightness.dark
                                            ? const Color(0xFF5B2B2B)
                                            : const Color(0xFFFFCDD2))
                                        : status == "Expiring"
                                            ? (theme.brightness ==
                                                    Brightness.dark
                                                ? Colors.orange[900]
                                                : Colors.orange[100])
                                            : (theme.brightness ==
                                                    Brightness.dark
                                                ? const Color(0xFF5B2B2B)
                                                : Colors.red[100]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: status == "Archived"
                          ? const Color(0xFFF57C00)
                          : status == "In Stock"
                              ? (theme.brightness == Brightness.dark
                                  ? Colors.green[300]
                                  : Colors.green)
                              : status == "Low Stock"
                                  ? (theme.brightness == Brightness.dark
                                      ? Colors.orange[300]
                                      : Colors.orange)
                                  : status == "Out of Stock"
                                      ? (theme.brightness == Brightness.dark
                                          ? const Color(0xFFFF8A80)
                                          : const Color(0xFFFF4747))
                                      : status == "Expired"
                                          ? (theme.brightness == Brightness.dark
                                              ? const Color(0xFFFF8A80)
                                              : const Color(0xFFFF4747))
                                          : status == "Expiring"
                                              ? (theme.brightness ==
                                                      Brightness.dark
                                                  ? Colors.orange[300]
                                                  : Colors.orange)
                                              : (theme.brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFFFF8A80)
                                                  : Colors.red),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            // Show expiry date only when sorting by expiry AND not "Out of Stock"
            if (!hideExpiry && isExpirySort && status != "Out of Stock") ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue[50]!,
                      Colors.blue[100]!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue[600],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      formatExpiryDate(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
