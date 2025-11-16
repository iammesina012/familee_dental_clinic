import 'package:flutter/material.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:cached_network_image/cached_network_image.dart';

class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final String? status;
  final String? currentSort;
  final bool? showExpiryDate;
  final int? overrideStock; // When provided, display this instead of item.stock
  final bool hideStock;
  final bool hideExpiry;
  final List<InventoryItem>? variants; // Variants for counting status badges
  final String? titleOverride; // Optional override for displayed name/title
  const InventoryItemCard(
      {required this.item,
      this.status,
      this.currentSort,
      this.showExpiryDate,
      this.overrideStock,
      this.hideStock = false,
      this.hideExpiry = false,
      this.variants,
      this.titleOverride,
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

    // Use manually set threshold for low stock detection
    if (item.lowStockBaseline != null &&
        item.lowStockBaseline! > 0 &&
        item.stock <= item.lowStockBaseline!) {
      return "Low Stock";
    }

    return "In Stock";
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
      return "No Expiry";
    }

    try {
      final expiryDate = DateTime.parse(item.expiry!.replaceAll('/', '-'));
      return "${expiryDate.month}/${expiryDate.day}/${expiryDate.year}";
    } catch (e) {
      return item.expiry!; // Return as-is if parsing fails
    }
  }

  // Count status occurrences in variants (excluding the main item's status)
  Map<String, int> _getStatusCounts() {
    final counts = <String, int>{};
    final overallStatus = getStatus();

    if (variants == null || variants!.isEmpty) {
      return counts; // No variants, no badges
    }

    // Group all items (main item + variants) by type
    final allItems = [item, ...variants!];
    final Map<String, List<InventoryItem>> itemsByType = {};

    for (final variantItem in allItems) {
      // Use empty string for null/empty types to group them together
      final typeKey = (variantItem.type ?? '').trim();
      if (!itemsByType.containsKey(typeKey)) {
        itemsByType[typeKey] = [];
      }
      itemsByType[typeKey]!.add(variantItem);
    }

    // Calculate status for each type and count
    for (final typeGroup in itemsByType.values) {
      // Sum stock across all batches of this type
      final totalStockForType =
          typeGroup.fold(0, (sum, item) => sum + item.stock);

      // Get the threshold (all batches of same type share the same threshold)
      final threshold = typeGroup.first.lowStockBaseline ?? 0;

      // Determine status for this type
      String typeStatus;
      if (totalStockForType == 0) {
        typeStatus = "Out of Stock";
      } else if (threshold > 0 && totalStockForType <= threshold) {
        typeStatus = "Low Stock";
      } else {
        typeStatus = "In Stock";
      }

      // Only count if status is different from overall status
      // and not "Archived" or "In Stock" (we only show Low Stock and Out of Stock badges)
      if (typeStatus != overallStatus &&
          typeStatus != "Archived" &&
          typeStatus != "In Stock") {
        counts[typeStatus] = (counts[typeStatus] ?? 0) + 1;
      }
    }

    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final status = getStatus();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusCounts = _getStatusCounts();
    final hasBadges = statusCounts.isNotEmpty;

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
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Show Supabase image (or placeholder) with caching
                item.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl,
                        width: 96,
                        height: 96,
                        fit: BoxFit.contain,
                        placeholder: (context, url) {
                          debugPrint(
                              '[IMAGE_CARD] Loading placeholder for ${item.name} (URL: $url)');
                          return Container(
                            width: 96,
                            height: 96,
                            color: Colors.grey[200],
                            child: Icon(Icons.image,
                                size: 48, color: Colors.grey[400]),
                          );
                        },
                        errorWidget: (context, url, error) {
                          debugPrint(
                              '[IMAGE_CARD] ERROR loading ${item.name} (URL: $url, Error: $error)');
                          return Icon(Icons.image_not_supported,
                              size: 96, color: Colors.grey);
                        },
                        fadeInDuration: const Duration(milliseconds: 200),
                        fadeOutDuration: const Duration(milliseconds: 100),
                      )
                    : Icon(Icons.image_not_supported,
                        size: 96, color: Colors.grey),
                SizedBox(height: 16),
                // Flexible text container that adjusts based on expiry display
                Flexible(
                  child: Text(
                    titleOverride ?? item.name,
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
                                            ? (theme.brightness ==
                                                    Brightness.dark
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
                                              ? (theme.brightness ==
                                                      Brightness.dark
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
                if (!hideExpiry &&
                    isExpirySort &&
                    status != "Out of Stock") ...[
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
          // Status badges in top right corner
          if (hasBadges)
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show badges in order: Out of Stock first, then Low Stock
                  if (statusCounts.containsKey("Out of Stock"))
                    _buildStatusBadge(
                      context,
                      statusCounts["Out of Stock"]!,
                      "Out of Stock",
                    ),
                  if (statusCounts.containsKey("Out of Stock") &&
                      statusCounts.containsKey("Low Stock"))
                    SizedBox(width: 4),
                  if (statusCounts.containsKey("Low Stock"))
                    _buildStatusBadge(
                      context,
                      statusCounts["Low Stock"]!,
                      "Low Stock",
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, int count, String statusType) {
    final isLowStock = statusType == "Low Stock";
    final isOutOfStock = statusType == "Out of Stock";
    final theme = Theme.of(context);

    Color backgroundColor;
    Color borderColor;
    Color textColor;

    if (isLowStock) {
      // Light orange background with orange border (matching Low Stock status indicator)
      backgroundColor = theme.brightness == Brightness.dark
          ? Colors.orange[900]!
          : Colors.orange[100]!;
      borderColor = theme.brightness == Brightness.dark
          ? Colors.orange[300]!
          : Colors.orange;
      textColor = theme.brightness == Brightness.dark
          ? Colors.orange[300]!
          : Colors.orange;
    } else if (isOutOfStock) {
      // Light red with red border
      backgroundColor = const Color(0xFFFFEBEE); // Light red
      borderColor = Colors.red;
      textColor = Colors.red;
    } else {
      // Default
      backgroundColor = Colors.grey[100]!;
      borderColor = Colors.grey;
      textColor = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '+$count',
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
