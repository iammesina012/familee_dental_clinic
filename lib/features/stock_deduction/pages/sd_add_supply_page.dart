import 'package:flutter/material.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/stock_deduction/controller/sd_add_supply_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:shimmer/shimmer.dart';

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
  bool _multiSelectMode = false;
  final Set<String> _selectedIds = {};
  final Map<String, InventoryItem> _selectedItems = {};
  bool _isFirstLoad = true;

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

  void _toggleSelect(InventoryItem item) async {
    if (_controller.isOutOfStock(item)) {
      await _showOutOfStockDialog(item.name);
      return;
    }
    _controller.toggleSelect(item, _selectedIds, _selectedItems, () {
      setState(() {});
    });
  }

  void _submitSelection() {
    if (_selectedItems.isEmpty) return;
    final list = _controller.submitSelection(_selectedItems);
    Navigator.pop(context, list);
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: Colors.red, size: 30),
              onPressed: () {
                Navigator.pushNamed(context, '/notifications');
              },
            ),
          ),
        ],
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
                TextField(
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
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<List<GroupedInventoryItem>>(
                    stream: _controller.getGroupedSuppliesStream(
                        archived: false, expired: false),
                    builder: (context, snapshot) {
                      // Show skeleton loader only on first load
                      if (_isFirstLoad && !snapshot.hasData) {
                        return _buildSkeletonLoader(context);
                      }

                      // Mark first load as complete once we have data
                      if (snapshot.hasData && _isFirstLoad) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _isFirstLoad = false;
                            });
                          }
                        });
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading inventory',
                            style: AppFonts.sfProStyle(
                                fontSize: 16, color: Colors.red),
                          ),
                        );
                      }

                      final groups = snapshot.data ?? [];
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
                              final bool selected =
                                  _selectedIds.contains(item.id);
                              return GestureDetector(
                                onLongPress: () async {
                                  if (!_multiSelectMode) {
                                    setState(() => _multiSelectMode = true);
                                  }
                                  if (_controller.isDuplicate(
                                      item.id, existingDocIds)) {
                                    await _showDuplicateDialog(item.name);
                                    return;
                                  }
                                  _toggleSelect(item);
                                },
                                onTap: () async {
                                  if (_multiSelectMode) {
                                    if (_controller.isDuplicate(
                                        item.id, existingDocIds)) {
                                      await _showDuplicateDialog(item.name);
                                      return;
                                    }
                                    _toggleSelect(item);
                                  } else {
                                    if (_controller.isOutOfStock(item)) {
                                      await _showOutOfStockDialog(item.name);
                                      return;
                                    }
                                    if (_controller.isDuplicate(
                                        item.id, existingDocIds)) {
                                      await _showDuplicateDialog(item.name);
                                      return;
                                    }
                                    Navigator.pop(
                                        context, _controller.toReturnMap(item));
                                  }
                                },
                                child: _buildInventoryStyleCard(
                                    context, item, selected),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                if (_multiSelectMode)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _selectedItems.isEmpty
                                  ? null
                                  : _submitSelection,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedItems.isEmpty
                                    ? Colors.grey[400]
                                    : const Color(0xFF00D4AA),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                _selectedItems.isEmpty
                                    ? 'Add (0)'
                                    : 'Add (${_selectedItems.length})',
                                style: AppFonts.sfProStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _multiSelectMode = false;
                                _selectedIds.clear();
                                _selectedItems.clear();
                              });
                            },
                            child: Text(
                              'Cancel',
                              style: AppFonts.sfProStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryStyleCard(
      BuildContext context, InventoryItem item, bool selected) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: selected
            ? Border.all(color: const Color(0xFF00D4AA), width: 2)
            : null,
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
              children: [
                // Product Image (exact same as inventory)
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
                    : Icon(Icons.image_not_supported,
                        size: 96, color: Colors.grey),
                const SizedBox(height: 16),

                // Product Name (exact same as inventory)
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
                const SizedBox(height: 10),

                // Stock Information (exact same as inventory)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Stock: ${item.stock}',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Expiry Date Information (exact same as inventory)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue[600],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _controller.formatExpiry(item.expiry, item.noExpiry),
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
            ),
          ),

          // Selection indicator
          if (_multiSelectMode)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF00D4AA) : scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF00D4AA)
                        : theme.dividerColor.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
