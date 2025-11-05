import 'package:flutter/material.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/inventory/pages/view_supply_page.dart'; // for status helpers
import 'package:familee_dental/features/inventory/controller/view_supply_controller.dart';
import 'package:familee_dental/features/inventory/controller/inventory_controller.dart';
import 'package:shimmer/shimmer.dart';

class SupabaseOtherSupplyBatches extends StatefulWidget {
  final InventoryItem item;
  const SupabaseOtherSupplyBatches({super.key, required this.item});

  @override
  State<SupabaseOtherSupplyBatches> createState() =>
      _SupabaseOtherSupplyBatchesState();
}

class _SupabaseOtherSupplyBatchesState
    extends State<SupabaseOtherSupplyBatches> {
  // Cache for processed batches to prevent expensive recomputation on rebuilds
  List<InventoryItem>? _cachedProcessedBatches;
  String? _lastItemId;

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
    final controller = ViewSupplyController();
    final inventoryController = InventoryController();

    // Use cached batches if item hasn't changed
    final useCache =
        _cachedProcessedBatches != null && _lastItemId == widget.item.id;

    return StreamBuilder<List<InventoryItem>>(
      stream: useCache
          ? Stream.value(_cachedProcessedBatches!)
          : inventoryController.getSuppliesStream().map((items) {
              // Normalize type comparison: handle null, empty, and case-insensitive
              final normalizedItemType =
                  (widget.item.type ?? '').toString().trim().toLowerCase();
              return items.where((item) {
                final rowName = item.name.toString().trim();
                final itemName = widget.item.name.toString().trim();
                if (rowName != itemName) return false;

                // Normalize type comparison
                final rowType =
                    (item.type ?? '').toString().trim().toLowerCase();
                return rowType == normalizedItemType;
              }).toList();
            }),
      builder: (context, snapshot) {
        // Show skeleton loader only if no data exists (no cached data available)
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData &&
            !snapshot.hasError) {
          return _buildSkeletonLoader(theme, scheme);
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
                "No other supply batches found.",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ),
          );
        }

        // Process batches only if we have new data or cache is invalid
        List<InventoryItem> batches;
        if (useCache && _cachedProcessedBatches != null) {
          // Use cached fully processed batches (already filtered, sorted, and merged)
          batches = _cachedProcessedBatches!;
        } else {
          // Process batches from scratch - ALL EXISTING LOGIC PRESERVED
          batches = snapshot.data!.where((batch) {
            // Keep only same category using normalized comparison
            final batchCat = batch.category.trim().toLowerCase();
            final currentCat = widget.item.category.trim().toLowerCase();
            if (batchCat != currentCat) return false;

            // Exclude the item we are viewing
            // All other batches with same name, type, and category should show,
            // regardless of brand, supplier, cost, expiry, stock, etc.
            if (batch.id == widget.item.id) return false;

            // Filter out expired batches ONLY for non-archived view and ONLY for items WITH expiry dates.
            // When viewing an archived item, include expired batches so they are visible.
            // Items with no expiry are always included regardless of archived status.
            final bool viewingArchived = widget.item.archived;
            if (!viewingArchived &&
                !batch.noExpiry &&
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

            return true;
          }).toList();

          // Filter out zero-stock batches only if there are other batches with stock
          // Include the main item's stock in the calculation
          final hasStockBatches =
              widget.item.stock > 0 || batches.any((batch) => batch.stock > 0);
          if (hasStockBatches) {
            batches.removeWhere((batch) => batch.stock == 0);
          }

          // Sort by expiry date (earliest first, no expiry last). Normalize formats.
          DateTime? parseExpiry(String? value) {
            if (value == null || value.isEmpty || value == 'No expiry')
              return null;
            return DateTime.tryParse(value) ??
                DateTime.tryParse(value.replaceAll('/', '-'));
          }

          batches.sort((a, b) {
            // Handle no expiry items
            final aNoExpiry = a.noExpiry ||
                a.expiry == null ||
                a.expiry!.isEmpty ||
                a.expiry == 'No expiry';
            final bNoExpiry = b.noExpiry ||
                b.expiry == null ||
                b.expiry!.isEmpty ||
                b.expiry == 'No expiry';

            if (aNoExpiry && bNoExpiry)
              return 0; // Both no expiry, keep original order
            if (aNoExpiry) return 1; // a has no expiry, put it last
            if (bNoExpiry) return -1; // b has no expiry, put it last

            // Both have expiry dates, sort by date (earliest first)
            final da = parseExpiry(a.expiry);
            final db = parseExpiry(b.expiry);
            if (da == null && db == null) return 0;
            if (da == null) return 1;
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
                  "No other supply batches found.",
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
                type: existing.type,
                imageUrl: existing.imageUrl,
                category: existing.category,
                cost: existing.cost,
                stock: existing.stock + b.stock,
                unit: existing.unit,
                packagingUnit: existing.packagingUnit,
                packagingContent: existing.packagingContent,
                packagingQuantity: existing.packagingQuantity,
                packagingContentQuantity: existing.packagingContentQuantity,
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

          final mergedListTemp = merged.values.toList();

          // Cache the fully processed batches to prevent recomputation on rebuild
          if (mounted) {
            _cachedProcessedBatches = mergedListTemp;
            _lastItemId = widget.item.id;
          }

          // Check if empty after merging
          if (mergedListTemp.isEmpty) {
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
                  "No other supply batches found.",
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
              ),
            );
          }

          // Use the merged list for rendering
          batches = mergedListTemp;
        }

        // Final check for empty (for both cached and newly processed batches)
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
                "No other supply batches found.",
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ),
          );
        }

        final mergedList = batches;

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
                      batch.noExpiry ||
                              batch.expiry == null ||
                              batch.expiry!.isEmpty
                          ? "No expiry"
                          : batch.expiry!.replaceAll('-', '/'),
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
