import 'package:flutter/material.dart';
import 'package:projects/shared/themes/font.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';
import 'package:projects/features/stock_deduction/controller/sd_add_supply_controller.dart';

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

  Widget _expiryChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 12, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppFonts.sfProStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _stockChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 12, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppFonts.sfProStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    // Read existing selections to prevent duplicates
    final args = ModalRoute.of(context)?.settings.arguments;
    final Set<String> existingDocIds = _controller.parseExistingDocIds(args);
    return Scaffold(
      backgroundColor: const Color(0xFFF9EFF2),
      appBar: AppBar(
        title: Text(
          'Add Supply',
          style: AppFonts.sfProStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        toolbarHeight: 70,
        iconTheme: const IconThemeData(size: 30, color: Colors.black),
        elevation: 5,
        shadowColor: Colors.black54,
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchText = v),
                decoration: InputDecoration(
                  hintText: 'Search supplies...',
                  hintStyle: AppFonts.sfProStyle(
                      fontSize: 16, color: Colors.grey[600]),
                  prefixIcon: const Icon(Icons.search, color: Colors.black),
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
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<GroupedInventoryItem>>(
                  stream: _controller.getGroupedSuppliesStream(archived: false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF00D4AA)),
                      );
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

                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        // Taller tiles to better fit long names
                        childAspectRatio: 0.75,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final InventoryItem item = filtered[index]
                            .mainItem; // earliest-expiry with stock preference
                        final bool selected = _selectedIds.contains(item.id);
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
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              // Highlight when selected (visual only)
                              border: selected
                                  ? Border.all(
                                      color: const Color(0xFF00D4AA), width: 2)
                                  : null,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 4, 12, 4),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      item.imageUrl.isNotEmpty
                                          ? Image.network(
                                              item.imageUrl,
                                              width: 96,
                                              height: 96,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error,
                                                      stackTrace) =>
                                                  const Icon(
                                                      Icons.image_not_supported,
                                                      size: 96,
                                                      color: Colors.grey),
                                            )
                                          : const Icon(
                                              Icons.image_not_supported,
                                              size: 96,
                                              color: Colors.grey),
                                      const SizedBox(height: 16),
                                      Flexible(
                                        child: Text(
                                          item.name,
                                          style: AppFonts.sfProStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                          textAlign: TextAlign.center,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      _expiryChip('Expiry: ' +
                                          _controller.formatExpiry(
                                              item.expiry, item.noExpiry)),
                                      const SizedBox(height: 6),
                                      _stockChip(
                                          'Stock: ' + item.stock.toString()),
                                    ],
                                  ),
                                ),
                                if (_multiSelectMode)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? const Color(0xFF00D4AA)
                                            : Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(100),
                                        border: Border.all(
                                            color: selected
                                                ? const Color(0xFF00D4AA)
                                                : Colors.grey[400]!,
                                            width: 2),
                                      ),
                                      child: selected
                                          ? const Icon(Icons.check,
                                              color: Colors.white, size: 16)
                                          : null,
                                    ),
                                  ),
                              ],
                            ),
                          ),
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
    );
  }
}
