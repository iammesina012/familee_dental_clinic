import 'package:flutter/material.dart';
import 'package:projects/shared/drawer.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';
import 'package:projects/features/inventory/components/inventory_item_card.dart';
import 'package:projects/features/inventory/components/inventory_fab.dart';
import 'package:projects/features/inventory/components/inventory_filter.dart';
import 'package:projects/features/inventory/components/inventory_sort.dart'; // Your sort modal
import 'package:projects/features/inventory/pages/add_supply_page.dart';
import 'package:projects/features/inventory/pages/view_supply_page.dart';
import 'package:projects/features/inventory/pages/add_category_page.dart';
import 'package:projects/features/inventory/pages/edit_categories_page.dart';
import '../controller/inventory_controller.dart';
import 'package:projects/features/inventory/pages/expired_supply_page.dart';
import '../controller/filter_controller.dart';
import '../controller/categories_controller.dart';
import 'package:projects/features/inventory/pages/archive_supply_page.dart';
import 'package:projects/shared/themes/font.dart';

class Inventory extends StatefulWidget {
  const Inventory({super.key});

  @override
  State<Inventory> createState() => _InventoryState();
}

class _InventoryState extends State<Inventory> {
  int selectedCategory = 0;
  String? _highlightSupplyName; // for deep-link from notifications
  bool _deepLinkHandled = false;
  // summary filter removed

  final TextEditingController searchController = TextEditingController();
  String searchText = '';

  String? selectedSort = "Name (A → Z)";

  // Filter state
  Map<String, dynamic> currentFilters = {};

  // Use the controller for all logic
  final InventoryController controller = InventoryController();
  final FilterController filterController = FilterController();
  final CategoriesController categoriesController = CategoriesController();

  // ─── Real-time State ─────────────────────────────────────────────────────
  Key _categoriesStreamKey = UniqueKey();
  Key _inventoryStreamKey = UniqueKey();

  // Add ScrollController for Choice Chips
  final ScrollController _chipsScrollController = ScrollController();

  // Map to store GlobalKeys for each chip
  final Map<int, GlobalKey> _chipKeys = {};

  // Method to refresh the categories stream
  void _refreshCategoriesStream() {
    setState(() {
      _categoriesStreamKey = UniqueKey();
    });
  }

  // Method to refresh the inventory stream
  void _refreshInventoryStream() {
    setState(() {
      _inventoryStreamKey = UniqueKey();
    });
  }

  // Method to refresh both streams
  void _refreshAllStreams() {
    setState(() {
      _categoriesStreamKey = UniqueKey();
      _inventoryStreamKey = UniqueKey();
    });
  }

  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => InventoryFilterModal(
        onApply: (filters) {
          setState(() {
            currentFilters = filters;
          });
        },
        currentFilters: currentFilters,
      ),
    );
  }

  void _showSortModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => InventorySortModal(
        selected: selectedSort,
        onSelect: (sort) {
          setState(() {
            selectedSort = sort;
          });
        },
      ),
    );
  }

  // Method to scroll to selected chip using GlobalKey for precise positioning
  void _scrollToSelectedChip(int index, List<String> categories) {
    if (index >= 0 &&
        index < categories.length &&
        _chipsScrollController.hasClients) {
      final key = _chipKeys[index];
      if (key?.currentContext != null) {
        final RenderBox renderBox =
            key!.currentContext!.findRenderObject() as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);
        final scrollPosition = _chipsScrollController.position.pixels +
            position.dx -
            16; // 16px padding from left

        _chipsScrollController.animateTo(
          scrollPosition.clamp(
              0.0, _chipsScrollController.position.maxScrollExtent),
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        // Fallback to estimated positioning if GlobalKey is not available
        double estimatedChipWidth = 140.0;
        double scrollPosition = index * estimatedChipWidth;
        double maxScroll = _chipsScrollController.position.maxScrollExtent;
        scrollPosition = scrollPosition.clamp(0.0, maxScroll);

        _chipsScrollController.animateTo(
          scrollPosition,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize default categories and migrate existing data
    _initializeData();
    // Best-effort cleanup of zero-stock duplicates when there are stocked batches
    controller.cleanupZeroStockDuplicates();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Capture deep-link arg once
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      if (_highlightSupplyName == null &&
          args['highlightSupplyName'] is String) {
        _highlightSupplyName = (args['highlightSupplyName'] as String).trim();
      }
      // removed: applyStatusFilter deep-link
    }
  }

  Future<void> _initializeData() async {
    await categoriesController.initializeDefaultCategories();
    await filterController.migrateExistingBrandsAndSuppliers();
  }

  @override
  void dispose() {
    searchController.dispose();
    _chipsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Inventory",
          style: AppFonts.sfProStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: theme.appBarTheme.iconTheme,
        elevation: theme.appBarTheme.elevation,
        shadowColor: theme.appBarTheme.shadowColor,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: Colors.red, size: 30),
              tooltip: 'Notifications',
              onPressed: () {
                Navigator.pushNamed(context, '/notifications');
              },
            ),
          ),
        ],
      ),
      drawer: const MyDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _refreshAllStreams();
            // Wait a bit for the streams to update
            await Future.delayed(Duration(milliseconds: 500));
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar + filter/sort
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: AppFonts.sfProStyle(
                            fontSize: 16,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.6),
                          ),
                          prefixIcon:
                              Icon(Icons.search, color: theme.iconTheme.color),
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
                              EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          filled: true,
                          fillColor: scheme.surface,
                        ),
                        onChanged: (value) {
                          setState(() {
                            searchText = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 48,
                      width: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: currentFilters.isNotEmpty
                              ? const Color(0xFF4E38D4)
                              : scheme.surface,
                          foregroundColor: currentFilters.isNotEmpty
                              ? Colors.white
                              : theme.textTheme.bodyMedium?.color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                        ),
                        onPressed: () => _showFilterModal(context),
                        child: Icon(Icons.filter_alt_outlined),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      width: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: scheme.surface,
                          foregroundColor: theme.textTheme.bodyMedium?.color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                        ),
                        onPressed: () => _showSortModal(context),
                        child: Icon(Icons.sort_by_alpha),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<String>>(
                  key: _categoriesStreamKey,
                  stream: categoriesController.getCategoriesStream(),
                  builder: (context, snapshot) {
                    final currentCategories = snapshot.data ?? [];
                    final List<String> categoriesWithAll = [
                      'All Supplies',
                      ...currentCategories
                    ];
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SizedBox(height: 50);
                    }

                    if (snapshot.hasError) {
                      return SizedBox(
                        height: 50,
                        child: Center(
                          child: Text(
                            'Error loading categories',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }

                    // Auto-scroll to selected chip when categories are loaded
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (selectedCategory < categoriesWithAll.length &&
                          _chipsScrollController.hasClients) {
                        _scrollToSelectedChip(
                            selectedCategory, categoriesWithAll);
                      }
                    });

                    // Clear old keys if categories changed
                    if (_chipKeys.length != categoriesWithAll.length) {
                      _chipKeys.clear();
                    }

                    return SingleChildScrollView(
                      controller: _chipsScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            List.generate(categoriesWithAll.length, (index) {
                          final isSelected = selectedCategory == index;
                          // Ensure we have a GlobalKey for this index
                          if (!_chipKeys.containsKey(index)) {
                            _chipKeys[index] = GlobalKey();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              key: _chipKeys[index],
                              label: Text(categoriesWithAll[index]),
                              selected: isSelected,
                              showCheckmark: false,
                              selectedColor: const Color(0xFF4E38D4),
                              backgroundColor: scheme.surface,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : theme.textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.bold,
                              ),
                              shape: StadiumBorder(
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF4E38D4)
                                      : theme.dividerColor,
                                ),
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  selectedCategory = index;
                                });
                                // Scroll to the selected chip
                                _scrollToSelectedChip(index, categoriesWithAll);
                              },
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Firestore-powered, category-filtered, search-filtered, responsive grid
                Expanded(
                  child: StreamBuilder<List<String>>(
                    key: _categoriesStreamKey,
                    stream: categoriesController.getCategoriesStream(),
                    builder: (context, categorySnapshot) {
                      final currentCategories = categorySnapshot.data ?? [];
                      final categoriesWithAll = [
                        'All Supplies',
                        ...currentCategories
                      ];
                      final selectedCategoryName = (selectedCategory == 0)
                          ? "" // empty means no category filter -> show all
                          : (selectedCategory < categoriesWithAll.length
                              ? categoriesWithAll[selectedCategory]
                              : "");

                      return StreamBuilder<List<GroupedInventoryItem>>(
                        key: _inventoryStreamKey,
                        stream: controller.getGroupedSuppliesStream(
                            archived: false),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: SizedBox(),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 64, color: Colors.red),
                                  SizedBox(height: 16),
                                  Text(
                                    'Error loading inventory',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Please try again later',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined,
                                      size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'No supplies found',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Add your first supply using the + button',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // Use controller to filter and sort grouped items
                          final sortedItems =
                              controller.filterAndSortGroupedItems(
                            items: snapshot.data!,
                            selectedCategory: selectedCategoryName,
                            searchText: searchText,
                            selectedSort: selectedSort,
                            filters: currentFilters,
                          );

                          // Filter out expired items from main inventory - they should only appear in Expired Supply page
                          // But keep non-expired batches even if other batches of the same product are expired
                          final visibleItems = sortedItems.where((item) {
                            return item.getStatus() != "Expired";
                          }).toList();

                          // Handle deep-link to specific supply once, after frame
                          if (!_deepLinkHandled &&
                              _highlightSupplyName != null &&
                              _highlightSupplyName!.isNotEmpty) {
                            GroupedInventoryItem? target;
                            for (final g in sortedItems) {
                              if (g.mainItem.name.toLowerCase() ==
                                  _highlightSupplyName!.toLowerCase()) {
                                target = g;
                                break;
                              }
                            }
                            if (target != null) {
                              _deepLinkHandled = true;
                              final t = target;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                // Check if this is a placeholder (0 stock, no expiry, and not expired)
                                if (t.mainItem.stock == 0 &&
                                    t.mainItem.noExpiry &&
                                    t.getStatus() != "Expired") {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '${t.mainItem.name} has expired and is no longer available.'),
                                      backgroundColor: Colors.orange,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          InventoryViewSupplyPage(
                                              item: t.mainItem),
                                    ),
                                  );
                                }
                              });
                            }
                          }

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              // Since cards now show expiry dates for expiring/expired items regardless of filters,
                              // use a more conservative aspect ratio to accommodate the extra height
                              double aspectRatio =
                                  constraints.maxWidth < 400 ? 0.7 : 0.85;
                              return GridView.builder(
                                  physics: AlwaysScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: aspectRatio,
                                  ),
                                  itemCount: visibleItems.length,
                                  itemBuilder: (context, index) {
                                    final groupedItem = visibleItems[index];
                                    return GestureDetector(
                                      onTap: () {
                                        // Check if this is a placeholder (0 stock, no expiry, and not expired)
                                        // Only show message for true placeholders, not expired items
                                        if (groupedItem.mainItem.stock == 0 &&
                                            groupedItem.mainItem.noExpiry &&
                                            groupedItem.getStatus() !=
                                                "Expired") {
                                          // Show a message for placeholder items
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  '${groupedItem.mainItem.name} has expired and is no longer available.'),
                                              backgroundColor: Colors.orange,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                          return;
                                        }
                                        // Allow navigation for all other items, including expired ones
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                InventoryViewSupplyPage(
                                                    item: groupedItem.mainItem),
                                          ),
                                        );
                                      },
                                      child: InventoryItemCard(
                                        item: groupedItem.mainItem,
                                        status: groupedItem.getStatus(),
                                        currentSort: selectedSort,
                                        overrideStock: groupedItem.totalStock,
                                      ),
                                    );
                                  });
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
      floatingActionButton: InventoryFAB(
        onAddSupply: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddSupplyPage(),
            ),
          );
          // Refresh inventory stream when returning from add page
          if (result == true || result == 'added') {
            _refreshInventoryStream();
          }
        },
        onArchivedSupply: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ArchiveSupplyPage(),
            ),
          );
          // Refresh inventory stream when returning from archive page
          if (result == true || result == 'unarchived') {
            _refreshInventoryStream();
          }
        },
        onExpiredSupply: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ExpiredSupplyPage(),
            ),
          );
          // Refresh inventory stream when returning from expired page
          if (result == true || result == 'disposed') {
            _refreshInventoryStream();
          }
        },
        onAddCategory: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddCategoryPage(),
            ),
          );
          // Refresh categories stream when returning from add page
          if (result == true || result == 'added') {
            _refreshCategoriesStream();
          }
        },
        onEditCategory: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditCategoriesPage(),
            ),
          );
          // Refresh categories stream when returning from edit page
          if (result == true || result == 'updated' || result == 'deleted') {
            _refreshCategoriesStream();
          }
        },
      ),
    );
  }

  // Info banner intentionally removed for Inventory
}
