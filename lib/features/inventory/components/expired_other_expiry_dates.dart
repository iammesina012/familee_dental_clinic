import 'package:flutter/material.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/inventory/pages/expired_view_supply_page.dart';
import 'package:familee_dental/features/inventory/controller/expired_view_supply_controller.dart';
import 'package:shimmer/shimmer.dart';

class ExpiredOtherExpiryBatches extends StatefulWidget {
  final InventoryItem item;
  const ExpiredOtherExpiryBatches({super.key, required this.item});

  @override
  State<ExpiredOtherExpiryBatches> createState() =>
      _ExpiredOtherExpiryBatchesState();
}

class _ExpiredOtherExpiryBatchesState extends State<ExpiredOtherExpiryBatches> {
  Widget _buildSkeletonLoader(ThemeData theme, ColorScheme scheme) {
    return Shimmer.fromColors(
      baseColor: theme.brightness == Brightness.dark
          ? Colors.grey[800]!
          : Colors.grey[300]!,
      highlightColor: theme.brightness == Brightness.dark
          ? Colors.grey[700]!
          : Colors.grey[100]!,
      child: Column(
        children: List.generate(
            3,
            (index) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: theme.dividerColor.withOpacity(0.2)),
                  ),
                  height: 50,
                )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (widget.item.noExpiry == true) {
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

    final controller = ExpiredViewSupplyController();

    return StreamBuilder<List<InventoryItem>>(
      stream: controller.getOtherExpiredBatchesStream(
          widget.item.name, widget.item.brand, widget.item.id),
      builder: (context, snapshot) {
        // Show skeleton loader only if no cached data is available
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData &&
            !snapshot.hasError) {
          return _buildSkeletonLoader(theme, scheme);
        }

        // On error, show empty state instead of error message
        if (snapshot.hasError && !snapshot.hasData) {
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
                "No other expired batches found.",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                "No other expired batches found.",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ),
          );
        }

        // Exclude the same expiry date as the current item to avoid duplicating the main section
        final batches = snapshot.data!;
        DateTime? currentDt;
        try {
          currentDt = DateTime.tryParse(widget.item.expiry ?? '') ??
              DateTime.tryParse(
                  (widget.item.expiry ?? '').replaceAll('/', '-'));
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
                color: scheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      "$totalStock",
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
                        color: theme.brightness == Brightness.dark
                            ? const Color(0xFF5B2B2B)
                            : const Color(0xFFFFCDD2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFFFF8A80)
                              : const Color(0xFFFF4747),
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
                    icon: Icon(Icons.arrow_forward_ios,
                        size: 16,
                        color: theme.iconTheme.color?.withOpacity(0.6)),
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
