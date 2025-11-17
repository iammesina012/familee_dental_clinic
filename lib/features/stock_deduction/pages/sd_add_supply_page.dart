import 'package:flutter/material.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/stock_deduction/controller/sd_add_supply_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StockDeductionAddSupplyPage extends StatefulWidget {
  const StockDeductionAddSupplyPage({super.key});

  @override
  State<StockDeductionAddSupplyPage> createState() =>
      _StockDeductionAddSupplyPageState();
}

class _StockDeductionAddSupplyPageState
    extends State<StockDeductionAddSupplyPage> {
  final TextEditingController _searchController = TextEditingController();
  final SdAddSupplyController _controller = SdAddSupplyController();
  String _searchText = '';
  bool _isFirstLoad = true;
  List<GroupedInventoryItem> _lastKnownGroups = [];

  Future<void> _showOutOfStockDialog(String name) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Out of stock',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            '"$name" has no available stock to deduct.',
            style: AppFonts.sfProStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: AppFonts.sfProStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDuplicateDialog(String name) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Already in list',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            '"$name" is already in your deduction list.',
            style: AppFonts.sfProStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: AppFonts.sfProStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool boldLabel = false, bool boldValue = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: AppFonts.sfProStyle(
                fontSize: 14,
                fontWeight: boldLabel ? FontWeight.bold : FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppFonts.sfProStyle(
                fontSize: 14,
                fontWeight: boldValue ? FontWeight.bold : FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<InventoryItem?> _showBatchSelectionDialog(
    BuildContext context,
    String supplyName,
    String? type,
    List<InventoryItem> batches,
  ) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Sort batches by expiry (earliest first, no expiry last) - FEFO
    // For batches with no expiry, use FIFO (First In First Out) based on createdAt
    final sortedBatches = List<InventoryItem>.from(batches);
    sortedBatches.sort((a, b) {
      // If both have no expiry, sort by createdAt (FIFO - earliest first)
      if (a.noExpiry && b.noExpiry) {
        if (a.createdAt != null && b.createdAt != null) {
          return a.createdAt!.compareTo(b.createdAt!); // Earliest first
        }
        if (a.createdAt != null)
          return -1; // a has createdAt, b doesn't - a comes first
        if (b.createdAt != null)
          return 1; // b has createdAt, a doesn't - b comes first
        return 0; // Neither has createdAt, maintain order
      }
      if (a.noExpiry) return 1; // No expiry goes to end
      if (b.noExpiry) return -1;

      final aExpiry = a.expiry != null
          ? DateTime.tryParse(a.expiry!.replaceAll('/', '-'))
          : null;
      final bExpiry = b.expiry != null
          ? DateTime.tryParse(b.expiry!.replaceAll('/', '-'))
          : null;

      if (aExpiry == null && bExpiry == null) return 0;
      if (aExpiry == null) return 1;
      if (bExpiry == null) return -1;
      return aExpiry.compareTo(bExpiry); // Earliest first
    });

    // Find the priority batch:
    // 1. If there are batches with expiry, use the earliest expiry batch
    // 2. If all batches have no expiry, use the earliest createdAt batch (FIFO)
    InventoryItem? priorityBatch;
    final batchesWithExpiry = sortedBatches
        .where(
          (b) => !b.noExpiry && b.expiry != null && b.expiry!.isNotEmpty,
        )
        .toList();

    if (batchesWithExpiry.isNotEmpty) {
      // Use FEFO - earliest expiry batch
      priorityBatch = batchesWithExpiry.first;
    } else {
      // All batches have no expiry - use FIFO based on createdAt
      final batchesWithCreatedAt = sortedBatches
          .where(
            (b) => b.createdAt != null,
          )
          .toList();

      if (batchesWithCreatedAt.isNotEmpty) {
        // Sort by createdAt to get the earliest
        batchesWithCreatedAt
            .sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
        priorityBatch = batchesWithCreatedAt.first;
      } else {
        // No batches have createdAt, don't show priority badge
        priorityBatch = null;
      }
    }

    // Format packaging info
    String formatPackaging(InventoryItem batch) {
      // Show: "100 pieces per box" format
      if (batch.packagingContentQuantity != null &&
          batch.packagingContentQuantity! > 0 &&
          batch.packagingContent != null &&
          batch.packagingContent!.isNotEmpty) {
        final content = batch.packagingContent!;
        final unit = batch.packagingUnit ?? batch.unit;
        if (unit.isNotEmpty) {
          return '${batch.packagingContentQuantity} $content per $unit';
        } else {
          return '${batch.packagingContentQuantity} $content';
        }
      }

      // Fallback: show packaging content if available
      if (batch.packagingContent != null &&
          batch.packagingContent!.isNotEmpty) {
        final unit = batch.packagingUnit ?? batch.unit;
        if (unit.isNotEmpty) {
          return '${batch.packagingContent} per $unit';
        } else {
          return batch.packagingContent!;
        }
      }

      // Fallback: show packaging unit or regular unit
      return batch.packagingUnit?.isNotEmpty == true
          ? batch.packagingUnit!
          : batch.unit;
    }

    return await showDialog<InventoryItem>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Batch Overview',
                  style: AppFonts.sfProStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  supplyName,
                  style: AppFonts.sfProStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Priority batch section
                        if (priorityBatch != null) ...[
                          Text(
                            'Priority',
                            style: AppFonts.sfProStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF00D4AA),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Priority batch details card (Label: Value format)
                          Builder(
                            builder: (context) {
                              final batch = priorityBatch!;
                              final unit = batch.packagingUnit?.isNotEmpty ==
                                      true
                                  ? batch.packagingUnit!
                                  : (batch.unit.isNotEmpty ? batch.unit : '');
                              final stockDisplay = unit.isNotEmpty
                                  ? '${batch.stock} $unit'
                                  : batch.stock.toString();

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF00D4AA),
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDetailRow('Stock', stockDisplay,
                                        boldLabel: true, boldValue: true),
                                    _buildDetailRow(
                                        'Type',
                                        batch.type?.isNotEmpty == true
                                            ? batch.type!
                                            : 'No Type'),
                                    _buildDetailRow(
                                        'Supplier',
                                        batch.supplier.isNotEmpty
                                            ? batch.supplier
                                            : 'Not specified'),
                                    _buildDetailRow(
                                        'Brand',
                                        batch.brand.isNotEmpty
                                            ? batch.brand
                                            : 'Not specified'),
                                    _buildDetailRow(
                                        'Category',
                                        batch.category.isNotEmpty
                                            ? batch.category
                                            : 'Not selected'),
                                    _buildDetailRow(
                                        'Packaging', formatPackaging(batch)),
                                    _buildDetailRow(
                                        'Expiry',
                                        _controller.formatExpiry(
                                            batch.expiry, batch.noExpiry)),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Next batches section
                        ...() {
                          final otherBatches = sortedBatches
                              .where((b) => priorityBatch?.id != b.id)
                              .toList();
                          if (otherBatches.isEmpty) return <Widget>[];
                          return [
                            Text(
                              'Next Batches:',
                              style: AppFonts.sfProStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...otherBatches.map((batch) {
                              final packagingInfo = formatPackaging(batch);
                              final unit = batch.packagingUnit?.isNotEmpty ==
                                      true
                                  ? batch.packagingUnit!
                                  : (batch.unit.isNotEmpty ? batch.unit : '');
                              final stockDisplay = unit.isNotEmpty
                                  ? '${batch.stock} $unit'
                                  : batch.stock.toString();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.dividerColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Stock: $stockDisplay',
                                                style: AppFonts.sfProStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.textTheme
                                                      .bodyLarge?.color,
                                                ),
                                              ),
                                              if (packagingInfo.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  packagingInfo,
                                                  style: AppFonts.sfProStyle(
                                                    fontSize: 14,
                                                    color: theme.textTheme
                                                        .bodyMedium?.color,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Text(
                                          _controller.formatExpiry(
                                              batch.expiry, batch.noExpiry),
                                          style: AppFonts.sfProStyle(
                                            fontSize: 12,
                                            color: theme
                                                .textTheme.bodySmall?.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (batch.brand.isNotEmpty ||
                                        batch.supplier.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          if (batch.brand.isNotEmpty) ...[
                                            Text(
                                              'Brand: ${batch.brand}',
                                              style: AppFonts.sfProStyle(
                                                fontSize: 12,
                                                color: theme
                                                    .textTheme.bodySmall?.color,
                                              ),
                                            ),
                                          ],
                                          if (batch.brand.isNotEmpty &&
                                              batch.supplier.isNotEmpty)
                                            Text(
                                              ' • ',
                                              style: AppFonts.sfProStyle(
                                                fontSize: 12,
                                                color: theme
                                                    .textTheme.bodySmall?.color,
                                              ),
                                            ),
                                          if (batch.supplier.isNotEmpty)
                                            Text(
                                              'Supplier: ${batch.supplier}',
                                              style: AppFonts.sfProStyle(
                                                fontSize: 12,
                                                color: theme
                                                    .textTheme.bodySmall?.color,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ];
                        }(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: AppFonts.sfProStyle(fontSize: 16),
                      ),
                    ),
                    if (priorityBatch != null) ...[
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pop(priorityBatch),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D4AA),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Add Supply',
                          style: AppFonts.sfProStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<InventoryItem?> _showTypeSelectionDialog(
    BuildContext context,
    GroupedInventoryItem groupedItem,
    List<InventoryItem> validBatches,
  ) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Group batches by type
    final Map<String?, List<InventoryItem>> batchesByType = {};
    for (final batch in validBatches) {
      final type = batch.type;
      if (!batchesByType.containsKey(type)) {
        batchesByType[type] = [];
      }
      batchesByType[type]!.add(batch);
    }

    // Sort batches within each type by expiry (earliest first)
    for (final typeBatches in batchesByType.values) {
      typeBatches.sort((a, b) {
        if (a.noExpiry && b.noExpiry) return 0;
        if (a.noExpiry) return 1;
        if (b.noExpiry) return -1;

        final aExpiry = a.expiry != null
            ? DateTime.tryParse(a.expiry!.replaceAll('/', '-'))
            : null;
        final bExpiry = b.expiry != null
            ? DateTime.tryParse(b.expiry!.replaceAll('/', '-'))
            : null;

        if (aExpiry == null && bExpiry == null) return 0;
        if (aExpiry == null) return 1;
        if (bExpiry == null) return -1;
        return aExpiry.compareTo(bExpiry);
      });
    }

    return await showDialog<InventoryItem>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Type',
                  style: AppFonts.sfProStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${groupedItem.mainItem.name}',
                  style: AppFonts.sfProStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: batchesByType.length,
                    itemBuilder: (context, index) {
                      final type = batchesByType.keys.elementAt(index);
                      final batches = batchesByType[type]!;

                      // Calculate total stock for this type
                      final totalStock = batches.fold<int>(
                          0, (sum, batch) => sum + batch.stock);

                      // If multiple batches exist for this type, show batch selection
                      final hasMultipleBatches = batches.length > 1;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: theme.colorScheme.surface,
                        child: InkWell(
                          onTap: () async {
                            // Always show batch selection dialog
                            final selectedBatch =
                                await _showBatchSelectionDialog(
                              context,
                              groupedItem.mainItem.name,
                              type,
                              batches,
                            );
                            // If batch was selected, return it and close type dialog
                            if (selectedBatch != null) {
                              Navigator.of(context).pop(selectedBatch);
                            }
                            // If cancelled, just close batch dialog (type dialog remains open)
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        type != null && type.isNotEmpty
                                            ? '${groupedItem.mainItem.name}($type)'
                                            : groupedItem.mainItem.name,
                                        style: AppFonts.sfProStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              theme.textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Text(
                                            'Stock: $totalStock',
                                            style: AppFonts.sfProStyle(
                                              fontSize: 14,
                                              color: theme
                                                  .textTheme.bodyMedium?.color,
                                            ),
                                          ),
                                          if (hasMultipleBatches) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${batches.length} batches',
                                                style: AppFonts.sfProStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios,
                                    size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: AppFonts.sfProStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Column(
      children: [
        // Search bar skeleton
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            height: 56,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Supply grid skeleton
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 800
                  ? 4
                  : constraints.maxWidth > 600
                      ? 3
                      : 2;

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  return Shimmer.fromColors(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read existing selections to prevent duplicates
    final args = ModalRoute.of(context)?.settings.arguments;
    final Set<String> existingDocIds = _controller.parseExistingDocIds(args);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Add Supply',
          style: AppFonts.sfProStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).appBarTheme.titleTextStyle?.color ??
                  Theme.of(context).textTheme.titleLarge?.color),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
        elevation: Theme.of(context).appBarTheme.elevation ?? 5,
        shadowColor: Theme.of(context).appBarTheme.shadowColor ??
            Theme.of(context).shadowColor,
      ),
      body: ResponsiveContainer(
        maxWidth: 1200,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withOpacity(0.08),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchText = v),
                    decoration: InputDecoration(
                      hintText: 'Search supplies...',
                      hintStyle: AppFonts.sfProStyle(
                          fontSize: 16,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withOpacity(0.6)),
                      prefixIcon: Icon(Icons.search,
                          color: Theme.of(context).iconTheme.color),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    style: AppFonts.sfProStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<List<GroupedInventoryItem>>(
                    stream: _controller.getGroupedSuppliesStream(
                        archived: false, expired: false),
                    builder: (context, snapshot) {
                      final live =
                          snapshot.data ?? const <GroupedInventoryItem>[];
                      final hasLive = live.isNotEmpty;
                      final bool showSkeleton = _isFirstLoad &&
                          (snapshot.connectionState ==
                                  ConnectionState.waiting ||
                              snapshot.connectionState ==
                                  ConnectionState.active) &&
                          !hasLive &&
                          _lastKnownGroups.isEmpty;

                      if (showSkeleton) {
                        return _buildSkeletonLoader(context);
                      }

                      if (hasLive) {
                        _lastKnownGroups = live;
                        if (_isFirstLoad) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _isFirstLoad = false;
                              });
                            }
                          });
                        }
                      }

                      final groups = hasLive
                          ? live
                          : (_lastKnownGroups.isNotEmpty
                              ? _lastKnownGroups
                              : live);
                      final filtered =
                          _controller.filterSupplies(groups, _searchText);

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off,
                                  size: 60, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No supplies found',
                                style: AppFonts.sfProStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your search terms',
                                style: AppFonts.sfProStyle(
                                    fontSize: 14, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: constraints.maxWidth > 800
                                  ? 4
                                  : constraints.maxWidth > 600
                                      ? 3
                                      : 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              // Taller tiles to better fit long names
                              childAspectRatio: 0.75,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final groupedItem = filtered[index];

                              // Find the earliest expiry item with stock for display
                              final allBatches = [
                                groupedItem.mainItem,
                                ...groupedItem.variants
                              ];
                              final validBatches = allBatches
                                  .where((batch) => batch.stock > 0)
                                  .toList();

                              // Sort by expiry (earliest first, no expiry last)
                              validBatches.sort((a, b) {
                                if (a.noExpiry && b.noExpiry) return 0;
                                if (a.noExpiry) return 1;
                                if (b.noExpiry) return -1;

                                final aExpiry = a.expiry != null
                                    ? DateTime.tryParse(
                                        a.expiry!.replaceAll('/', '-'))
                                    : null;
                                final bExpiry = b.expiry != null
                                    ? DateTime.tryParse(
                                        b.expiry!.replaceAll('/', '-'))
                                    : null;

                                if (aExpiry == null && bExpiry == null)
                                  return 0;
                                if (aExpiry == null) return 1;
                                if (bExpiry == null) return -1;
                                return aExpiry.compareTo(bExpiry);
                              });

                              // Use earliest expiry item for display, fallback to mainItem if no valid batches
                              final InventoryItem item = validBatches.isNotEmpty
                                  ? validBatches.first
                                  : groupedItem.mainItem;
                              return GestureDetector(
                                onTap: () async {
                                  if (_controller.isOutOfStock(item)) {
                                    await _showOutOfStockDialog(item.name);
                                    return;
                                  }

                                  // Helper to finalize selection after choosing exact batch
                                  Future<void> finalizeSelection(
                                      InventoryItem selectedBatch) async {
                                    if (_controller.isDuplicate(
                                        selectedBatch.id, existingDocIds)) {
                                      await _showDuplicateDialog(
                                          selectedBatch.name);
                                      return;
                                    }
                                    if (!mounted) return;
                                    Navigator.pop(context,
                                        _controller.toReturnMap(selectedBatch));
                                  }

                                  // Check if there are multiple types/variants
                                  final allBatches = [
                                    groupedItem.mainItem,
                                    ...groupedItem.variants
                                  ];
                                  final validBatches = allBatches
                                      .where((batch) => batch.stock > 0)
                                      .toList();

                                  // Group batches by type (null/empty types are grouped together)
                                  final Map<String?, List<InventoryItem>>
                                      batchesByType = {};
                                  for (final batch in validBatches) {
                                    final typeKey = (batch.type != null &&
                                            batch.type!.isNotEmpty)
                                        ? batch.type
                                        : null;
                                    batchesByType[typeKey] ??= [];
                                    batchesByType[typeKey]!.add(batch);
                                  }

                                  // If multiple types exist (including null as a type), show type selection dialog
                                  if (batchesByType.length > 1) {
                                    final selectedBatch =
                                        await _showTypeSelectionDialog(
                                            context, groupedItem, validBatches);
                                    if (selectedBatch != null) {
                                      await finalizeSelection(selectedBatch);
                                    }
                                  } else {
                                    // Single type or no type - always show batch selection dialog
                                    final singleTypeBatches =
                                        batchesByType.values.first;
                                    final selectedBatch =
                                        await _showBatchSelectionDialog(
                                      context,
                                      groupedItem.mainItem.name,
                                      batchesByType.keys.first,
                                      singleTypeBatches,
                                    );
                                    if (selectedBatch != null) {
                                      await finalizeSelection(selectedBatch);
                                    }
                                  }
                                },
                                child: _buildInventoryStyleCard(context, item),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryStyleCard(BuildContext context, InventoryItem item) {
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: item.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          width: 96,
                          height: 96,
                          fit: BoxFit.contain,
                          placeholder: (context, url) {
                            return Container(
                              width: 96,
                              height: 96,
                              color: Colors.grey[200],
                              child: Icon(Icons.image,
                                  size: 48, color: Colors.grey[400]),
                            );
                          },
                          errorWidget: (context, url, error) => const Icon(
                              Icons.image_not_supported,
                              size: 96,
                              color: Colors.grey),
                          fadeInDuration: const Duration(milliseconds: 200),
                          fadeOutDuration: const Duration(milliseconds: 100),
                        )
                      : const Icon(Icons.image_not_supported,
                          size: 96, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Product Name
                Flexible(
                  child: SizedBox(
                    width: double.infinity,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
