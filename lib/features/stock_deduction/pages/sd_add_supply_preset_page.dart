import 'package:flutter/material.dart';
import 'package:projects/shared/themes/font.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';
import 'package:projects/features/stock_deduction/controller/sd_add_supply_preset_controller.dart';

class StockDeductionAddSupplyForPresetPage extends StatefulWidget {
  const StockDeductionAddSupplyForPresetPage({super.key});

  @override
  State<StockDeductionAddSupplyForPresetPage> createState() =>
      _StockDeductionAddSupplyForPresetPageState();
}

class _StockDeductionAddSupplyForPresetPageState
    extends State<StockDeductionAddSupplyForPresetPage> {
  final TextEditingController _searchController = TextEditingController();
  final SdAddSupplyPresetController _controller = SdAddSupplyPresetController();
  String _searchText = '';
  bool _multiSelectMode = false;
  final Set<String> _selectedIds = {};
  final Map<String, GroupedInventoryItem> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(GroupedInventoryItem item) {
    setState(() {
      if (_selectedIds.contains(item.mainItem.id)) {
        _selectedIds.remove(item.mainItem.id);
        _selectedItems.remove(item.mainItem.id);
      } else {
        _selectedIds.add(item.mainItem.id);
        _selectedItems[item.mainItem.id] = item;
      }
    });
  }

  void _addSelectedItems() {
    if (_selectedItems.isEmpty) return;

    // Check for duplicates in existing selections
    final args = ModalRoute.of(context)?.settings.arguments;
    final Set<String> existingDocIds = _controller.parseExistingDocIds(args);

    // Check if any selected item is already in the existing list
    if (_controller.hasDuplicateItems(_selectedItems, existingDocIds)) {
      final duplicateName =
          _controller.getFirstDuplicateItemName(_selectedItems, existingDocIds);
      if (duplicateName != null) {
        _showDuplicateDialog(duplicateName);
      }
      return;
    }

    final List<Map<String, dynamic>> itemsToAdd =
        _controller.toReturnMapList(_selectedItems);
    Navigator.of(context).pop(itemsToAdd);
  }

  void _addSingleItem(GroupedInventoryItem item) {
    // Check for duplicates in existing selections
    final args = ModalRoute.of(context)?.settings.arguments;
    final Set<String> existingDocIds = _controller.parseExistingDocIds(args);

    if (_controller.isDuplicate(item.mainItem.id, existingDocIds)) {
      _showDuplicateDialog(item.mainItem.name);
      return;
    }

    final Map<String, dynamic> itemToAdd = _controller.toReturnMap(item);
    Navigator.of(context).pop([itemToAdd]);
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
            '"$name" is already in your preset list.',
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
                  stream: _controller.getGroupedSuppliesStream(archived: false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading inventory',
                          style: AppFonts.sfProStyle(fontSize: 16),
                        ),
                      );
                    }

                    final items = snapshot.data ?? [];
                    final filteredItems =
                        _controller.filterSupplies(items, _searchText);

                    if (filteredItems.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchText.isEmpty
                                  ? 'No supplies found'
                                  : 'No supplies match your search',
                              style: AppFonts.sfProStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
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
                        // Same ratio as PO add supply page for consistency
                        childAspectRatio: 0.9,
                      ),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final isSelected =
                            _selectedIds.contains(item.mainItem.id);

                        return GestureDetector(
                          onTap: _multiSelectMode
                              ? () => _toggleSelection(item)
                              : () => _addSingleItem(item),
                          onLongPress: () {
                            if (!_multiSelectMode) {
                              setState(() {
                                _multiSelectMode = true;
                                _selectedIds.add(item.mainItem.id);
                                _selectedItems[item.mainItem.id] = item;
                              });
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              // Highlight when selected (visual only)
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(0xFF00D4AA), width: 2)
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context)
                                      .shadowColor
                                      .withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
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
                                      item.mainItem.imageUrl.isNotEmpty
                                          ? Image.network(
                                              item.mainItem.imageUrl,
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
                                          item.mainItem.name,
                                          style: AppFonts.sfProStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color),
                                          textAlign: TextAlign.center,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_multiSelectMode)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF00D4AA)
                                            : Theme.of(context)
                                                .colorScheme
                                                .surface,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF00D4AA)
                                              : Theme.of(context)
                                                  .dividerColor
                                                  .withOpacity(0.4),
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              size: 16,
                                              color: Colors.white,
                                            )
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
                                : _addSelectedItems,
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
